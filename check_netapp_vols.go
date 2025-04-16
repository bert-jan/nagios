package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
)

type Volume struct {
	Name    string `json:"name"`
	Svm     string `json:"svm"`
}

type ApiResponse struct {
	Records []Volume `json:"records"`
}

func main() {
	// Command line flags
	username := flag.String("u", "", "Username for NetApp REST API")
	password := flag.String("p", "", "Password for NetApp REST API")
	warning := flag.Int("w", 0, "Warning threshold for number of volumes")
	critical := flag.Int("c", 0, "Critical threshold for number of volumes")
	svm := flag.String("v", "svm1", "Name of the SVM (Storage Virtual Machine)")
	hostname := flag.String("h", "", "NetApp hostname or IP address")
	apiUrl := flag.String("a", "/api/storage/volumes", "NetApp API URL")
	flag.Parse()

	// Check required flags
	if *username == "" || *password == "" || *warning == 0 || *critical == 0 || *hostname == "" {
		fmt.Println("ERROR: Missing required parameters")
		flag.Usage()
		os.Exit(3)
	}

	// Construct API URL
	apiUrl := fmt.Sprintf("https://%s%s?svm=%s", *hostname, *apiUrl, *svm)

	// Make API request
	req, err := http.NewRequest("GET", apiUrl, nil)
	if err != nil {
		fmt.Println("ERROR: Failed to create HTTP request:", err)
		os.Exit(2)
	}

	// Basic Auth
	req.SetBasicAuth(*username, *password)

	// Get the response from the API
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("ERROR: Failed to query NetApp API:", err)
		os.Exit(2)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("ERROR: Failed to read API response:", err)
		os.Exit(2)
	}

	// Parse the JSON response
	var apiResp ApiResponse
	err = json.Unmarshal(body, &apiResp)
	if err != nil {
		fmt.Println("ERROR: Failed to parse API response:", err)
		os.Exit(2)
	}

	// Count the number of volumes
	volumeCount := len(apiResp.Records)

	// Perfdata
	perfdata := fmt.Sprintf("volumes=%d;;;;", volumeCount)

	// Output based on thresholds
	if volumeCount >= *critical {
		fmt.Printf("CRITICAL: %d volumes (>= %d) | %s\n", volumeCount, *critical, perfdata)
		os.Exit(2)
	} else if volumeCount >= *warning {
		fmt.Printf("WARNING: %d volumes (>= %d) | %s\n", volumeCount, *warning, perfdata)
		os.Exit(1)
	} else {
		fmt.Printf("OK: %d volumes | %s\n", volumeCount, perfdata)
		os.Exit(0)
	}
}
