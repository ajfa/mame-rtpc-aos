#!/bin/bash
# Throw the working disk away and go back to the freshly installed AOS.
. "$(dirname "$0")/common.sh"

if running; then
    fail "A machine is up. Run stop.sh first."
    exit 1
fi
if [ ! -f "$DISK" ]; then
    echo "There is no working disk: you are already on the original."
    exit 0
fi
rm -f "$DISK"
rm -rf "$DIR/cfg" "$DIR/shots" "$DIR/state"
mkdir -p "$DIR/cfg" "$DIR/shots" "$DIR/state"
echo "Done. The next start copies the original disk again."
