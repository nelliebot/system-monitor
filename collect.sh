#!/bin/bash
# Lightweight system stats collector - v2
# Run via cron: */5 * * * *

OUTPUT_DIR="/home/nellie/Nellie/system-monitor"
DATA_FILE="$OUTPUT_DIR/data.json"
HISTORY_FILE="$OUTPUT_DIR/history.json"
MAX_HISTORY=288  # 24 hours at 5-min intervals

# Get system info
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
SWAP=$(free -h | grep Swap | awk '{print $3 "/" $2}')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
CHROMIUM_COUNT=$(ps aux | grep -E "chromium|chrome" | grep -v grep | wc -l)
UPTIME=$(uptime -p)

# Gateway status
if pgrep -f "openclaw-gateway" > /dev/null; then
    GATEWAY_STATUS="running"
else
    GATEWAY_STATUS="stopped"
fi

# Agent activity - check for recent cron runs (proxy for agent activity)
# Count cron runs in last 30 min as proxy for activity
RECENT_CRON_RUNS=$(find ~/.openclaw/cron/runs -name "*.jsonl" -mmin -30 2>/dev/null | wc -l)

# Also check if we have recent heartbeat activity
LAST_HEARTBEAT=$(find ~/.openclaw/cron/runs -name "*.jsonl" -mmin -30 2>/dev/null | head -1)
if [ -n "$LAST_HEARTBEAT" ]; then
    AGENT_STATUS="active"
else
    AGENT_STATUS="idle"
fi

# Current time ISO
TIMESTAMP=$(date -Iseconds)

# Write current JSON
cat > "$DATA_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "temp_celsius": $TEMP,
  "memory_used": "$MEM",
  "swap_used": "$SWAP",
  "load_avg": $LOAD,
  "chromium_processes": $CHROMIUM_COUNT,
  "gateway_status": "$GATEWAY_STATUS",
  "active_sessions": $RECENT_CRON_RUNS,
  "agent_status": "$AGENT_STATUS",
  "uptime": "$UPTIME"
}
EOF

# Update history (append new, keep last MAX_HISTORY)
if [ -f "$HISTORY_FILE" ]; then
    python3 << PYTHON
import json
try:
    with open('$HISTORY_FILE', 'r') as f:
        history = json.load(f)
except:
    history = []

history.append({
  "timestamp": "$TIMESTAMP",
  "temp_celsius": $TEMP,
  "memory_used": "$MEM",
  "load_avg": $LOAD,
  "chromium_processes": $CHROMIUM_COUNT,
  "gateway_status": "$GATEWAY_STATUS",
  "active_sessions": $RECENT_CRON_RUNS,
  "agent_status": "$AGENT_STATUS"
})

# Keep last MAX_HISTORY entries
history = history[-$MAX_HISTORY:]

with open('$HISTORY_FILE', 'w') as f:
    json.dump(history, f, indent=2)
PYTHON
else
    echo '[{"timestamp": "'$TIMESTAMP'", "temp_celsius": '$TEMP', "memory_used": "'$MEM'", "load_avg": '$LOAD', "chromium_processes": '$CHROMIUM_COUNT', "gateway_status": "'$GATEWAY_STATUS'", "active_sessions": '$SESSION_COUNT'}]' > "$HISTORY_FILE"
fi

echo "Collected at $TIMESTAMP | Temp: ${TEMP}°C | Sessions: $SESSION_COUNT"

# Push to GitHub (hourly to save API calls)
CURRENT_HOUR=$(date +%H)
if [ "$CURRENT_HOUR" = "00" ] || [ "$CURRENT_HOUR" = "06" ] || [ "$CURRENT_HOUR" = "12" ] || [ "$CURRENT_HOUR" = "18" ]; then
    # Use GH_PAT from environment
    
    # Push data.json
    DATA_CONTENT=$(base64 -w0 "$DATA_FILE")
    SHA_DATA=$(curl -s "https://api.github.com/repos/nelliebot/system-monitor/contents/data.json?ref=gh-pages" -H "Authorization: token $GH_PAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null)
    if [ -n "$SHA_DATA" ]; then
        curl -s -X PUT "https://api.github.com/repos/nelliebot/system-monitor/contents/data.json" \
          -H "Authorization: token $GH_PAT" \
          -H "Content-Type: application/json" \
          -d "{\"message\":\"Update data\",\"content\":\"$DATA_CONTENT\",\"sha\":\"$SHA_DATA\",\"branch\":\"gh-pages\"}" > /dev/null
    fi
    
    # Push history.json (larger, so only on even hours)
    if [ $(date +%H) -eq 0 ] || [ $(date +%H) -eq 12 ]; then
        HISTORY_CONTENT=$(base64 -w0 "$HISTORY_FILE")
        SHA_HISTORY=$(curl -s "https://api.github.com/repos/nelliebot/system-monitor/contents/history.json?ref=gh-pages" -H "Authorization: token $GH_PAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null)
        if [ -n "$SHA_HISTORY" ]; then
            curl -s -X PUT "https://api.github.com/repos/nelliebot/system-monitor/contents/history.json" \
              -H "Authorization: token $GH_PAT" \
              -H "Content-Type: application/json" \
              -d "{\"message\":\"Update history\",\"content\":\"$HISTORY_CONTENT\",\"sha\":\"$SHA_HISTORY\",\"branch\":\"gh-pages\"}" > /dev/null
        fi
    fi
    echo "Pushed to GitHub"
fi
