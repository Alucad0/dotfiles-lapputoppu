#!/usr/bin/env bash
# Promote wallpaper(s) into the repo: moves the real file into the
# pictures package (keeping its subpath under ~/Pictures/Wallpaper)
# and symlinks it back, so hyprpaper/waypaper/the cycler still see it.
#   ./add-wallpaper.sh ~/Pictures/Wallpaper/girl.jpg [more...]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WP_HOME="$HOME/Pictures/Wallpaper"
WP_REPO="$REPO/pictures/Wallpaper"

for img in "$@"; do
    img="$(realpath -s "$img")"
    case "$img" in
        "$WP_HOME"/*) ;;
        *) echo "skip (not under $WP_HOME): $img" >&2; continue ;;
    esac
    rel="${img#"$WP_HOME"/}"
    if [ -L "$img" ]; then
        echo "already a symlink: $rel" >&2
        continue
    fi
    mkdir -p "$WP_REPO/$(dirname "$rel")"
    mv "$img" "$WP_REPO/$rel"
    ln -s "$WP_REPO/$rel" "$img"
    echo "promoted: $rel"
done

echo "-> commit & push in $REPO to sync"
