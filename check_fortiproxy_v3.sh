#!/bin/bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default values
FORTIPROXY_IP=""
USER=""
PASSWORD=""
COMPONENT=""
TOKEN_URL="https://${FORTIPROXY_IP}/api/v2/auth/login/"
API_URL=""
TOKEN=""

# Function to display usage
usage() {
    echo "Usage: $0 -H <fortiproxy_ip> -u <username> -p <password> -c <component>"
    echo ""
    echo "  -H | --host          FortiProxy IP address"
    echo "  -u | --user          Username for FortiProxy"
    echo "  -p | --pass          Password for FortiProxy"
    echo "  -c | --component     Component to check (psu, fan, temp)"
    exit $UNKNOWN
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -H|--host) FORTIPROXY_IP="$2"; shift ;;
        -u|--user) USER="$2"; shift ;;
        -p|--pass) PASSWORD="$2"; shift ;;
        -c|--component) COMPONENT="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if mandatory arguments are provided
if [[ -z "$FORTIPROXY_IP" || -z "$USER" || -z "$PASSWORD" || -z "$COMPONENT" ]]; then
    usage
fi

# Function to get the bearer token using user credentials
get_token() {
    response=$(curl -k -s -X POST "$TOKEN_URL" \
      -H "Content-Type: application/json" \
      -d "{\"username\": \"$USER\", \"password\": \"$PASSWORD\"}")
    
    # Extract token from response
    TOKEN=$(echo "$response" | jq -r '.token')
    
    # Check if token is valid
    if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
        echo "CRITICAL: Failed to authenticate and retrieve token"
        exit $CRITICAL
    fi
}

# Get bearer token
TOKEN_URL="https://${FORTIPROXY_IP}/api/v2/auth/login/"
get_token

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

    sensor1_status=$(echo "$response" | jq -r --arg SENSOR "$sensor1" '.results[] | select(.name == $SENSOR) | .status')
    sensor1_value=$(echo "$response" | jq -r --arg SENSOR "$sensor1" '.results[] | select(.name == $SENSOR) | .value')

    sensor2_status=$(echo "$response" | jq -r --arg SENSOR "$sensor2" '.results[] | select(.name == $SENSOR) | .status')
    sensor2_value=$(echo "$response" | jq -r --arg SENSOR "$sensor2" '.results[] | select(.name == $SENSOR) | .value')

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
        check_sensors "PSU" "PSU1" "PSU2"
        ;;
    fan)
        check_sensors "Fan" "PSUFAN1" "PSUFAN2"
        ;;
    temp)
        check_sensors "Temperature" "PSUTEMP1" "PSUTEMP2"
        ;;
    *)
        echo "UNKNOWN: Invalid component specified. Please use 'psu', 'fan', or 'temp'."
        exit $UNKNOWN
        ;;
esac
