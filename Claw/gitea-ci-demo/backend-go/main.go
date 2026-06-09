package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

type HealthResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
}

type InfoResponse struct {
	Service  string `json:"service"`
	Language string `json:"language"`
	Message  string `json:"message"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	version := os.Getenv("APP_VERSION")
	if version == "" {
		version = "dev"
	}

	mux := http.NewServeMux()

	// 健康检查
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(HealthResponse{
			Status:    "ok",
			Service:   "backend-go",
			Version:   version,
			Timestamp: time.Now().Format(time.RFC3339),
		})
	})

	// API 信息
	mux.HandleFunc("GET /api/info", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(InfoResponse{
			Service:  "backend-go",
			Language: "Go",
			Message:  "Hello from Go backend!",
		})
	})

	addr := fmt.Sprintf(":%s", port)
	log.Printf("Go backend starting on %s (version: %s)", addr, version)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
