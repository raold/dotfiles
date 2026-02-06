#!/bin/bash
# Mullvad VPN waybar module - outputs JSON for waybar custom module
# Usage:
#   mullvad-waybar.sh        - Output status JSON for waybar
#   mullvad-waybar.sh --menu - Show rofi server selection menu
# States: connected, connecting, disconnected, blocked

ROFI_THEME="$HOME/.config/rofi/gruvbox-pills.rasi"

ICON_SHIELD=$'\U000f0425'      # 󰐥 shield-lock (nerd font)
ICON_SHIELD_OFF=$'\U000f099e'  # 󰦞 shield-off (nerd font)

# Cache relay list to avoid repeated calls
RELAY_CACHE="/tmp/mullvad_relay_cache"

get_relay_list() {
    # Cache for 1 hour
    if [[ -f "$RELAY_CACHE" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$RELAY_CACHE") )) -lt 3600 ]]; then
        cat "$RELAY_CACHE"
    else
        mullvad relay list 2>/dev/null | tee "$RELAY_CACHE"
    fi
}

# ── Helper: get current status ──────────────────────
get_status() {
    mullvad status 2>/dev/null
}

# ── Rofi helper ─────────────────────────────────────
rofi_menu() {
    local prompt="$1" mesg="$2" lines="$3"
    shift 3
    rofi -dmenu -i \
        -p "$prompt" \
        -mesg "$mesg" \
        -theme "$ROFI_THEME" \
        -theme-str "window {width: 400px;} listview {lines: ${lines};}" \
        "$@"
}

# ── Main menu ───────────────────────────────────────
show_menu() {
    local status_output
    status_output=$(get_status)
    local status_line
    status_line=$(echo "$status_output" | head -1)

    if [[ "$status_line" == Connected* ]]; then
        local server visible_info
        server=$(echo "$status_output" | grep "Relay:" | sed 's/.*Relay:[[:space:]]*//')
        visible_info=$(echo "$status_output" | grep "Visible location:" | sed 's/.*Visible location:[[:space:]]*//')
        status_msg="Connected: $visible_info ($server)"
        toggle_label="󰈂  Disconnect"
    else
        status_msg="Disconnected"
        toggle_label="󰈀  Quick Connect"
    fi

    local options
    options="$toggle_label
󰍜  Select Location
󰑐  Reconnect (new server)"

    local chosen
    chosen=$(echo "$options" | rofi_menu "Mullvad VPN" "$status_msg" 3)

    case "$chosen" in
        *"Disconnect"*)
            mullvad disconnect
            notify-send "Mullvad VPN" "Disconnected" -i network-vpn
            ;;
        *"Quick Connect"*)
            mullvad connect
            notify-send "Mullvad VPN" "Connecting..." -i network-vpn
            ;;
        *"Select Location"*)
            select_country
            ;;
        *"Reconnect"*)
            mullvad reconnect
            notify-send "Mullvad VPN" "Reconnecting..." -i network-vpn
            ;;
    esac
}

# ── Country picker ──────────────────────────────────
select_country() {
    local relay_data
    relay_data=$(get_relay_list)

    # Parse country lines: "Country Name (code)"
    local countries
    countries=$(echo "$relay_data" | grep -E '^[A-Z]' | sed 's/ @.*//')

    local options
    options="  Back
$countries"

    local chosen
    chosen=$(echo "$options" | rofi_menu "Country" "Select a country" 12)

    if [[ -z "$chosen" || "$chosen" == *"Back"* ]]; then
        show_menu
        return
    fi

    # Extract country code from "Country Name (xx)"
    local country_code
    country_code=$(echo "$chosen" | grep -oP '\(\K[a-z]+(?=\))')

    if [[ "$country_code" == "us" ]]; then
        select_us_state
    elif [[ -n "$country_code" ]]; then
        # Non-US: connect directly to country
        mullvad relay set location "$country_code" 2>/dev/null
        mullvad connect
        local country_name
        country_name=$(echo "$chosen" | sed 's/ ([a-z]*)$//')
        notify-send "Mullvad VPN" "Connecting to $country_name" -i network-vpn
    fi
}

