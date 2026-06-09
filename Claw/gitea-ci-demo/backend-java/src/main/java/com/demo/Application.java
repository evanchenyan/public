package com.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@SpringBootApplication
@RestController
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
            "status", "ok",
            "service", "backend-java",
            "version", System.getenv().getOrDefault("APP_VERSION", "dev"),
            "timestamp", Instant.now().toString()
        );
    }

    @GetMapping("/api/info")
    public Map<String, Object> info() {
        return Map.of(
            "service", "backend-java",
            "language", "Java",
            "message", "Hello from Java backend!"
        );
    }
}
