#!/usr/bin/env bash
# Randomly cycles the Hyprland wallpaper among the images of the *current
# theme* (~/Pictures/Wallpaper/<theme>/, see ~/.local/bin/theme), changing
# every INTERVAL seconds. It never switches theme on its own — that's the
# selector's and `theme set`/`theme next`'s job; this only follows along.
# Re-reads the theme and re-scans its folder every cycle, so theme switches
# and images added/removed later are picked up automatically.
# SIGUSR1 (sent after a manual pick or a theme switch) restarts the timer
# without changing the wallpaper, so that pick stays up a full interval.

THEME="$HOME/.local/bin/theme"
INTERVAL=1200  # seconds between changes (20 minutes)

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
    # A manual pick / theme switch just happened: keep it, restart the timer.
    if (( skip_change )); then
        skip_change=0
        snooze
        continue
    fi

    mapfile -t images < <("$THEME" images)

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

    # Applies to every monitor and keeps the SDDM background in sync
    "$THEME" wallpaper "$img"

    last="$img"
    snooze
done
