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

  # Haal data op van de Nutanix API
  response=$(curl -s -k -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "${URL}/PrismGateway/services/rest/v2.0/alerts/?resolved=false&severity=${severity}&get_causes=true&detailed_info=true")

  # Parse JSON response
  alert_count=$(echo "$response" | jq '.metadata.total_entities')
  alert_titles=$(echo "$response" | jq -r '.entities[].alert_title')

  # Output bij alert overschrijding
  if [[ "$alert_count" -ge "$threshold" ]]; then
    echo "$severity - $alert_count $severity alert(s) (Threshold: $threshold)"
    echo "$alert_titles"
  fi

  # Perfdata output toevoegen
  perfdata="${severity,,}s=${alert_count};${threshold}; "
  echo -n "$perfdata"
}

# Controleer op WARNING alerts en print status
warning_output=$(check_alerts "WARNING" "$WARNING_THRESHOLD")
warning_exit=$?

# Controleer op CRITICAL alerts en print status, alleen bij alerts > 0
critical_output=$(check_alerts "CRITICAL" "$CRITICAL_THRESHOLD")
critical_exit=$?

# Nagios status en perfdata samenvatting
if [[ "$critical_exit" -eq 2 ]]; then
  echo "$critical_output | $warning_output"
  exit 2
elif [[ "$warning_exit" -eq 1 ]]; then
  echo "$warning_output | $critical_output"
  exit 1
else
  echo "OK - No active alerts exceeding thresholds | ${warning_output}${critical_output}"
  exit 0
fi
