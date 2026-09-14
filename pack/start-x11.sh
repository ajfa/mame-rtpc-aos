#!/bin/bash
# Boot AOS 4.3 and bring up X11 on the EGA, without handing MAME the mouse.
. "$(dirname "$0")/common.sh"
check_environment
prepare_disk

if running; then
    fail "A machine is already up. Run stop.sh before starting another."
    exit 1
fi

cat <<'TXT'
Starting the IBM RT PC with AOS 4.3 and X11 on the EGA card.

Nothing to press. In three to five minutes AOS boots, logs in as root, and
starts the X server, an xterm, a clock and the uwm window manager.

This one does NOT hand the mouse to the machine, so the pointer stays yours
and you can keep working on your desktop. For the RT PC mouse, use
start-x11-mouse.sh.

To shut down, run stop.sh. Do not just close the window.
TXT

export RIG_X=1
start_mame window-nomouse
sleep 2
if ! running; then
    fail "The emulator did not start. Look at state/mame.log"
    exit 1
fi
echo "Up (pid $(cat "$PIDF")). Waiting for AOS to boot and X11 to appear..."
if log_in_and_start_x; then
    note "X11 is up."
else
    echo "X11 did not confirm. Look at the window and at state/mame.log; the machine is still up."
fi
