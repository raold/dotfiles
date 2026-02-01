#!/bin/bash

# Dotfiles update script
# Usage: ./update.sh [--collect|--install]

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
CONFIG_DIR="$HOME/.config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Home directory dotfiles
HOME_FILES=(
    ".bashrc"
    ".bash_profile"
    ".zshrc"
    ".p10k.zsh"
    ".profile"
    ".gitconfig"
    ".tmux.conf"
    ".nanorc"
    ".xinitrc"
    ".gtkrc-2.0"
    ".xprofile"
    ".fehbg"
    # "CLAUDE.md"  # Now symlinked: ~/CLAUDE.md → ~/rice/dotfiles-repo/CLAUDE.md
)

# .config directories to sync
CONFIG_DIRS=(
    "i3"
    "polybar"
    "rofi"
    "dunst"
    "picom"
    "kitty"
    "btop"
    "bat"
    "atuin"
    "cava"
    "neofetch"
    "lazygit"
    "psd"
    "gtk-3.0"
    "flashfocus"
    "mpv"
    "wal"
    "fontconfig"
    "fastfetch"
    "wm-common"
    "sway"
    "hypr"
    "waybar"
    "easyeffects"
    "spicetify"
    # Added 2026-01-10
    "arch-update"
    "ghostty"
    "htop"
    "spotifyd"
    "flameshot"
    "slimbookbattery"
    "nnn"
    "git"
    "nvim"
    "systemd/user"
)

# .config files to sync
CONFIG_FILES=(
    "starship.toml"
    "greenclip.toml"
)

# Claude Code settings - NOW SYMLINKED (no collect/install needed)
# ~/.claude/settings.json → ~/rice/dotfiles-repo/.claude/settings.json
# ~/.claude/settings.local.json → ~/rice/dotfiles-repo/.claude/settings.local.json
# CLAUDE_FILES=(
#     "settings.json"
#     "settings.local.json"
# )

# User scripts from .local/bin
LOCAL_BIN_SCRIPTS=(
    "spotify-theme"
    "power-switch"
    # Added 2026-01-10
    "battery-mode"
    "clip2path"
    "fix-keyring"
    "update-mirrors"
    "wttr"
    # Dissertation workflow scripts (added 2026-01-10)
    "diss-watch"
    "diss-diff"
    "diss-stats"
    "diss-compress"
    "diss-clean"
    "diss-lint"
    "diss-figures"
    "diss-chapter"
    # Startpage scripts (added 2026-01-24)
    "startpage-stats.sh"
    "startpage-ping.sh"
)

# .local/share directories to sync
LOCAL_SHARE_DIRS=(
    "icc"  # ICC color profiles (Framework display calibration)
    "startpage"  # Custom browser startpage (added 2026-01-24)
)

# Boot configuration files (requires sudo)
BOOT_FILES=(
    "refind_linux.conf"
)

# System configuration files (requires sudo)
SYSTEM_CONFIGS=(
    "/etc/NetworkManager/dispatcher.d/90-captive-portal"
    "/etc/modprobe.d/amd-pmc.conf"
    "/etc/modprobe.d/amdgpu.conf"
    "/etc/systemd/sleep.conf.d/framework-amd.conf"
    "/etc/systemd/logind.conf.d/lid-suspend-hibernate.conf"
    "/etc/mkinitcpio.conf"
    "/etc/udev/rules.d/60-ioschedulers.rules"
    "/etc/scx_loader/config.toml"
    # Added 2026-01-10
    "/etc/systemd/system/keyring-update.service"
    "/etc/systemd/system/keyring-update.timer"
    "/etc/pacman.d/hooks/refresh-keyring.hook"
    # Added 2026-01-16 (captive portal fix)
    "/etc/NetworkManager/conf.d/20-connectivity.conf"
    # Added 2026-02-01 (RAM optimizations)
    "/etc/systemd/zram-generator.conf"
    "/etc/sysctl.d/99-ram-optimizations.conf"
)

