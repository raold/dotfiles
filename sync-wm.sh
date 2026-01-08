#!/bin/bash
# Main WM sync dispatcher
# Usage: ./sync-wm.sh [i3|sway|hyprland|shared|all] [--collect|--install|--validate]

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

show_help() {
    cat << EOF
WM Config Sync Tool

Usage: $0 <target> <action>

Targets:
  i3          Sync i3wm + polybar + X11 tools
  sway        Sync Sway + waybar + Wayland tools
  hyprland    Sync Hyprland + waybar + Wayland tools
  shared      Sync wm-common/ shared configs
  all         Sync everything

Actions:
  --collect   Collect configs from system to repo
  --install   Install configs from repo to system
  --validate  Validate configs without installing

Examples:
  $0 shared --collect     # Collect shared configs to repo
  $0 sway --install       # Install Sway config to system
  $0 all --collect        # Collect all WM configs
  $0 hyprland --validate  # Validate Hyprland config

Files synced:
  shared:   ~/.config/wm-common/
  i3:       ~/.config/i3/, ~/.config/polybar/
  sway:     ~/.config/sway/, ~/.config/waybar/
  hyprland: ~/.config/hypr/, ~/.config/waybar/

EOF
}

case "$1" in
    i3)
        "$SCRIPT_DIR/sync-i3.sh" "$2"
        ;;
    sway)
        "$SCRIPT_DIR/sync-sway.sh" "$2"
        ;;
    hyprland)
        "$SCRIPT_DIR/sync-hyprland.sh" "$2"
        ;;
    shared)
        "$SCRIPT_DIR/sync-shared.sh" "$2"
        ;;
    all)
        log_info "Syncing all WM configs..."
        "$SCRIPT_DIR/sync-shared.sh" "$2"
        "$SCRIPT_DIR/sync-i3.sh" "$2"
        "$SCRIPT_DIR/sync-sway.sh" "$2"
        "$SCRIPT_DIR/sync-hyprland.sh" "$2"
        log_ok "All WM configs synced!"
        ;;
    --help|-h|"")
        show_help
        ;;
    *)
        log_error "Unknown target: $1"
        show_help
        exit 1
        ;;
esac