# ── US state picker ─────────────────────────────────
select_us_state() {
    local relay_data
    relay_data=$(get_relay_list)

    # Extract US cities: "	City, ST (code)" or "	Washington DC (was)"
    local us_cities
    us_cities=$(echo "$relay_data" \
        | awk '/^USA \(us\)/{found=1; next} found && /^[A-Z]/{exit} found' \
        | grep -P '^\t[A-Z]' \
        | sed 's/^\t//' | sed 's/ @.*//')

    # Extract unique states from "City, ST (code)" format
    # Special case: "Washington DC (was)" → DC
    local states
    states=$(echo "$us_cities" | while IFS= read -r line; do
        if [[ "$line" == *", "* ]]; then
            echo "$line" | grep -oP ', \K[A-Z]{2}(?= \()'
        elif [[ "$line" == "Washington DC"* ]]; then
            echo "DC"
        fi
    done | sort -u)

    # Build state list with city counts
    local state_options=""
    while IFS= read -r state; do
        local count
        if [[ "$state" == "DC" ]]; then
            count=$(echo "$us_cities" | grep -c "Washington DC")
        else
            count=$(echo "$us_cities" | grep -c ", ${state} (")
        fi
        if [[ "$count" -eq 1 ]]; then
            state_options+="${state}  (1 city)\n"
        else
            state_options+="${state}  ($count cities)\n"
        fi
    done <<< "$states"

    local options
    options="  Connect to any US server
  Back
$(echo -e "$state_options" | sed '/^$/d')"

    local line_count
    line_count=$(echo "$options" | wc -l)
    [[ $line_count -gt 12 ]] && line_count=12

    local chosen
    chosen=$(echo "$options" | rofi_menu "US State" "USA" "$line_count")

    if [[ -z "$chosen" || "$chosen" == *"Back"* ]]; then
        select_country
        return
    fi

    if [[ "$chosen" == *"any US server"* ]]; then
        mullvad relay set location us 2>/dev/null
        mullvad connect
        notify-send "Mullvad VPN" "Connecting to USA (any server)" -i network-vpn
        return
    fi

    # Extract state code (first two uppercase letters)
    local state_code
    state_code=$(echo "$chosen" | grep -oP '^[A-Z]{2}')

    if [[ -n "$state_code" ]]; then
        select_us_city "$state_code" "$us_cities"
    fi
}

# ── US city picker (within a state) ─────────────────
select_us_city() {
    local state_code="$1"
    local us_cities="$2"

    # Filter cities for this state
    local cities
    if [[ "$state_code" == "DC" ]]; then
        cities=$(echo "$us_cities" | grep "Washington DC")
    else
        cities=$(echo "$us_cities" | grep ", ${state_code} (")
    fi

    local city_count
    city_count=$(echo "$cities" | wc -l)

    # If only one city, connect directly
    if [[ "$city_count" -le 1 ]]; then
        local city_code
        city_code=$(echo "$cities" | grep -oP '\(\K[a-z]+(?=\))')
        mullvad relay set location us "$city_code" 2>/dev/null
        mullvad connect
        local city_name
        city_name=$(echo "$cities" | sed 's/ (.*//')
        notify-send "Mullvad VPN" "Connecting to $city_name" -i network-vpn
        return
    fi

    # Multiple cities — show picker
    local options
    options="  Back
$cities"

    local lines=$((city_count + 1))
    [[ $lines -gt 12 ]] && lines=12

    local chosen
    chosen=$(echo "$options" | rofi_menu "City" "USA — $state_code" "$lines")

    if [[ -z "$chosen" || "$chosen" == *"Back"* ]]; then
        select_us_state
        return
    fi

    local city_code
    city_code=$(echo "$chosen" | grep -oP '\(\K[a-z]+(?=\))')

    if [[ -n "$city_code" ]]; then
        mullvad relay set location us "$city_code" 2>/dev/null
        mullvad connect
        local city_name
        city_name=$(echo "$chosen" | sed 's/ (.*//')
        notify-send "Mullvad VPN" "Connecting to $city_name" -i network-vpn
    fi
}

# ── Status output for waybar ────────────────────────
output_status() {
    local status_output
    status_output=$(get_status)
    local status_line
    status_line=$(echo "$status_output" | head -1)

    case "$status_line" in
        Connected*)
            local server country_code visible_info
            server=$(echo "$status_output" | grep "Relay:" | sed 's/.*Relay:[[:space:]]*//')
            country_code=$(echo "$server" | cut -d'-' -f1 | tr '[:lower:]' '[:upper:]')
            visible_info=$(echo "$status_output" | grep "Visible location:" | sed 's/.*Visible location:[[:space:]]*//')

            local tooltip="Server: ${server}\nLocation: ${visible_info}"
            echo "{\"text\": \"${ICON_SHIELD} ${country_code}\", \"tooltip\": \"${tooltip}\", \"class\": \"connected\"}"
            ;;
        Connecting*)
            echo "{\"text\": \"${ICON_SHIELD} ...\", \"tooltip\": \"Connecting...\", \"class\": \"connecting\"}"
            ;;
        Disconnected*)
            echo "{\"text\": \"${ICON_SHIELD_OFF}\", \"tooltip\": \"VPN disconnected\", \"class\": \"disconnected\"}"
            ;;
        *blocked*|*Block*)
            echo "{\"text\": \"${ICON_SHIELD_OFF} !\", \"tooltip\": \"Network blocked (lockdown mode)\", \"class\": \"blocked\"}"
            ;;
        *)
            echo "{\"text\": \"${ICON_SHIELD_OFF} ?\", \"tooltip\": \"Mullvad status unknown: ${status_line}\", \"class\": \"disconnected\"}"
            ;;
    esac
}

# ── Main dispatch ───────────────────────────────────
case "$1" in
    --menu)
        show_menu
        ;;
    *)
        output_status
        ;;
esac
