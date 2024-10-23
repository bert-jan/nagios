#!/bin/bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default values
FORTIPROXY_IP=""
TOKEN=""
COMPONENT=""
WARN_TEMP=35
CRIT_TEMP=40
API_URL=""

# Function to display usage
usage() {
    echo "Usage: $0 -H <fortiproxy_ip> -t <bearer_token> -c <component> [-w <warning_temp>] [-C <critical_temp>]"
    echo ""
    echo "  -H | --host          FortiProxy IP address"
    echo "  -t | --token         Bearer token for FortiProxy"
    echo "  -c | --component     Component to check (psu, fan, temp)"
    echo "  -w | --warning       Warning temperature threshold (default: 35°C)"
    echo "  -C | --critical      Critical temperature threshold (default: 40°C)"
    exit $UNKNOWN
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -H|--host) FORTIPROXY_IP="$2"; shift ;;
        -t|--token) TOKEN="$2"; shift ;;
        -c|--component) COMPONENT="$2"; shift ;;
        -w|--warning) WARN_TEMP="$2"; shift ;;
        -C|--critical) CRIT_TEMP="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if mandatory arguments are provided
if [[ -z "$FORTIPROXY_IP" || -z "$TOKEN" || -z "$COMPONENT" ]]; then
    usage
fi

# Define API URL for system sensor check
API_URL="https://${FORTIPROXY_IP}/api/v2/monitor/system/sensor"

# Curl command to fetch sensor data using bearer token
response=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" -X GET "${API_URL}")

# Check if curl executed successfully
if [ $? -ne 0 ]; then
    echo "CRITICAL: Failed to query FortiProxy API"
    exit $CRITICAL
fi

# Function to check sensors based on the component
check_sensors() {
    local component_name=$1
    local sensor1=$2
    local sensor2=$3
    local is_temp=$4

    sensor1_status=$(echo "$response" | jq -r --arg SENSOR "$sensor1" '.results[] | select(.name == $SENSOR) | .status')
    sensor1_value=$(echo "$response" | jq -r --arg SENSOR "$sensor1" '.results[] | select(.name == $SENSOR) | .value')

    sensor2_status=$(echo "$response" | jq -r --arg SENSOR "$sensor2" '.results[] | select(.name == $SENSOR) | .status')
    sensor2_value=$(echo "$response" | jq -r --arg SENSOR "$sensor2" '.results[] | select(.name == $SENSOR) | .value')

    # If checking temperatures, apply thresholds for warning and critical levels
    if [[ "$is_temp" == "true" ]]; then
        # Check thresholds for sensor 1
        if (( $(echo "$sensor1_value > $CRIT_TEMP" | bc -l) )); then
            echo "CRITICAL: $sensor1 ($sensor1_value°C) exceeds critical threshold ($CRIT_TEMP°C)"
            exit $CRITICAL
        elif (( $(echo "$sensor1_value > $WARN_TEMP" | bc -l) )); then
            echo "WARNING: $sensor1 ($sensor1_value°C) exceeds warning threshold ($WARN_TEMP°C)"
            exit $WARNING
        fi

        # Check thresholds for sensor 2
        if (( $(echo "$sensor2_value > $CRIT_TEMP" | bc -l) )); then
            echo "CRITICAL: $sensor2 ($sensor2_value°C) exceeds critical threshold ($CRIT_TEMP°C)"
            exit $CRITICAL
        elif (( $(echo "$sensor2_value > $WARN_TEMP" | bc -l) )); then
            echo "WARNING: $sensor2 ($sensor2_value°C) exceeds warning threshold ($WARN_TEMP°C)"
            exit $WARNING
        fi
    fi

    # Check the status of both sensors
    if [[ "$sensor1_status" == "normal" && "$sensor2_status" == "normal" ]]; then
        echo "OK: Both $component_name are normal | ${sensor1}_value=${sensor1_value} ${sensor2}_value=${sensor2_value}"
        exit $OK
    elif [[ "$sensor1_status" != "normal" || "$sensor2_status" != "normal" ]]; then
        echo "CRITICAL: $component_name status issue detected | ${sensor1}_status=${sensor1_status}, ${sensor2}_status=${sensor2_status} ${sensor1}_value=${sensor1_value} ${sensor2}_value=${sensor2_value}"
        exit $CRITICAL
    else
        echo "UNKNOWN: $component_name status could not be determined"
        exit $UNKNOWN
    fi
}

# Check the component provided by the user
case $COMPONENT in
    psu)
        check_sensors "PSU" "PSU1" "PSU2" "false"
        ;;
    fan)
        check_sensors "Fan" "PSUFAN1" "PSUFAN2" "false"
        ;;
    temp)
        check_sensors "Temperature" "PSUTEMP1" "PSUTEMP2" "true"
        ;;
    *)
        echo "UNKNOWN: Invalid component specified. Please use 'psu', 'fan', or 'temp'."
        exit $UNKNOWN
        ;;
esac
