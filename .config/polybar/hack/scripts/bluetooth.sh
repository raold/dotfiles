#!/bin/bash

# Bluetooth polybar module script
# Usage:
#   bluetooth.sh        - Output status for polybar
#   bluetooth.sh --menu - Show rofi control menu

# Colors (Gruvbox)
COLOR_ON="#83a598"      # Blue - bluetooth on
COLOR_OFF="#928374"     # Gray - bluetooth off
COLOR_CONNECTED="#b8bb26"  # Green - device connected

# Icons (Nerd Font - using printf for reliable unicode)
ICON_ON=$(printf '\uf293')       #
ICON_OFF=$(printf '\uf294')      #
ICON_CONNECTED=$(printf '\uf293') #

# Show rofi menu for bluetooth control
show_menu() {
    # Check current state
    if ! systemctl is-active --quiet bluetooth; then
        power_status="Service: Stopped"
        power_action="  Start Bluetooth Service"
    elif ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        power_status="Power: Off"
        power_action="  Turn Bluetooth On"
    else
        power_status="Power: On"
        power_action="  Turn Bluetooth Off"
    fi

    # Get connected devices (only if service is running)
    if systemctl is-active --quiet bluetooth; then
        connected_devices=$(bluetoothctl devices Connected 2>/dev/null)
        if [ -n "$connected_devices" ]; then
            connected_count=$(echo "$connected_devices" | wc -l)
            connected_info="Connected: $connected_count device(s)"
        else
            connected_info="Connected: None"
        fi
    else
        connected_devices=""
        connected_info="Service stopped"
    fi

    # Build menu options
    options="$power_action\n  Connected Devices\n  Scan & Connect\n  Open Bluetooth Manager\n  Disconnect All"

    # Show rofi menu
    chosen=$(echo -e "$options" | rofi -dmenu -i -p "Bluetooth" -mesg "$power_status | $connected_info" -theme-str 'window {width: 300px;}')

    case "$chosen" in
        *"Start Bluetooth Service"*)
            sudo systemctl start bluetooth
            sleep 1
            bluetoothctl power on
            notify-send "Bluetooth" "Service started and powered on" -i bluetooth
            ;;
        *"Turn Bluetooth On"*)
            bluetoothctl power on
            notify-send "Bluetooth" "Powered on" -i bluetooth
            ;;
        *"Turn Bluetooth Off"*)
            bluetoothctl power off
            notify-send "Bluetooth" "Powered off" -i bluetooth
            ;;
        *"Connected Devices"*)
            show_connected_devices
            ;;
        *"Scan & Connect"*)
            scan_and_connect
            ;;
        *"Open Bluetooth Manager"*)
            blueman-manager &
            ;;
        *"Disconnect All"*)
            disconnect_all
            ;;
    esac
}

# Show connected devices submenu
show_connected_devices() {
    devices=$(bluetoothctl devices Connected 2>/dev/null)

    if [ -z "$devices" ]; then
        notify-send "Bluetooth" "No devices connected" -i bluetooth
        return
    fi

    # Format: "XX:XX:XX:XX:XX:XX Device Name" -> "Device Name (disconnect)"
    options=""
    while IFS= read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)
        options+="  $name\n"
    done <<< "$devices"
    options+="  Back"

    chosen=$(echo -e "$options" | rofi -dmenu -i -p "Connected Devices" -theme-str 'window {width: 350px;}')

    if [[ "$chosen" == *"Back"* ]]; then
        show_menu
    elif [ -n "$chosen" ]; then
        # Extract device name and find MAC
        device_name=$(echo "$chosen" | sed 's/^  //')
        mac=$(bluetoothctl devices Connected | grep "$device_name" | awk '{print $2}')
        if [ -n "$mac" ]; then
            action=$(echo -e "  Disconnect\n  Back" | rofi -dmenu -i -p "$device_name")
            if [[ "$action" == *"Disconnect"* ]]; then
                bluetoothctl disconnect "$mac"
                notify-send "Bluetooth" "Disconnected from $device_name" -i bluetooth
            fi
        fi
    fi
}

