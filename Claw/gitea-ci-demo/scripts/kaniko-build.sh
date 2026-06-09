#!/bin/sh
# ============================================
# Kaniko 镜像构建 & 推送脚本
# 用法:
#   kaniko-build.sh <context_dir> <dockerfile_path> <image_name> <image_tag>
# 示例:
#   kaniko-build.sh backend-go backend-go/Dockerfile backend-go v1.0.0
# ============================================
set -e

CONTEXT_DIR="$1"
DOCKERFILE="$2"
IMAGE_NAME="$3"
IMAGE_TAG="$4"

if [ -z "$REGISTRY_URL" ]; then
  echo "ERROR: REGISTRY_URL 环境变量未设置"
  exit 1
fi

if [ -z "$REGISTRY_USER" ] || [ -z "$REGISTRY_PASS" ]; then
  echo "ERROR: REGISTRY_USER 或 REGISTRY_PASS 未设置"
  exit 1
fi

echo "============================================"
echo "Kaniko Build & Push"
echo "  构建上下文: ${CONTEXT_DIR}"
echo "  Dockerfile: ${DOCKERFILE}"
echo "  镜像名称: ${IMAGE_NAME}"
echo "  镜像标签: ${IMAGE_TAG}"
echo "  镜像仓库: ${REGISTRY_URL}"
echo "============================================"

# 创建 Docker config (用于私有仓库认证)
mkdir -p /kaniko/.docker
AUTH=$(echo -n "${REGISTRY_USER}:${REGISTRY_PASS}" | base64 -w 0)
cat > /kaniko/.docker/config.json <<DOCKERCFG
{
  "auths": {
    "${REGISTRY_URL}": {
      "auth": "${AUTH}"
    }
  }
}
DOCKERCFG

FULL_IMAGE="${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
LATEST_IMAGE="${REGISTRY_URL}/${IMAGE_NAME}:latest"

echo "目标镜像: ${FULL_IMAGE}"
echo ""

# 执行 Kaniko 构建
# --cache=true         启用层缓存
# --cache-ttl=24h      缓存有效期
# --cleanup            构建后清理
# --skip-tls-verify    如果仓库用了自签名证书，取消下面的注释
exec /kaniko/executor \
  --context="dir://${CONTEXT_DIR}" \
  --dockerfile="${DOCKERFILE}" \
  --destination="${FULL_IMAGE}" \
  --destination="${LATEST_IMAGE}" \
  --cache=true \
  --cache-ttl=24h \
  --cleanup
  # --skip-tls-verify       # 自签名证书时使用
  # --insecure               # HTTP 仓库时使用
  # --insecure-registry=xxx  # 指定不安全的仓库地址
