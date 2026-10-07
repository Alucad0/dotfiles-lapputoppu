#!/bin/sh
# Re-light eDP-1 after s2idle resume. Hyprland's dpms dispatcher (and even
# hyprctl reload) silently no-op when run in the first seconds after wake —
# they return "ok" while the output stays disabled — so retry with growing
# delays until hyprctl monitors actually reports the display on.
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/resume-fix.log"
echo "--- resume $(date '+%F %T') ---" >>"$LOG"

for delay in 1 2 3 5 8 13; do
    sleep "$delay"
    hyprctl reload >>"$LOG" 2>&1
    sleep 1
    hyprctl dispatch "hl.dsp.dpms({ mode = 'on' })" >>"$LOG" 2>&1
    sleep 1
    if hyprctl monitors | grep -q 'dpmsStatus: 1'; then
        echo "display on after +${delay}s attempt" >>"$LOG"
        exit 0
    fi
    echo "attempt at +${delay}s failed, dpmsStatus still 0" >>"$LOG"
done

echo "giving up: display still off after all attempts" >>"$LOG"
exit 1
