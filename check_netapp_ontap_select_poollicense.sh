#!/bin/bash

# Default variables
ONTAP_API_URL=""
USERNAME=""
PASSWORD=""
WARN_DAYS=90
CRIT_DAYS=60

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u|--url) ONTAP_API_URL="$2"; shift ;;
        -U|--username) USERNAME="$2"; shift ;;
        -P|--password) PASSWORD="$2"; shift ;;
        -w|--warning) WARN_DAYS="$2"; shift ;;
        -c|--critical) CRIT_DAYS="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 3 ;;
    esac
    shift
done

# Check if the required arguments are provided
if [[ -z "$ONTAP_API_URL" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
    echo "UNKNOWN - URL (-u), Username (-U), and Password (-P) are required arguments."
    exit 3
fi

# Obtain the bearer token
auth_response=$(curl -s -X POST -k -u "$USERNAME:$PASSWORD" "$ONTAP_API_URL/api/v1/auth/login" -H "Content-Type: application/json")
if [[ $? -ne 0 ]]; then
    echo "UNKNOWN - Unable to connect to ONTAP API"
    exit 3
fi

# Extract the token from the response
bearer_token=$(echo "$auth_response" | jq -r '.token')
if [[ -z "$bearer_token" || "$bearer_token" == "null" ]]; then
    echo "UNKNOWN - Authentication failed, could not retrieve token"
    exit 3
fi

# Fetch capacity pool expiry date using the bearer token
capacity_response=$(curl -s -k -H "Authorization: Bearer $bearer_token" "$ONTAP_API_URL/api/v1/capacity-pool")
expiry_date=$(echo "$capacity_response" | jq -r '.expiry_date')

# Check if expiry date was retrieved
if [[ -z "$expiry_date" || "$expiry_date" == "null" ]]; then
    echo "UNKNOWN - Unable to retrieve capacity pool expiry date"
    exit 3
fi

# Convert expiry date (in ISO 8601 format) and current date to epoch format
expiry_epoch=$(date -d "$(echo "$expiry_date" | sed 's/\(.*\)T.*/\1/')" +%s)
current_epoch=$(date +%s)
diff_days=$(( (expiry_epoch - current_epoch) / 86400 ))

# Determine Nagios status based on the remaining days
if (( diff_days <= CRIT_DAYS )); then
    echo "CRITICAL - Capacity pool expires in $diff_days days on $expiry_date"
    exit 2
elif (( diff_days <= WARN_DAYS )); then
    echo "WARNING - Capacity pool expires in $diff_days days on $expiry_date"
    exit 1
else
    echo "OK - Capacity pool expires in $diff_days days on $expiry_date"
    exit 0
fi
