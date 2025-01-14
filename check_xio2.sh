#!/bin/bash

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
CHECK_IOPS=false
HOST_URL=""

while getopts "u:l:w:c:b:d:i:" opt; do
  case ${opt} in
    u ) HOST_URL=$OPTARG ;;  # Host URL
    l ) LATENCY_THRESHOLD=$OPTARG; CHECK_LATENCY=true ;;  # Latency Threshold
    w ) BW_WARNING=$OPTARG; CHECK_BW=true ;;  # Bandwidth Warning
    c ) BW_CRITICAL=$OPTARG; CHECK_BW=true ;;  # Bandwidth Critical
    b ) LATENCY_WARNING=$OPTARG; CHECK_LATENCY=true ;;  # Bandwidth Threshold
    i ) CHECK_IOPS=true ;;  # IOPS Check
    d ) DEBUG=true ;;  # Debugging
    \? ) echo "Usage: $0 [-u host_url] [-l latency_threshold] [-w bw_warning] [-c bw_critical] [-i]"; exit 1 ;;
  esac
done

# Controleren of HOST_URL is opgegeven
if [ -z "$HOST_URL" ]; then
  echo "Error: Host URL is required (-u <url>)"
  exit 1
fi

# Verkrijg API-gegevens
response=$(curl -s -u $USER:$PASS $HOST_URL/api/1.4/system/statistics)

# Haal de gemiddelde latency (in microseconden), doorvoersnelheid (bandbreedte in bytes), en IOPS op
avg_latency_us=$(get_json_value '.statistics[0].avg_latency')
bandwidth_bytes=$(get_json_value '.statistics[0].throughput')
iops=$(get_json_value '.statistics[0].iops')

# Converteer de latency naar milliseconden en de bandbreedte naar GB/s
avg_latency_ms=$(echo "scale=2; $avg_latency_us / 1000" | bc)
bandwidth_gb=$(echo "scale=2; $bandwidth_bytes / (1024*1024*1024)" | bc)

# Format de latency om ervoor te zorgen dat het altijd 1 cijfer voor de komma heeft en 2 decimalen
formatted_latency=$(round $avg_latency_ms)

# Debug-output (indien ingeschakeld)
if [ "$DEBUG" == "true" ]; then
    echo "API Response: $response"
    echo "Avg Latency (us): $avg_latency_us"
    echo "Bandwidth (bytes): $bandwidth_bytes"
    echo "Avg Latency (ms): $formatted_latency"
    echo "Bandwidth (GB/s): $bandwidth_gb"
    echo "IOPS: $iops"
fi

# Controleer latency drempel (als ingesteld)
if [ "$CHECK_LATENCY" == true ]; then
    if [ ! -z "$LATENCY_THRESHOLD" ]; then
        if (( $(echo "$formatted_latency > $LATENCY_THRESHOLD" | bc -l) )); then
            echo "CRITICAL - Average Latency is $formatted_latency ms | avg_latency=$formatted_latency ms"
            exit 2
        elif [ ! -z "$LATENCY_WARNING" ] && (( $(echo "$formatted_latency > $LATENCY_WARNING" | bc -l) )); then
            echo "WARNING - Average Latency is $formatted_latency ms | avg_latency=$formatted_latency ms"
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

# Controleer IOPS (indien nodig)
if [ "$CHECK_IOPS" == true ]; then
    if [ ! -z "$iops" ]; then
        echo "IOPS: $iops"
    else
        echo "Error: Unable to fetch IOPS data"
        exit 3
    fi
fi

# Als alles goed is, dan is de status OK
echo "OK - Average Latency is $formatted_latency ms, Bandwidth is $bandwidth_gb GB/s, IOPS is $iops | avg_latency=$formatted_latency ms; bandwidth=$bandwidth_gb GB/s; iops=$iops"
exit 0
