#!/bin/bash
# Usage collector - parses OpenClaw session files for API usage stats

AGENTS_DIR="/home/nellie/.openclaw/agents"
OUTPUT_FILE="/home/nellie/Nellie/system-monitor/data.json"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get system stats
temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f", $1/1000}')
mem_info=$(free -h 2>/dev/null | grep Mem || echo "0Gi 0Gi")
mem_used=$(echo $mem_info | awk '{print $3}')
mem_total=$(echo $mem_info | awk '{print $2}')
swap_used=$(free -h 2>/dev/null | grep Swap | awk '{print $3}')
load_avg=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
chromium_procs=$(pgrep -c chromium 2>/dev/null || echo 0)

# Gateway status
gateway_status="stopped"
if pgrep -f "openclaw-gateway" > /dev/null 2>&1; then
    gateway_status="running"
fi

# Active sessions (last 60 min)
active_sessions=0
for dir in "$AGENTS_DIR"/*/sessions; do
    if [ -d "$dir" ]; then
        session_count=$(find "$dir" -name "*.jsonl" -mmin -60 2>/dev/null | wc -l)
        active_sessions=$((active_sessions + session_count))
    fi
done

uptime_info=$(uptime -p 2>/dev/null || echo "unknown")

# Count total usage from recent sessions (last 24h)
total_calls=$(find "$AGENTS_DIR" -name "*.jsonl" -mtime -1 -exec grep -c '"role":"assistant"' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')
total_errors=$(find "$AGENTS_DIR" -name "*.jsonl" -mtime -1 -exec grep -c '"errorMessage"' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')
total_tokens=$(find "$AGENTS_DIR" -name "*.jsonl" -mtime -1 -exec grep -o '"totalTokens":[0-9]*' {} \; 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
total_input=$(find "$AGENTS_DIR" -name "*.jsonl" -mtime -1 -exec grep -o '"input":[0-9]*' {} \; 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
total_output=$(find "$AGENTS_DIR" -name "*.jsonl" -mtime -1 -exec grep -o '"output":[0-9]*' {} \; 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')

# Handle empty values
[ -z "$total_calls" ] && total_calls=0
[ -z "$total_errors" ] && total_errors=0
[ -z "$total_tokens" ] && total_tokens=0
[ -z "$total_input" ] && total_input=0
[ -z "$total_output" ] && total_output=0

# Write JSON
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "temp_celsius": $temp,
  "memory_used": "${mem_used}B/${mem_total}",
  "memory_used_raw": "$mem_used",
  "memory_total_raw": "$mem_total",
  "swap_used": "${swap_used}",
  "load_avg": "$load_avg",
  "chromium_processes": $chromium_procs,
  "gateway_status": "$gateway_status",
  "active_sessions": $active_sessions,
  "uptime": "$uptime_info",
  "usage": {
    "total_calls_24h": $total_calls,
    "total_tokens_24h": $total_tokens,
    "total_input_24h": $total_input,
    "total_output_24h": $total_output,
    "total_errors_24h": $total_errors
  }
}
EOF

echo "Done: $total_calls calls, $total_tokens tokens, $total_errors errors"
