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
PSU=""
TOKEN_URL="https://${FORTIPROXY_IP}/api/v2/auth/login/"
API_URL=""
TOKEN=""

# Function to display usage
usage() {
    echo "Usage: $0 -H <fortiproxy_ip> -u <username> -p <password> -s <psu_name>"
    echo ""
    echo "  -H | --host          FortiProxy IP address"
    echo "  -u | --user          Username for FortiProxy"
    echo "  -p | --pass          Password for FortiProxy"
    echo "  -s | --psu           PSU name to check (e.g. PSU1, PSU2)"
    exit $UNKNOWN
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -H|--host) FORTIPROXY_IP="$2"; shift ;;
        -u|--user) USER="$2"; shift ;;
        -p|--pass) PASSWORD="$2"; shift ;;
        -s|--psu) PSU="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if mandatory arguments are provided
if [[ -z "$FORTIPROXY_IP" || -z "$USER" || -z "$PASSWORD" || -z "$PSU" ]]; then
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

# Extract sensor information for the specified PSU from the JSON response
psu_status=$(echo "$response" | jq -r --arg PSU "$PSU" '.results[] | select(.name == $PSU) | .status')
psu_value=$(echo "$response" | jq -r --arg PSU "$PSU" '.results[] | select(.name == $PSU) | .value')

# Check if PSU exists in the response
if [[ -z "$psu_status" ]]; then
    echo "UNKNOWN: PSU $PSU not found in sensor data"
    exit $UNKNOWN
fi

# Check the status of the PSU
if [[ "$psu_status" == "normal" ]]; then
    echo "OK: $PSU is normal | ${PSU}_value=${psu_value}"
    exit $OK
else
    echo "CRITICAL: $PSU status is $psu_status | ${PSU}_value=${psu_value}"
    exit $CRITICAL
fi
