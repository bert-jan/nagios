#!/bin/bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Input variables (update to use your FortiProxy IP and API Token)
FORTIPROXY_IP="<FORTIPROXY_IP>"
API_TOKEN="<YOUR_API_TOKEN>"

# API Endpoint
API_URL="https://${FORTIPROXY_IP}/api/v2/monitor/system/sensor"

# Curl command to fetch sensor data
response=$(curl -k -s -H "Authorization: Bearer ${API_TOKEN}" -X GET "${API_URL}")

# Check if curl executed successfully
if [ $? -ne 0 ]; then
    echo "CRITICAL: Failed to query FortiProxy API"
    exit $CRITICAL
fi

# Extract sensor information for PSU1 and PSU2 from the JSON response
psu1_status=$(echo "$response" | jq -r '.results[] | select(.name == "PSU1") | .status')
psu1_value=$(echo "$response" | jq -r '.results[] | select(.name == "PSU1") | .value')
psu2_status=$(echo "$response" | jq -r '.results[] | select(.name == "PSU2") | .status')
psu2_value=$(echo "$response" | jq -r '.results[] | select(.name == "PSU2") | .value')

# Check if PSU1 and PSU2 exist in the response
if [[ -z "$psu1_status" || -z "$psu2_status" ]]; then
    echo "UNKNOWN: PSU1 or PSU2 not found in sensor data"
    exit $UNKNOWN
fi

# Check the status of PSU1 and PSU2
if [[ "$psu1_status" == "normal" && "$psu2_status" == "normal" ]]; then
    echo "OK: PSU1 and PSU2 are normal | PSU1_value=${psu1_value} PSU2_value=${psu2_value}"
    exit $OK
else
    if [[ "$psu1_status" != "normal" ]]; then
        echo "CRITICAL: PSU1 status is $psu1_status | PSU1_value=${psu1_value} PSU2_value=${psu2_value}"
        exit $CRITICAL
    elif [[ "$psu2_status" != "normal" ]]; then
        echo "CRITICAL: PSU2 status is $psu2_status | PSU1_value=${psu1_value} PSU2_value=${psu2_value}"
        exit $CRITICAL
    else
        echo "UNKNOWN: Unable to determine PSU status | PSU1_value=${psu1_value} PSU2_value=${psu2_value}"
        exit $UNKNOWN
    fi
fi
