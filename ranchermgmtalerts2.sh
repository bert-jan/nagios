#!/bin/bash

# Default variables
RANCHER_API_URL=""
BEARER_TOKEN=""
LOCAL_API_URL=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u|--url) RANCHER_API_URL="$2"; shift ;;
        -t|--token) BEARER_TOKEN="$2"; shift ;;
        -l|--local-url) LOCAL_API_URL="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 3 ;;
    esac
    shift
done

# Check if the required arguments are provided
if [[ -z "$RANCHER_API_URL" || -z "$BEARER_TOKEN" ]]; then
    echo "UNKNOWN - API URL (-u) and Bearer token (-t) are required arguments."
    exit 3
fi

# Use LOCAL_API_URL if specified; otherwise, default to RANCHER_API_URL
API_URL="${LOCAL_API_URL:-$RANCHER_API_URL}"

# Fetch alerts from the API
alerts_response=$(curl -s -k -H "Authorization: Bearer $BEARER_TOKEN" "$API_URL/v3/cluster/alerts")

# Check for API request errors
if [[ $? -ne 0 ]]; then
    echo "UNKNOWN - API request failed"
    exit 3
fi

# Extract the 'data' array from the JSON response
alerts=$(echo "$alerts_response" | jq -r '.data[]')

# Initialize counters
warning_count=0
critical_count=0
alert_messages=""

# Process each alert
while IFS= read -r alert; do
    severity=$(echo "$alert" | jq -r '.labels.severity')
    description=$(echo "$alert" | jq -r '.annotations.description // "No description provided"')

    case "$severity" in
        warning)
            ((warning_count++))
            alert_messages+="WARNING - $description | "
            ;;
        critical)
            ((critical_count++))
            alert_messages+="CRITICAL - $description | "
            ;;
    esac
done <<< "$alerts"

# Generate output based on the counts
if (( critical_count > 0 )); then
    echo "CRITICAL - $critical_count critical alert(s) | $alert_messages"
    exit 2
elif (( warning_count > 0 )); then
    echo "WARNING - $warning_count warning alert(s) | $alert_messages"
    exit 1
else
    echo "OK - No warning or critical alerts"
    exit 0
fi
