# dotfiles — lapputoppu

The dotfiles for my riced Arch Linux setup. Catppuccin Mocha everywhere.

| | |
|---|---|
| WM | [Hyprland](https://hyprland.org/) + hyprpaper (wallpaper cycler in `hypr/scripts/`) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) — frosted islands, per-core CPU dropdown (`waybar/scripts/`) |
| Terminal | kitty — Monokai Vibrant, deliberately: it matches the VS Code theme rather than the Mocha rest |
| Shell | zsh + oh-my-zsh + powerlevel10k (`zsh/.p10k.zsh` is the prompt) |
| Launcher | wofi — Mocha-styled drun menu (`wofi/`) |
| Login | [SDDM](https://github.com/sddm/sddm) + [sugar-candy](https://github.com/Kangie/sddm-sugar-candy) theme (`sddm/`, system config — see below) |
| Editor | VS Code — settings in `vscode/`, extensions in `vscode-extensions.txt`, CodeNewRoman Nerd Font in editor + integrated terminal |
| Qt/KDE apps | Breeze Dark via `kde/.config/kdeglobals`; Hyprland exports `QT_QPA_PLATFORMTHEME=kde` |
| Portals | `xdg/` pins the xdg-desktop-portal backends — hyprland for screencast, GTK for file dialogs and dark mode |
| Screenshots | `bin/.local/bin/{snapshot,screenshot}` — full screen (SUPER+P) and drag-to-select |
| Claude Code | ccstatusline status line + settings |
| Fonts | CodeNewRoman [Nerd Font](https://www.nerdfonts.com/cheat-sheet) for icons, Noto CJK + Color Emoji for Japanese/emoji — `fontconfig/` prefers the JP glyph variants and adds emoji fallback |

## Preview

![waybar](preview_waybar.png)

## Layout

Every top-level directory is a "package" mirroring its layout relative to `$HOME`
(GNU stow style — `waybar/.config/waybar/config.jsonc` → `~/.config/waybar/config.jsonc`,
`pictures/Pictures/Wallpaper/deer.jpg` → `~/Pictures/Wallpaper/deer.jpg`).

Exception: `sddm/` holds system config (files under `/etc` and `/usr/share`), so
`install.sh` refuses to symlink it — install it manually, see below.

Configs use `$HOME` rather than absolute paths wherever the consumer runs them
through a shell, so nothing here is tied to this username.

## Install (new machine)

```sh
# 1. packages (pacman takes no comments on stdin, hence the grep)
grep -vE '^\s*(#|$)' packages.txt | sudo pacman -S --needed -

# 2. AUR packages — bootstrap yay first if it isn't there:
#    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
grep -vE '^\s*(#|$)' packages-aur.txt | yay -S --needed -

# 3. dotfiles
git clone git@github.com:Alucad0/dotfiles-lapputoppu.git
cd dotfiles-lapputoppu
./install.sh                 # symlink everything
./install.sh -n              # ...or dry-run it first
./install.sh waybar zsh      # ...or just some packages

# 4. services
sudo systemctl enable --now NetworkManager bluetooth sddm
systemctl --user enable --now wireplumber

# 5. make zsh the login shell
chsh -s /bin/zsh
```

`install.sh` symlinks every file into place and moves anything it would
overwrite to `~/.dotfiles-backup/<timestamp>/`. It also clones oh-my-zsh and
powerlevel10k (with the `zsh` package) and downloads the Catppuccin GTK theme
(with the `gtk` package). No dependencies — but the layout is stow-compatible,
so `stow */` works too if you prefer.

`./uninstall.sh` reverses it: it removes symlinks that point into this repo and
leaves real files and the backups alone. It takes the same package arguments
and `-n`.

Editing a linked file edits the repo copy: `git diff` in the repo shows your
uncommitted tweaks, `git pull` updates both machines. That includes the prompt —
`p10k configure` rewrites `~/.p10k.zsh`, which is `zsh/.p10k.zsh` here.

`./add-wallpaper.sh ~/Pictures/Wallpaper/foo.jpg` promotes a new wallpaper into
the `pictures` package and links it back, so hyprpaper and the cycler keep
seeing it.

## Manual bits not covered

- **SDDM**: the sddm package itself is in `packages.txt`, but the
  [sugar-candy theme](https://github.com/Kangie/sddm-sugar-candy) is not in the
  repos — install it from the AUR (`sddm-sugar-candy-git`) or clone it into
  `/usr/share/sddm/themes/sugar-candy`. Then copy the configs (root-owned, so
  no symlinks — re-copy after editing):

  ```sh
  sudo cp sddm/sddm.conf.d/zz-sugar-candy.conf /etc/sddm.conf.d/
  sudo cp sddm/themes/sugar-candy/theme.conf /usr/share/sddm/themes/sugar-candy/
  sudo cp sddm/themes/sugar-candy/Components/Input.qml /usr/share/sddm/themes/sugar-candy/Components/
  sudo chown "$USER" /usr/share/sddm/themes/sugar-candy/Backgrounds/current.jpg
  sudo systemctl enable sddm
  ```

  `theme.conf` restyles the theme (blur, cyan accent, `AllowBadUsernames` for
  the lowercase login). `Input.qml` patches two upstream bugs: the last user
  not being prefilled, and the ComboBox rendering a stray first-letter of the
  username behind the user icon (`displayText: ""`).

  The login background is `Backgrounds/current.jpg` — the wallpaper scripts
  (`wallpaper-cycle.sh`, `wallpaper-select.sh`) overwrite it on every wallpaper
  change so the greeter matches the session. That's what the `chown` above is
  for; without it the scripts silently skip the sync.
- **bun** (JS runtime, no node on these machines): `curl -fsSL https://bun.sh/install | bash`,
  then `bun install -g ccstatusline`. The Claude Code status line and the
  `ccstatusline` zsh alias expect it at `~/.bun` / `~/.cache/.bun/bin`.
- **VS Code extensions**: `grep -vE '^\s*(#|$)' vscode-extensions.txt | xargs -n1 code --install-extension`.

## Known gaps

Deliberately not set up yet, listed so they don't get rediscovered as bugs:

- **No notification daemon.** `libnotify` is installed but nothing owns
  `org.freedesktop.Notifications`, so `notify-send` hangs and no app can notify.
  Fix by installing `mako` or `swaync` and autostarting it in `hyprland.lua`.
- **No lock screen or idle handling** (`hyprlock` / `hypridle`) — the laptop
  never locks on lid close or idle, and never suspends on idle.
- **No clipboard tooling** — `wl-clipboard` isn't installed, so there's no
  `wl-copy` and no `cliphist` history.
- **No polkit agent** (`hyprpolkitagent`), so GUI apps can't raise an auth
  prompt (mounting a drive from Dolphin, for instance).
