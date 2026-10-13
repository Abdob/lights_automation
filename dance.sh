#!/usr/bin/env bash
# Usage: dance.sh [rounds]
# Flashes lights 02-04 in patterns, then leaves them all on.
set -euo pipefail

rounds=${1:-3}
if [[ ! $rounds =~ ^[0-9]+$ ]]; then
    echo "Usage: $(basename "$0") [rounds]" >&2
    exit 2
fi

lights=(02 03 04)
broker=lights-mosquitto
beat=0.4

set_light() {
    docker exec "$broker" mosquitto_pub -t "zigbee2mqtt/light_$1/set" -m "{\"state\":\"$2\"}"
}

all() {
    for l in "${lights[@]}"; do set_light "$l" "$1"; done
}

# Never leave the room dark, even on Ctrl-C
trap 'all ON' EXIT

for ((r = 1; r <= rounds; r++)); do
    # Chase: one light at a time, down the line and back
    all OFF
    for l in 02 03 04 03 02; do
        set_light "$l" ON
        sleep "$beat"
        set_light "$l" OFF
    done

    # Fill up, then drain
    for l in "${lights[@]}"; do set_light "$l" ON; sleep "$beat"; done
    for l in "${lights[@]}"; do set_light "$l" OFF; sleep "$beat"; done

    # Outside vs middle
    for _ in 1 2; do
        set_light 02 ON; set_light 04 ON; set_light 03 OFF
        sleep "$beat"
        set_light 02 OFF; set_light 04 OFF; set_light 03 ON
        sleep "$beat"
    done

    # All together
    for _ in 1 2; do
        all ON
        sleep "$beat"
        all OFF
        sleep "$beat"
    done
done
