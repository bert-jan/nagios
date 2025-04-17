#!/bin/bash

SCRIPT_NAME=$(basename "$0")

# === Function: Print usage help ===
print_usage() {
  cat <<EOF
Usage: $SCRIPT_NAME --volume-count -H <host> -n <username> -p <password> -s <svm> -w <warning> -c <critical>

Check:
  --volume-count     Checks the number of volumes in the specified SVM

Options:
  -H   NetApp ONTAP API base URL (e.g. https://netapp.local)
  -n   Username
  -p   Password
  -s   SVM name (Storage Virtual Machine)
  -w   Warning threshold (e.g. 100)
  -c   Critical threshold (e.g. 150)

Example:
  $SCRIPT_NAME --volume-count -H https://netapp.local -n admin -p secret -s svm1 -w 100 -c 150
EOF
  exit 3
}

# === Function: Output status with perfdata ===
exit_with_status() {
  local status=$1
  local message=$2
  local perfdata=$3
  echo "$message | $perfdata"
  exit "$status"
}

# === Function: Make API call ===
perform_api_call() {
  local endpoint="$1"
  RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" -k "$HOST$endpoint")
  if [[ -z "$RESPONSE" ]]; then
    exit_with_status 2 "CRITICAL - No response from API ($endpoint)" ""
  fi
}

# === Function: Check volume count ===
check_volume_count() {
  local endpoint="/api/storage/volumes?svm=${SVM}"
  perform_api_call "$endpoint"

  NUM_RECORDS=$(echo "$RESPONSE" | jq -r '.num_records')

  if ! [[ "$NUM_RECORDS" =~ ^[0-9]+$ ]]; then
    exit_with_status 2 "CRITICAL - Could not parse 'num_records' from API response" "volumes=0;$WARNING;$CRITICAL;0;"
  fi

  if (( NUM_RECORDS >= CRITICAL )); then
    exit_with_status 2 "CRITICAL - Volume count is $NUM_RECORDS" "volumes=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  elif (( NUM_RECORDS >= WARNING )); then
    exit_with_status 1 "WARNING - Volume count is $NUM_RECORDS" "volumes=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  else
    exit_with_status 0 "OK - Volume count is $NUM_RECORDS" "volumes=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  fi
}

# === Function: Parse arguments ===
parse_args() {
  while [[ "$1" != "" ]]; do
    case "$1" in
      --volume-count)    CHECK_TYPE="volume" ;;
      -H)                shift; HOST="$1" ;;
      -n)                shift; USERNAME="$1" ;;
      -p)                shift; PASSWORD="$1" ;;
      -s)                shift; SVM="$1" ;;
      -w)                shift; WARNING="$1" ;;
      -c)                shift; CRITICAL="$1" ;;
      -h|--help)         print_usage ;;
      *) echo "Unknown parameter: $1"; print_usage ;;
    esac
    shift
  done

  # Validate required arguments
  if [[ -z "$CHECK_TYPE" || -z "$HOST" || -z "$USERNAME" || -z "$PASSWORD" || -z "$SVM" || -z "$WARNING" || -z "$CRITICAL" ]]; then
    echo "Error: Missing required arguments"
    print_usage
  fi

  if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is not installed"
    exit 2
  fi
}

# === Main function ===
main() {
  parse_args "$@"

  case "$CHECK_TYPE" in
    volume)
      check_volume_count
      ;;
    *)
      exit_with_status 3 "UNKNOWN - Invalid check type" ""
      ;;
  esac
}

main "$@"
