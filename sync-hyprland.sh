#!/bin/bash
# Sync Hyprland + waybar + Wayland tools
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

HYPR_DIRS=(hypr waybar)

collect() {
    log_info "Collecting Hyprland configs from system to repo..."

    for dir in "${HYPR_DIRS[@]}"; do
        if [[ -d "$CONFIG_DIR/$dir" ]]; then
            rm -rf "$DOTFILES_DIR/.config/$dir"
            cp -r "$CONFIG_DIR/$dir" "$DOTFILES_DIR/.config/$dir"
            log_ok "Collected: .config/$dir/"
        else
            log_warn "Not found: .config/$dir/"
        fi
    done

    log_ok "Hyprland configs collected to repo"
}

install() {
    log_info "Installing Hyprland configs from repo to system..."
    check_packages hyprland || log_warn "Some Hyprland packages missing (continuing anyway)"

    for dir in "${HYPR_DIRS[@]}"; do
        if [[ -d "$DOTFILES_DIR/.config/$dir" ]]; then
            if [[ -d "$CONFIG_DIR/$dir" ]]; then
                backup_dir "$CONFIG_DIR/$dir"
            fi
            rm -rf "$CONFIG_DIR/$dir"
            cp -r "$DOTFILES_DIR/.config/$dir" "$CONFIG_DIR/$dir"
            log_ok "Installed: .config/$dir/"
        else
            log_warn "Not in repo: .config/$dir/"
        fi
    done

    log_ok "Hyprland configs installed to system"
}

validate() {
    log_info "Validating Hyprland config..."

    if [[ ! -f "$CONFIG_DIR/hypr/hyprland.conf" ]]; then
        log_error "Hyprland config not found"
        return 1
    fi

    # Basic syntax check
    local errors=0

    # Check for empty values
    if grep -qE '^\s*[a-z_]+\s*=\s*$' "$CONFIG_DIR/hypr/hyprland.conf"; then
        log_error "Empty value detected in Hyprland config"
        ((errors++))
    fi

    # Check required source files exist
    for file in colors.conf keybindings.conf workspaces.conf window-rules.conf hyprland-specific.conf; do
        if [[ ! -f "$CONFIG_DIR/hypr/$file" ]]; then
            log_error "Missing: hypr/$file"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_ok "Hyprland config appears valid"
        return 0
    else
        return 1
    fi
}

case "$1" in
    --collect)  collect ;;
    --install)  install ;;
    --validate) validate ;;
    *)
        echo "Usage: $0 [--collect|--install|--validate]"
        exit 1
        ;;
esac
