#!/bin/bash
# Lightweight system stats collector
# Run via cron: */5 * * * *

OUTPUT_DIR="/home/nellie/Nellie/system-monitor"
DATA_FILE="$OUTPUT_DIR/data.json"
HISTORY_FILE="$OUTPUT_DIR/history.json"
MAX_HISTORY=20

# Get system info
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
SWAP=$(free -h | grep Swap | awk '{print $3 "/" $2}')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
CHROMIUM_COUNT=$(ps aux | grep chromium | grep -v grep | wc -l)
UPTIME=$(uptime -p)

# Gateway status (if running)
if pgrep -f "openclaw-gateway" > /dev/null; then
    GATEWAY_STATUS="running"
else
    GATEWAY_STATUS="stopped"
fi

# OpenClaw sessions
SESSION_COUNT=$(ls -1 ~/.openclaw/sessions/*.session 2>/dev/null | wc -l)

# Current time ISO
TIMESTAMP=$(date -Iseconds)

# Write JSON
cat > "$DATA_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "temp_celsius": $TEMP,
  "memory_used": "$MEM",
  "swap_used": "$SWAP",
  "load_avg": $LOAD,
  "chromium_processes": $CHROMIUM_COUNT,
  "gateway_status": "$GATEWAY_STATUS",
  "sessions": $SESSION_COUNT,
  "uptime": "$UPTIME"
}
EOF

# Update history
if [ -f "$HISTORY_FILE" ]; then
    # Read existing history, add new entry, keep last MAX_HISTORY
    python3 << PYTHON
import json
with open('$HISTORY_FILE', 'r') as f:
    history = json.load(f)
history.append({
  "timestamp": "$TIMESTAMP",
  "temp_celsius": $TEMP,
  "memory_used": "$MEM",
  "load_avg": $LOAD,
  "chromium_processes": $CHROMIUM_COUNT,
  "gateway_status": "$GATEWAY_STATUS"
})
history = history[-$MAX_HISTORY:]
with open('$HISTORY_FILE', 'w') as f:
    json.dump(history, f)
PYTHON
else
    echo '[{"timestamp": "'$TIMESTAMP'", "temp_celsius": '$TEMP', "memory_used": "'$MEM'", "load_avg": '$LOAD', "chromium_processes": '$CHROMIUM_COUNT', "gateway_status": "'$GATEWAY_STATUS'"}]' > "$HISTORY_FILE"
fi

echo "Collected at $TIMESTAMP"
