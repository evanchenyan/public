# Flagger + Istio 灰度发布方案（Flux GitOps）

基于 **HelmRelease + Kustomization** 的 GitOps 灰度发布，由 Flux 同步到集群，Flagger 驱动 Canary 流程。

## 架构

```
Git Repository
      │
      ▼
Flux Kustomization (clusters/my-cluster/infrastructure.yaml)
      │
      ▼
infrastructure/my-cluster/
      │
      ├── HelmRelease: istio-base / istiod / istio-ingress
      ├── HelmRelease: prometheus (Istio 指标采集)
      ├── HelmRelease: flagger + loadtester
      ├── Canary CR + MetricTemplate
      └── Deployment / Service / Gateway
              │
              ▼
      Flagger 自动管控流量
      primary (90%) ←→ canary (10%)
              │
      Prometheus 指标驱动放量 / 回滚
```

## 目录结构

```
infrastructure/my-cluster/
├── kustomization.yaml
└── flagger-istio-canary/
    ├── kustomization.yaml
    ├── namespaces.yaml              # istio-system / flagger-system / test
    ├── helmrepositories.yaml        # istio / flagger / prometheus-community
    ├── istio/helmreleases.yaml      # Istio 三件套
    ├── prometheus/helmrelease.yaml  # 供 Flagger 分析的 Prometheus
    ├── flagger/
    │   ├── helmrelease.yaml         # Flagger (meshProvider=istio)
    │   ├── loadtester-helmrelease.yaml
    │   └── canary.yaml              # Canary CR + MetricTemplate
    └── app/                         # 示例应用 + Istio Gateway/VS
```

## 部署（GitOps）

```bash
# 1. 提交并推送
git add infrastructure/my-cluster clusters/my-cluster
git commit -m "feat: Flagger+Istio 灰度 GitOps"
git push

# 2. Flux 自动同步（或手动触发）
flux reconcile kustomization infrastructure --with-source

# 3. 观察 HelmRelease 就绪
kubectl get helmrelease -A
kubectl get canary -n test
```

## 触发灰度

Flagger 监听 Deployment 镜像变更。更新镜像 tag 即可触发 Canary：

```bash
# 方式一：kubectl 手动触发（演示）
kubectl set image deployment/my-app -n test app=docker.io/library/my-app:2.0.0

# 方式二：GitOps — 修改 app/deployment-v1.yaml 中的 image tag 并 push
```

## 观察灰度

```bash
# Canary 状态
kubectl get canary my-app -n test -w

# VirtualService 流量权重
kubectl get virtualservice my-app -n test -o yaml | grep -A5 weight

# Flagger 日志
kubectl logs -n flagger-system deploy/flagger -f
```

## Canary 策略（canary.yaml）

| 参数 | 值 | 说明 |
|------|-----|------|
| stepWeight | 10 | 每步增加 10% 流量到 canary |
| maxWeight | 50 | 最大灰度 50% |
| threshold | 5 | 连续 5 次分析失败则回滚 |
| request-success-rate | ≥ 99% | 5xx 错误率 ≤ 1% |
| request-duration | P99 < 500ms | 延迟阈值 |

## 本地 Makefile 演示（可选）

仍可使用 `Makefile` 做本地快速验证，无需 Flux：

```bash
cd infrastructure/my-cluster/flagger-istio-canary
make demo-full
```

## 与应用 HelmRelease 集成

业务服务若已通过 Flux HelmRelease 部署（见 `scripts/create-service.sh`），只需额外添加：

1. 目标 namespace 开启 `istio-injection=enabled`
2. 为 Deployment 创建 `Canary` CR（参考 `flagger/canary.yaml`）
3. Flagger 会自动创建 `my-app-primary` / `my-app-canary` Service 和 VirtualService

灰度触发方式：Flux ImageUpdate 更新镜像 tag → Deployment 滚动 → Flagger 接管流量切换。
