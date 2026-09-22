#!/usr/bin/env bash
# Symlinks every file in the given packages (default: all) into $HOME,
# mirroring the repo's directory structure — GNU stow layout, no stow needed.
# Existing real files are moved to ~/.dotfiles-backup/<timestamp>/ first.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ALL_PACKAGES=(hypr waybar kitty ccstatusline waypaper zsh git claude pictures vscode fontconfig wofi gtk bin kde xdg)

PACKAGES=("${@:-${ALL_PACKAGES[@]}}")

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
        mkdir -p "$(dirname "$dest")"
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
            continue  # already linked
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            mkdir -p "$BACKUP/$(dirname "$rel")"
            mv "$dest" "$BACKUP/$rel"
            echo "backed up: ~/$rel"
        fi
        ln -s "$src" "$dest"
        echo "linked: ~/$rel"
    done < <(find "$REPO/$pkg" -type f -print0)
done

# oh-my-zsh + powerlevel10k are git clones, not packages. Cloned directly
# rather than run through omz's install.sh, which would overwrite the ~/.zshrc
# symlink this script just created.
if [[ " ${PACKAGES[*]} " == *" zsh "* ]]; then
    OMZ="$HOME/.oh-my-zsh"
    P10K="$OMZ/custom/themes/powerlevel10k"
    if [ ! -d "$OMZ" ]; then
        echo "cloning oh-my-zsh"
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ"
    fi
    if [ ! -d "$P10K" ]; then
        echo "cloning powerlevel10k"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K"
    fi
fi

# GTK theme (Catppuccin Mocha, green accent) — downloaded into ~/.themes, not vendored here
if [[ " ${PACKAGES[*]} " == *" gtk "* ]]; then
    GTK_THEME_NAME="catppuccin-mocha-green-standard+default"
    GTK_THEME_URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3/$GTK_THEME_NAME.zip"
    if [ ! -d "$HOME/.themes/$GTK_THEME_NAME" ]; then
        echo "downloading GTK theme: $GTK_THEME_NAME"
        mkdir -p "$HOME/.themes"
        curl -sL --fail "$GTK_THEME_URL" | bsdtar -xf - -C "$HOME/.themes"
    fi
    # libadwaita (GTK4) apps ignore gtk-theme-name and read css straight from ~/.config/gtk-4.0
    mkdir -p "$HOME/.config/gtk-4.0"
    ln -sfn "$HOME/.themes/$GTK_THEME_NAME/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    ln -sfn "$HOME/.themes/$GTK_THEME_NAME/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
    ln -sfn "$HOME/.themes/$GTK_THEME_NAME/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"
    # xdg-desktop-portal-gtk (file choosers) reads the theme from dconf, not settings.ini
    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME"
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    fi
fi

echo "done. backups (if any) in $BACKUP"
