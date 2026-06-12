#!/bin/bash
# ============================================================
# build.sh — 构建并推送示例应用 Docker 镜像
# ============================================================
set -euo pipefail

APP="my-app"
REGISTRY="docker.io/library"
VERSIONS=("1.0.0" "2.0.0")

echo "=========================================="
echo "  构建示例应用镜像"
echo "=========================================="

cd "$(dirname "$0")/../app"

for version in "${VERSIONS[@]}"; do
  echo ""
  echo ">>> 构建 ${APP}:${version} ..."

  # 用 sed 修改 Go 源码中的版本号
  sed -i '' "s/getEnv(\"APP_VERSION\", \".*\")/getEnv(\"APP_VERSION\", \"${version}\")/" main.go

  docker build -t "${REGISTRY}/${APP}:${version}" .

  echo ">>> 推送镜像 ${REGISTRY}/${APP}:${version}"
  docker push "${REGISTRY}/${APP}:${version}"
done

# 恢复版本号为 1.0.0
sed -i '' 's/getEnv("APP_VERSION", ".*")/getEnv("APP_VERSION", "1.0.0")/' main.go

echo ""
echo "=========================================="
echo "  镜像构建完成"
echo "=========================================="
echo ""
echo "可用镜像:"
for version in "${VERSIONS[@]}"; do
  echo "  ${REGISTRY}/${APP}:${version}"
done