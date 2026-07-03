#!/usr/bin/env bash
# Randomly cycles the Hyprland wallpaper among the top-level images in
# ~/Pictures/Wallpaper, changing once per hour. Re-scans the folder every
# cycle, so images added/removed later are picked up automatically.
#
# Uses hyprpaper's IPC: `hyprctl hyprpaper wallpaper "MONITOR,path"` which,
# in hyprpaper >= 0.8, auto-loads the image (no separate preload needed).

WALLPAPER_DIR="$HOME/Pictures/Wallpaper"
INTERVAL=2700   # seconds between changes (45 minutes)

# Single-instance guard via flock (avoids killing parent/wrapper shells).
LOCK="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-cycle.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

# Wait for hyprpaper's IPC to be ready (e.g. right after login).
for _ in $(seq 1 30); do
    hyprctl hyprpaper listactive >/dev/null 2>&1 && break
    sleep 1
done

last=""
while true; do
    # Collect top-level images only (no recursion into subfolders).
    mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) | sort)

    count=${#images[@]}
    if (( count == 0 )); then
        sleep "$INTERVAL" 9>&-
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
    sleep "$INTERVAL" 9>&-
done
