package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

var (
	version   = getEnv("APP_VERSION", "1.0.0")
	hostname, _ = os.Hostname()
)

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

type Response struct {
	Version  string            `json:"version"`
	Hostname string            `json:"hostname"`
	Message  string            `json:"message"`
	Canary   bool              `json:"canary"`
	Headers  map[string]string `json:"headers,omitempty"`
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	canary := false
	if r.Header.Get("X-Canary") == "true" {
		canary = true
	}

	resp := Response{
		Version:  version,
		Hostname: hostname,
		Message:  fmt.Sprintf("Hello from my-app version %s on %s", version, hostname),
		Canary:   canary,
		Headers: map[string]string{
			"x-forwarded-for": r.Header.Get("X-Forwarded-For"),
			"x-request-id":    r.Header.Get("X-Request-Id"),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-App-Version", version)
	w.Header().Set("X-App-Host", hostname)
	if canary {
		w.Header().Set("X-Canary", "true")
	}

	json.NewEncoder(w).Encode(resp)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"version": version,
	})
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintf(w, "# HELP app_info Application version info\n")
	fmt.Fprintf(w, "# TYPE app_info gauge\n")
	fmt.Fprintf(w, "app_info{version=\"%s\",host=\"%s\"} 1\n", version, hostname)
}

func main() {
	port := getEnv("PORT", "8080")

	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/metrics", metricsHandler)

	log.Printf("Starting my-app version %s on port %s", version, port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}