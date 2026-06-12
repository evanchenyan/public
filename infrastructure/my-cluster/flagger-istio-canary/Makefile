.PHONY: help install-istio install-flagger install-prometheus deploy-app \
        init-canary trigger-canary promote rollback watch status demo-full \
        load-test cleanup slack-notify

HELM := helm
KUBECTL := kubectl

NS_ISTIO := istio-system
NS_FLAGGER := flagger-system
NS_APP := test

REPO := docker.io/library
APP := my-app

help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── 基础设施安装 ───────────────────────────────────────────

install-istio: ## 安装 Istio 服务网格
	@echo ">>> 安装 Istio..."
	$(KUBECTL) create namespace $(NS_ISTIO) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(HELM) repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
	$(HELM) upgrade -i istio-base istio/base --namespace $(NS_ISTIO) --wait
	$(HELM) upgrade -i istiod istio/istiod --namespace $(NS_ISTIO) --wait
	$(HELM) upgrade -i istio-ingress istio/gateway --namespace $(NS_ISTIO) --wait
	@echo ">>> Istio 安装完成 ✓"

install-flagger: ## 安装 Flagger
	@echo ">>> 安装 Flagger..."
	$(HELM) repo add flagger https://flagger.app 2>/dev/null || true
	$(HELM) upgrade -i flagger flagger/flagger \
		--namespace $(NS_FLAGGER) \
		--create-namespace \
		--set meshProvider=istio \
		--set metricsServer=http://prometheus-operated.$(NS_APP):9090 \
		--wait
	@echo ">>> Flagger 安装完成 ✓"

install-prometheus: ## 安装 Prometheus（用于 Flagger 指标分析）
	@echo ">>> 安装 Prometheus..."
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
	$(HELM) upgrade -i prometheus prometheus-community/kube-prometheus-stack \
		--namespace $(NS_APP) \
		--values prometheus/values.yaml \
		--wait
	@echo ">>> Prometheus 安装完成 ✓"

# ─── 应用部署 ───────────────────────────────────────────────

deploy-app: ## 部署示例应用 v1.0.0
	@echo ">>> 创建命名空间并启用 Istio 注入..."
	$(KUBECTL) create namespace $(NS_APP) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) label namespace $(NS_APP) istio-injection=enabled --overwrite

	@echo ">>> 部署应用 Pod & Service..."
	$(KUBECTL) apply -f app/deployment-v1.yaml -n $(NS_APP)
	$(KUBECTL) apply -f app/service.yaml -n $(NS_APP)

	@echo ">>> 部署 Istio 网关..."
	$(KUBECTL) apply -f istio/gateway.yaml -n $(NS_APP)

	@echo ">>> 等待 Pod 就绪..."
	$(KUBECTL) wait --for=condition=available deployment/$(APP) -n $(NS_APP) --timeout=120s
	@echo ">>> 应用部署完成 ✓"

# ─── Canary 灰度配置 ────────────────────────────────────────

init-canary: ## 初始化 Flagger Canary CRD
	@echo ">>> 应用 Flagger Canary 配置..."
	$(KUBECTL) apply -f flagger/canary.yaml -n $(NS_APP)
	@sleep 10
	@echo ">>> Canary 资源状态:"
	$(KUBECTL) get canary -n $(NS_APP)
	@echo ">>> Canary 初始化完成 ✓"

trigger-canary: ## 触发灰度发布（升级镜像到 v2.0.0）
	@echo ">>> 触发灰度发布: v1.0.0 → v2.0.0"
	$(KUBECTL) set image deployment/$(APP) \
		-n $(NS_APP) \
		app=$(REPO)/$(APP):2.0.0
	@echo ">>> Flagger 已检测到变更，开始灰度流程..."
	@sleep 3
	$(KUBECTL) describe canary $(APP) -n $(NS_APP) | head -30

# ─── 运营操作 ───────────────────────────────────────────────

promote: ## 手动跳过当前步骤（继续下一阶段）
	@echo ">>> 手动 Promote..."
	$(KUBECTL) -n $(NS_APP) patch canary $(APP) --type merge \
		-p='{"status": {"promoted": true}}' 2>/dev/null || \
	$(KUBECTL) -n $(NS_APP) label canary $(APP) flagger.app/promote=true --overwrite
	@echo ">>> Promote 完成"

rollback: ## 紧急回滚到 v1.0.0
	@echo ">>> 执行紧急回滚..."
	$(KUBECTL) set image deployment/$(APP) \
		-n $(NS_APP) \
		app=$(REPO)/$(APP):1.0.0
	@sleep 5
	$(KUBECTL) get canary $(APP) -n $(NS_APP)
	@echo ">>> 回滚指令已发出"

