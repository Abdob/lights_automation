#!/usr/bin/env bash
# Usage: turn_light.sh <light number> <on|off>
# Light N is the Zigbee2MQTT device named light_N.
set -euo pipefail

if [[ $# -ne 2 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Usage: $(basename "$0") <light number> <on|off>" >&2
    exit 2
fi

case "${2,,}" in
    on)  state=ON ;;
    off) state=OFF ;;
    *)   echo "State must be 'on' or 'off', got '$2'" >&2; exit 2 ;;
esac

topic="zigbee2mqtt/light_$1"
broker=lights-mosquitto

# Listen for the switch's confirmation before sending, so it can't be missed
reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
docker exec "$broker" mosquitto_sub -t "$topic" -C 1 -W 5 >"$reply" 2>/dev/null &
sub=$!
sleep 0.3

docker exec "$broker" mosquitto_pub -t "$topic/set" -m "{\"state\":\"$state\"}"

wait "$sub" || true
if grep -q "\"state\":\"$state\"" "$reply"; then
    echo "light_$1 is $state"
else
    echo "light_$1: no confirmation from the switch within 5s" >&2
    exit 1
fi
