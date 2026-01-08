# Dotfiles

Personal dotfiles for **Arch Linux** on **Framework Laptop 13 AMD** with a triple window manager setup and Gruvbox Material Dark theme.

## Highlights

- **Triple WM**: i3 (X11) + Sway (Wayland) + Hyprland (Wayland) with synchronized configs
- **CachyOS Kernel**: znver4-optimized with EEVDF scheduler and sched-ext support
- **Performance Tuned**: ADIOS I/O scheduler, scx_lavd, power-profiles-daemon
- **Framework Optimized**: Proper S0i3 sleep, AMD P-State EPP, speaker EQ presets

## Window Managers

All three WMs share keybindings, colors, and workspace definitions via `~/.config/wm-common/`:

| WM | Display | Bar | Use Case |
|----|---------|-----|----------|
| i3wm | X11 | polybar | Daily driver, max compatibility |
| Sway | Wayland | waybar | Battery life, modern apps |
| Hyprland | Wayland | waybar | Eye candy (animations off by default) |

See [WM-SETUP.md](WM-SETUP.md) for complete documentation.

## Contents

### Window Managers
- `.config/wm-common/` - Shared keybindings, colors, modes
- `.config/i3/` - i3wm + X11-specific settings
- `.config/sway/` - Sway + Wayland-specific settings
- `.config/hypr/` - Hyprland configs (hyprpaper, hyprlock, hypridle)
- `.config/polybar/` - i3 status bar (hack theme)
- `.config/waybar/` - Sway/Hyprland status bar

### Shell & Terminal
- `.zshrc` - Zsh with starship prompt
- `.config/kitty/` - Kitty terminal (Gruvbox theme)
- `.config/atuin/` - Shell history sync
- `.config/starship.toml` - Prompt configuration

### Desktop Environment
- `.config/rofi/` - Application launcher
- `.config/dunst/` - Notifications
- `.config/picom/` - X11 compositor
- `.config/gtk-3.0/` - GTK theme settings

### CLI Tools
- `.config/btop/` - System monitor
- `.config/bat/` - Syntax-highlighted cat
- `.config/lazygit/` - Git TUI
- `.config/fastfetch/` - System info

### Performance & Hardware
- `system-configs/udev.rules.d/` - ADIOS I/O scheduler
- `system-configs/scx_loader/` - scx_lavd scheduler config
- `system-configs/modprobe.d/` - AMD GPU/PMC settings
- `.config/easyeffects/` - Framework speaker EQ presets
- `refind/` - rEFInd bootloader config

### System
- `.gitconfig` - Git configuration
- `.xinitrc`, `.xprofile` - X11 startup
- `CLAUDE.md` - Claude Code AI assistant context

## Installation

```bash
# Clone
git clone https://github.com/raold/dotfiles.git ~/rice/dotfiles-repo
cd ~/rice/dotfiles-repo

# Install user configs
./update.sh --install

# Install system configs (sudo required)
./update.sh --system
```

### WM-Specific Sync

```bash
# Sync all WM configs
./sync-wm.sh all --install

# Or individually
./sync-wm.sh i3 --install
./sync-wm.sh sway --install
./sync-wm.sh hyprland --install
```

## Updating

```bash
# Collect from system to repo
./update.sh --collect
./sync-wm.sh all --collect

# Push to system from repo
./update.sh --install
./sync-wm.sh all --install
```

## Dependencies

### Core
- zsh + starship
- kitty
- rofi (rofi-wayland for Wayland)
- dunst
- btop, bat, atuin, lazygit

### i3 (X11)
- i3-wm, polybar, picom, feh
- flameshot, greenclip, betterlockscreen

### Sway (Wayland)
- sway, waybar, swaybg, swaylock, swayidle
- grim, slurp, wl-clipboard, cliphist

### Hyprland (Wayland)
- hyprland, hyprpaper, hyprlock, hypridle
- (shares waybar, grim, slurp with Sway)

### Framework 13 AMD
- linux-cachyos (CachyOS kernel)
- power-profiles-daemon
- scx-scheds (sched-ext schedulers)
- easyeffects (speaker EQ)

## Theme

- **Colors**: Gruvbox Material Dark
- **GTK**: Gruvbox-Dark-B-LB
- **Icons**: Gruvbox-Plus-Dark
- **Cursor**: Bibata-Modern-Classic
- **Font**: CaskaydiaCove Nerd Font

## Hardware

Optimized for **Framework Laptop 13 AMD** (Ryzen 7040 series):
- AMD Radeon 780M integrated graphics
- Proper S0i3 sleep with kernel parameters
- ICC color profile for BOE display
- Speaker EQ for downward-firing speakers

## Documentation

- [WM-SETUP.md](WM-SETUP.md) - Complete triple WM guide
- [BOOT_ARCHITECTURE.md](BOOT_ARCHITECTURE.md) - rEFInd dual-boot setup
- [CLAUDE.md](CLAUDE.md) - System context for Claude Code

## License

Personal configuration files. Use freely.
