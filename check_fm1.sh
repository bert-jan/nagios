#!/bin/bash

# Default values
USERNAME=""
PASSWORD=""
HOSTNAME=""
WARNING_THRESHOLD=0
CRITICAL_THRESHOLD=0
API_URL="/api/v1/QuarantineDirectoryDisplay"

# Help function
usage() {
  echo "Usage: $0 -u <username> -p <password> -H <hostname> -w <warning_threshold> -c <critical_threshold>"
  echo "  -u, --username      : FortiManager API username"
  echo "  -p, --password      : FortiManager API password"
  echo "  -H, --hostname      : FortiManager hostname or IP address"
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

# API request to get QuarantineDirectoryDisplay data
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" "https://$HOSTNAME$API_URL")

# Check if the API request was successful
if [ $? -ne 0 ]; then
  echo "CRITICAL: Could not reach FortiManager API"
  exit 2
fi

# Parse JSON data for the count of each quarantine category
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

# Calculate total quarantine count (sum of all categories)
TOTAL_COUNT=$((BULK_COUNT + CONTENT_COUNT + DLP_COUNT + VIRUS_COUNT + PERSONALOUT_COUNT))

# Define the return status based on thresholds
STATUS="OK"
EXIT_CODE=0
if [ "$TOTAL_COUNT" -ge "$CRITICAL_THRESHOLD" ]; then
  STATUS="CRITICAL"
  EXIT_CODE=2
elif [ "$TOTAL_COUNT" -ge "$WARNING_THRESHOLD" ]; then
  STATUS="WARNING"
  EXIT_CODE=1
fi

# Output Nagios-compatible message and perfdata
echo "$STATUS: Total Quarantine Count: $TOTAL_COUNT | bulk=$BULK_COUNT content=$CONTENT_COUNT dlp=$DLP_COUNT virus=$VIRUS_COUNT personalOut=$PERSONALOUT_COUNT"

# Exit with appropriate code
exit $EXIT_CODE
