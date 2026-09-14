# Shared settings for the launchers. Not meant to be run on its own.
#
# Expected layout next to this file:
#   mame/rtpc                 MAME built with the patches in ../patch
#   roms/                     the ROMs MAME asks for under rtpc025, plus ega
#   disk/aos43-installed.chd  your own installed AOS 4.3 disk
#   template/rtpc025.cfg      MAME config carrying the 16 MB memory setting
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

ORIGINAL="$DIR/disk/aos43-installed.chd"
DISK="$DIR/disk/work.chd"
ORDERS="$DIR/state/orders"
ACKS="$DIR/state/acks"
PIDF="$DIR/state/mame.pid"
LOGD="$DIR/state"

export LD_LIBRARY_PATH="$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export RIG_KEYS="$DIR/keys.lua"
export RIG_CMD="$ORDERS"
export RIG_ACK="$ACKS"

note() {
    echo "$*"
    if command -v zenity > /dev/null 2>&1; then
        zenity --info --no-wrap --title "AOS 4.3 on the RT PC" --text "$*" > /dev/null 2>&1 &
    fi
}

fail() {
    echo "ERROR: $*" >&2
    if command -v zenity > /dev/null 2>&1; then
        zenity --error --no-wrap --title "AOS 4.3 on the RT PC" --text "$*" > /dev/null 2>&1 &
    fi
}

check_environment() {
    case "$DIR" in
        *" "*) fail "The directory name cannot contain spaces:
$DIR"; exit 1 ;;
    esac
    if [ ! -x "$DIR/mame/rtpc" ]; then
        fail "mame/rtpc is missing or not executable."; exit 1
    fi
    if ! "$DIR/mame/rtpc" -help > /dev/null 2>&1; then
        fail "The emulator does not run on this machine. It said:
$("$DIR/mame/rtpc" -help 2>&1 | head -3)"
        exit 1
    fi
    if ! command -v python3 > /dev/null 2>&1; then
        fail "python3 is needed to look at what is on the screen."
        exit 1
    fi
    mkdir -p "$DIR/state" "$DIR/cfg" "$DIR/shots"
}

prepare_disk() {
    # MAME keeps the memory size (16 MB, in the :mmu:MCR config ports) in its
    # own config file and rewrites that file on exit, so keep a pristine copy
    # and put it back whenever it goes missing
    mkdir -p "$DIR/cfg"
    if ! grep -q "mmu:MCR" "$DIR/cfg/rtpc025.cfg" 2>/dev/null; then
        cp "$DIR/template/rtpc025.cfg" "$DIR/cfg/rtpc025.cfg"
    fi
    if [ ! -f "$DISK" ]; then
        echo "First run: copying the working disk, this takes a few seconds..."
        cp "$ORIGINAL" "$DISK" || { fail "Could not copy the disk."; exit 1; }
    fi
}

running() {
    if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then return 0; fi
    return 1
}

start_mame() {
    # $1 = window|headless ; anything after that goes to MAME
    local mode=$1; shift
    : > "$ORDERS"; : > "$ACKS"
    local extra=""
    if [ "$mode" = headless ]; then
        extra="-video none -sound none"
        unset DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE
        export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
    elif [ "$mode" = window-nomouse ]; then
        # SDL under Wayland is unreliable with the pointer: ask for X11, which
        # on Ubuntu goes through XWayland and behaves
        export SDL_VIDEODRIVER=x11
        extra="-window -nomaximize -sound none"
    else
        export SDL_VIDEODRIVER=x11
        extra="-window -nomaximize -sound none -mouse -uimodekey INSERT"
    fi
    # nohup so the machine survives the launcher, and the terminal closing
    # shellcheck disable=SC2086
    nohup "$DIR/mame/rtpc" rtpc025 \
        -rompath "$DIR/roms" \
        -hard1 "$DISK" \
        -isa3 ega \
        -cfg_directory "$DIR/cfg" \
        -snapshot_directory "$DIR/shots" \
        -autoboot_script "$DIR/rig.lua" -autoboot_delay 1 \
        -nothrottle -skip_gameinfo \
        -seconds_to_run 2000000 \
        $extra "$@" > "$LOGD/mame.log" 2>&1 &
    echo $! > "$PIDF"
    disown 2>/dev/null || true
}

