#!/bin/bash

# Parameters
RANCHER_API_URL="https://<rancher-mgmt-url>/v3/clusters/local/clusteralerts" # Rancher Management cluster
RANCHER_API_TOKEN="<api-token>" # Create via User Avatar > Account & API Keys > Create API Key
SEVERITIES=("warning" "critical")

# Get alerts from Rancher API
response=$(curl -s -k -u "$RANCHER_API_TOKEN" "$RANCHER_API_URL")

# Verify API-call
if [ $? -ne 0 ]; then
    echo "CRITICAL: Failed to connect to Rancher API"
    exit 2
fi

# Filter alerts based on severity warning and critical
alerts=$(echo "$response" | jq '[.data[] | select(.state=="alerting" and (.severity=="warning" or .severity=="critical"))]')

# Count warnings and critical alerts
warning_count=$(echo "$alerts" | jq '[.[] | select(.severity == "warning")] | length')
critical_count=$(echo "$alerts" | jq '[.[] | select(.severity == "critical")] | length')

# Set Nagios status based on alerts  (warn/crit)
if [ "$critical_count" -gt 0 ]; then
    echo "CRITICAL: $critical_count critical alerts found!"
    exit 2
elif [ "$warning_count" -gt 0 ]; then
    echo "WARNING: $warning_count warning alerts found!"
    exit 1
else
    echo "OK: No warning or critical alerts"
    exit 0
fi
