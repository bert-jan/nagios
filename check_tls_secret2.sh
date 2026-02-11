#!/bin/bash

# Nagios TLS Secret Expiry Check via Rancher API
# Author: B. van der Kolk
# Usage:
# ./check_tls_secret.sh -u <RANCHER_URL> -t <TOKEN> -c <CLUSTER> -n <NAMESPACE> -s <SECRET> -w <WARNING_DAYS> -c <CRITICAL_DAYS>

print_help() {
    echo "Usage: $0 -u <RANCHER_URL> -t <TOKEN> -c <CLUSTER> -n <NAMESPACE> -s <SECRET> -w <WARNING_DAYS> -C <CRITICAL_DAYS>"
    echo "Example:"
    echo "$0 -u https://rancher.example.com -t ABCDEF12345 -c local -n cattle-system -s serving-cert -w 30 -C 15"
}

# Parse arguments
while getopts "u:t:c:n:s:w:C:h" opt; do
  case $opt in
    u) RANCHER_URL="$OPTARG" ;;
    t) TOKEN="$OPTARG" ;;
    c) CLUSTER="$OPTARG" ;;
    n) NAMESPACE="$OPTARG" ;;
    s) SECRET="$OPTARG" ;;
    w) WARNING="$OPTARG" ;;
    C) CRITICAL="$OPTARG" ;;
    h) print_help; exit 0 ;;
    *) print_help; exit 1 ;;
  esac
done

# Check mandatory arguments
if [[ -z "$RANCHER_URL" || -z "$TOKEN" || -z "$CLUSTER" || -z "$NAMESPACE" || -z "$SECRET" || -z "$WARNING" || -z "$CRITICAL" ]]; then
    print_help
    exit 1
fi

# Construct API path
SECRET_URI="/k8s/clusters/$CLUSTER/api/v1/namespaces/$NAMESPACE/secrets/$SECRET"

# Fetch tls.crt from Rancher API and decode
CERT_PEM=$(curl -s -k -H "Authorization: Bearer $TOKEN" "$RANCHER_URL$SECRET_URI" \
          | jq -r '.data["tls.crt"]' \
          | base64 -d 2>/dev/null)

if [[ -z "$CERT_PEM" ]]; then
    echo "CRITICAL: Could not retrieve or decode tls.crt"
    exit 2
fi

# Extract end date in seconds since epoch
ENDDATE_EPOCH=$(echo "$CERT_PEM" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 | xargs -I{} date -d "{}" +%s 2>/dev/null)

if [[ -z "$ENDDATE_EPOCH" ]]; then
    echo "CRITICAL: Could not parse certificate end date"
    exit 2
fi

# Current date in seconds
NOW_EPOCH=$(date +%s)

# Days until expiry
DAYS_LEFT=$(( (ENDDATE_EPOCH - NOW_EPOCH) / 86400 ))

# Nagios thresholds
if (( DAYS_LEFT <= CRITICAL )); then
    echo "CRITICAL: Certificate '$SECRET' in namespace '$NAMESPACE' expires in $DAYS_LEFT days"
    exit 2
elif (( DAYS_LEFT <= WARNING )); then
    echo "WARNING: Certificate '$SECRET' in namespace '$NAMESPACE' expires in $DAYS_LEFT days"
    exit 1
else
    echo "OK: Certificate '$SECRET' in namespace '$NAMESPACE' expires in $DAYS_LEFT days"
    exit 0
fi
