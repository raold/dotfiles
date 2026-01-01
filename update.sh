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
    "CLAUDE.md"
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
)

# .config files to sync
CONFIG_FILES=(
    "starship.toml"
    "greenclip.toml"
)

# Claude Code settings (NOT credentials or history)
CLAUDE_FILES=(
    "settings.json"
    "settings.local.json"
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

    # Copy Claude Code settings (not credentials/history)
    mkdir -p "$DOTFILES_DIR/.claude"
    for file in "${CLAUDE_FILES[@]}"; do
        if [[ -f "$HOME/.claude/$file" ]]; then
            cp "$HOME/.claude/$file" "$DOTFILES_DIR/.claude/$file"
            echo -e "${GREEN}  Collected: .claude/$file${NC}"
        else
            echo -e "${RED}  Not found: .claude/$file${NC}"
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
    mkdir -p "$DOTFILES_DIR/system-configs/NetworkManager"
    mkdir -p "$DOTFILES_DIR/system-configs/modprobe.d"
    mkdir -p "$DOTFILES_DIR/system-configs/systemd-sleep"
    for filepath in "${SYSTEM_CONFIGS[@]}"; do
        if [[ -f "$filepath" ]]; then
            filename=$(basename "$filepath")
            case "$filepath" in
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

    # Install Claude Code settings
    if [[ -d "$DOTFILES_DIR/.claude" ]]; then
        mkdir -p "$HOME/.claude"
        for file in "${CLAUDE_FILES[@]}"; do
            if [[ -f "$DOTFILES_DIR/.claude/$file" ]]; then
                if [[ -f "$HOME/.claude/$file" ]]; then
                    cp "$HOME/.claude/$file" "$BACKUP_DIR/"
                fi
                cp "$DOTFILES_DIR/.claude/$file" "$HOME/.claude/$file"
                echo -e "${GREEN}  Installed: .claude/$file${NC}"
            fi
        done
    fi

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
            */NetworkManager/*)
                src="$DOTFILES_DIR/system-configs/NetworkManager/$filename"
                ;;
            */modprobe.d/*)
                src="$DOTFILES_DIR/system-configs/modprobe.d/$filename"
                ;;
            */sleep.conf.d/*)
                src="$DOTFILES_DIR/system-configs/systemd-sleep/$filename"
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
    echo "  - Home dotfiles (.zshrc, .gitconfig, CLAUDE.md, etc.)"
    echo "  - .config directories (i3, polybar, kitty, etc.)"
    echo "  - Claude Code settings (.claude/settings.json)"
    echo "  - Boot configs (refind_linux.conf, refind.conf)"
    echo "  - System configs (captive-portal, modprobe, sleep)"
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
