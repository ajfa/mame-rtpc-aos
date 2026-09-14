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
Starting the IBM RT PC with AOS 4.3 and X11 on the EGA card, with the mouse.

Nothing to press while it boots. In three to five minutes AOS boots, logs in
as root, and starts the X server, an xterm, a clock and the uwm window
manager. After that your real mouse drives the RT PC one.

The RT PC mouse has only two buttons, so the middle one is both at once: on
the background that is what brings up the WindowOps menu.

WATCH OUT FOR THE POINTER: while it is over the window, MAME keeps it. One
key does not give it back. In MAME's own code the pointer is released when
the emulation is PAUSED or when the pointer is outside the window, so the
sequence is: press Insert (keyboard goes to MAME), then P (pauses, and you
get the pointer back); move the pointer off the window and press P again to
carry on. From a terminal, ./stop.sh always works. If you would rather not
deal with it, start-x11.sh brings up the same desktop without taking the
mouse.

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
