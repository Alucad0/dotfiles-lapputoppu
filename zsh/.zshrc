# Powerlevel10k instant prompt — keep this at the top. Anything that prints to
# or reads from the console must go above it.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# oh-my-zsh + powerlevel10k — both are git clones, not packages; install.sh
# fetches them when the zsh package is linked (see README)
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Prompt appearance. `p10k configure` rewrites ~/.p10k.zsh, which is this
# repo's zsh/.p10k.zsh — so reconfiguring the prompt shows up in `git diff`.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# pipx shims + the scripts in the `bin` package (snapshot, screenshot)
export PATH="$HOME/.local/bin:$PATH"

# bun (the JS runtime; no node on these machines)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ccstatusline config TUI (runs via bun, no node installed)
alias ccstatusline="bun $HOME/.cache/.bun/bin/ccstatusline"

# Hyprland's log is ~99% libinput touchpad debug from aquamarine (gesture/tap
# state machines). `debug:disable_logs` doesn't gate those - they come from
# aquamarine's own logger - so filter them out when reading instead.
alias hyprlog="grep -vE 'DEBUG from aquamarine' \"\$(ls -t /run/user/\$UID/hypr/*/hyprland.log | head -1)\""
