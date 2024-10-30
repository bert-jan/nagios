#!/bin/bash

# Default values
WARNING_THRESHOLD=1
CRITICAL_THRESHOLD=1

# Usage
usage() {
  echo "Usage: $0 -h|--hostname <HOSTNAME> -u|--username <USERNAME> -p|--password <PASSWORD> [-w <warning threshold>] [-c <critical threshold>]"
  exit 3
}

# Script parameters
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--hostname) HOSTNAME="$2"; shift ;;
    -u|--username) USERNAME="$2"; shift ;;
    -p|--password) PASSWORD="$2"; shift ;;
    -w|--warning) WARNING_THRESHOLD="$2"; shift ;;
    -c|--critical) CRITICAL_THRESHOLD="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

# Check parameters
if [[ -z "$URL" || -z "$TOKEN" ]]; then
  usage
fi

# Check alerts
check_alerts() {
  local severity="$1"
  local threshold="$2"
  local perf_label="${severity,,}s"

  # Get data from Nutanix API
  response=$(curl -s -k -u "$USERNAME:$PASSWORD" -H "Content-Type: application/json" \
    "https://${HOSTNAME}:9440/PrismGateway/services/rest/v2.0/alerts/?resolved=false&severity=${severity}&get_causes=true&detailed_info=true")

  # Parse JSON response
  alert_count=$(echo "$response" | jq '.metadata.total_entities')
  alert_titles=$(echo "$response" | jq -r '.entities[].alert_title')

  # Check alerts treshold
  if [[ "$alert_count" -ge "$threshold" && "$alert_count" -gt 0 ]]; then
    echo "$severity - $alert_count $severity alert(s) (Threshold: $threshold)"
    echo "$alert_titles"
  fi

  # Perfdata output
  echo -n "$perf_label=${alert_count};${threshold}; "
}

# Warning and critical tresholds
warning_output=$(check_alerts "WARNING" "$WARNING_THRESHOLD")
critical_output=$(check_alerts "CRITICAL" "$CRITICAL_THRESHOLD")

# Nagios output
if [[ -n "$critical_output" ]]; then
  echo "$critical_output | $(check_alerts "CRITICAL" "$CRITICAL_THRESHOLD")$(check_alerts "WARNING" "$WARNING_THRESHOLD")"
  exit 2
elif [[ -n "$warning_output" ]]; then
  echo "$warning_output | $(check_alerts "WARNING" "$WARNING_THRESHOLD")"
  exit 1
else
  echo "OK - No active alerts exceeding thresholds | warnings=${WARNING_THRESHOLD};;;0; criticals=${CRITICAL_THRESHOLD};;;0;"
  exit 0
fi
