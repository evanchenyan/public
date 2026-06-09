# ============================================
# Stage 1: 编译（使用 Maven 离线缓存加速）
# ============================================
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

WORKDIR /app
COPY pom.xml .
# 先下载依赖（利用 Docker 层缓存）
RUN mvn dependency:go-offline -B -q

COPY src ./src
RUN mvn package -DskipTests -B -q

# ============================================
# Stage 2: 运行
# ============================================
FROM eclipse-temurin:17-jre-alpine

RUN adduser -D appuser
WORKDIR /app
COPY --from=builder /app/target/app.jar .

USER appuser
EXPOSE 8080

ENV PORT=8080
ENV APP_VERSION=dev

ENTRYPOINT ["java","-jar","/app/app.jar"]
