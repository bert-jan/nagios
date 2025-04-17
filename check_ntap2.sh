#!/bin/bash

SCRIPT_NAME=$(basename "$0")

# === Functie: Help ===
print_usage() {
  cat <<EOF
Usage: $SCRIPT_NAME --volume-count|--snapshot-count -H <host> -n <username> -p <password> -s <svm> -w <warning> -c <critical>

Checks:
  --volume-count     Controleert het aantal volumes in de SVM
  --snapshot-count   Controleert het aantal snapshots in de SVM

Voorbeeld:
  $SCRIPT_NAME --snapshot-count -H https://netapp.local -n admin -p geheim -s svm1 -w 500 -c 800
EOF
  exit 3
}

# === Functie: Exiteren met perfdata ===
exit_with_status() {
  local status=$1
  local message=$2
  local perfdata=$3
  echo "$message | $perfdata"
  exit "$status"
}

# === Functie: API call ===
perform_api_call() {
  local endpoint="$1"
  RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" -k "$HOST$endpoint")
  if [[ -z "$RESPONSE" ]]; then
    exit_with_status 2 "CRITICAL - Geen antwoord van API ($endpoint)" ""
  fi
}

# === Functie: Volume Count Check ===
check_volume_count() {
  local endpoint="/api/storage/volumes?svm=${SVM}"
  perform_api_call "$endpoint"

  NUM_RECORDS=$(echo "$RESPONSE" | jq -r '.num_records')
  if ! [[ "$NUM_RECORDS" =~ ^[0-9]+$ ]]; then
    exit_with_status 2 "CRITICAL - Kon 'num_records' niet uitlezen (volumes)" "volumes=0;$WARNING;$CRITICAL;0;"
  fi

  if (( NUM_RECORDS >= CRITICAL )); then
    exit_with_status 2 "CRITICAL - Aantal volumes: $NUM_RECORDS" "volumes=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  elif (( NUM_RECORDS >= WARNING )); then
    exit_with_status 1 "WARNING - Aantal volumes: $NUM_RECORDS" "volumes=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  else
    exit_with_status 0 "OK - Aantal volumes: $NUM_RECORDS" "volumes=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  fi
}

# === Functie: Snapshot Count Check ===
check_snapshot_count() {
  local endpoint="/api/storage/snapshots?svm=${SVM}"
  perform_api_call "$endpoint"

  NUM_RECORDS=$(echo "$RESPONSE" | jq -r '.num_records')
  if ! [[ "$NUM_RECORDS" =~ ^[0-9]+$ ]]; then
    exit_with_status 2 "CRITICAL - Kon 'num_records' niet uitlezen (snapshots)" "snapshots=0;$WARNING;$CRITICAL;0;"
  fi

  if (( NUM_RECORDS >= CRITICAL )); then
    exit_with_status 2 "CRITICAL - Aantal snapshots: $NUM_RECORDS" "snapshots=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  elif (( NUM_RECORDS >= WARNING )); then
    exit_with_status 1 "WARNING - Aantal snapshots: $NUM_RECORDS" "snapshots=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  else
    exit_with_status 0 "OK - Aantal snapshots: $NUM_RECORDS" "snapshots=$NUM_RECORDS;$WARNING;$CRITICAL;0;"
  fi
}

# === Argument parsing ===
parse_args() {
  while [[ "$1" != "" ]]; do
    case "$1" in
      --volume-count)    CHECK_TYPE="volume" ;;
      --snapshot-count)  CHECK_TYPE="snapshot" ;;
      -H)                shift; HOST="$1" ;;
      -n)                shift; USERNAME="$1" ;;
      -p)                shift; PASSWORD="$1" ;;
      -s)                shift; SVM="$1" ;;
      -w)                shift; WARNING="$1" ;;
      -c)                shift; CRITICAL="$1" ;;
      -h|--help)         print_usage ;;
      *) echo "Onbekende parameter: $1"; print_usage ;;
    esac
    shift
  done

  if [[ -z "$CHECK_TYPE" || -z "$HOST" || -z "$USERNAME" || -z "$PASSWORD" || -z "$SVM" || -z "$WARNING" || -z "$CRITICAL" ]]; then
    echo "Fout: Vereiste parameters ontbreken"
    print_usage
  fi

  if ! command -v jq &>/dev/null; then
    echo "Fout: 'jq' is niet geïnstalleerd"
    exit 2
  fi
}

# === Main ===
main() {
  parse_args "$@"

  case "$CHECK_TYPE" in
    volume)
      check_volume_count
      ;;
    snapshot)
      check_snapshot_count
      ;;
    *)
      exit_with_status 3 "UNKNOWN - Ongeldige check type" ""
      ;;
  esac
}

main "$@"