collect_dotfiles() {
    echo -e "${YELLOW}Collecting dotfiles from system...${NC}"

    # Copy home directory dotfiles
    for file in "${HOME_FILES[@]}"; do
        if [[ -f "$HOME_DIR/$file" ]]; then
            cp "$HOME_DIR/$file" "$DOTFILES_DIR/$file"
            echo -e "${GREEN}  Collected: $file${NC}"
        else
            echo -e "${RED}  Not found: $file${NC}"
        fi
    done

    # Copy .config directories
    mkdir -p "$DOTFILES_DIR/.config"
    for dir in "${CONFIG_DIRS[@]}"; do
        if [[ -d "$CONFIG_DIR/$dir" ]]; then
            rm -rf "$DOTFILES_DIR/.config/$dir"
            cp -r "$CONFIG_DIR/$dir" "$DOTFILES_DIR/.config/"
            echo -e "${GREEN}  Collected: .config/$dir${NC}"
        else
            echo -e "${RED}  Not found: .config/$dir${NC}"
        fi
    done

    # Copy .config files
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$CONFIG_DIR/$file" ]]; then
            cp "$CONFIG_DIR/$file" "$DOTFILES_DIR/.config/$file"
            echo -e "${GREEN}  Collected: .config/$file${NC}"
        else
            echo -e "${RED}  Not found: .config/$file${NC}"
        fi
    done

    # Claude Code settings - SKIPPED (now symlinked to repo)
    # for file in "${CLAUDE_FILES[@]}"; do
    #     if [[ -f "$HOME/.claude/$file" ]]; then
    #         cp "$HOME/.claude/$file" "$DOTFILES_DIR/.claude/$file"
    #         echo -e "${GREEN}  Collected: .claude/$file${NC}"
    #     fi
    # done

    # Copy user scripts from .local/bin
    mkdir -p "$DOTFILES_DIR/.local/bin"
    for script in "${LOCAL_BIN_SCRIPTS[@]}"; do
        if [[ -f "$HOME/.local/bin/$script" ]]; then
            cp "$HOME/.local/bin/$script" "$DOTFILES_DIR/.local/bin/$script"
            echo -e "${GREEN}  Collected: .local/bin/$script${NC}"
        else
            echo -e "${RED}  Not found: .local/bin/$script${NC}"
        fi
    done

    # Copy .local/share directories
    mkdir -p "$DOTFILES_DIR/.local/share"
    for dir in "${LOCAL_SHARE_DIRS[@]}"; do
        if [[ -d "$HOME/.local/share/$dir" ]]; then
            rm -rf "$DOTFILES_DIR/.local/share/$dir"
            cp -r "$HOME/.local/share/$dir" "$DOTFILES_DIR/.local/share/"
            echo -e "${GREEN}  Collected: .local/share/$dir${NC}"
        else
            echo -e "${RED}  Not found: .local/share/$dir${NC}"
        fi
    done

    # Copy rEFInd config (requires sudo)
    if [[ -f "/boot/EFI/refind/refind.conf" ]]; then
        mkdir -p "$DOTFILES_DIR/refind"
        sudo cp /boot/EFI/refind/refind.conf "$DOTFILES_DIR/refind/"
        sudo chown "$USER:$USER" "$DOTFILES_DIR/refind/refind.conf"
        echo -e "${GREEN}  Collected: refind/refind.conf${NC}"
    fi

    # Copy boot files (requires sudo)
    for file in "${BOOT_FILES[@]}"; do
        if [[ -f "/boot/$file" ]]; then
            sudo cp "/boot/$file" "$DOTFILES_DIR/refind/$file"
            sudo chown "$USER:$USER" "$DOTFILES_DIR/refind/$file"
            echo -e "${GREEN}  Collected: refind/$file${NC}"
        else
            echo -e "${RED}  Not found: /boot/$file${NC}"
        fi
    done

    # Copy system configs (requires sudo)
    mkdir -p "$DOTFILES_DIR/system-configs/NetworkManager/conf.d"
    mkdir -p "$DOTFILES_DIR/system-configs/modprobe.d"
    mkdir -p "$DOTFILES_DIR/system-configs/systemd-sleep"
    mkdir -p "$DOTFILES_DIR/system-configs/logind.conf.d"
    mkdir -p "$DOTFILES_DIR/system-configs/udev.rules.d"
    mkdir -p "$DOTFILES_DIR/system-configs/scx_loader"
    mkdir -p "$DOTFILES_DIR/system-configs/sysctl.d"
    for filepath in "${SYSTEM_CONFIGS[@]}"; do
        if [[ -f "$filepath" ]]; then
            filename=$(basename "$filepath")
            case "$filepath" in
                */NetworkManager/conf.d/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/NetworkManager/conf.d/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/NetworkManager/conf.d/$filename"
                    ;;
                */NetworkManager/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/NetworkManager/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/NetworkManager/$filename"
                    ;;
                */modprobe.d/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/modprobe.d/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/modprobe.d/$filename"
                    ;;
                */sleep.conf.d/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/systemd-sleep/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/systemd-sleep/$filename"
                    ;;
                */logind.conf.d/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/logind.conf.d/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/logind.conf.d/$filename"
                    ;;
                */mkinitcpio.conf)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/$filename"
                    ;;
                */udev/rules.d/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/udev.rules.d/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/udev.rules.d/$filename"
                    ;;
                */scx_loader/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/scx_loader/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/scx_loader/$filename"
                    ;;
                */systemd/system/*)
                    mkdir -p "$DOTFILES_DIR/system-configs/systemd-system"
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/systemd-system/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/systemd-system/$filename"
                    ;;
                */pacman.d/hooks/*)
                    mkdir -p "$DOTFILES_DIR/system-configs/pacman.d/hooks"
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/pacman.d/hooks/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/pacman.d/hooks/$filename"
                    ;;
                */sysctl.d/*)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/sysctl.d/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/sysctl.d/$filename"
                    ;;
                */zram-generator.conf)
                    sudo cp "$filepath" "$DOTFILES_DIR/system-configs/$filename"
                    sudo chown "$USER:$USER" "$DOTFILES_DIR/system-configs/$filename"
                    ;;
            esac
            echo -e "${GREEN}  Collected: system-configs/.../$filename${NC}"
        else
            echo -e "${RED}  Not found: $filepath${NC}"
        fi
    done

    echo -e "${GREEN}Done! Review changes with 'git diff'${NC}"
}

