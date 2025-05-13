#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def login(apic, username, password):
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
        return None, f"Login failed: {response.status_code} - {response.text}"
    return session, None

def get_endpoints(session, apic, tenant, app_profile, epg):
    epg_dn = f"uni/tn-{tenant}/ap-{app_profile}/epg-{epg}"
    url = f"{apic}/api/node/class/fvCEp.json?query-target-filter=eq(fvCEp.epgDn,\"{epg_dn}\")"
    response = session.get(url, verify=False)
    if response.status_code != 200:
        return None, f"Failed to get endpoints: {response.status_code} - {response.text}"
    data = response.json()
    return [ep["fvCEp"]["attributes"]["dn"] for ep in data.get("imdata", [])], None

def delete_endpoint(session, apic, dn):
    response = session.delete(f"{apic}/api/node/mo/{dn}.json", verify=False)
    return response.status_code == 200, response.text

def run_module():
    module_args = dict(
        apic=dict(type='str', required=True),
        username=dict(type='str', required=True),
        password=dict(type='str', required=True, no_log=True),
        tenant=dict(type='str', required=True),
        app_profile=dict(type='str', required=True),
        epg=dict(type='str', required=True)
    )

    result = dict(changed=False, endpoints_deleted=[], errors=[])

    module = AnsibleModule(argument_spec=module_args, supports_check_mode=False)

    apic = module.params['apic']
    username = module.params['username']
    password = module.params['password']
    tenant = module.params['tenant']
    app_profile = module.params['app_profile']
    epg = module.params['epg']

    session, error = login(apic, username, password)
    if not session:
        module.fail_json(msg=error, **result)

    endpoints, error = get_endpoints(session, apic, tenant, app_profile, epg)
    if endpoints is None:
        module.fail_json(msg=error, **result)

    for dn in endpoints:
        success, message = delete_endpoint(session, apic, dn)
        if success:
            result['endpoints_deleted'].append(dn)
            result['changed'] = True
        else:
            result['errors'].append(f"{dn}: {message}")

    if result['errors']:
        module.fail_json(msg="Some deletions failed.", **result)

    module.exit_json(**result)

if __name__ == '__main__':
    run_module()
