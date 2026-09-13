#!/bin/bash
# Boot AOS 4.3 in a window and leave a root shell on the console.
. "$(dirname "$0")/common.sh"
check_environment
prepare_disk

if running; then
    fail "A machine is already up. Run stop.sh before starting another."
    exit 1
fi

cat <<'TXT'
Starting the IBM RT PC with AOS 4.3.

MAME shows TWO warning screens before the machine runs: the system information
one and the red "known problems" one. Press a key on each. The boot then takes
a couple of minutes and the root session opens on its own.

To shut down, run stop.sh. Do not just close the window.
TXT

export RIG_X=0
start_mame window
sleep 2
if ! running; then
    fail "The emulator did not start. Look at state/mame.log"
    exit 1
fi
echo "Up (pid $(cat "$PIDF")). Waiting for the console prompt..."
if log_in_and_start_x; then
    echo "Ready: there is a root shell in the window."
else
    echo "Taking longer than usual. Look at the window; the login is  root  with no password."
fi
