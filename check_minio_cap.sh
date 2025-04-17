#!/bin/bash

# Nagios plugin: Check MinIO capacity usage via mc admin info
# Usage: ./check_minio_capacity.sh -H myminio -w 75 -c 90

HOST_ALIAS=""
WARNING=""
CRITICAL=""

usage() {
    echo "Gebruik: $0 -H <mc alias> -w <warning%> -c <critical%>"
    exit 3
}

# Argumenten parsen
while getopts "H:w:c:" opt; do
    case $opt in
        H) HOST_ALIAS=$OPTARG ;;
        w) WARNING=$OPTARG ;;
        c) CRITICAL=$OPTARG ;;
        *) usage ;;
    esac
done

if [[ -z "$HOST_ALIAS" || -z "$WARNING" || -z "$CRITICAL" ]]; then
    usage
fi

# Data ophalen
USAGE_JSON=$(mc admin info --json "$HOST_ALIAS" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$USAGE_JSON" ]; then
    echo "CRITICAL - Kan geen data ophalen van $HOST_ALIAS"
    exit 2
fi

# Extract rawUsage en rawCapacity
RAW_USAGE=$(echo "$USAGE_JSON" | jq '.info.pools["0.0"].rawUsage')
RAW_CAPACITY=$(echo "$USAGE_JSON" | jq '.info.pools["0.0"].rawCapacity')

# Validatie
if [[ -z "$RAW_USAGE" || -z "$RAW_CAPACITY" || "$RAW_CAPACITY" -eq 0 ]]; then
    echo "UNKNOWN - Ongeldige opslagdata"
    exit 3
fi

# Berekeningen
PERCENTAGE_USED=$(echo "scale=2; $RAW_USAGE * 100 / $RAW_CAPACITY" | bc)
USAGE_TIB=$(echo "scale=2; $RAW_USAGE / 1024 / 1024 / 1024 / 1024" | bc)
CAPACITY_TIB=$(echo "scale=2; $RAW_CAPACITY / 1024 / 1024 / 1024 / 1024" | bc)

# Afronden voor Nagios thresholds (zonder decimalen)
PERCENTAGE_INT=$(printf "%.0f" "$PERCENTAGE_USED")

# Status bepalen
STATUS="OK"
EXIT_CODE=0

if (( PERCENTAGE_INT >= CRITICAL )); then
    STATUS="CRITICAL"
    EXIT_CODE=2
elif (( PERCENTAGE_INT >= WARNING )); then
    STATUS="WARNING"
    EXIT_CODE=1
fi

# Output voor Nagios
echo "$STATUS - $USAGE_TIB TiB gebruikt van $CAPACITY_TIB TiB ($PERCENTAGE_USED%) | usage=${PERCENTAGE_USED}%;$WARNING;$CRITICAL;0;100"
exit $EXIT_CODE
