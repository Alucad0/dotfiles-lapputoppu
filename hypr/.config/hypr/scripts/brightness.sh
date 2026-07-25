#!/usr/bin/env bash
# Brightness up/down in 2.5% steps, snapped to the nearest multiple, never below 5%.
# Math is done in tenths of a percent since the step is fractional.
# Usage: brightness.sh up|down
set -euo pipefail

STEP=25    # tenths of a percent (25 = 2.5%)
MIN=50     # tenths of a percent (50 = 5%)
FULL=1000

max=$(brightnessctl m)
cur=$(brightnessctl g)

pct=$(( (cur * FULL + max / 2) / max ))     # current, rounded to nearest 0.1%
snap=$(( (pct + STEP / 2) / STEP * STEP ))  # nearest multiple of STEP

case "${1:-}" in
    up)   new=$(( snap + STEP )) ;;
    down) new=$(( snap - STEP )) ;;
    *)    echo "usage: $(basename "$0") up|down" >&2; exit 1 ;;
esac

if (( new < MIN )); then new=$MIN; fi
if (( new > FULL )); then new=$FULL; fi

brightnessctl -q set $(( (new * max + FULL / 2) / FULL ))
