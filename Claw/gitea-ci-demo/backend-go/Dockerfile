# ============================================
# Stage 1: 编译
# ============================================
FROM golang:1.22-alpine AS builder

ARG APP_VERSION=dev
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN go build -ldflags="-s -w -X main.version=${APP_VERSION}" -o /app/server .

# ============================================
# Stage 2: 运行
# ============================================
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata && \
    adduser -D -g '' appuser

WORKDIR /app
COPY --from=builder /app/server .

USER appuser
EXPOSE 8080

ENV PORT=8080
ENV APP_VERSION=dev

ENTRYPOINT ["./server"]