install_dotfiles() {
    echo -e "${YELLOW}Installing dotfiles to system...${NC}"

    # Create backup directory
    BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    echo -e "${YELLOW}Backup directory: $BACKUP_DIR${NC}"

    # Install home directory dotfiles
    for file in "${HOME_FILES[@]}"; do
        if [[ -f "$DOTFILES_DIR/$file" ]]; then
            # Backup existing
            if [[ -f "$HOME_DIR/$file" ]]; then
                cp "$HOME_DIR/$file" "$BACKUP_DIR/"
            fi
            cp "$DOTFILES_DIR/$file" "$HOME_DIR/$file"
            echo -e "${GREEN}  Installed: $file${NC}"
        fi
    done

    # Install .config directories
    mkdir -p "$CONFIG_DIR"
    for dir in "${CONFIG_DIRS[@]}"; do
        if [[ -d "$DOTFILES_DIR/.config/$dir" ]]; then
            # Backup existing
            if [[ -d "$CONFIG_DIR/$dir" ]]; then
                cp -r "$CONFIG_DIR/$dir" "$BACKUP_DIR/"
            fi
            rm -rf "$CONFIG_DIR/$dir"
            cp -r "$DOTFILES_DIR/.config/$dir" "$CONFIG_DIR/"
            echo -e "${GREEN}  Installed: .config/$dir${NC}"
        fi
    done

    # Install .config files
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$DOTFILES_DIR/.config/$file" ]]; then
            # Backup existing
            if [[ -f "$CONFIG_DIR/$file" ]]; then
                cp "$CONFIG_DIR/$file" "$BACKUP_DIR/"
            fi
            cp "$DOTFILES_DIR/.config/$file" "$CONFIG_DIR/$file"
            echo -e "${GREEN}  Installed: .config/$file${NC}"
        fi
    done

    # Install user scripts from .local/bin
    mkdir -p "$HOME/.local/bin"
    for script in "${LOCAL_BIN_SCRIPTS[@]}"; do
        if [[ -f "$DOTFILES_DIR/.local/bin/$script" ]]; then
            cp "$DOTFILES_DIR/.local/bin/$script" "$HOME/.local/bin/$script"
            chmod +x "$HOME/.local/bin/$script"
            echo -e "${GREEN}  Installed: .local/bin/$script${NC}"
        fi
    done

    # Install .local/share directories
    mkdir -p "$HOME/.local/share"
    for dir in "${LOCAL_SHARE_DIRS[@]}"; do
        if [[ -d "$DOTFILES_DIR/.local/share/$dir" ]]; then
            # Backup existing
            if [[ -d "$HOME/.local/share/$dir" ]]; then
                cp -r "$HOME/.local/share/$dir" "$BACKUP_DIR/"
            fi
            rm -rf "$HOME/.local/share/$dir"
            cp -r "$DOTFILES_DIR/.local/share/$dir" "$HOME/.local/share/"
            echo -e "${GREEN}  Installed: .local/share/$dir${NC}"
        fi
    done

    # Claude Code settings - SKIPPED (now symlinked to repo)
    # Symlinks: ~/.claude/settings.json → ~/rice/dotfiles-repo/.claude/settings.json
    # To set up symlinks on a fresh machine, run:
    #   ln -s ~/rice/dotfiles-repo/.claude/settings.json ~/.claude/settings.json
    #   ln -s ~/rice/dotfiles-repo/.claude/settings.local.json ~/.claude/settings.local.json

    echo -e "${GREEN}Done! Backups saved to: $BACKUP_DIR${NC}"
    echo -e "${YELLOW}You may need to restart your shell or WM to see changes.${NC}"
}

