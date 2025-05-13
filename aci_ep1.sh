#!/bin/bash

# Configuratie
APIC="https://<apic_ip>"
USERNAME="admin"
PASSWORD="your_password"
TENANT="your_tenant"
APP_PROFILE="your_app_profile"
EPG="your_epg"

# Login en verkrijg token
TOKEN=$(curl -sk -X POST "$APIC/api/aaaLogin.json" \
    -d "{\"aaaUser\":{\"attributes\":{\"name\":\"$USERNAME\",\"pwd\":\"$PASSWORD\"}}}" | \
    jq -r '.imdata[0].aaaLogin.attributes.token')

COOKIE="APIC-cookie=$TOKEN"

# Ophalen van alle endpoints in EPG
EPG_DN="uni/tn-$TENANT/ap-$APP_PROFILE/epg-$EPG"
ENDPOINTS=$(curl -sk -H "Cookie: $COOKIE" "$APIC/api/node/class/fvCEp.json?query-target-filter=eq(fvCEp.epgDn,\"$EPG_DN\")" | jq -r '.imdata[].fvCEp.attributes.dn')

# Verwijder alle gevonden endpoints
for DN in $ENDPOINTS; do
    echo "Verwijderen: $DN"
    curl -sk -X DELETE -H "Cookie: $COOKIE" "$APIC/api/node/mo/$DN.json"
done

echo "Klaar met verwijderen van endpoints."
