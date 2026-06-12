# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o my-app .

# Runtime stage
FROM alpine:3.19
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/my-app .

EXPOSE 8080

ENV APP_VERSION=1.0.0
ENV PORT=8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["./my-app"]