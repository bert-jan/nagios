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
	"net/url"
	"os"
	"strings"
	"time"
)

type Secret struct {
	Data map[string]string `json:"data"`
}

func main() {
	baseURL := flag.String("url", "", "Rancher URL")
	token := flag.String("token", "", "Bearer token")
	cluster := flag.String("cluster", "", "Cluster name")
	namespace := flag.String("namespace", "", "Namespace")
	secrets := flag.String("secrets", "", "Comma separated secret names")
	warning := flag.Int("warning", 0, "Warning days")
	critical := flag.Int("critical", 0, "Critical days")
	insecure := flag.Bool("insecure", false, "Skip TLS verify")
	proxyStr := flag.String("proxy", "", "Proxy URL")

	flag.Parse()

	if *baseURL == "" || *token == "" || *cluster == "" || *namespace == "" || *secrets == "" || *warning == 0 || *critical == 0 {
		fmt.Println("UNKNOWN - Missing required arguments")
		os.Exit(3)
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: *insecure},
	}

	if *proxyStr != "" {
		proxyURL, err := url.Parse(*proxyStr)
		if err == nil {
			tr.Proxy = http.ProxyURL(proxyURL)
		}
	}

	client := &http.Client{Transport: tr}

	exitCode := 0
	output := ""
	perfdata := ""

	for _, secretName := range strings.Split(*secrets, ",") {

		secretURL := fmt.Sprintf("%s/k8s/clusters/%s/api/v1/namespaces/%s/secrets/%s",
			*baseURL, *cluster, *namespace, secretName)

		req, _ := http.NewRequest("GET", secretURL, nil)
		req.Header.Set("Authorization", "Bearer "+*token)

		resp, err := client.Do(req)
		if err != nil || resp.StatusCode != 200 {
			output += fmt.Sprintf("CRITICAL: %s API error; ", secretName)
			exitCode = 2
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var s Secret
		if err := json.Unmarshal(body, &s); err != nil {
			output += fmt.Sprintf("CRITICAL: %s JSON error; ", secretName)
			exitCode = 2
			continue
		}

		certB64, ok := s.Data["tls.crt"]
		if !ok {
			output += fmt.Sprintf("CRITICAL: %s missing tls.crt; ", secretName)
			exitCode = 2
			continue
		}

		certBytes, err := base64.StdEncoding.DecodeString(certB64)
		if err != nil {
			output += fmt.Sprintf("CRITICAL: %s base64 error; ", secretName)
			exitCode = 2
			continue
		}

		cert, err := x509.ParseCertificate(certBytes)
		if err != nil {
			output += fmt.Sprintf("CRITICAL: %s parse error; ", secretName)
			exitCode = 2
			continue
		}

		daysLeft := int(time.Until(cert.NotAfter).Hours() / 24)
		perfdata += fmt.Sprintf("%s=%d;%d;%d ",
			secretName, daysLeft, *warning, *critical)

		if daysLeft <= *critical {
			output += fmt.Sprintf("CRITICAL: %s %d days; ", secretName, daysLeft)
			exitCode = 2
		} else if daysLeft <= *warning {
			if exitCode < 2 {
				exitCode = 1
			}
			output += fmt.Sprintf("WARNING: %s %d days; ", secretName, daysLeft)
		} else {
			output += fmt.Sprintf("OK: %s %d days; ", secretName, daysLeft)
		}
	}

	status := "OK"
	if exitCode == 1 {
		status = "WARNING"
	} else if exitCode == 2 {
		status = "CRITICAL"
	}

	fmt.Printf("%s - %s| %s\n", status, output, perfdata)
	os.Exit(exitCode)
}
