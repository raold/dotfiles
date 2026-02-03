#!/bin/bash

# Default location: 24502 (Lynchburg, VA area)
# Override with WEATHER_LOCATION environment variable
LOCATION="${WEATHER_LOCATION:-24502}"

# Fetch weather from wttr.in (no API key needed)
# Format: emoji + temperature
weather=$(curl -sf "wttr.in/${LOCATION}?format=%c%t" 2>/dev/null)

if [ -n "$weather" ]; then
    # Remove + sign from temperature
    echo "$weather" | tr -d '+'
else
    echo ""
fi