install_system() {
    echo -e "${YELLOW}Installing system configs (requires sudo)...${NC}"

    # Install boot files
    for file in "${BOOT_FILES[@]}"; do
        if [[ -f "$DOTFILES_DIR/refind/$file" ]]; then
            sudo cp "/boot/$file" "/boot/$file.bak" 2>/dev/null
            sudo cp "$DOTFILES_DIR/refind/$file" "/boot/$file"
            echo -e "${GREEN}  Installed: /boot/$file${NC}"
        fi
    done

    # Install system configs
    for filepath in "${SYSTEM_CONFIGS[@]}"; do
        filename=$(basename "$filepath")
        case "$filepath" in
            */NetworkManager/conf.d/*)
                src="$DOTFILES_DIR/system-configs/NetworkManager/conf.d/$filename"
                ;;
            */NetworkManager/*)
                src="$DOTFILES_DIR/system-configs/NetworkManager/$filename"
                ;;
            */modprobe.d/*)
                src="$DOTFILES_DIR/system-configs/modprobe.d/$filename"
                ;;
            */sleep.conf.d/*)
                src="$DOTFILES_DIR/system-configs/systemd-sleep/$filename"
                ;;
            */logind.conf.d/*)
                src="$DOTFILES_DIR/system-configs/logind.conf.d/$filename"
                ;;
            */mkinitcpio.conf)
                src="$DOTFILES_DIR/system-configs/$filename"
                ;;
            */udev/rules.d/*)
                src="$DOTFILES_DIR/system-configs/udev.rules.d/$filename"
                ;;
            */scx_loader/*)
                src="$DOTFILES_DIR/system-configs/scx_loader/$filename"
                ;;
            */systemd/system/*)
                src="$DOTFILES_DIR/system-configs/systemd-system/$filename"
                ;;
            */pacman.d/hooks/*)
                src="$DOTFILES_DIR/system-configs/pacman.d/hooks/$filename"
                ;;
            */sysctl.d/*)
                src="$DOTFILES_DIR/system-configs/sysctl.d/$filename"
                ;;
            */zram-generator.conf)
                src="$DOTFILES_DIR/system-configs/$filename"
                ;;
        esac
        if [[ -f "$src" ]]; then
            sudo cp "$filepath" "$filepath.bak" 2>/dev/null
            sudo mkdir -p "$(dirname "$filepath")"
            sudo cp "$src" "$filepath"
            sudo chmod +x "$filepath" 2>/dev/null  # For scripts
            echo -e "${GREEN}  Installed: $filepath${NC}"
        fi
    done

    echo -e "${GREEN}Done! Some changes may require reboot.${NC}"
}

install_refind() {
    echo -e "${YELLOW}Installing rEFInd config (requires sudo)...${NC}"
    if [[ -f "$DOTFILES_DIR/refind/refind.conf" ]]; then
        sudo cp /boot/EFI/refind/refind.conf /boot/EFI/refind/refind.conf.bak
        sudo cp "$DOTFILES_DIR/refind/refind.conf" /boot/EFI/refind/
        echo -e "${GREEN}  Installed: refind.conf (backup: refind.conf.bak)${NC}"
    else
        echo -e "${RED}  Not found: refind/refind.conf${NC}"
    fi
}

show_help() {
    echo "Dotfiles update script"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  --collect       Collect dotfiles from system into repo"
    echo "  --install       Install dotfiles from repo to system (user configs)"
    echo "  --system        Install system configs (boot, modprobe, etc. - requires sudo)"
    echo "  --refind        Install rEFInd config only (requires sudo)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --collect    # After making changes, sync to repo"
    echo "  $0 --install    # Fresh install or restore from repo"
    echo "  $0 --system     # Install system-level configs (Framework 13 AMD)"
    echo ""
    echo "Collected files include:"
    echo "  - Home dotfiles (.zshrc, .gitconfig, etc.)"
    echo "  - .config directories (i3, sway, hypr, polybar, waybar, kitty, etc.)"
    echo "  - Shared WM configs (wm-common/)"
    echo "  - Boot configs (refind_linux.conf, refind.conf)"
    echo "  - System configs (modprobe, sleep, udev rules, scx_loader)"
    echo ""
    echo "Symlinked files (auto-synced, no collect needed):"
    echo "  - ~/CLAUDE.md → dotfiles-repo/CLAUDE.md"
    echo "  - ~/.claude/settings.json → dotfiles-repo/.claude/settings.json"
    echo ""
    echo "For WM-specific sync, use: ./sync-wm.sh --help"
}

case "$1" in
    --collect)
        collect_dotfiles
        ;;
    --install)
        install_dotfiles
        ;;
    --system)
        install_system
        ;;
    --refind)
        install_refind
        ;;
    --help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac
