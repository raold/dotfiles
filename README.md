# Dotfiles

Personal dotfiles for Arch Linux with i3wm.

## Contents

### Shell
- `.bashrc`, `.bash_profile` - Bash configuration
- `.zshrc`, `.p10k.zsh` - Zsh with Powerlevel10k theme
- `.profile` - Shell profile

### Window Manager & Desktop
- `.config/i3/` - i3wm configuration
- `.config/polybar/` - Polybar status bar
- `.config/rofi/` - Rofi application launcher
- `.config/dunst/` - Dunst notification daemon
- `.config/picom/` - Picom compositor

### Terminal & Editors
- `.config/kitty/` - Kitty terminal
- `.nanorc` - Nano editor configuration
- `.tmux.conf` - Tmux terminal multiplexer

### CLI Tools
- `.config/btop/` - Btop system monitor
- `.config/bat/` - Bat (cat replacement)
- `.config/atuin/` - Atuin shell history
- `.config/starship.toml` - Starship prompt
- `.config/neofetch/` - Neofetch system info
- `.config/lazygit/` - Lazygit TUI
- `.config/cava/` - Cava audio visualizer
- `.config/greenclip.toml` - Greenclip clipboard manager

### System
- `.gitconfig` - Git configuration
- `.xinitrc` - X11 init script
- `refind/` - rEFInd bootloader configuration
- `.config/psd/` - Profile-sync-daemon

## Installation

Clone this repository:
```bash
git clone https://github.com/raold/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Run the update script to sync dotfiles:
```bash
./update.sh --install
```

## Updating

To pull latest dotfiles from your system into the repo:
```bash
./update.sh --collect
```

To push repo dotfiles to your system:
```bash
./update.sh --install
```

## Dependencies

- zsh + oh-my-zsh + powerlevel10k
- i3-gaps
- polybar
- rofi
- dunst
- picom
- kitty
- btop, bat, atuin, starship, neofetch
- rEFInd (bootloader)