# ─── 监控与观察 ─────────────────────────────────────────────

watch: ## 实时观察 Canary 状态
	@echo ">>> 实时监控 Canary 发布..."
	$(KUBECTL) get canary $(APP) -n $(NS_APP) -w

status: ## 查看当前灰度发布状态
	@echo "========================================="
	@echo "  Canary 状态"
	@echo "========================================="
	$(KUBECTL) get canary $(APP) -n $(NS_APP) -o wide
	@echo ""
	@echo "--- VirtualService 流量分配 ---"
	$(KUBECTL) get virtualservice $(APP) -n $(NS_APP) -o yaml | \
		grep -A5 "weight" | head -20
	@echo ""
	@echo "--- 相关 Pod ---"
	$(KUBECTL) get pods -n $(NS_APP) -l app=$(APP) -o wide

dashboard: ## 启动 Flagger Dashboard
	@echo ">>> Dashboard: http://localhost:8080"
	$(KUBECTL) -n $(NS_FLAGGER) port-forward svc/flagger 8080:80

load-test: ## 运行负载测试（模拟流量）
	@echo ">>> 启动后台负载测试..."
	nohup $(KUBECTL) run load-test --image=busybox --restart=Never \
		-n $(NS_APP) \
		-- /bin/sh -c 'while true; do \
			wget -q -O- http://$(APP)-canary.$(NS_APP):80; \
			wget -q -O- http://$(APP)-primary.$(NS_APP):80; \
			sleep 0.2; \
		done' 2>&1 &
	@echo ">>> 负载测试已在后台启动"

logs: ## 查看 Flagger 日志
	$(KUBECTL) -n $(NS_FLAGGER) logs deployment/flagger --tail=100 -f

# ─── 清理 ───────────────────────────────────────────────────

cleanup: ## 清理全部资源
	@echo ">>> 清理资源..."
	-$(KUBECTL) delete namespace $(NS_APP) --ignore-not-found
	-$(HELM) uninstall flagger -n $(NS_FLAGGER)
	-$(KUBECTL) delete namespace $(NS_FLAGGER) --ignore-not-found
	-$(HELM) uninstall istio-ingress -n $(NS_ISTIO)
	-$(HELM) uninstall istiod -n $(NS_ISTIO)
	-$(HELM) uninstall istio-base -n $(NS_ISTIO)
	-$(KUBECTL) delete namespace $(NS_ISTIO) --ignore-not-found
	@echo ">>> 清理完成 ✓"

stop-load: ## 停止负载测试
	-$(KUBECTL) delete pod load-test -n $(NS_APP) --ignore-not-found

# ─── 完整演示 ───────────────────────────────────────────────

demo-full: ## 完整演示全流程
	@echo "╔══════════════════════════════════════════════╗"
	@echo "║     Flagger + Istio 灰度发布完整演示        ║"
	@echo "╚══════════════════════════════════════════════╝"
	@echo ""
	@echo "[1/7] 安装 Istio"
	$(MAKE) install-istio
	@echo ""
	@echo "[2/7] 安装 Prometheus"
	$(MAKE) install-prometheus
	@echo ""
	@echo "[3/7] 安装 Flagger"
	$(MAKE) install-flagger
	@echo ""
	@echo "[4/7] 部署示例应用 v1.0.0"
	$(MAKE) deploy-app
	@echo ""
	@echo "[5/7] 初始化 Canary"
	$(MAKE) init-canary
	@echo ""
	@echo "[6/7] 触发灰度发布 → v2.0.0"
	$(MAKE) trigger-canary
	@echo ""
	@echo "[7/7] 开启实时监控"
	@echo ""
	@echo "============================================"
	@echo "  观察命令:  make watch"
	@echo "  状态查询:  make status"
	@echo "  Flagger日志: make logs"
	@echo "  负载测试:  make load-test"
	@echo "  Grafana:    kubectl port-forward -n $(NS_APP) svc/prometheus-grafana 3000:80"
	@echo "============================================"

# ─── Slack 通知 ─────────────────────────────────────────────

slack-notify: ## 配置 Slack 通知 Webhook（需设置 SLACK_URL）
	@test -n "$(SLACK_URL)" || (echo "请设置 SLACK_URL=xxx"; exit 1)
	$(KUBECTL) -n $(NS_FLAGGER) create secret generic flagger-slack \
		--from-literal=url=$(SLACK_URL) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	@echo ">>> Slack 通知已配置"