wait_ack() {
    # $1 = text that has to show up in the acks, $2 = seconds to wait
    local i=0
    while [ "$i" -lt "${2:-600}" ]; do
        if grep -q "$1" "$ACKS" 2>/dev/null; then return 0; fi
        if [ -f "$PIDF" ] && ! kill -0 "$(cat "$PIDF")" 2>/dev/null; then return 2; fi
        sleep 1
        i=$((i + 1))
    done
    return 1
}

order() {
    printf '%s\n' "$@" >> "$ORDERS"
}

# --- looking at what is on the emulated screen ------------------------------
# MAME writes real PNGs even without a window, so the shell can look at the
# machine: the AOS text console is black with a little red text (about 4 per
# cent of the sampled points light), and the X11 desktop is a dense weave with
# white windows on it (about 25 per cent, more once a window is open).
light() {
    python3 "$DIR/../tools/count-light.py" "$1" 2>/dev/null | awk '{print $1}'
}

percent() {
    python3 "$DIR/../tools/count-light.py" "$1" 2>/dev/null | awk '{printf "%d", $1 * 100 / $2}'
}

latest_shot() {
    ls -t "$DIR/shots"/*_"$1".png 2>/dev/null | head -1
}

look() {
    # $1 = name for the snapshot; echoes the file it produced
    local before now i=0
    before=$(latest_shot "$1")
    order "S $1"
    while [ $i -lt 300 ]; do
        now=$(latest_shot "$1")
        if [ -n "$now" ] && [ "$now" != "$before" ]; then
            sleep 1
            echo "$now"
            return 0
        fi
        if [ -f "$PIDF" ] && ! kill -0 "$(cat "$PIDF")" 2>/dev/null; then return 1; fi
        sleep 1
        i=$((i + 1))
    done
    return 1
}

wait_for_prompt() {
    # AOS takes as long as the host lets it to run /etc/rc, and the login
    # prompt has no fixed time. The clue is the screen going still. The
    # snapshots cannot be compared byte for byte: the cursor at the prompt
    # blinks, so two in a row never come out identical. Compare the number of
    # light points instead, which the cursor moves by a handful.
    local png n prev same=0 i=0
    prev=""
    while [ $i -lt 60 ]; do
        png=$(look idle) || return 1
        n=$(light "$png")
        if [ -z "$n" ]; then return 1; fi
        if [ -n "$prev" ]; then
            local d=$((n - prev))
            if [ $d -lt 0 ]; then d=$((-d)); fi
            if [ $d -le 25 ]; then
                same=$((same + 1))
                echo "     screen still for $same readings ($n points)"
                if [ $same -ge 2 ]; then return 0; fi
            else
                same=0
                echo "     screen still changing ($prev -> $n points)"
            fi
        else
            echo "     first reading of the screen: $n points"
        fi
        prev=$n
        sleep 15
        i=$((i + 1))
    done
    return 1
}

log_in_and_start_x() {
    # waits for the prompt, tells the rig to log in and start X11, and looks
    # at the screen to see whether it worked; retries if it did not
    local try png pct before now i
    # give the machine all the time it needs to come up before looking
    if ! wait_ack "started" 3000; then return 1; fi
    for try in 1 2 3 4; do
        echo "     try $try: waiting for the console prompt..."
        wait_for_prompt || return 1
        before=$(grep -c "L done" "$ACKS" 2>/dev/null); before=${before:-0}
        order "L"
        i=0
        while [ $i -lt 1200 ]; do
            now=$(grep -c "L done" "$ACKS" 2>/dev/null); now=${now:-0}
            if [ "$now" -gt "$before" ]; then break; fi
            if [ -f "$PIDF" ] && ! kill -0 "$(cat "$PIDF")" 2>/dev/null; then return 1; fi
            sleep 2
            i=$((i + 2))
        done
        if [ "$RIG_X" != "1" ]; then return 0; fi
        png=$(look probe) || return 1
        pct=$(percent "$png")
        echo "     try $try: $pct per cent of the screen is light"
        if [ -n "$pct" ] && [ "$pct" -gt 10 ]; then return 0; fi
    done
    return 1
}
