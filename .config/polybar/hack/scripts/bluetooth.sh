#!/bin/bash

# Check if bluetooth service is running
if ! systemctl is-active --quiet bluetooth; then
    # Service disabled - show off icon
    echo "%{F#928374}󰂲%{F-}"
    exit 0
fi

# Check if bluetooth is powered on
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    # Powered off - show off icon
    echo "%{F#928374}󰂲%{F-}"
    exit 0
fi

# Get connected device name
connected=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)

if [ -n "$connected" ]; then
    # Connected - show device name
    echo "󰂱 $connected"
else
    # On but not connected
    echo "󰂯"
fi
