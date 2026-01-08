#!/bin/bash
# Common functions for WM sync scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$HOME/.config"
WM_COMMON="$CONFIG_DIR/wm-common"

# Backup with timestamp
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up: $file -> $backup"
    fi
}

backup_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        local backup="${dir}.backup-$(date +%Y%m%d-%H%M%S)"
        cp -r "$dir" "$backup"
        log_info "Backed up: $dir -> $backup"
    fi
}

# Safe copy with validation
safe_copy() {
    local src="$1"
    local dst="$2"

    if [[ ! -e "$src" ]]; then
        log_error "Source not found: $src"
        return 1
    fi

    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"

    if [[ $? -eq 0 ]]; then
        log_ok "Copied: $src -> $dst"
        return 0
    else
        log_error "Failed to copy: $src -> $dst"
        return 1
    fi
}

# Validate config syntax
validate_i3_config() {
    local config="$1"
    if command -v i3 &>/dev/null; then
        if i3 -C -c "$config" 2>&1 | grep -q "ERROR"; then
            return 1
        fi
        return 0
    else
        log_warn "i3 not installed, skipping validation"
        return 0
    fi
}

validate_sway_config() {
    local config="$1"
    if command -v sway &>/dev/null; then
        if sway -C -c "$config" 2>&1 | grep -q "Error"; then
            return 1
        fi
        return 0
    else
        log_warn "Sway not installed, skipping validation"
        return 0
    fi
}

validate_hyprland_config() {
    local config="$1"
    # Hyprland doesn't have a standalone config validator
    # Check for obvious syntax errors
    if grep -qE '^\s*[a-z]+\s*=\s*$' "$config" 2>/dev/null; then
        log_error "Empty value detected in Hyprland config"
        return 1
    fi
    log_info "Basic Hyprland config validation passed"
    return 0
}

# Check required packages
check_packages() {
    local wm="$1"
    local missing=()

    case "$wm" in
        i3)
            local pkgs=(i3-wm polybar picom feh dunst rofi flameshot xcalib xclip)
            ;;
        sway)
            local pkgs=(sway waybar swaybg swaylock swayidle dunst rofi-wayland grim slurp wl-clipboard)
            ;;
        hyprland)
            local pkgs=(hyprland waybar hyprpaper hyprlock hypridle dunst rofi-wayland grim slurp wl-clipboard)
            ;;
        *)
            log_error "Unknown WM: $wm"
            return 1
            ;;
    esac

    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing packages for $wm: ${missing[*]}"
        echo "Install with: sudo pacman -S ${missing[*]}"
        return 1
    fi

    log_ok "All packages for $wm are installed"
    return 0
}

# Detect which WM is running
detect_wm() {
    if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        echo "hyprland"
    elif [[ -n "$SWAYSOCK" ]]; then
        echo "sway"
    elif [[ -n "$I3SOCK" ]]; then
        echo "i3"
    else
        echo "unknown"
    fi
}
