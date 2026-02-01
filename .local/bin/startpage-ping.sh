#!/bin/bash
# Pings configured services and writes status to startpage data directory

DATA_DIR="$HOME/.local/share/startpage/data"
CONFIG_FILE="$HOME/.local/share/startpage/config.json"
OUTPUT_FILE="$DATA_DIR/services.json"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Extract services from config using jq
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed" >&2
    exit 1
fi

# Read services from config
services=$(jq -c '.services // []' "$CONFIG_FILE")

# Build output JSON
output='{"services": ['
first=true

# Process each service
echo "$services" | jq -c '.[]' | while read -r service; do
    name=$(echo "$service" | jq -r '.name')
    url=$(echo "$service" | jq -r '.url')

    # Ping the service with a 5 second timeout
    if curl -s -o /dev/null -w '' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null; then
        status="up"
    else
        status="down"
    fi

    # Output as JSON line
    echo "$name|$url|$status"
done | {
    # Collect all results and build JSON
    results=()
    while IFS='|' read -r name url status; do
        results+=("{\"name\": \"$name\", \"url\": \"$url\", \"status\": \"$status\"}")
    done

    # Join with commas
    IFS=','
    services_json="${results[*]}"

    timestamp=$(date -Iseconds)

    cat > "$OUTPUT_FILE" << EOF
{
  "services": [$services_json],
  "updated": "$timestamp"
}
EOF
}
