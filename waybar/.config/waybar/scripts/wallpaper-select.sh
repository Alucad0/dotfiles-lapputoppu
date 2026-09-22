#!/usr/bin/env bash
# Wallpaper picker behind the waybar image icon: wofi thumbnail grid of every
# theme's wallpapers (~/Pictures/Wallpaper/<theme>/), the current theme's
# first. Other themes' entries are tagged with their theme's name, and picking
# one switches the whole desktop to that theme. The pick goes through
# ~/.local/bin/theme (hyprpaper IPC + SDDM sync), then the cycler gets USR1 so
# its auto-cycle timer restarts at a full interval without immediately
# replacing the manual pick.

THEME="$HOME/.local/bin/theme"
current="$("$THEME")"

# current theme first, then the rest in their usual order
mapfile -t order < <(printf '%s\n' "$current"; "$THEME" list | grep -vxF -- "$current")

images=() labels=()
for t in "${order[@]}"; do
    while IFS= read -r img; do
        [ -n "$img" ] || continue
        name="$(basename "$img")"; name="${name%.*}"
        [ "$t" = "$current" ] || name="$name · $t"
        images+=("$img"); labels+=("$name")
    done < <("$THEME" images "$t")
done
(( ${#images[@]} > 0 )) || exit 0


choice=$(for i in "${!images[@]}"; do
        printf 'img:%s:text:%s\n' "${images[i]}" "${labels[i]}"
    done | wofi --dmenu --allow-images --define image_size=110 \
        --columns 4 --width 640 --height 480 --prompt "wallpaper — $("$THEME" label)" \
        --insensitive --hide-scroll --cache-file /dev/null)
[ -n "$choice" ] || exit 0

# wofi may echo back the raw "img:PATH:text:NAME" line or just NAME
case "$choice" in
    img:*)
        img="${choice#img:}"
        img="${img%%:text:*}"
        ;;
    *)
        img=""
        for i in "${!labels[@]}"; do
            [ "${labels[i]}" = "$choice" ] && img="${images[i]}" && break
        done
        ;;
esac
[ -f "$img" ] || exit 1

# switches theme first if the image lives in another theme's folder
"$THEME" wallpaper "$img"

# restart the auto-cycle timer (no-op if the cycler isn't running); exact
# command-line match so an editor with the script open doesn't get the USR1
pkill -USR1 -fx '(/usr/bin/)?bash .*/wallpaper-cycle\.sh' 2>/dev/null
exit 0
