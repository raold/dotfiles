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

    # Copy rEFInd config (requires sudo)
    if [[ -f "/boot/EFI/refind/refind.conf" ]]; then
        mkdir -p "$DOTFILES_DIR/refind"
        sudo cp /boot/EFI/refind/refind.conf "$DOTFILES_DIR/refind/"
        sudo chown "$USER:$USER" "$DOTFILES_DIR/refind/refind.conf"
        echo -e "${GREEN}  Collected: refind/refind.conf${NC}"
    fi

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

    echo -e "${GREEN}Done! Backups saved to: $BACKUP_DIR${NC}"
    echo -e "${YELLOW}You may need to restart your shell or WM to see changes.${NC}"
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
    echo "  --install       Install dotfiles from repo to system"
    echo "  --refind        Install rEFInd config (requires sudo)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --collect    # After making changes, sync to repo"
    echo "  $0 --install    # Fresh install or restore from repo"
}

case "$1" in
    --collect)
        collect_dotfiles
        ;;
    --install)
        install_dotfiles
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
