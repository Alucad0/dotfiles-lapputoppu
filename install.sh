#!/usr/bin/env bash
# Symlinks every file in the given packages (default: all) into $HOME,
# mirroring the repo's directory structure — GNU stow layout, no stow needed.
# Existing real files are moved to ~/.dotfiles-backup/<timestamp>/ first.
#
#   ./install.sh                # link everything
#   ./install.sh waybar zsh     # ...or just some packages
#   ./install.sh -n             # dry run: print what would happen, change nothing
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ALL_PACKAGES=(hypr waybar kitty ccstatusline waypaper zsh git claude pictures
              vscode fontconfig wofi gtk bin kde xdg)

DRY_RUN=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        -h|--help)    sed -n '2,8p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)           echo "!! unknown flag: $arg" >&2; exit 1 ;;
        *)            ARGS+=("$arg") ;;
    esac
done

PACKAGES=("${ARGS[@]:-${ALL_PACKAGES[@]}}")

# Every mutating command goes through this, so --dry-run is one code path.
run() {
    if (( DRY_RUN )); then
        printf 'would:'; printf ' %q' "$@"; printf '\n'
    else
        "$@"
    fi
}

for pkg in "${PACKAGES[@]}"; do
    if [ "$pkg" = sddm ]; then
        echo "!! sddm is system config, not a \$HOME package — see README (sudo cp)" >&2
        exit 1
    fi
    if [ ! -d "$REPO/$pkg" ]; then
        echo "!! unknown package: $pkg (available: ${ALL_PACKAGES[*]})" >&2
        exit 1
    fi
    while IFS= read -r -d '' src; do
        rel="${src#"$REPO/$pkg/"}"
        dest="$HOME/$rel"
        run mkdir -p "$(dirname "$dest")"
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
            continue  # already linked
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            run mkdir -p "$BACKUP/$(dirname "$rel")"
            run mv "$dest" "$BACKUP/$rel"
            echo "backed up: ~/$rel"
        fi
        run ln -s "$src" "$dest"
        echo "linked: ~/$rel"
    done < <(find "$REPO/$pkg" -type f -print0)
done

# Links whose repo file was moved or renamed (e.g. wallpapers sorted into theme
# folders) are left dangling by the loop above. Remove those — only symlinks
# that point into this repo and resolve to nothing — from every directory a
# linked file lives in, plus its parents up to $HOME.
declare -A DIRS=()
for pkg in "${PACKAGES[@]}"; do
    while IFS= read -r -d '' src; do
        dir="$(dirname "$HOME/${src#"$REPO/$pkg/"}")"
        while [ "$dir" != "$HOME" ] && [ "$dir" != / ]; do
            DIRS[$dir]=1
            dir="$(dirname "$dir")"
        done
    done < <(find "$REPO/$pkg" -type f -print0)
done
for dir in "${!DIRS[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r -d '' link; do
        case "$(readlink "$link")" in
            "$REPO"/*) run rm "$link"; echo "removed dangling: ~/${link#"$HOME/"}" ;;
        esac
    done < <(find "$dir" -maxdepth 1 -xtype l -print0)
done

# oh-my-zsh + powerlevel10k are git clones, not packages. Cloned directly
# rather than run through omz's install.sh, which would overwrite the ~/.zshrc
# symlink this script just created.
if [[ " ${PACKAGES[*]} " == *" zsh "* ]]; then
    OMZ="$HOME/.oh-my-zsh"
    P10K="$OMZ/custom/themes/powerlevel10k"
    if [ ! -d "$OMZ" ]; then
        echo "cloning oh-my-zsh"
        run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ"
    fi
    if [ ! -d "$P10K" ]; then
        echo "cloning powerlevel10k"
        run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"
    fi
fi

# GTK theme (Catppuccin Mocha, green accent) — downloaded into ~/.themes, not vendored here
if [[ " ${PACKAGES[*]} " == *" gtk "* ]]; then
    GTK_THEME_NAME="catppuccin-mocha-green-standard+default"
    GTK_THEME_URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3/$GTK_THEME_NAME.zip"
    if [ ! -d "$HOME/.themes/$GTK_THEME_NAME" ]; then
        echo "downloading GTK theme: $GTK_THEME_NAME"
        run mkdir -p "$HOME/.themes"
        if (( DRY_RUN )); then
            echo "would: curl -sL $GTK_THEME_URL | bsdtar -xf - -C $HOME/.themes"
        else
            curl -sL --fail "$GTK_THEME_URL" | bsdtar -xf - -C "$HOME/.themes"
        fi
    fi
    # libadwaita (GTK4) apps ignore gtk-theme-name and read css straight from ~/.config/gtk-4.0
    run mkdir -p "$HOME/.config/gtk-4.0"
    run ln -sfn "$HOME/.themes/$GTK_THEME_NAME/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    run ln -sfn "$HOME/.themes/$GTK_THEME_NAME/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
    run ln -sfn "$HOME/.themes/$GTK_THEME_NAME/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"
    # xdg-desktop-portal-gtk (file choosers) reads the theme from dconf, not settings.ini
    if command -v gsettings >/dev/null; then
        run gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME"
        run gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    fi
fi

if (( DRY_RUN )); then
    echo "dry run — nothing was changed."
else
    echo "done. backups (if any) in $BACKUP"
    echo "not covered here: packages, services and SDDM — see the README."
fi
