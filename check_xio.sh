#!/bin/bash

# XtremIO API-instellingen
API_URL="https://<xtremio_host>/api/1.4/system/statistics"
USER="username"
PASS="password"

# Functie voor het afronden op 2 decimalen
round() {
    printf "%.2f\n" "$1"
}

# Hulpfunctie voor het verkrijgen van JSON-waarde
get_json_value() {
    local json_key="$1"
    echo "$response" | jq -r "$json_key"
}

# Command-line argumenten voor de waarschuwing- en kritieke drempels
LATENCY_THRESHOLD=""
BW_WARNING=""
BW_CRITICAL=""
LATENCY_WARNING=""
LATENCY_CRITICAL=""
CHECK_LATENCY=false
CHECK_BW=false

while getopts "l:w:c:b:d:" opt; do
  case ${opt} in
    l ) LATENCY_THRESHOLD=$OPTARG; CHECK_LATENCY=true ;;
    w ) BW_WARNING=$OPTARG; CHECK_BW=true ;;
    c ) BW_CRITICAL=$OPTARG; CHECK_BW=true ;;
    b ) LATENCY_THRESHOLD=$OPTARG; CHECK_LATENCY=true ;;
    d ) DEBUG=true ;;
    \? ) echo "Usage: $0 [-l latency_threshold] [-w bw_warning] [-c bw_critical]"; exit 1 ;;
  esac
done

# Verkrijg API-gegevens
response=$(curl -s -u $USER:$PASS $API_URL)

# Haal de gemiddelde latency (in microseconden) en doorvoersnelheid (bandbreedte in bytes) op
avg_latency_us=$(get_json_value '.statistics[0].avg_latency')
bandwidth_bytes=$(get_json_value '.statistics[0].throughput')

# Converteer de latency naar milliseconden en de bandbreedte naar GB/s
avg_latency_ms=$(echo "scale=2; $avg_latency_us / 1000" | bc)
bandwidth_gb=$(echo "scale=2; $bandwidth_bytes / (1024*1024*1024)" | bc)

# Debug-output (indien ingeschakeld)
if [ "$DEBUG" == "true" ]; then
    echo "API Response: $response"
    echo "Avg Latency (us): $avg_latency_us"
    echo "Bandwidth (bytes): $bandwidth_bytes"
    echo "Avg Latency (ms): $avg_latency_ms"
    echo "Bandwidth (GB/s): $bandwidth_gb"
fi

# Controleer latency drempel (als ingesteld)
if [ "$CHECK_LATENCY" == true ]; then
    if [ ! -z "$LATENCY_THRESHOLD" ]; then
        if (( $(echo "$avg_latency_ms > $LATENCY_THRESHOLD" | bc -l) )); then
            echo "CRITICAL - Average Latency is $avg_latency_ms ms | avg_latency=$avg_latency_ms ms"
            exit 2
        elif [ ! -z "$LATENCY_WARNING" ] && (( $(echo "$avg_latency_ms > $LATENCY_WARNING" | bc -l) )); then
            echo "WARNING - Average Latency is $avg_latency_ms ms | avg_latency=$avg_latency_ms ms"
            exit 1
        fi
    fi
fi

# Controleer bandbreedte drempel (als ingesteld)
if [ "$CHECK_BW" == true ]; then
    if [ ! -z "$BW_WARNING" ] && (( $(echo "$bandwidth_gb > $BW_WARNING" | bc -l) )); then
        echo "WARNING - Bandwidth is $bandwidth_gb GB/s | bandwidth=$bandwidth_gb GB/s"
        exit 1
    elif [ ! -z "$BW_CRITICAL" ] && (( $(echo "$bandwidth_gb > $BW_CRITICAL" | bc -l) )); then
        echo "CRITICAL - Bandwidth is $bandwidth_gb GB/s | bandwidth=$bandwidth_gb GB/s"
        exit 2
    fi
fi

# Als alles goed is, dan is de status OK
echo "OK - Average Latency is $avg_latency_ms ms, Bandwidth is $bandwidth_gb GB/s | avg_latency=$avg_latency_ms ms; bandwidth=$bandwidth_gb GB/s"
exit 0
