#!/bin/bash
# monitor.sh — Checks resource usage, triggers auto-scaling when >75%

THRESHOLD=75
PROMETHEUS_URL="http://localhost:9090"
COOLDOWN_FILE="/tmp/autoscale_cooldown"
COOLDOWN_SECONDS=300  # 5-minute cooldown
LOG_FILE="/var/log/autoscale.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a $LOG_FILE
}

get_cpu() {
    curl -s "$PROMETHEUS_URL/api/v1/query?query=\
100-(avg(rate(node_cpu_seconds_total\
{mode='idle'}[2m]))*100)" | python3 -c \
"import sys,json; print(float(json.load(\
sys.stdin)['data']['result'][0]['value'][1]))"
}

get_memory() {
    curl -s "$PROMETHEUS_URL/api/v1/query?query=\
(1-node_memory_MemAvailable_bytes\
/node_memory_MemTotal_bytes)*100" | python3 -c \
"import sys,json; print(float(json.load(\
sys.stdin)['data']['result'][0]['value'][1]))"
}

check_cooldown() {
    if [ -f "$COOLDOWN_FILE" ]; then
        last=$(cat $COOLDOWN_FILE); now=$(date +%s)
        if [ $((now - last)) -lt $COOLDOWN_SECONDS ]; then
            log "COOLDOWN active. Skipping."; return 1
        fi
    fi
    return 0
}

log "=== Auto-Scale Monitor Started ==="
log "Threshold: ${THRESHOLD}% | Cooldown: ${COOLDOWN_SECONDS}s"

while true; do
    CPU=$(get_cpu)
    MEM=$(get_memory)
    log "CPU: ${CPU}% | Memory: ${MEM}%"

    CPU_INT=${CPU%.*}
    MEM_INT=${MEM%.*}

    if [ "$CPU_INT" -gt "$THRESHOLD" ] || \
       [ "$MEM_INT" -gt "$THRESHOLD" ]; then
        log "ALERT: Threshold exceeded!"
        if check_cooldown; then
            log "Triggering auto-scale to GCP..."
            python3 /opt/autoscale-demo/scripts/autoscale.py scale-up
            date +%s > $COOLDOWN_FILE
        fi
    fi

    sleep 30
done
