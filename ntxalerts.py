import requests
import argparse
import sys
from datetime import datetime

def check_alerts(api_url, bearer_token, severity, threshold):
    headers = {
        'Authorization': f'Bearer {bearer_token}',
        'Content-Type': 'application/json'
    }
    url = f"{api_url}/PrismGateway/services/rest/v2.0/alerts/?resolved=false&severity={severity}&get_causes=true&detailed_info=true"
    
    try:
        response = requests.get(url, headers=headers, verify=False)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        print(f"UNKNOWN - API request failed for {severity} alerts: {e}")
        sys.exit(3)

    data = response.json()
    alert_count = data.get('metadata', {}).get('total_entities', 0)
    alert_titles = [entity.get('alert_title', 'No description provided') for entity in data.get('entities', [])]

    if alert_count >= threshold:
        status_text = f"{severity.upper()} - {alert_count} {severity.lower()} alert(s) (Threshold: {threshold})"
        status_code = 2 if severity == "CRITICAL" else 1
    else:
        status_text = f"OK - No {severity.lower()} alerts exceeding threshold"
        status_code = 0

    extended_info = "\n".join(alert_titles)
    perf_data = f"{severity.lower()}s={alert_count}"
    
    return status_text, status_code, perf_data, extended_info

def main():
    parser = argparse.ArgumentParser(description="Nagios check for Nutanix Prism alerts.")
    parser.add_argument("-u", "--url", required=True, help="Nutanix API base URL (e.g., https://HOSTNAME:9440)")
    parser.add_argument("-t", "--token", required=True, help="Bearer token for Nutanix API authentication")
    parser.add_argument("-w", "--warning-count", type=int, default=1, help="Threshold for warning alerts")
    parser.add_argument("-c", "--critical-count", type=int, default=1, help="Threshold for critical alerts")
    
    args = parser.parse_args()

    warning_text, warning_status, warning_perf, warning_info = check_alerts(args.url, args.token, "WARNING", args.warning_count)
    critical_text, critical_status, critical_perf, critical_info = check_alerts(args.url, args.token, "CRITICAL", args.critical_count)

    if critical_status == 2:
        print(f"{critical_text} | {critical_perf}\n{critical_info}")
        sys.exit(2)
    elif warning_status == 1:
        print(f"{warning_text} | {warning_perf}\n{warning_info}")
        sys.exit(1)
    else:
        print(f"{warning_text} | {warning_perf}\nNo active alerts exceeding thresholds")
        sys.exit(0)

if __name__ == "__main__":
    main()
