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

# Function to fetch alerts and display details
function check_alerts() {
    local severity="$1"
    local threshold="$2"

    # Fetch alerts for the specified severity
    local response=$(curl -s -k -H "Authorization: Bearer $BEARER_TOKEN" \
        "${NUTANIX_API_URL}/PrismGateway/services/rest/v2.0/alerts/?resolved=false&severity=${severity}&get_causes=true&detailed_info=true")

    # Check if API call was successful
    if [[ $? -ne 0 || -z "$response" ]]; then
        echo "UNKNOWN - API request failed or returned empty response for ${severity} alerts"
        return 3
    fi

    # Count the number of alerts based on .metadata.total_entities
    local alert_count=$(echo "$response" | jq '.metadata.total_entities')
    if [[ -z "$alert_count" || "$alert_count" == "null" ]]; then
        alert_count=0
    fi

    # Collect alert titles for extended status information
    local alert_titles=$(echo "$response" | jq -r '.entities[].alert_title')

    # Evaluate threshold and prepare status
    local output=""
    local status=0
    if (( alert_count >= threshold )); then
        if [[ "$severity" == "CRITICAL" ]]; then
            output="CRITICAL - $alert_count critical alert(s) (Threshold: $threshold)"
            status=2
        elif [[ "$severity" == "WARNING" ]]; then
            output="WARNING - $alert_count warning alert(s) (Threshold: $threshold)"
            status=1
        fi
    else
        output="OK - No $severity alerts exceeding threshold"
    fi

    # Generate final output with extended status information
    echo -e "$output | ${severity,,}s=$alert_count\n$alert_titles"
    return $status
}

# Run checks for both WARNING and CRITICAL severities
check_alerts "WARNING" "$WARNING_COUNT_THRESHOLD"
warning_status=$?
check_alerts "CRITICAL" "$CRITICAL_COUNT_THRESHOLD"
critical_status=$?

# Exit with the highest status among warning and critical checks
if (( critical_status == 2 )); then
    exit 2
elif (( warning_status == 1 )); then
    exit 1
else
    exit 0
fi
