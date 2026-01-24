#!/bin/bash
# Collects system stats and writes to startpage data directory

DATA_DIR="$HOME/.local/share/startpage/data"
OUTPUT_FILE="$DATA_DIR/system.json"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Get CPU usage (average over 1 second)
get_cpu() {
    # Read initial CPU stats
    read -r cpu user1 nice1 system1 idle1 iowait1 irq1 softirq1 _ < /proc/stat

    # Wait briefly
    sleep 0.5

    # Read again
    read -r cpu user2 nice2 system2 idle2 iowait2 irq2 softirq2 _ < /proc/stat

    # Calculate differences
    idle_diff=$((idle2 - idle1))
    total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1))
    total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2))
    total_diff=$((total2 - total1))

    # Calculate CPU percentage (non-idle)
    if [[ $total_diff -gt 0 ]]; then
        cpu_pct=$(( (total_diff - idle_diff) * 100 / total_diff ))
    else
        cpu_pct=0
    fi

    echo "$cpu_pct"
}

# Get RAM usage percentage
get_ram() {
    # Parse /proc/meminfo
    while IFS=': ' read -r key value _; do
        case "$key" in
            MemTotal) mem_total=$value ;;
            MemAvailable) mem_available=$value ;;
        esac
    done < /proc/meminfo

    if [[ $mem_total -gt 0 ]]; then
        mem_used=$((mem_total - mem_available))
        ram_pct=$((mem_used * 100 / mem_total))
    else
        ram_pct=0
    fi

    echo "$ram_pct"
}

# Get disk usage percentage for root partition
get_disk() {
    df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

# Collect stats
cpu=$(get_cpu)
ram=$(get_ram)
disk=$(get_disk)
timestamp=$(date -Iseconds)

# Write JSON output
cat > "$OUTPUT_FILE" << EOF
{
  "cpu": $cpu,
  "ram": $ram,
  "disk": $disk,
  "updated": "$timestamp"
}
EOF
