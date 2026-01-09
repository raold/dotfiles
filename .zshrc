# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Plugins
plugins=(
    git
    sudo
    extract
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Zsh options
setopt AUTO_CD
setopt CORRECT
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

source $ZSH/oh-my-zsh.sh

# Aliases
alias zshconfig="nano ~/.zshrc"
alias ohmyzsh="nano ~/.oh-my-zsh"
alias i3config="nano ~/.config/i3/config"
alias polyconfig="nano ~/.config/polybar/config.ini"
alias kittyconfig="nano ~/.config/kitty/kitty.conf"
alias ls="eza -al"
alias lst3="eza -T --level=3"
alias powerst="upower -i /org/freedesktop/UPower/devices/battery_BAT1"
alias wttr="bash ~/rice/bash-script-wttr/wttr lynchburg"
alias dotfiles="cd ~/rice/dotfiles-repo && git status"
alias nfl="cd ~/rice/nfl-analytics && git status"

# PATH configuration (consolidated)
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/.spicetify:$PATH"
export PATH="$HOME/.lmstudio/bin:$PATH"
export PATH="/opt/rocm/bin:$PATH"

# ROCm
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export ROCM_PATH=/opt/rocm
export PYTORCH_ROCM_ARCH=gfx1103

# Starship prompt
eval "$(starship init zsh)"

# Zoxide (smarter cd)
eval "$(zoxide init zsh)"

# Atuin (shell history)
eval "$(atuin init zsh)"

# FZF keybindings and completion
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--color=bg+:#3c3836,bg:#282828,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934'

# Show system info on terminal start
fastfetch

# Centered bold tty-clock with Gruvbox yellow
alias clock='tty-clock -c -b -C 3'
