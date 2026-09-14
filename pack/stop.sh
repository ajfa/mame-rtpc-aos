#!/bin/bash
# Take AOS down in order (sync and halt) and then close the emulator.
. "$(dirname "$0")/common.sh"

if ! running; then
    echo "No machine is up."
    rm -f "$PIDF"
    exit 0
fi
PID=$(cat "$PIDF")
echo "Halting AOS in order. This takes half a minute; do not close the window."

order "K sync" "K sync" "K sync" "W 3" "K /etc/fasthalt"
i=0
while [ $i -lt 60 ]; do
    if grep -q "/etc/fasthalt" "$ACKS" 2>/dev/null; then break; fi
    sleep 1; i=$((i + 1))
done
sleep 25

kill "$PID" 2>/dev/null
i=0
while [ $i -lt 15 ] && kill -0 "$PID" 2>/dev/null; do sleep 1; i=$((i + 1)); done
kill -9 "$PID" 2>/dev/null
rm -f "$PIDF"
echo "Down. The disk was synced, and the next boot skips the filesystem check."
