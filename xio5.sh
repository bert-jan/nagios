#!/bin/bash

# Functie voor het afdrukken van de helptekst
print_help() {
    echo "Usage: $0 [-u <url>] [-l <latency_threshold>] [-w <bw_warning>] [-c <bw_critical>] [-i]"
    echo ""
    echo "Required arguments:"
    echo "  -u <url>                  The URL of the XtremIO API to fetch statistics from (e.g. https://your_xtremio_host/api/1.4/system/statistics)"
    echo ""
    echo "Optional arguments:"
    echo "  -l <latency_threshold>    Latency threshold in milliseconds (ms). If the average latency exceeds this threshold, a WARNING or CRITICAL status will be returned."
    echo "  -w <bw_warning>           Bandwidth warning threshold in GB/s. If the bandwidth exceeds this threshold, a WARNING status will be returned."
    echo "  -c <bw_critical>          Bandwidth critical threshold in GB/s. If the bandwidth exceeds this threshold, a CRITICAL status will be returned."
    echo "  -i                        Fetches and checks IOPS (Input/Output Operations Per Second) from the XtremIO array."
    echo ""
    echo "Examples:"
    echo "  ./check_xtremio.sh -u 'https://your_xtremio_host/api/1.4/system/statistics' -l 5"
    echo "  ./check_xtremio.sh -u 'https://your_xtremio_host/api/1.4/system/statistics' -w 0.5 -c 1.0"
    echo "  ./check_xtremio.sh -u 'https://your_xtremio_host/api/1.4/system/statistics' -i"
    echo "  ./check_xtremio.sh -u 'https://your_xtremio_host/api/1.4/system/statistics' -l 2 -w 1"
}

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

while getopts "u:l:w:c:i" opt; do
  case ${opt} in
    u ) HOST_URL=$OPTARG ;;  # Host URL
    l ) LATENCY_THRESHOLD=$OPTARG; CHECK_LATENCY=true ;;  # Latency Threshold
    w ) BW_WARNING=$OPTARG; CHECK_BW=true ;;  # Bandwidth Warning
    c ) BW_CRITICAL=$OPTARG; CHECK_BW=true ;;  # Bandwidth Critical
    i ) CHECK_IOPS=true ;;  # IOPS Check, zonder argument
    \? ) print_help; exit 1 ;;  # Onjuiste optie, toon helptekst
  esac
done

# Controleren of HOST_URL is opgegeven
if [ -z "$HOST_URL" ]; then
  echo "Error: Host URL is required (-u <url>)"
  print_help
  exit 1
fi

# Verkrijg API-gegevens
response=$(curl -s -u $USER:$PASS $HOST_URL/api/1.4/system/statistics)

# Haal de gemiddelde latency (in microseconden), bandbreedte en IOPS op
avg_latency_us=$(get_json_value '.content."avg-latency"')
bandwidth_bytes=$(get_json_value '.content.bw')
iops=$(get_json_value '.content.iops')

# Controleer of we geldige numerieke waarden hebben voor de drempels
is_numeric() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

# Controleer of de latentie-drempel een geldig numeriek getal is
if [ ! -z "$LATENCY_THRESHOLD" ] && ! is_numeric "$LATENCY_THRESHOLD"; then
    echo "Error: Latency threshold (-l) must be a numeric value."
    exit 1
fi

# Controleer of de bandbreedte drempels geldige numerieke waarden zijn
if [ ! -z "$BW_WARNING" ] && ! is_numeric "$BW_WARNING"; then
    echo "Error: Bandwidth warning threshold (-w) must be a numeric value."
    exit 1
fi

if [ ! -z "$BW_CRITICAL" ] && ! is_numeric "$BW_CRITICAL"; then
    echo "Error: Bandwidth critical threshold (-c) must be a numeric value."
    exit 1
fi

# Converteer de latency naar milliseconden en de bandbreedte naar GB/s
avg_latency_ms=$(echo "scale=2; $avg_latency_us / 1000" | bc)

# Deel de bandbreedte twee keer door 1024 en converteer naar GB/s
bandwidth_gb=$(echo "scale=2; $bandwidth_bytes / (1024*1024*1024)" | bc)

# Format de latency om ervoor te zorgen dat het altijd 1 cijfer voor de komma heeft en 2 decimalen
formatted_latency=$(round $avg_latency_ms)

# ------------------ Latency Check ------------------
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

    # Als alles goed is, dan is de status OK
    echo "OK - Average Latency is $formatted_latency ms | avg_latency=$formatted_latency ms"
    exit 0
fi

# ------------------ Bandwidth Check ------------------
if [ "$CHECK_BW" == true ]; then
    if [ ! -z "$BW_WARNING" ] && (( $(echo "$bandwidth_gb > $BW_WARNING" | bc -l) )); then
        echo "WARNING - Bandwidth is $bandwidth_gb GB/s | bandwidth=$bandwidth_gb GB/s"
        exit 1
    elif [ ! -z "$BW_CRITICAL" ] && (( $(echo "$bandwidth_gb > $BW_CRITICAL" | bc -l) )); then
        echo "CRITICAL - Bandwidth is $bandwidth_gb GB/s | bandwidth=$bandwidth_gb GB/s"
        exit 2
    fi

    # Als alles goed is, dan is de status OK
    echo "OK - Bandwidth is $bandwidth_gb GB/s | bandwidth=$bandwidth_gb GB/s"
    exit 0
fi

# ------------------ IOPS Check ------------------
if [ "$CHECK_IOPS" == true ]; then
    if [ -z "$iops" ]; then
        echo "Error: Unable to fetch IOPS data"
        exit 3
    fi

    # Als alles goed is, dan is de status OK
    echo "OK - IOPS is $iops | iops=$iops"
    exit 0
fi

# Als geen van de parameters is ingesteld, geeft een foutmelding
echo "Error: No check selected. Please specify -l, -w or -i."
print_help
exit 1
