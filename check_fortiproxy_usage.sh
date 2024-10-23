#!/bin/bash

# Default variables for FortiProxy API
FORTIPROXY_API_URL="https://<fortiproxy-ip>/api/v2/monitor/system/proxy-sessions"
FORTIPROXY_TOKEN="<your_bearer_token>"
CRIT_THRESHOLD=1000  # Define critical threshold for proxy sessions
WARN_THRESHOLD=500   # Define warning threshold for proxy sessions

# Parse command line arguments for thresholds (optional)
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--critical) CRIT_THRESHOLD="$2"; shift ;;
        -w|--warning) WARN_THRESHOLD="$2"; shift ;;
        -t|--token) FORTIPROXY_TOKEN="$2"; shift ;;
        -u|--url) FORTIPROXY_API_URL="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 3 ;;
    esac
    shift
done

# Query FortiProxy API for active proxy sessions
response=$(curl -s -k -H "Authorization: Bearer $FORTIPROXY_TOKEN" "$FORTIPROXY_API_URL")

# Check if curl request was successful
if [[ $? -ne 0 ]]; then
  echo "UNKNOWN - Unable to connect to FortiProxy API"
  exit 3
fi

# Extract number of active proxy sessions (customize this according to the API response structure)
active_proxy_sessions=$(echo "$response" | jq '.results.active_pure_proxy_sessions')

# Check if the jq query was successful
if [[ -z "$active_proxy_sessions" || "$active_proxy_sessions" == "null" ]]; then
  echo "UNKNOWN - Unable to parse FortiProxy API response"
  exit 3
fi

# Output Nagios result based on session count
if (( active_proxy_sessions >= CRIT_THRESHOLD )); then
  echo "CRITICAL - Active proxy sessions: $active_proxy_sessions | sessions=$active_proxy_sessions"
  exit 2
elif (( active_proxy_sessions >= WARN_THRESHOLD )); then
  echo "WARNING - Active proxy sessions: $active_proxy_sessions | sessions=$active_proxy_sessions"
  exit 1
else
  echo "OK - Active proxy sessions: $active_proxy_sessions | sessions=$active_proxy_sessions"
  exit 0
fi