# Scan for new devices and connect
scan_and_connect() {
    # Ensure bluetooth is on
    if ! systemctl is-active --quiet bluetooth; then
        notify-send "Bluetooth" "Starting bluetooth service..." -i bluetooth
        sudo systemctl start bluetooth
        sleep 1
    fi

    bluetoothctl power on 2>/dev/null

    notify-send "Bluetooth" "Scanning for devices (10s)..." -i bluetooth -t 3000

    # Start scanning
    bluetoothctl --timeout 10 scan on &>/dev/null &
    sleep 10

    # Get paired and discovered devices
    paired=$(bluetoothctl devices Paired 2>/dev/null)
    # Note: discovered devices require agent interaction, showing paired for now

    if [ -z "$paired" ]; then
        notify-send "Bluetooth" "No paired devices found. Use Bluetooth Manager for new pairing." -i bluetooth
        blueman-manager &
        return
    fi

    options=""
    while IFS= read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)
        # Check if already connected
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            options+="  $name (connected)\n"
        else
            options+="  $name\n"
        fi
    done <<< "$paired"
    options+="  Open Bluetooth Manager\n  Back"

    chosen=$(echo -e "$options" | rofi -dmenu -i -p "Select Device" -theme-str 'window {width: 350px;}')

    if [[ "$chosen" == *"Back"* ]]; then
        show_menu
    elif [[ "$chosen" == *"Bluetooth Manager"* ]]; then
        blueman-manager &
    elif [ -n "$chosen" ]; then
        device_name=$(echo "$chosen" | sed 's/^  //' | sed 's/ (connected)$//')
        mac=$(bluetoothctl devices Paired | grep "$device_name" | awk '{print $2}')
        if [ -n "$mac" ]; then
            notify-send "Bluetooth" "Connecting to $device_name..." -i bluetooth -t 2000
            if bluetoothctl connect "$mac"; then
                notify-send "Bluetooth" "Connected to $device_name" -i bluetooth
            else
                notify-send "Bluetooth" "Failed to connect to $device_name" -i bluetooth -u critical
            fi
        fi
    fi
}

# Disconnect all devices
disconnect_all() {
    devices=$(bluetoothctl devices Connected 2>/dev/null)

    if [ -z "$devices" ]; then
        notify-send "Bluetooth" "No devices to disconnect" -i bluetooth
        return
    fi

    while IFS= read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        bluetoothctl disconnect "$mac" 2>/dev/null
    done <<< "$devices"

    notify-send "Bluetooth" "All devices disconnected" -i bluetooth
}

# Main: output status for polybar
output_status() {
    # Check if bluetooth service is running
    if ! systemctl is-active --quiet bluetooth; then
        echo "%{F$COLOR_OFF}$ICON_OFF%{F-}"
        exit 0
    fi

    # Check if bluetooth is powered on
    if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        echo "%{F$COLOR_OFF}$ICON_OFF%{F-}"
        exit 0
    fi

    # Get connected device name
    connected=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)

    if [ -n "$connected" ]; then
        # Connected - show connected icon with device name
        echo "%{F$COLOR_CONNECTED}$ICON_CONNECTED $connected%{F-}"
    else
        # On but not connected - show blue icon
        echo "%{F$COLOR_ON}$ICON_ON%{F-}"
    fi
}

# Debug function - outputs to a temp file for troubleshooting
debug_output() {
    echo "$(date): Script executed" >> /tmp/bluetooth_debug.log
    echo "Service: $(systemctl is-active bluetooth)" >> /tmp/bluetooth_debug.log
    echo "Output: $(output_status)" >> /tmp/bluetooth_debug.log
}

# Handle arguments
case "$1" in
    --menu)
        show_menu
        ;;
    *)
        output_status
        ;;
esac
