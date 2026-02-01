#!/usr/bin/env bash
# Waybar module for arch-update integration
# Outputs JSON with text/tooltip/class for CSS styling

ICON_UPDATED=$'\U000f03d1'   # nf-md-package_check 󰏑
ICON_UPDATES=$'\U000f03d0'   # nf-md-package_down 󰏐
ICON_MANY=$'\U000f03d7'      # nf-md-package_variant_closed_plus 󰏗

# State files from arch-update
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-update"
PACMAN_UPDATES="$STATE_DIR/last_updates_check_packages"
AUR_UPDATES="$STATE_DIR/last_updates_check_aur"

get_updates() {
    local pacman_count=0
    local aur_count=0

    [[ -f "$PACMAN_UPDATES" ]] && pacman_count=$(wc -l < "$PACMAN_UPDATES" 2>/dev/null | tr -d ' ')
    [[ -f "$AUR_UPDATES" ]] && aur_count=$(wc -l < "$AUR_UPDATES" 2>/dev/null | tr -d ' ')

    [[ "$pacman_count" -eq 1 ]] && [[ ! -s "$PACMAN_UPDATES" ]] && pacman_count=0
    [[ "$aur_count" -eq 1 ]] && [[ ! -s "$AUR_UPDATES" ]] && aur_count=0

    echo "$((pacman_count + aur_count))"
}

UPDATES=$(get_updates)

if (( UPDATES == 0 )); then
    echo '{"text": "'"$ICON_UPDATED"'", "tooltip": "System up to date", "class": "updated"}'
elif (( UPDATES < 10 )); then
    echo '{"text": "'"$ICON_UPDATES"' '"$UPDATES"'", "tooltip": "'"$UPDATES"' updates available", "class": "few"}'
elif (( UPDATES < 50 )); then
    echo '{"text": "'"$ICON_MANY"' '"$UPDATES"'", "tooltip": "'"$UPDATES"' updates available", "class": "many"}'
else
    echo '{"text": "'"$ICON_MANY"' '"$UPDATES"'!", "tooltip": "'"$UPDATES"' updates available!", "class": "urgent"}'
fi
