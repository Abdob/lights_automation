#!/usr/bin/env bash
# Usage: dance.sh [rounds]
# Flashes lights 01-12 in patterns, then leaves them all on.
set -euo pipefail

rounds=${1:-3}
if [[ ! $rounds =~ ^[0-9]+$ ]]; then
    echo "Usage: $(basename "$0") [rounds]" >&2
    exit 2
fi

lights=(01 02 03 04 05 06 07 08 09 10 11 12)
broker=lights-mosquitto
beat=0.4

set_light() {
    docker exec "$broker" mosquitto_pub -t "zigbee2mqtt/light_$1/set" -m "{\"state\":\"$2\"}"
}

# Switch several lights at once: some <ON|OFF> <light>...
some() {
    local state=$1 l
    shift
    for l in "$@"; do set_light "$l" "$state" & done
    wait
}

all() {
    some "$1" "${lights[@]}"
}

n=${#lights[@]}
odd=() even=()
for ((i = 0; i < n; i++)); do
    if ((i % 2 == 0)); then odd+=("${lights[i]}"); else even+=("${lights[i]}"); fi
done

# Never leave the room dark, even on Ctrl-C
trap 'all ON' EXIT

for ((r = 1; r <= rounds; r++)); do
    # Chase: one light at a time, down the line and back
    all OFF
    for ((i = 0; i < n; i++)); do
        set_light "${lights[i]}" ON; sleep "$beat"; set_light "${lights[i]}" OFF
    done
    for ((i = n - 2; i > 0; i--)); do
        set_light "${lights[i]}" ON; sleep "$beat"; set_light "${lights[i]}" OFF
    done

    # Fill up, then drain
    for l in "${lights[@]}"; do set_light "$l" ON; sleep "$beat"; done
    for l in "${lights[@]}"; do set_light "$l" OFF; sleep "$beat"; done

    # Odd vs even
    for _ in 1 2 3; do
        some ON "${odd[@]}"; some OFF "${even[@]}"; sleep "$beat"
        some OFF "${odd[@]}"; some ON "${even[@]}"; sleep "$beat"
    done
    all OFF

    # Close in from both ends, then open back out
    for ((i = 0; i < n / 2; i++)); do
        some ON "${lights[i]}" "${lights[n - 1 - i]}"; sleep "$beat"
    done
    for ((i = n / 2 - 1; i >= 0; i--)); do
        some OFF "${lights[i]}" "${lights[n - 1 - i]}"; sleep "$beat"
    done

    # All together
    for _ in 1 2; do
        all ON; sleep "$beat"
        all OFF; sleep "$beat"
    done
done
