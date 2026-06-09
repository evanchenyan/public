# ============================================
# Stage 1: 构建
# ============================================
FROM node:20-alpine AS builder

WORKDIR /app
COPY package.json ./
RUN npm install --registry=https://registry.npmmirror.com

COPY vite.config.js ./
COPY index.html ./
COPY src ./src

ARG APP_VERSION=dev
ENV VITE_APP_VERSION=${APP_VERSION}
RUN npm run build

# ============================================
# Stage 2: 运行（nginx）
# ============================================
FROM nginx:1.25-alpine

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 复制构建产物
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s \
  CMD wget -qO- http://localhost/health || exit 1
