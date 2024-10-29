#!/bin/bash

# Default variables for Rancher API
RANCHER_API_URL=""
RANCHER_API_TOKEN=""
CRIT_THRESHOLD=10  # Critical threshold for number of critical alerts
WARN_THRESHOLD=5   # Warning threshold for number of warning alerts

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--critical) CRIT_THRESHOLD="$2"; shift ;;
        -w|--warning) WARN_THRESHOLD="$2"; shift ;;
        -u|--url) RANCHER_API_URL="$2"; shift ;;
        -t|--token) RANCHER_API_TOKEN="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 3 ;;
    esac
    shift
done

# Check if the required arguments are provided
if [[ -z "$RANCHER_API_URL" || -z "$RANCHER_API_TOKEN" ]]; then
    echo "UNKNOWN - URL (-u) and Token (-t) are required arguments."
    exit 3
fi

# Query Rancher API for alerts
response=$(curl -s -k -H "Authorization: Bearer $RANCHER_API_TOKEN" "$RANCHER_API_URL")

# Check if curl request was successful
if [[ $? -ne 0 ]]; then
  echo "UNKNOWN - Unable to connect to Rancher API"
  exit 3
fi

# Extract alerts for warnings and criticals using jq
warning_alerts=$(echo "$response" | jq '[.data[] | select(.labels.severity == "warning")]')
critical_alerts=$(echo "$response" | jq '[.data[] | select(.labels.severity == "critical")]')

# Count the number of warning and critical alerts
warning_count=$(echo "$warning_alerts" | jq 'length')
critical_count=$(echo "$critical_alerts" | jq 'length')

# Format description output for each alert
print_alerts() {
    local alerts=$1
    local severity=$2
    echo "$alerts" | jq -r --arg severity "$severity" '.[] | "\($severity) - \(.annotations.description)"'
}

# Output the descriptions of warnings and criticals
warning_descriptions=$(print_alerts "$warning_alerts" "WARNING")
critical_descriptions=$(print_alerts "$critical_alerts" "CRITICAL")

# Nagios Output based on the alert counts and descriptions
if (( critical_count >= CRIT_THRESHOLD )); then
    echo -e "CRITICAL - $critical_count critical alerts\n$critical_descriptions | warnings=$warning_count criticals=$critical_count"
    exit 2
elif (( warning_count >= WARN_THRESHOLD )); then
    echo -e "WARNING - $warning_count warning alerts\n$warning_descriptions | warnings=$warning_count criticals=$critical_count"
    exit 1
else
    echo -e "OK - No significant alerts | warnings=$warning_count criticals=$critical_count"
    exit 0
fi
