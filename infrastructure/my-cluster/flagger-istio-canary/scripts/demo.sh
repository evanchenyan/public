#!/bin/bash
# ============================================================
# demo.sh — Flagger + Istio 灰度发布演示脚本
# ============================================================
# 使用方式:
#   ./demo.sh              # 全自动演示
#   ./demo.sh interactive  # 交互式演示（每步暂停）
# ============================================================
set -euo pipefail

MODE="${1:-auto}"
APP_NS="test"
APP="my-app"

echo "╔══════════════════════════════════════════════╗"
echo "║     Flagger + Istio 灰度发布演示             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

pause() {
  if [ "$MODE" = "interactive" ]; then
    echo ""
    read -p "按 Enter 继续..."
  fi
}

# ─── Step 1: 检查环境 ─────────────────────────────────────

echo "[Step 1] 检查环境依赖..."
command -v kubectl >/dev/null 2>&1 || { echo "需要 kubectl"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "需要 helm"; exit 1; }
echo "  ✓ kubectl 已安装"
echo "  ✓ helm 已安装"
pause

# ─── Step 2: 部署基础设施 ─────────────────────────────────

echo ""
echo "[Step 2] 部署基础设施..."

# Istio
echo "  → 安装 Istio..."
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm upgrade -i istio-base istio/base --namespace istio-system --wait 2>/dev/null
helm upgrade -i istiod istio/istiod --namespace istio-system --wait 2>/dev/null
helm upgrade -i istio-ingress istio/gateway --namespace istio-system --wait 2>/dev/null
echo "  ✓ Istio 就绪"
pause

# Prometheus
echo "  → 安装 Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm upgrade -i prometheus prometheus-community/kube-prometheus-stack \
  --namespace "$APP_NS" \
  --values ../prometheus/values.yaml \
  --wait 2>/dev/null
echo "  ✓ Prometheus 就绪"
pause

# Flagger
echo "  → 安装 Flagger..."
helm repo add flagger https://flagger.app 2>/dev/null || true
helm upgrade -i flagger flagger/flagger \
  --namespace flagger-system \
  --create-namespace \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus-operated.${APP_NS}:9090 \
  --wait 2>/dev/null
echo "  ✓ Flagger 就绪"
pause

# ─── Step 3: 部署应用 v1.0.0 ───────────────────────────────

echo ""
echo "[Step 3] 部署应用 v1.0.0..."

kubectl create namespace "$APP_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$APP_NS" istio-injection=enabled --overwrite 2>/dev/null

kubectl apply -f ../app/deployment-v1.yaml -n "$APP_NS"
kubectl apply -f ../app/service.yaml -n "$APP_NS"
kubectl apply -f ../istio/gateway.yaml -n "$APP_NS"

echo "  → 等待 Pod 就绪..."
kubectl wait --for=condition=available deployment/"$APP" -n "$APP_NS" --timeout=120s

# 验证
echo "  → 验证应用... "
POD=$(kubectl get pod -n "$APP_NS" -l app="$APP" -o jsonpath='{.items[0].metadata.name}')
VERSION=$(kubectl exec -n "$APP_NS" "$POD" -c app -- wget -q -O- http://localhost:8080/ 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
echo "  版本: $VERSION"
echo "  ✓ 应用 v1.0.0 就绪"
pause

# ─── Step 4: 初始化 Canary ─────────────────────────────────

echo ""
echo "[Step 4] 初始化 Flagger Canary..."

kubectl apply -f ../flagger/canary.yaml -n "$APP_NS"
sleep 10

echo "  → 查看 Canary 状态:"
kubectl get canary "$APP" -n "$APP_NS"

# Flagger 会自动创建 primary Service
echo "  → 等待 Flagger 创建 primary 资源..."
sleep 10
kubectl get svc -n "$APP_NS" | grep "$APP"
echo "  ✓ Canary 初始化完成"
pause

# ─── Step 5: 启动负载测试 ──────────────────────────────────

echo ""
echo "[Step 5] 启动负载测试..."

kubectl run load-test --image=busybox --restart=Never -n "$APP_NS" \
  -- /bin/sh -c 'while true; do \
    wget -q -O- http://my-app-canary.test:80/ >/dev/null 2>&1; \
    wget -q -O- http://my-app-primary.test:80/ >/dev/null 2>&1; \
    sleep 0.2; done' 2>/dev/null &

echo "  ✓ 负载测试已启动"
pause

# ─── Step 6: 触发灰度发布 ──────────────────────────────────

echo ""
echo "[Step 6] 触发灰度发布 v1.0.0 → v2.0.0"
echo "  → 更新 Deployment 镜像..."

kubectl set image deployment/"$APP" -n "$APP_NS" app=docker.io/library/$APP:2.0.0

echo "  → Flagger 开始灰度流程..."
echo ""
echo "  期望行为:"
echo "  ┌──────────┬──────────┬──────────┐"
echo "  │  阶段    │ canary % │ 持续时间 │"
echo "  ├──────────┼──────────┼──────────┤"
echo "  │  初始    │   0%     │   ---    │"
echo "  │  阶段 1  │  10%     │  60s     │"
echo "  │  阶段 2  │  20%     │  60s     │"
echo "  │  阶段 3  │  30%     │  60s     │"
echo "  │  阶段 4  │  40%     │  60s     │"
echo "  │  阶段 5  │  50%     │  60s     │"
echo "  │  完成    │ 100%     │   ---    │"
echo "  └──────────┴──────────┴──────────┘"
echo ""
echo "  每个阶段 Flagger 会检查:"
echo "  - 请求成功率 >= 99%"
echo "  - P99 延迟 <= 500ms"
echo "  任一检查失败 → 自动回滚到 v1.0.0"
pause

# ─── Step 7: 实时观察 ──────────────────────────────────────

echo ""
echo "=========================================="
echo "  开始实时观察灰度过程..."
echo "=========================================="
echo ""
echo "打开新终端执行以下命令查看详细状态:"
echo ""
echo "  观察 Canary 权重变化:"
echo "    kubectl get canary $APP -n $APP_NS -w"
echo ""
echo "  查看 VirtualService 流量分配:"
echo "    kubectl get virtualservice $APP -n $APP_NS -o yaml | grep -A5 weight"
echo ""
echo "  查看 Flagger 日志:"
echo "    kubectl -n flagger-system logs deployment/flagger --tail=50 -f"
echo ""
echo "  查看 Pod 状态:"
echo "    kubectl get pods -n $APP_NS -l app=$APP -w"
echo ""
echo "  启动 Grafana Dashboard:"
echo "    kubectl port-forward -n $APP_NS svc/prometheus-grafana 3000:80"
echo "    浏览器打开: http://localhost:3000 (admin/admin)"
echo ""

# 自动观察 60 秒
echo "自动观察 60 秒（Ctrl+C 跳过）..."
for i in $(seq 1 6); do
  echo "--- 第 $((i*10)) 秒 ---"
  kubectl get canary "$APP" -n "$APP_NS" 2>/dev/null || true
  kubectl get virtualservice "$APP" -n "$APP_NS" -o yaml 2>/dev/null | grep -A5 "weight" | head -10 || true
  sleep 10
done

echo ""
echo "=========================================="
echo "  演示完成"
echo "=========================================="
echo ""
echo "清理资源:  make -C .. cleanup"
echo "检查状态:  make -C .. status"