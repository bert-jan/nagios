package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type Secret struct {
	Data map[string]string `json:"data"`
}

func main() {
	// Arguments
	url := flag.String("url", "", "Rancher base URL (e.g. https://rancher.example.com)")
	token := flag.String("token", "", "Rancher API Bearer token")
	cluster := flag.String("cluster", "", "Cluster name (e.g. local)")
	namespace := flag.String("namespace", "", "Namespace")
	secretName := flag.String("secret", "", "Secret name")
	warning := flag.Int("warning", 0, "Warning threshold in days")
	critical := flag.Int("critical", 0, "Critical threshold in days")

	flag.Parse()

	if *url == "" || *token == "" || *cluster == "" || *namespace == "" || *secretName == "" || *warning == 0 || *critical == 0 {
		fmt.Println("UNKNOWN: Missing required arguments")
		os.Exit(3)
	}

	// Construct API URL
	secretURL := fmt.Sprintf("%s/k8s/clusters/%s/api/v1/namespaces/%s/secrets/%s",
		*url, *cluster, *namespace, *secretName)

	// HTTP client (skip TLS verify like curl -k)
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := &http.Client{Transport: tr}

	req, err := http.NewRequest("GET", secretURL, nil)
	if err != nil {
		fmt.Println("CRITICAL: Failed to create request")
		os.Exit(2)
	}

	req.Header.Set("Authorization", "Bearer "+*token)

	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("CRITICAL: Failed to query Rancher API")
		os.Exit(2)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		fmt.Printf("CRITICAL: Rancher API returned HTTP %d\n", resp.StatusCode)
		os.Exit(2)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("CRITICAL: Failed to read response body")
		os.Exit(2)
	}

	var secret Secret
	if err := json.Unmarshal(body, &secret); err != nil {
		fmt.Println("CRITICAL: Failed to parse JSON")
		os.Exit(2)
	}

	certBase64, ok := secret.Data["tls.crt"]
	if !ok {
		fmt.Println("CRITICAL: tls.crt not found in secret")
		os.Exit(2)
	}

	certBytes, err := base64.StdEncoding.DecodeString(certBase64)
	if err != nil {
		fmt.Println("CRITICAL: Failed to decode base64 certificate")
		os.Exit(2)
	}

	cert, err := x509.ParseCertificate(certBytes)
	if err != nil {
		fmt.Println("CRITICAL: Failed to parse certificate")
		os.Exit(2)
	}

	daysLeft := int(time.Until(cert.NotAfter).Hours() / 24)

	// Nagios logic
	if daysLeft <= *critical {
		fmt.Printf("CRITICAL: Certificate '%s' in namespace '%s' expires in %d days\n",
			*secretName, *namespace, daysLeft)
		os.Exit(2)
	} else if daysLeft <= *warning {
		fmt.Printf("WARNING: Certificate '%s' in namespace '%s' expires in %d days\n",
			*secretName, *namespace, daysLeft)
		os.Exit(1)
	} else {
		fmt.Printf("OK: Certificate '%s' in namespace '%s' expires in %d days\n",
			*secretName, *namespace, daysLeft)
		os.Exit(0)
	}
}
