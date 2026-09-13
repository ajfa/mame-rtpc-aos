#!/bin/bash
# Headless check: boot AOS, confirm X11 comes up on the EGA, move the mouse,
# open the uwm menu with both buttons, halt in order, and say GREEN or RED.
# Leaves the evidence in shots/.
. "$(dirname "$0")/common.sh"
VERDICT=none
trap 'rc=$?; if [ $rc -eq 0 ] && [ "$VERDICT" = none ]; then echo "RED: the check ended without reaching a verdict."; exit 1; fi' EXIT

check_environment
prepare_disk

if running; then
    fail "A machine is up. Run stop.sh first."
    exit 1
fi

echo "Headless check. Five to fifteen minutes depending on the host."
echo "Cores available: $(nproc)"
rm -f "$DIR/shots"/*.png 2>/dev/null

export RIG_X=1
start_mame headless
sleep 3
if ! running; then
    echo "RED: the emulator did not start. Look at state/mame.log"; VERDICT=red; exit 1
fi

finish() {
    order "K sync" "K sync" "K /etc/halt"
    sleep 40
    kill "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; sleep 5
    kill -9 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null
    rm -f "$PIDF"
}

echo "1/4  waiting for AOS to boot and X11 to appear..."
if ! log_in_and_start_x; then
    echo "RED: X11 never appeared. Look at shots/ and state/mame.log"
    finish; VERDICT=red; exit 1
fi
echo "     X11 is on screen."

echo "2/4  moving the mouse onto the root window..."
for i in 1 2 3 4 5 6 7; do order "X 40 0" "W 0.4"; done
order "W 2"
IDLE=$(look 1-desktop) || IDLE=""

echo "3/4  pressing both buttons to bring up the WindowOps menu..."
order "B 160" "W 4"
MENU=$(look 2-menu-open) || MENU=""
order "B 0" "W 3"
CLOSED=$(look 3-menu-closed) || CLOSED=""

echo "4/4  halting AOS in order..."
finish

BAD=0
if [ -z "$IDLE" ] || [ -z "$MENU" ] || [ -z "$CLOSED" ]; then
    echo "RED: could not take the snapshots for the mouse test."; BAD=1
else
    A=$(light "$IDLE"); B=$(light "$MENU"); C=$(light "$CLOSED")
    echo "     light points: desktop $A, menu open $B, released $C"
    UP=$((B - C))
    if [ "$UP" -lt 150 ]; then
        echo "RED: pressing both buttons opened no menu ($UP points of difference)."
        echo "     the mouse is not reaching the guest."
        BAD=1
    else
        echo "     the menu added $UP light points"
    fi
fi

if [ "$BAD" -eq 0 ]; then
    echo
    echo "GREEN: AOS 4.3 boots, X11 comes up on the EGA, and the mouse moves the"
    echo "       pointer and opens the menu. Evidence in shots/."
    VERDICT=green
    exit 0
fi
echo
echo "RED: look at state/mame.log and shots/."
VERDICT=red
exit 1
