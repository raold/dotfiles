![Logo](https://preview.redd.it/i3-gruvboxed-my-framework-v0-cg37b1jz4xlc1.png?width=1080&crop=smart&auto=webp&s=9fcaa609a96859197b25a048af9fdf3868493d38)

# Dotfiles

Personal dotfiles for **Arch Linux** on **Framework Laptop 13 AMD** with a triple window manager setup and Gruvbox Material Dark theme.

## Highlights

- **Triple WM**: i3 (X11) + Sway (Wayland) + Hyprland (Wayland) with synchronized configs
- **CachyOS Kernel**: znver4-optimized with EEVDF scheduler and sched-ext support
- **Performance Tuned**: ADIOS I/O scheduler, scx_lavd, power-profiles-daemon
- **Framework Optimized**: Proper S0i3 sleep, AMD P-State EPP, speaker EQ presets
- **Display Manager**: greetd + ReGreet (GTK4 Wayland greeter)

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
- `.config/ghostty/` - Ghostty terminal (alternative)
- `.config/atuin/` - Shell history sync
- `.config/starship.toml` - Prompt configuration
- `.config/nvim/` - Neovim full config (Lua-based)

### Desktop Environment
- `.config/rofi/` - Application launcher
- `.config/dunst/` - Notifications
- `.config/picom/` - X11 compositor
- `.config/gtk-3.0/` - GTK3 theme settings
- `.config/gtk-4.0/` - GTK4 theme settings
- `.config/fontconfig/` - Font rendering (macOS-style: hintslight, stem darkening)

### CLI Tools
- `.config/btop/` - System monitor
- `.config/htop/` - htop layout config
- `.config/bat/` - Syntax-highlighted cat
- `.config/lazygit/` - Git TUI
- `.config/fastfetch/` - System info
- `.config/git/` - Global gitignore

### Custom Scripts (`.local/bin/`)
- `power-switch` - AC/battery power profile switching (systemd + udev triggered)
- `hyprland-power-switch` - Hyprland compositor power optimization (blur, animations, waybar polling)
- `battery-mode` - Aggressive battery optimization
- `spotify-theme` - Spotify theme customizer
- `update-mirrors` - Reflector + CachyOS mirror refresh
- `fix-keyring` - Emergency pacman keyring repair
- `clip2path` - Clipboard image to file path (kitty)
- `wttr` - Weather CLI

### Performance & Hardware
- `system-configs/udev.rules.d/` - ADIOS I/O scheduler
- `system-configs/scx_loader/` - scx_lavd scheduler config
- `system-configs/modprobe.d/` - AMD GPU/PMC settings
- `system-configs/systemd-system/` - Keyring update timer
- `system-configs/pacman.d/hooks/` - Keyring refresh hook
- `.config/easyeffects/` - Framework speaker EQ presets
- `.config/slimbookbattery/` - Battery profile manager
- `.local/share/icc/` - Framework display ICC profile
- `refind/` - rEFInd bootloader config

### Application Configs
- `.config/arch-update/` - arch-update configuration
- `.config/spotifyd/` - Spotify daemon
- `.config/spicetify/` - Spotify theming (Gruvbox)
- `.config/flameshot/` - Screenshot tool
- `.config/nnn/` - File manager bookmarks

### System
- `.gitconfig` - Git configuration
- `.xinitrc`, `.xprofile` - X11 startup
- `CLAUDE.md` - Claude Code AI assistant context (symlinked)
- `.claude/settings.json` - Claude Code settings (symlinked)
- `.config/systemd/user/` - User systemd services (spotifyd, dunst)

## Installation

```bash
# Clone
git clone https://github.com/raold/dotfiles.git ~/rice/dotfiles-repo
cd ~/rice/dotfiles-repo

# Install user configs
./update.sh --install

# Install system configs (sudo required)
./update.sh --system

# Set up symlinks for version-controlled configs
ln -s ~/rice/dotfiles-repo/CLAUDE.md ~/CLAUDE.md
mkdir -p ~/.claude
ln -s ~/rice/dotfiles-repo/.claude/settings.json ~/.claude/settings.json
ln -s ~/rice/dotfiles-repo/.claude/settings.local.json ~/.claude/settings.local.json
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
- Fractional scaling at 1.175 (1920×1280 logical on 2256×1504 panel)
- Dynamic power switching (blur/animations off on battery)
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
- **UI Font**: Inter (macOS-style rendering with stem darkening)
- **Terminal Font**: JetBrainsMono Nerd Font
- **Font Rendering**: hintslight + no subpixel AA (optimized for HiDPI)

## Hardware

Optimized for **Framework Laptop 13 AMD** (Ryzen 7040 series):
- AMD Radeon 780M integrated graphics
- Proper S0i3 sleep with kernel parameters
- ICC color profile for BOE display
- Speaker EQ for downward-firing speakers

## CachyOS Performance Stack

This setup uses the [CachyOS kernel](https://cachyos.org/) and performance packages for optimal desktop responsiveness:

### Kernel & CPU Scheduling

| Component | Setting | Purpose |
|-----------|---------|---------|
| **Kernel** | `linux-cachyos` | znver4-optimized for Zen 4 (Clang/LLVM, 1000Hz) |
| **CPU Scheduler** | `scx_lavd` via scx_loader | BPF-based scheduler for low-latency desktop use |
| **Fallback** | EEVDF | Default if scx_loader not running |
| **CPU Governor** | `amd-pstate-epp` | AMD's native power management with EPP hints |

**scx_lavd** is designed for interactive workloads (originally for Steam Deck) — prioritizes latency over throughput.

### I/O Scheduling

```bash
# system-configs/udev.rules.d/60-ioschedulers.rules
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="adios"
```

The **ADIOS** (Adaptive Deadline I/O Scheduler) is optimized for NVMe SSDs, providing better latency than the default `none` or `mq-deadline` schedulers while maintaining throughput.

### Power Management

- **power-profiles-daemon**: AMD-recommended over TLP (respects platform limits)
  - `powerprofilesctl set power-saver` — Battery focus
  - `powerprofilesctl set balanced` — Normal use
  - `powerprofilesctl set performance` — Full power
- **ananicy-cpp**: Auto-prioritizes processes (browsers get nice, builds get background)
- **irqbalance**: Distributes hardware interrupts across CPU cores

### System Services

```bash
# Enabled services
systemctl is-active scx_loader ananicy-cpp irqbalance power-profiles-daemon
```

### Configuration Files

| File | System Path | Purpose |
|------|-------------|---------|
| `scx_loader/config.toml` | `/etc/scx_loader/` | Default scheduler (scx_lavd, Auto mode) |
| `udev.rules.d/60-ioschedulers.rules` | `/etc/udev/rules.d/` | ADIOS for NVMe/SSD |
| `modprobe.d/amd-pmc.conf` | `/etc/modprobe.d/` | PMC soft-dep, disable STB |
| `modprobe.d/amdgpu.conf` | `/etc/modprobe.d/` | Disable PSR for stable resume |
| `systemd-system/keyring-update.*` | `/etc/systemd/system/` | Daily keyring sync (prevents signature failures) |
| `pacman.d/hooks/refresh-keyring.hook` | `/etc/pacman.d/hooks/` | Auto-populate keyring on update |

### Verify Setup

```bash
# Check active scheduler
cat /sys/kernel/sched_ext/root/ops  # Should show: lavd

# Check I/O scheduler
cat /sys/block/nvme0n1/queue/scheduler  # Should show: [adios]

# Check power profile
powerprofilesctl get  # balanced / power-saver / performance

# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver  # amd-pstate-epp
```

## Display Manager

**greetd + ReGreet** — GTK4 Wayland greeter running inside cage (kiosk compositor).

- Config: `/etc/greetd/config.toml`, `/etc/greetd/regreet.toml`
- Theme: Gruvbox Material Dark CSS (`/etc/greetd/regreet.css`)
- Wallpaper: `/usr/share/backgrounds/gruvbox/`
- Fallback: `ly` TUI greeter (installed but disabled)

See [CLAUDE.md](CLAUDE.md) for greetd configuration details and rollback instructions.

## Documentation

- [WM-SETUP.md](WM-SETUP.md) - Complete triple WM guide
- [BOOT_ARCHITECTURE.md](BOOT_ARCHITECTURE.md) - rEFInd dual-boot setup
- [CLAUDE.md](CLAUDE.md) - System context for Claude Code

## License

Personal configuration files. Use freely.
