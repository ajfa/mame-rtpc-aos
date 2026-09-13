#!/bin/bash
# Boot AOS 4.3 and bring up X11 on the EGA, with the mouse working.
. "$(dirname "$0")/common.sh"
check_environment
prepare_disk

if running; then
    fail "A machine is already up. Run stop.sh before starting another."
    exit 1
fi

cat <<'TXT'
Starting the IBM RT PC with AOS 4.3 and X11 on the EGA card.

MAME shows TWO warning screens before the machine runs: the system information
one and the red "known problems" one. Press a key on each.

After that it takes three to five minutes: AOS boots, logs in as root, starts
the X server, an xterm, a clock and the uwm window manager.

Once it is up your real mouse drives the RT PC one. The RT PC mouse has only
two buttons, so the middle button is both at once: on the background that is
what brings up the WindowOps menu.

To release the mouse from MAME's window, press Insert.
To shut down, run stop.sh. Do not just close the window.
TXT

export RIG_X=1
start_mame window
sleep 2
if ! running; then
    fail "The emulator did not start. Look at state/mame.log"
    exit 1
fi
echo "Up (pid $(cat "$PIDF")). Waiting for AOS to boot and X11 to appear..."
if log_in_and_start_x; then
    note "X11 is up. The mouse now drives the RT PC."
else
    echo "X11 did not confirm. Look at the window and at state/mame.log; the machine is still up."
fi
