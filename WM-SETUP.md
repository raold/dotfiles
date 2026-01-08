# Triple Window Manager Setup Guide

Comprehensive documentation for the synchronized i3 + Sway + Hyprland configuration on Framework Laptop 13 AMD.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Quick Start](#quick-start)
5. [Sync Scripts Reference](#sync-scripts-reference)
6. [Package Requirements](#package-requirements)
7. [Keybinding Reference](#keybinding-reference)
8. [Configuration Files](#configuration-files)
9. [Workflow Examples](#workflow-examples)
10. [Testing Guide](#testing-guide)
11. [Troubleshooting](#troubleshooting)
12. [Battery Optimization](#battery-optimization)

---

## Overview

### The Three Window Managers

| WM | Display Server | Config Compatibility | Best For |
|----|----------------|---------------------|----------|
| **i3wm** | X11 | Source of truth | Daily driver, max app compatibility |
| **Sway** | Wayland | 99% i3 compatible | Battery life, modern Wayland apps |
| **Hyprland** | Wayland | Different syntax | Eye candy (animations disabled for battery) |

### Why Three WMs?

- **i3**: Mature, stable, works with everything (screen sharing, legacy apps)
- **Sway**: Better battery, native Wayland, drop-in i3 replacement
- **Hyprland**: Modern features, smooth animations (when you want them)

### The Synchronization Problem

Without sync, you'd maintain 3 separate configs. Change a keybinding? Edit 3 files. Forget one? Inconsistent experience.

### The Solution

A shared config directory (`~/.config/wm-common/`) containing:
- All keybindings
- Color scheme (Gruvbox Material Dark)
- Workspace definitions
- Window rules
- Modes (resize, gaps, power menu)

i3 and Sway use `include` to import these directly. Hyprland uses translated versions.

---

## Architecture

### Config Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    wm-common/ (Source of Truth)             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ variables    │ │ colors       │ │ keybindings          │ │
│  │ .conf        │ │ .conf        │ │ .conf                │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ workspaces   │ │ modes        │ │ window-rules         │ │
│  │ .conf        │ │ .conf        │ │ .conf                │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
           │                    │                    │
           │ include            │ include            │ translate
           ▼                    ▼                    ▼
    ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
    │    i3wm     │      │    Sway     │      │  Hyprland   │
    │   config    │      │   config    │      │   configs   │
    │             │      │             │      │             │
    │ + X11       │      │ + Wayland   │      │ + Wayland   │
    │   specific  │      │   specific  │      │   specific  │
    └─────────────┘      └─────────────┘      └─────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
    │   polybar   │      │   waybar    │      │   waybar    │
    │   picom     │      │   swaybg    │      │  hyprpaper  │
    │   feh       │      │  swaylock   │      │  hyprlock   │
    │  flameshot  │      │  swayidle   │      │  hypridle   │
    │  greenclip  │      │  cliphist   │      │  cliphist   │
    └─────────────┘      └─────────────┘      └─────────────┘
```

### Tool Mapping

| Function | i3 (X11) | Sway (Wayland) | Hyprland (Wayland) |
|----------|----------|----------------|-------------------|
| Compositor | picom | Built-in | Built-in |
| Bar | polybar | waybar | waybar |
| Notifications | dunst | dunst | dunst |
| Launcher | rofi | rofi-wayland | rofi-wayland |
| Screenshots | flameshot | grim + slurp | grim + slurp |
| Wallpaper | feh | swaybg | hyprpaper |
| Display config | xrandr | swaymsg output | hyprctl monitors |
| Color profile | xcalib | (sway color mgmt) | (env vars) |
| Clipboard | greenclip | cliphist | cliphist |
| Screen lock | betterlockscreen | swaylock | hyprlock |
| Idle mgmt | xss-lock | swayidle | hypridle |

---

## Directory Structure

### System Configuration (`~/.config/`)

```
~/.config/
│
├── wm-common/                      # ★ SHARED SOURCE OF TRUTH ★
│   ├── variables.conf              # $mod, $term, gap values
│   ├── colors.conf                 # Gruvbox Material Dark palette
│   ├── keybindings.conf            # All keyboard shortcuts
│   ├── workspaces.conf             # Workspace names and bindings
│   ├── modes.conf                  # Resize, gaps, power modes
│   └── window-rules.conf           # Borders, gaps, scratchpads
│
├── i3/
│   ├── config                      # Main config (includes wm-common/*)
│   └── config.backup-*             # Automatic backups
│
├── sway/
│   └── config                      # Main config (includes wm-common/*)
│
├── hypr/
│   ├── hyprland.conf               # Main config (sources below)
│   ├── colors.conf                 # Auto-generated from wm-common
│   ├── keybindings.conf            # Manually synced (different syntax)
│   ├── workspaces.conf             # Auto-generated from wm-common
│   ├── window-rules.conf           # Hyprland window rules
│   ├── hyprland-specific.conf      # Battery optimizations, misc
│   ├── hyprpaper.conf              # Wallpaper configuration
│   ├── hypridle.conf               # Idle/sleep management
│   └── hyprlock.conf               # Lock screen appearance
│
├── polybar/                        # i3 bar (X11)
│   └── hack/                       # Current theme
│       ├── config.ini
│       ├── colors.ini
│       ├── modules.ini
│       └── scripts/
│
├── waybar/                         # Sway/Hyprland bar (Wayland)
│   ├── config                      # JSON configuration
│   └── style.css                   # Gruvbox styling
│
├── rofi/                           # Application launcher (all WMs)
├── dunst/                          # Notifications (all WMs)
├── picom/                          # Compositor (i3 only)
└── kitty/                          # Terminal (all WMs)
```

### Repository Structure (`~/rice/dotfiles-repo/`)

```
dotfiles-repo/
│
├── README.md                       # General dotfiles readme
├── WM-SETUP.md                     # ★ THIS FILE ★
├── update.sh                       # Original dotfiles sync
│
├── lib/
│   └── common.sh                   # Shared bash functions
│
├── sync-wm.sh                      # Main dispatcher script
├── sync-shared.sh                  # Sync wm-common/
├── sync-i3.sh                      # Sync i3 + polybar + picom
├── sync-sway.sh                    # Sync sway + waybar
├── sync-hyprland.sh                # Sync hyprland + waybar
├── translate-hyprland.sh           # Regenerate hyprland from wm-common
│
├── .config/                        # Config mirror (repo copies)
│   ├── wm-common/
│   ├── i3/
│   ├── sway/
│   ├── hypr/
│   ├── waybar/
│   ├── polybar/
│   └── [other configs...]
│
├── .claude/                        # Claude Code settings
├── refind/                         # Boot config backups
└── system-configs/                 # /etc/* backups
```

### Session Files (`~/.local/share/wayland-sessions/`)

```
wayland-sessions/
├── sway.desktop                    # Sway session for display manager
└── hyprland.desktop                # Hyprland session for display manager
```

---

## Quick Start

### If You Just Want i3 (Already Working)

```bash
# Reload to pick up new modular config
i3-msg reload
# Or press: Super+Shift+r
```

### Adding Sway

```bash
# 1. Install packages
sudo pacman -S sway waybar swaybg swaylock swayidle \
    grim slurp wl-clipboard rofi-wayland cliphist \
    xdg-desktop-portal-wlr

# 2. Test from TTY
#    Press Ctrl+Alt+F2, login, then:
sway

# 3. Exit Sway
#    Press Super+Shift+e, then 'e' for exit
```

### Adding Hyprland

```bash
# 1. Install packages
sudo pacman -S hyprland hyprpaper hyprlock hypridle \
    xdg-desktop-portal-hyprland

# 2. Test from TTY
Hyprland

# 3. Exit Hyprland
#    Press Super+Shift+e
```

### Switching Between WMs

From your display manager (if using one), select:
- "i3" for i3wm
- "Sway" for Sway
- "Hyprland" for Hyprland

Or from TTY:
```bash
# Start specific WM
startx           # i3 (via .xinitrc)
sway             # Sway
Hyprland         # Hyprland
```

---

## Sync Scripts Reference

### Main Dispatcher: `sync-wm.sh`

```bash
./sync-wm.sh <target> <action>
```

**Targets:**
- `shared` - wm-common/ only
- `i3` - i3 + polybar + picom
- `sway` - Sway + waybar
- `hyprland` - Hyprland + waybar
- `all` - Everything

**Actions:**
- `--collect` - Copy from system to repo
- `--install` - Copy from repo to system
- `--validate` - Check configs without changing

### Examples

```bash
cd ~/rice/dotfiles-repo

# Before committing changes
./sync-wm.sh all --collect
git add -A && git commit -m "Update configs"

# Fresh machine setup
./sync-wm.sh all --install

# Just validate everything works
./sync-wm.sh all --validate

# Only sync shared keybindings
./sync-wm.sh shared --collect

# Only sync i3 stuff
./sync-wm.sh i3 --install
```

### Individual Scripts

| Script | Purpose | Syncs |
|--------|---------|-------|
| `sync-shared.sh` | Shared configs | `~/.config/wm-common/` |
| `sync-i3.sh` | i3 ecosystem | `i3/`, `polybar/`, `picom/` |
| `sync-sway.sh` | Sway ecosystem | `sway/`, `waybar/` |
| `sync-hyprland.sh` | Hyprland ecosystem | `hypr/`, `waybar/` |
| `translate-hyprland.sh` | Regenerate Hyprland | colors.conf, workspaces.conf |

### translate-hyprland.sh

Run this after modifying `wm-common/` to update Hyprland's generated files:

```bash
./translate-hyprland.sh
```

This regenerates:
- `~/.config/hypr/colors.conf` (from wm-common/colors.conf)
- `~/.config/hypr/workspaces.conf` (from wm-common/workspaces.conf)

**Note:** `keybindings.conf` must be manually updated for Hyprland due to syntax differences.

### Original Script: `update.sh`

Still works for general dotfiles:

```bash
./update.sh --collect    # System → Repo (all dotfiles)
./update.sh --install    # Repo → System (all dotfiles)
./update.sh --system     # Install /etc/* configs (sudo required)
./update.sh --refind     # Install rEFInd boot config (sudo required)
```

---

## Package Requirements

### Core (All WMs)

```bash
# Terminal & tools
sudo pacman -S kitty dunst brightnessctl pamixer playerctl rofi

# Already installed on your system
```

### i3 Stack (X11)

```bash
sudo pacman -S \
    i3-wm \
    polybar \
    picom \
    feh \
    flameshot \
    xcalib \
    xclip \
    betterlockscreen \
    greenclip \
    xss-lock \
    dex
```

### Sway Stack (Wayland)

```bash
sudo pacman -S \
    sway \
    waybar \
    swaybg \
    swaylock \
    swayidle \
    grim \
    slurp \
    wl-clipboard \
    rofi-wayland \
    cliphist \
    xdg-desktop-portal-wlr
```

### Hyprland Stack (Wayland)

```bash
sudo pacman -S \
    hyprland \
    hyprpaper \
    hyprlock \
    hypridle \
    xdg-desktop-portal-hyprland

# Shares with Sway: waybar, grim, slurp, wl-clipboard, rofi-wayland, cliphist
```

### AUR Packages (Optional)

```bash
# If using yay
yay -S betterlockscreen greenclip
```

---

## Keybinding Reference

All keybindings are **identical** across i3, Sway, and Hyprland.

### Legend

- `$mod` = Super (Windows) key
- `+` = Press together
- `,` = Then press

### Core Actions

| Keybinding | Action |
|------------|--------|
| `$mod + Return` | Open terminal (kitty) |
| `$mod + Shift + q` | Kill focused window |
| `$mod + d` | Open application launcher |
| `$mod + c` | Open calculator |
| `$mod + p` | Open clipboard history |

### Window Focus (jkl; Layout)

| Keybinding | Action |
|------------|--------|
| `$mod + j` | Focus left |
| `$mod + k` | Focus down |
| `$mod + l` | Focus up |
| `$mod + ;` (semicolon) | Focus right |
| `$mod + Left/Down/Up/Right` | Arrow key alternatives |

### Window Movement

| Keybinding | Action |
|------------|--------|
| `$mod + Shift + j` | Move window left |
| `$mod + Shift + k` | Move window down |
| `$mod + Shift + l` | Move window up |
| `$mod + Shift + ;` | Move window right |
| `$mod + Shift + Arrow` | Arrow key alternatives |

### Layout Control

| Keybinding | Action |
|------------|--------|
| `$mod + h` | Split horizontal |
| `$mod + v` | Split vertical |
| `$mod + f` | Toggle fullscreen |
| `$mod + s` | Stacking layout |
| `$mod + w` | Tabbed layout |
| `$mod + e` | Toggle split orientation |
| `$mod + Shift + Space` | Toggle floating |
| `$mod + Space` | Toggle focus (tiling/floating) |
| `$mod + a` | Focus parent container |

### Workspaces

| Keybinding | Action |
|------------|--------|
| `$mod + 1` through `$mod + 0` | Switch to workspace 1-10 |
| `$mod + Shift + 1` through `$mod + Shift + 0` | Move window to workspace 1-10 |
| `$mod + Tab` | Switch to previous workspace |

### Modes

| Keybinding | Action |
|------------|--------|
| `$mod + r` | Enter **resize** mode |
| `$mod + Shift + g` | Enter **gaps** mode |
| `$mod + Shift + e` | Enter **power** mode |

#### Resize Mode (`$mod + r`)

| Key | Action |
|-----|--------|
| `j` / `Left` | Shrink width |
| `;` / `Right` | Grow width |
| `k` / `Down` | Grow height |
| `l` / `Up` | Shrink height |
| `Escape` / `Return` | Exit mode |

#### Gaps Mode (`$mod + Shift + g`)

| Key | Action |
|-----|--------|
| `i` | Inner gaps submenu |
| `o` | Outer gaps submenu |
| `+` / `-` / `0` | Adjust current |
| `Shift + +/-/0` | Adjust all |
| `Escape` | Exit mode |

#### Power Mode (`$mod + Shift + e`)

| Key | Action |
|-----|--------|
| `l` | Lock screen |
| `e` | Exit WM |
| `s` | Suspend |
| `r` | Reboot |
| `p` | Poweroff |
| `Escape` | Cancel |

### Scratchpads (Dropdown Windows)

| Keybinding | Action |
|------------|--------|
| `$mod + u` | Toggle dropdown terminal |
| `$mod + i` | Toggle dropdown file manager (ranger) |

### Hardware Keys

| Key | Action |
|-----|--------|
| `XF86MonBrightnessUp` | Brightness +5% |
| `XF86MonBrightnessDown` | Brightness -5% |
| `XF86AudioRaiseVolume` | Volume +5% |
| `XF86AudioLowerVolume` | Volume -5% |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay` | Play/Pause media |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86AudioStop` | Stop media |
| `Print` | Screenshot (region select) |

### System

| Keybinding | Action |
|------------|--------|
| `$mod + x` | Lock screen |
| `$mod + Shift + c` | Reload config |
| `$mod + Shift + r` | Restart WM |

---

## Configuration Files

### wm-common/variables.conf

```bash
# Modifier key (Super/Windows)
set $mod Mod4

# Terminal emulator
set $term kitty

# Font for window titles
font pango:monospace 8

# Gap values
set $inner_gaps 10
set $outer_gaps 2

# Floating window behavior
floating_modifier $mod
tiling_drag modifier titlebar

# Workspace behavior
workspace_auto_back_and_forth yes
```

### wm-common/colors.conf

```bash
# Gruvbox Material Dark palette

# Backgrounds
set $bg         #282828
set $bg_soft    #32302f
set $bg_hard    #1d2021

# Foregrounds
set $fg         #d4be98
set $fg_dim     #a89984

# Accent colors
set $red        #ea6962
set $green      #a9b665
set $yellow     #d8a657
set $blue       #7daea3
set $purple     #d3869b
set $aqua       #89b482
set $orange     #e78a4e
set $gray       #928374

# Window decorations
client.focused          $orange   $bg   $fg   $orange  $orange
client.focused_inactive $gray     $bg   $fg   $bg      $gray
client.unfocused        $bg_soft  $bg   $gray $bg      $bg_soft
client.urgent           $red      $red  $bg   $red     $red
```

### WM-Specific Variables

Each WM's main config defines these variables differently:

| Variable | i3 | Sway | Hyprland |
|----------|-----|------|----------|
| `$launcher_cmd` | `~/.config/polybar/hack/scripts/launcher.sh` | `rofi -show drun` | `rofi -show drun` |
| `$screenshot_cmd` | `flameshot gui` | `grim -g "$(slurp)" - \| wl-copy` | `grim -g "$(slurp)" - \| wl-copy` |
| `$lock_cmd` | `betterlockscreen -l` | `swaylock -f` | `hyprlock` |
| `$clipboard_cmd` | `rofi -modi "clipboard:greenclip print" ...` | `cliphist list \| rofi -dmenu \| cliphist decode \| wl-copy` | Same as Sway |
| `$exit_cmd` | `i3-msg exit` | `swaymsg exit` | `exit` (builtin) |

### Hyprland-Specific Battery Settings

In `~/.config/hypr/hyprland-specific.conf`:

```bash
# Animations DISABLED for battery life
animations {
    enabled = false
}

# Decorations minimal
decoration {
    rounding = 0
    blur { enabled = false }
    shadow { enabled = false }
}

# Variable frame rate (saves battery when idle)
misc {
    vfr = true
    vrr = 0  # VRR off
}
```

---

## Workflow Examples

### Daily Workflow: Edit Keybinding

```bash
# 1. Edit the shared keybinding
nvim ~/.config/wm-common/keybindings.conf

# 2. Reload i3 (if running)
i3-msg reload  # or $mod+Shift+c

# 3. For Hyprland, manually update too (different syntax)
nvim ~/.config/hypr/keybindings.conf

# 4. Sync to repo
cd ~/rice/dotfiles-repo
./sync-wm.sh shared --collect
git add -A && git commit -m "Add new keybinding"
```

### Changing Color Scheme

```bash
# 1. Edit colors
nvim ~/.config/wm-common/colors.conf

# 2. Regenerate Hyprland colors
cd ~/rice/dotfiles-repo
./translate-hyprland.sh

# 3. Reload WMs
i3-msg reload        # if on i3
swaymsg reload       # if on Sway
hyprctl reload       # if on Hyprland

# 4. Sync to repo
./sync-wm.sh all --collect
```

### Fresh Machine Setup

```bash
# 1. Clone repo
git clone <your-repo> ~/rice/dotfiles-repo
cd ~/rice/dotfiles-repo

# 2. Install all configs
./update.sh --install
./sync-wm.sh all --install

# 3. Install packages (see Package Requirements section)

# 4. Reload/restart WM
i3-msg restart
```

### Before Major Changes

```bash
# Configs are auto-backed up, but manual backup:
cp -r ~/.config/i3 ~/.config/i3.manual-backup
cp -r ~/.config/wm-common ~/.config/wm-common.manual-backup
```

---

## Testing Guide

### Validate Without Running

```bash
# Validate all configs
cd ~/rice/dotfiles-repo
./sync-wm.sh all --validate

# Validate i3 specifically
i3 -C -c ~/.config/i3/config

# Sway (basic check - full validation needs display)
sway -C -c ~/.config/sway/config 2>&1 | head -20
```

### Test i3

```bash
# From running i3
i3-msg reload     # Reload config
i3-msg restart    # Full restart

# Or use keybindings
$mod+Shift+c      # Reload
$mod+Shift+r      # Restart
```

### Test Sway

```bash
# From TTY (Ctrl+Alt+F2)
sway

# From running Sway
swaymsg reload

# Check logs
journalctl --user -u sway -b
```

### Test Hyprland

```bash
# From TTY
Hyprland

# From running Hyprland
hyprctl reload

# Check logs
cat ~/.local/share/hyprland/hyprland.log
```

### Test Specific Features

```bash
# Test keybindings work
$mod+Return       # Should open kitty
$mod+d            # Should open launcher
$mod+u            # Should show dropdown terminal

# Test scratchpads
$mod+u            # Toggle dropdown terminal
$mod+i            # Toggle dropdown ranger

# Test modes
$mod+r            # Resize mode (press Escape to exit)
$mod+Shift+e      # Power menu (press Escape to exit)
```

---

## Troubleshooting

### i3 Won't Start

```bash
# Check for errors
i3 -C -c ~/.config/i3/config

# Common issues:
# - Missing include file → check wm-common/ exists
# - Syntax error → look at line number in error

# Restore backup
cp ~/.config/i3/config.backup-* ~/.config/i3/config
```

### Sway Black Screen

```bash
# Check XWayland
# In ~/.config/sway/config, ensure:
xwayland enable

# Check output config
swaymsg -t get_outputs

# GPU driver issue?
cat /var/log/Xorg.0.log | grep -i error
```

### Hyprland Crashes on Start

```bash
# Check log
cat ~/.local/share/hyprland/hyprland.log | tail -50

# Common issues:
# - Missing source file → verify all source = lines
# - GPU driver → check dmesg for amdgpu errors

# Start with minimal config
Hyprland -c /dev/null
```

### Keybinding Not Working

1. **Check if defined:** `grep "keybinding" ~/.config/wm-common/keybindings.conf`
2. **Check WM loaded it:** Reload config and watch for errors
3. **For Hyprland:** Different syntax - check `~/.config/hypr/keybindings.conf`
4. **Key grabbed by another app?** Try `xev` (X11) or check with `wev` (Wayland)

### Waybar Not Showing

```bash
# Check if running
pgrep waybar

# Start manually to see errors
waybar

# JSON syntax error?
cat ~/.config/waybar/config | jq .

# CSS error?
# Waybar continues without CSS, check stderr
```

### Scratchpad Not Working

```bash
# i3/Sway: Check window instance name
xprop | grep WM_CLASS    # for X11
swaymsg -t get_tree | jq '.nodes[].nodes[].nodes[].app_id'  # for Sway

# Should match:
# for_window [instance="dropdown"] ...
# for_window [app_id="dropdown"] ...   # Sway/Hyprland
```

### Clipboard Not Working

**i3 (X11):**
```bash
pgrep greenclip || greenclip daemon &
```

**Sway/Hyprland (Wayland):**
```bash
pgrep wl-paste || wl-paste --watch cliphist store &
```

### Lock Screen Not Working

**i3:**
```bash
# betterlockscreen needs cached image
betterlockscreen -u ~/Pictures/wallpaper.png
betterlockscreen -l
```

**Sway:**
```bash
swaylock -f
```

**Hyprland:**
```bash
hyprlock
```

---

## Battery Optimization

### Framework 13 AMD Specific

All three WMs are configured for battery life on Framework 13 AMD:

| Optimization | i3 | Sway | Hyprland |
|--------------|-----|------|----------|
| Compositor effects | picom minimal | Built-in | Disabled |
| Animations | N/A | N/A | `enabled = false` |
| Blur/shadows | picom config | N/A | Disabled |
| VRR | N/A | `adaptive_sync off` | `vrr = 0` |
| VFR | N/A | Built-in | `vfr = true` |

### Hyprland Battery Mode

The config in `hyprland-specific.conf` disables:
- All animations
- Blur effects
- Shadow effects
- Variable refresh rate

To enable eye candy (at cost of battery):
```bash
# Edit ~/.config/hypr/hyprland-specific.conf
animations {
    enabled = true  # Change to true
}
```

### Power Profiles

All WMs work with `power-profiles-daemon`:
```bash
# Check current profile
powerprofilesctl get

# Set profile
powerprofilesctl set power-saver
powerprofilesctl set balanced
powerprofilesctl set performance
```

### Idle Management

| WM | Tool | Config |
|----|------|--------|
| i3 | xss-lock | Via systemd |
| Sway | swayidle | In sway/config |
| Hyprland | hypridle | hypr/hypridle.conf |

Default timeouts:
- 2.5 min: Screen dims
- 5 min: Screen locks
- 5.5 min: Screen off
- 30 min: Suspend

---

## File Checklist

### System Files Created

- [x] `~/.config/wm-common/variables.conf`
- [x] `~/.config/wm-common/colors.conf`
- [x] `~/.config/wm-common/keybindings.conf`
- [x] `~/.config/wm-common/workspaces.conf`
- [x] `~/.config/wm-common/modes.conf`
- [x] `~/.config/wm-common/window-rules.conf`
- [x] `~/.config/i3/config` (refactored)
- [x] `~/.config/sway/config`
- [x] `~/.config/hypr/hyprland.conf`
- [x] `~/.config/hypr/colors.conf`
- [x] `~/.config/hypr/keybindings.conf`
- [x] `~/.config/hypr/workspaces.conf`
- [x] `~/.config/hypr/window-rules.conf`
- [x] `~/.config/hypr/hyprland-specific.conf`
- [x] `~/.config/hypr/hyprpaper.conf`
- [x] `~/.config/hypr/hypridle.conf`
- [x] `~/.config/hypr/hyprlock.conf`
- [x] `~/.config/waybar/config`
- [x] `~/.config/waybar/style.css`
- [x] `~/.local/share/wayland-sessions/sway.desktop`
- [x] `~/.local/share/wayland-sessions/hyprland.desktop`

### Repository Scripts Created

- [x] `~/rice/dotfiles-repo/lib/common.sh`
- [x] `~/rice/dotfiles-repo/sync-wm.sh`
- [x] `~/rice/dotfiles-repo/sync-shared.sh`
- [x] `~/rice/dotfiles-repo/sync-i3.sh`
- [x] `~/rice/dotfiles-repo/sync-sway.sh`
- [x] `~/rice/dotfiles-repo/sync-hyprland.sh`
- [x] `~/rice/dotfiles-repo/translate-hyprland.sh`

---

## Credits

- **Window Managers**: [i3wm](https://i3wm.org/), [Sway](https://swaywm.org/), [Hyprland](https://hyprland.org/)
- **Theme**: [Gruvbox Material](https://github.com/sainnhe/gruvbox-material)
- **Bar**: [Polybar](https://polybar.github.io/), [Waybar](https://github.com/Alexays/Waybar)
- **Hardware**: [Framework Laptop](https://frame.work/)

---

*Last updated: January 2026*
