#!/bin/bash

while getopts "u:p:w:c:h:" opt; do
  case $opt in
    u) USERNAME=$OPTARG ;;
    p) PASSWORD=$OPTARG ;;
    w) WARNING=$OPTARG ;;
    c) CRITICAL=$OPTARG ;;
    h) NETAPP_IP=$OPTARG ;;
    *) echo "Usage: $0 -u <username> -p <password> -w <warning> -c <critical> -h <NetApp_IP>" ;;
  esac
done

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$WARNING" ] || [ -z "$CRITICAL" ] || [ -z "$NETAPP_IP" ]; then
  echo "ERROR: Missing required arguments"
  exit 3
fi

SVM="svm1"

RESPONSE=$(curl -k -u "$USERNAME:$PASSWORD" "https://$NETAPP_IP/api/storage/volumes?svm=$SVM")

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to query NetApp API"
  exit 2
fi

VOLUME_COUNT=$(echo "$RESPONSE" | jq '.records | length')

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to parse API response"
  exit 2
fi

PERFDATA="volumes=$VOLUME_COUNT;;;;"

if [ "$VOLUME_COUNT" -ge "$CRITICAL" ]; then
  echo "CRITICAL: $VOLUME_COUNT volumes (>= $CRITICAL) | $PERFDATA"
  exit 2
elif [ "$VOLUME_COUNT" -ge "$WARNING" ]; then
  echo "WARNING: $VOLUME_COUNT volumes (>= $WARNING) | $PERFDATA"
  exit 1
else
  echo "OK: $VOLUME_COUNT volumes | $PERFDATA"
  exit 0
fi
