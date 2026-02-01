#!/bin/bash
# Bluetooth waybar module - outputs JSON for waybar custom module
# Reuses rofi menu from polybar bluetooth.sh

ICON_ON=$'\uf293'        #
ICON_OFF=$'\uf294'       #
ICON_CONNECTED=$'\uf293' #

# Show rofi menu (delegate to polybar script which has full menu logic)
if [[ "$1" == "--menu" ]]; then
    ~/.config/polybar/hack/scripts/bluetooth.sh --menu
    exit 0
fi

# Check if bluetooth service is running
if ! systemctl is-active --quiet bluetooth; then
    echo '{"text": "'"$ICON_OFF"'", "tooltip": "Bluetooth service stopped", "class": "off"}'
    exit 0
fi

# Check if bluetooth is powered on
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo '{"text": "'"$ICON_OFF"'", "tooltip": "Bluetooth powered off", "class": "off"}'
    exit 0
fi

# Get connected device name
connected=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)

if [ -n "$connected" ]; then
    echo '{"text": "'"$ICON_CONNECTED"' '"$connected"'", "tooltip": "Connected: '"$connected"'", "class": "connected"}'
else
    echo '{"text": "'"$ICON_ON"'", "tooltip": "Bluetooth on, no devices", "class": "on"}'
fi
