#!/bin/bash

# Default variables
NUTANIX_API_URL=""
BEARER_TOKEN=""
WARNING_COUNT_THRESHOLD=1  # Default warning threshold
CRITICAL_COUNT_THRESHOLD=1  # Default critical threshold

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u|--url) NUTANIX_API_URL="$2"; shift ;;
        -t|--token) BEARER_TOKEN="$2"; shift ;;
        -w|--warning-count) WARNING_COUNT_THRESHOLD="$2"; shift ;;
        -C|--critical-count) CRITICAL_COUNT_THRESHOLD="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 3 ;;
    esac
    shift
done

# Check if the required arguments are provided
if [[ -z "$NUTANIX_API_URL" || -z "$BEARER_TOKEN" ]]; then
    echo "UNKNOWN - API URL (-u) and Bearer token (-t) are required arguments."
    exit 3
fi

# Set the Nutanix API endpoint for alerts
API_URL="$NUTANIX_API_URL/api/nutanix/v2/alerts"

# Fetch alerts from the API
alerts_response=$(curl -s -k -H "Authorization: Bearer $BEARER_TOKEN" "$API_URL")

# Check for API request errors
if [[ $? -ne 0 || -z "$alerts_response" ]]; then
    echo "UNKNOWN - API request failed or returned empty response"
    exit 3
fi

# Validate JSON and check if 'entities' field is present
data_present=$(echo "$alerts_response" | jq -e '.entities | length > 0' 2>/dev/null)
if [[ "$data_present" != "true" ]]; then
    echo "OK - No alerts found or 'entities' field is empty in API response | warnings=0 criticals=0"
    exit 0
fi

# Initialize counters
warning_count=0
critical_count=0
alert_messages=""

# Process each alert
echo "$alerts_response" | jq -c '.entities[] | select(.severity == "WARNING" or .severity == "CRITICAL") | select(.resolved == false and .acknowledged == false)' | while IFS= read -r alert; do
    severity=$(echo "$alert" | jq -r '.severity')
    description=$(echo "$alert" | jq -r '.alert_title // "No description provided"')

    case "$severity" in
        WARNING)
            ((warning_count++))
            alert_messages+="WARNING - $description\n"
            ;;
        CRITICAL)
            ((critical_count++))
            alert_messages+="CRITICAL - $description\n"
            ;;
    esac
done

# Generate output based on the counts and specified thresholds
output=""
status=0
if (( critical_count >= CRITICAL_COUNT_THRESHOLD )); then
    output="CRITICAL - $critical_count critical alert(s) (Threshold: $CRITICAL_COUNT_THRESHOLD)"
    status=2
elif (( warning_count >= WARNING_COUNT_THRESHOLD )); then
    output="WARNING - $warning_count warning alert(s) (Threshold: $WARNING_COUNT_THRESHOLD)"
    status=1
else
    output="OK - No warning or critical alerts"
fi

# Print final output with perfdata
echo -e "$output | warnings=$warning_count criticals=$critical_count\n$alert_messages"
exit $status
