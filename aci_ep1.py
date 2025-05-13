import requests
import urllib3
import json

urllib3.disable_warnings()

# Configuratie
apic = "https://<apic_ip>"
username = "admin"
password = "your_password"
tenant = "your_tenant"
app_profile = "your_app_profile"
epg = "your_epg"

# Login
session = requests.Session()
login_data = {
    "aaaUser": {
        "attributes": {
            "name": username,
            "pwd": password
        }
    }
}

response = session.post(f"{apic}/api/aaaLogin.json", json=login_data, verify=False)
if response.status_code != 200:
    print("Login mislukt")
    exit(1)

# EPG Distinguished Name
epg_dn = f"uni/tn-{tenant}/ap-{app_profile}/epg-{epg}"

# Ophalen van alle endpoints
resp = session.get(f"{apic}/api/node/class/fvCEp.json?query-target-filter=eq(fvCEp.epgDn,\"{epg_dn}\")", verify=False)
data = resp.json()

endpoints = [ep["fvCEp"]["attributes"]["dn"] for ep in data.get("imdata", [])]

# Verwijderen van endpoints
for dn in endpoints:
    print(f"Verwijderen: {dn}")
    del_resp = session.delete(f"{apic}/api/node/mo/{dn}.json", verify=False)
    if del_resp.status_code == 200:
        print("✅ Succesvol verwijderd.")
    else:
        print(f"❌ Fout bij verwijderen: {del_resp.status_code} - {del_resp.text}")

print("Klaar met verwijderen van endpoints.")
