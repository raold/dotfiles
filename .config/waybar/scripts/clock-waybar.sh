#!/bin/bash
# Clock with hour-matching clock face icons for waybar

hour=$(date +%-I)

case $hour in
    1)  icon="🕐" ;; 2)  icon="🕑" ;; 3)  icon="🕒" ;;
    4)  icon="🕓" ;; 5)  icon="🕔" ;; 6)  icon="🕕" ;;
    7)  icon="🕖" ;; 8)  icon="🕗" ;; 9)  icon="🕘" ;;
    10) icon="🕙" ;; 11) icon="🕚" ;; 12) icon="🕛" ;;
esac

if [[ "$1" == "--alt" ]]; then
    text="$icon $(date +'%a, %d %b %Y')"
else
    text="$icon $(date +'%I:%M %p')"
fi

tooltip="$(date +'%A, %B %d, %Y\n%I:%M:%S %p')"

echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\"}"
