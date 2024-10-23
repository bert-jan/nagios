#!/bin/bash

# Default variables for FortiProxy API
FORTIPROXY_HOST=""
FORTIPROXY_VDOM=""
FORTIPROXY_TOKEN=""
FORTIPROXY_API_URL=""
CRIT_THRESHOLD=1000  # Define critical threshold for proxy sessions
WARN_THRESHOLD=500   # Define warning threshold for proxy sessions

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--critical) CRIT_THRESHOLD="$2"; shift ;;
        -w|--warning) WARN_THRESHOLD="$2"; shift ;;
        -t|--token) FORTIPROXY_TOKEN="$2"; shift ;;
        -H|--host) FORTIPROXY_HOST="$2"; shift ;;
        -s|--vdom) FORTIPROXY_VDOM="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 3 ;;
    esac
    shift
done

# Check if the required arguments are provided
if [[ -z "$FORTIPROXY_HOST" || -z "$FORTIPROXY_TOKEN" ]]; then
    echo "UNKNOWN - Host (-H) and Token (-t) are required arguments."
    exit 3
fi

# Set the FortiProxy API URL, including VDOM scope if provided
if [[ -n "$FORTIPROXY_VDOM" ]]; then
    FORTIPROXY_API_URL="https://$FORTIPROXY_HOST/api/v2/monitor/system/proxy-sessions?vdom=$FORTIPROXY_VDOM"
else
    FORTIPROXY_API_URL="https://$FORTIPROXY_HOST/api/v2/monitor/system/proxy-sessions"
fi

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
