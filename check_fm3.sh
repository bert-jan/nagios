#!/bin/bash

# Default values
USERNAME=""
PASSWORD=""
HOSTNAME=""
WARNING_THRESHOLD=0
CRITICAL_THRESHOLD=0
API_URL="/api/v1/QuarantineDirectoryDisplay"
LOGIN_URL="/api/v1/AdminLogin"
COOKIE_FILE=$(mktemp)  # temp file for cookie

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

# Function to clean up the cookie file after the script finishes
cleanup() {
  rm -f "$COOKIE_FILE"
}

# Trap the cleanup function to run when the script finishes
trap cleanup EXIT

# Authenticate via /api/v1/AdminLogin and get the session cookie
RESPONSE=$(curl -s -X POST -d '{"username": "'$USERNAME'", "password": "'$PASSWORD'"}' \
  -H "Content-Type: application/json" \
  -c "$COOKIE_FILE" "https://$HOSTNAME$LOGIN_URL")

# Check if login was successful
if [[ "$RESPONSE" == *"denied"* ]]; then
  echo "CRITICAL: Login failed. Check username/password."
  exit 2
fi

# API request to get QuarantineDirectoryDisplay data using the session cookie
RESPONSE=$(curl -s -b "$COOKIE_FILE" "https://$HOSTNAME$API_URL")

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

# Check the status based on the thresholds
EXIT_CODE=0
STATUS="OK"

# Compare each count against the warning and critical thresholds
if [ "$BULK_COUNT" -ge "$CRITICAL_THRESHOLD" ] || \
   [ "$CONTENT_COUNT" -ge "$CRITICAL_THRESHOLD" ] || \
   [ "$DLP_COUNT" -ge "$CRITICAL_THRESHOLD" ] || \
   [ "$VIRUS_COUNT" -ge "$CRITICAL_THRESHOLD" ] || \
   [ "$PERSONALOUT_COUNT" -ge "$CRITICAL_THRESHOLD" ]; then
  STATUS="CRITICAL"
  EXIT_CODE=2
elif [ "$BULK_COUNT" -ge "$WARNING_THRESHOLD" ] || \
     [ "$CONTENT_COUNT" -ge "$WARNING_THRESHOLD" ] || \
     [ "$DLP_COUNT" -ge "$WARNING_THRESHOLD" ] || \
     [ "$VIRUS_COUNT" -ge "$WARNING_THRESHOLD" ] || \
     [ "$PERSONALOUT_COUNT" -ge "$WARNING_THRESHOLD" ]; then
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

# Exit with appropriate code
exit $EXIT_CODE
