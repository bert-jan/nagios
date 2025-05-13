#!/bin/bash

# Default values
USERNAME=""
PASSWORD=""
HOSTNAME=""
WARNING_THRESHOLD=0
CRITICAL_THRESHOLD=0
API_PREFIX="/api/v1"
API_PATH="/QuarantineDirectoryDisplay"  # Standaard pad voor Quarantine
COOKIE_FILE=$(mktemp)  # tijdelijke file voor de cookie (wordt aan het einde verwijderd)
COMPONENT="QuarantineDirectoryDisplay"   # Standaard component

# Help function
usage() {
  echo "Usage: $0 -u <username> -p <password> -H <hostname> -C <component> -w <warning_threshold> -c <critical_threshold>"
  echo "  -u, --username      : FortiManager API username"
  echo "  -p, --password      : FortiManager API password"
  echo "  -H, --hostname      : FortiManager hostname or IP address"
  echo "  -C, --component     : Component (e.g., QuarantineDirectoryDisplay, PowerSupply, etc.)"
  echo "  -w, --warning       : Warning threshold for count (numeric)"
  echo "  -c, --critical      : Critical threshold for count (numeric)"
  exit 3
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -u|--username) USERNAME="$2"; shift ;;
    -p|--password) PASSWORD="$2"; shift ;;
    -H|--hostname) HOSTNAME="$2"; shift ;;
    -C|--component) COMPONENT="$2"; shift ;;
    -w|--warning) WARNING_THRESHOLD="$2"; shift ;;
    -c|--critical) CRITICAL_THRESHOLD="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
  shift
done

# Validate required arguments
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$HOSTNAME" ]; then
  echo "ERROR: Username, password, and hostname are required."
  usage
fi

# Function to clean up the cookie file after the script finishes
cleanup() {
  rm -f "$COOKIE_FILE"
}

# Trap the cleanup function to run when the script finishes
trap cleanup EXIT

# Authenticate via /api/v1/AdminLogin and get the session cookie
RESPONSE=$(curl -s -X POST -d '{"username": "'$USERNAME'", "password": "'$PASSWORD'"}' \
  -H "Content-Type: application/json" \
  -c "$COOKIE_FILE" "https://$HOSTNAME$API_PREFIX/AdminLogin")

# Check if login was successful by detecting "denied"
if [[ "$RESPONSE" == *"denied"* ]]; then
  echo "CRITICAL: Login failed. Check username/password."
  exit 2
fi

# Build the API endpoint path dynamically based on the component
API_URL="$API_PREFIX/$COMPONENT"

# API request to get data for the selected component using the session cookie
RESPONSE=$(curl -s -b "$COOKIE_FILE" "https://$HOSTNAME$API_URL")

# Check if the API request was successful
if [ $? -ne 0 ]; then
  echo "CRITICAL: Could not reach FortiManager API"
  exit 2
fi

# Depending on the component, parse the JSON response differently
case "$COMPONENT" in
  "QuarantineDirectoryDisplay")
    BULK_COUNT=$(echo "$RESPONSE" | jq '.Bulk')
    CONTENT_COUNT=$(echo "$RESPONSE" | jq '.Content')
    DLP_COUNT=$(echo "$RESPONSE" | jq '.Dlp')
    VIRUS_COUNT=$(echo "$RESPONSE" | jq '.Virus')
    PERSONALOUT_COUNT=$(echo "$RESPONSE" | jq '.PersonalOut')

    # Check if jq was successful
    if [ $? -ne 0 ]; then
      echo "CRITICAL: Failed to parse the JSON response"
      exit 2
    fi

    # Calculate the total quarantine count
    TOTAL_COUNT=$((BULK_COUNT + CONTENT_COUNT + DLP_COUNT + VIRUS_COUNT + PERSONALOUT_COUNT))

    # Check the status based on the thresholds
    EXIT_CODE=0
    STATUS="OK"

    if [ "$TOTAL_COUNT" -ge "$CRITICAL_THRESHOLD" ]; then
      STATUS="CRITICAL"
      EXIT_CODE=2
    elif [ "$TOTAL_COUNT" -ge "$WARNING_THRESHOLD" ]; then
      STATUS="WARNING"
      EXIT_CODE=1
    fi

    # Output Nagios-compatible message and perfdata
    echo "$STATUS: Bulk=$BULK_COUNT, Content=$CONTENT_COUNT, Dlp=$DLP_COUNT, Virus=$VIRUS_COUNT, PersonalOut=$PERSONALOUT_COUNT | \
    bulk=$BULK_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0; \
    content=$CONTENT_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0; \
    dlp=$DLP_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0; \
    virus=$VIRUS_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0; \
    personalOut=$PERSONALOUT_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0;"
    ;;

  "PowerSupply")
    # Handle power supply data retrieval and processing here (example structure)
    POWER_SUPPLY_STATUS=$(echo "$RESPONSE" | jq '.powerSupplyStatus')

    if [ $? -ne 0 ]; then
      echo "CRITICAL: Failed to parse the power supply status"
      exit 2
    fi

    STATUS="OK"
    if [[ "$POWER_SUPPLY_STATUS" == "failure" ]]; then
      STATUS="CRITICAL"
      EXIT_CODE=2
    fi

    # Output Nagios-compatible message for power supply
    echo "$STATUS: Power Supply Status: $POWER_SUPPLY_STATUS | powerSupplyStatus=$POWER_SUPPLY_STATUS"
    ;;

  *)
    echo "CRITICAL: Unknown component specified"
    exit 2
    ;;
esac

# Exit with appropriate code
exit $EXIT_CODE
