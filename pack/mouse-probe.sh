#!/bin/bash
# Does the host mouse reach the emulator at all? It does not boot AOS: it
# watches the emulated mouse ports, which follow the real mouse whether or
# not the machine is up.
. "$(dirname "$0")/common.sh"
check_environment
prepare_disk

if running; then
    fail "A machine is up. Run stop.sh first."
    exit 1
fi

cat <<'TXT'
Mouse test.

The emulator window is about to open. MOVE THE MOUSE IN CIRCLES OVER THAT
WINDOW for twenty seconds, and click its buttons a couple of times.

No need to wait for AOS: what is being measured is whether the motion reaches
the emulator at all.
TXT

: > "$ORDERS"; : > "$ACKS"
export RIG_X=0
export SDL_VIDEODRIVER=x11
nohup "$DIR/mame/rtpc" rtpc025 \
    -rompath "$DIR/roms" -hard1 "$DISK" -isa3 ega \
    -cfg_directory "$DIR/cfg" -snapshot_directory "$DIR/shots" \
    -autoboot_script "$DIR/mouse-probe.lua" -autoboot_delay 1 \
    -nothrottle -skip_gameinfo -seconds_to_run 120 \
    -window -nomaximize -sound none -mouse -uimodekey INSERT \
    > "$LOGD/mame.log" 2>&1 &
echo $! > "$PIDF"
disown 2>/dev/null || true

echo
echo "Move the mouse over the window NOW..."
i=0
while [ $i -lt 90 ]; do
    if grep -q VERDICT "$ACKS" 2>/dev/null; then break; fi
    sleep 1
    i=$((i + 1))
done
sleep 1
kill "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null
sleep 2
kill -9 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null
rm -f "$PIDF"

echo
echo "=============================================================="
cat "$ACKS"
echo "=============================================================="
echo
if grep -q "MOUSE-REACHES-MAME" "$ACKS" 2>/dev/null; then
    echo "The mouse DOES reach the emulator. If the pointer still does not move"
    echo "inside X, the problem is on the AOS side, not the host."
else
    echo "The mouse does NOT reach the emulator. That is a host problem."
    echo
    echo "In a VirtualBox guest the cause is mouse integration: with it on, the"
    echo "pointer is absolute and the relative motion MAME wants never arrives."
    echo "Turn it off in the VM window, Input menu, Mouse Integration, or with"
    echo "Host+I, and run this again."
    echo
    echo "On bare metal, the other known cause is SDL under Wayland: log in"
    echo "picking Xorg from the cog on the login screen."
fi
