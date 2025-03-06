#!/bin/bash

# Functie om te controleren of een json veld een specifieke waarde bevat
check_json_value() {
    local json=$1
    local key=$2
    local expected_value=$3
    local current_value=$(echo "$json" | jq -r "$key")

    if [[ "$current_value" == "$expected_value" ]]; then
        return 0  # OK
    else
        return 1  # Fout
    fi
}

# Functie om de node status te controleren
check_node_status() {
    # Verkrijg de node status in JSON formaat
    output=$(mc admin info myminio --json)

    # Controleer of elke node "online" is
    online_count=$(echo "$output" | jq '[.nodes[] | select(.status=="online")] | length')

    # Vergelijk het aantal online nodes met de opgegeven waarde
    if [ "$online_count" -ge "$1" ]; then
        echo "OK: $online_count nodes zijn online."
        exit 0
    else
        echo "CRITICAL: Minder dan $1 nodes zijn online ($online_count gevonden)."
        exit 2
    fi
}

# Functie om de disk status te controleren
check_disk_status() {
    # Verkrijg de disk status in JSON formaat
    output=$(mc admin info myminio --json)

    # Zoek naar schijven die "online" zijn
    online_disks=$(echo "$output" | jq '[.disks[] | select(.status=="online")] | length')

    # Vergelijk het aantal online disks met de opgegeven waarde
    if [ "$online_disks" -ge "$1" ]; then
        echo "OK: $online_disks disks zijn online."
        exit 0
    else
        echo "CRITICAL: Minder dan $1 disks zijn online ($online_disks gevonden)."
        exit 2
    fi
}

# Functie om de cluster status te controleren
check_cluster_status() {
    # Verkrijg de cluster status in JSON formaat
    output=$(mc admin info myminio --json)

    # Controleer of het cluster in "online" staat
    cluster_status=$(echo "$output" | jq -r '.status')

    if [[ "$cluster_status" == "online" ]]; then
        echo "OK: Cluster is online."
        exit 0
    else
        echo "CRITICAL: Cluster is niet online (huidige status: $cluster_status)."
        exit 2
    fi
}

# Functie om de argumenten te verwerken
parse_args() {
    while [[ "$1" != "" ]]; do
        case $1 in
            -n | --node)
                shift
                node_count=$1
                shift
                ;;
            -d | --disk)
                shift
                disk_count=$1
                shift
                ;;
            -c | --cluster)
                cluster_check=true
                shift
                ;;
            *)
                echo "USAGE: $0 {-n | --node <min_nodes>} {-d | --disk <min_disks>} [-c | --cluster]"
                exit 3
                ;;
        esac
    done
}

# Controleer of er argumenten zijn opgegeven
if [ $# -lt 1 ]; then
    echo "USAGE: $0 {-n | --node <min_nodes>} {-d | --disk <min_disks>} [-c | --cluster]"
    exit 3
fi

# Parse de command line arguments
parse_args "$@"

# Voer de juiste check uit op basis van de argumenten

if [ -n "$node_count" ]; then
    check_node_status "$node_count"
fi

if [ -n "$disk_count" ]; then
    check_disk_status "$disk_count"
fi

if [ "$cluster_check" = true ]; then
    check_cluster_status
fi
