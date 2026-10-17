#!/usr/bin/env bash
# Usage: turn_off_sign.sh
# Turns off the open_sign smart plug and waits for it to confirm.
set -euo pipefail

topic="zigbee2mqtt/open_sign"
broker=lights-mosquitto

# The plug also sends frequent power readings, so watch several messages
# for the new state instead of trusting the first one that arrives
reply=$(mktemp)
docker exec "$broker" mosquitto_sub -t "$topic" -W 5 >"$reply" 2>/dev/null &
sub=$!
trap 'kill "$sub" 2>/dev/null || true; rm -f "$reply"' EXIT
sleep 0.3

docker exec "$broker" mosquitto_pub -t "$topic/set" -m '{"state":"OFF"}'

for _ in $(seq 25); do
    if grep -q '"state":"OFF"' "$reply"; then
        echo "open_sign is OFF"
        exit 0
    fi
    sleep 0.2
done

echo "open_sign: no confirmation from the plug within 5s" >&2
exit 1
