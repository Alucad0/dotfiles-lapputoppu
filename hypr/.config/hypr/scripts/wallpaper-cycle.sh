#!/usr/bin/env bash
# Randomly cycles the Hyprland wallpaper among the top-level images in
# ~/Pictures/Wallpaper, changing every INTERVAL seconds. Re-scans the folder
# every cycle, so images added/removed later are picked up automatically.
# SIGUSR1 (sent by waybar's wallpaper-select.sh after a manual pick) restarts
# the timer without changing the wallpaper, so the pick stays a full interval.
#
# Uses hyprpaper's IPC: `hyprctl hyprpaper wallpaper "MONITOR,path"` which,
# in hyprpaper >= 0.8, auto-loads the image (no separate preload needed).

WALLPAPER_DIR="$HOME/Pictures/Wallpaper"
INTERVAL=900   # seconds between changes (15 minutes)

# Single-instance guard via flock (avoids killing parent/wrapper shells).
LOCK="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-cycle.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

# Wait for hyprpaper's IPC to be ready (e.g. right after login).
for _ in $(seq 1 30); do
    hyprctl hyprpaper listactive >/dev/null 2>&1 && break
    sleep 1
done

# Interruptible wait: background sleep + wait, so a trapped USR1 wakes us
# right away instead of after the remaining sleep. The child closes fd 9 so
# it can't hold the flock alive.
snooze() {
    sleep "$INTERVAL" 9>&- &
    wait $!
    kill $! 2>/dev/null
}

skip_change=0
trap 'skip_change=1' USR1

last=""
while true; do
    # A manual pick just happened: keep it, restart the timer.
    if (( skip_change )); then
        skip_change=0
        snooze
        continue
    fi

    # Collect top-level images only (no recursion into subfolders).
    mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) | sort)

    count=${#images[@]}
    if (( count == 0 )); then
        snooze
        continue
    fi

    # Pick a random image, avoiding an immediate repeat when possible.
    if (( count == 1 )); then
        img="${images[0]}"
    else
        while :; do
            img="${images[RANDOM % count]}"
            [[ "$img" != "$last" ]] && break
        done
    fi

    # Apply to every connected monitor (names fetched fresh each cycle).
    while read -r mon; do
        [ -n "$mon" ] && hyprctl hyprpaper wallpaper "$mon,$img" >/dev/null 2>&1
    done < <(hyprctl monitors | awk '/^Monitor/{print $2}')

    last="$img"
    snooze
done
