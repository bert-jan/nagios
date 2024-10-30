#!/bin/bash

# Standaardwaarden voor variabelen
WARNING_THRESHOLD=1
CRITICAL_THRESHOLD=1

# Functie om het script gebruik te tonen
usage() {
  echo "Usage: $0 -u <URL> -t <BEARER_TOKEN> [-w <warning threshold>] [-c <critical threshold>]"
  exit 3
}

# Verwerk de argumenten
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -u|--url) URL="$2"; shift ;;
    -t|--token) TOKEN="$2"; shift ;;
    -w|--warning) WARNING_THRESHOLD="$2"; shift ;;
    -c|--critical) CRITICAL_THRESHOLD="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

# Controleer op verplichte parameters
if [[ -z "$URL" || -z "$TOKEN" ]]; then
  usage
fi

# Functie om alerts op te halen en te controleren
check_alerts() {
  local severity="$1"
  local threshold="$2"
  local perf_label="${severity,,}s"

  # Haal data op van de Nutanix API
  response=$(curl -s -k -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "${URL}/PrismGateway/services/rest/v2.0/alerts/?resolved=false&severity=${severity}&get_causes=true&detailed_info=true")

  # Parse JSON response
  alert_count=$(echo "$response" | jq '.metadata.total_entities')
  alert_titles=$(echo "$response" | jq -r '.entities[].alert_title')

  # Controleer of het aantal alerts drempel overschrijdt en return output
  if [[ "$alert_count" -ge "$threshold" && "$alert_count" -gt 0 ]]; then
    echo "$severity - $alert_count $severity alert(s) (Threshold: $threshold)"
    echo "$alert_titles"
  fi

  # Perfdata output
  echo -n "$perf_label=${alert_count};${threshold}; "
}

# Variabelen voor waarschuwingen en kritische meldingen
warning_output=$(check_alerts "WARNING" "$WARNING_THRESHOLD")
critical_output=$(check_alerts "CRITICAL" "$CRITICAL_THRESHOLD")

# Samenvatting voor Nagios output
if [[ -n "$critical_output" ]]; then
  echo "$critical_output | $(check_alerts "CRITICAL" "$CRITICAL_THRESHOLD")$(check_alerts "WARNING" "$WARNING_THRESHOLD")"
  exit 2
elif [[ -n "$warning_output" ]]; then
  echo "$warning_output | $(check_alerts "WARNING" "$WARNING_THRESHOLD")"
  exit 1
else
  echo "OK - No active alerts exceeding thresholds | warnings=0;${WARNING_THRESHOLD}; criticals=0;${CRITICAL_THRESHOLD};"
  exit 0
fi
