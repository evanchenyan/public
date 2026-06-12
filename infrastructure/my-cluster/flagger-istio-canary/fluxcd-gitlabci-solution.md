# K8s + FluxCD + GitLab CI + Flagger + Istio 生产级自动化灰度发布方案

在企业级 GitOps 架构中，**GitLab CI**（负责 CI 构建/镜像打包/清单修改）、**FluxCD**（负责 GitOps 声明式持续部署）和 **Flagger + Istio**（负责在 K8s 集群内进行自动化灰度流量调度和指标验证）结合，可以实现**完全闭环的、零人工干预的渐进式交付（Progressive Delivery）**。

这里是为您的技术栈定制的完整灰度发布方案与各组件实现细节。

---

## 1. 整体架构与工作流

整个灰度过程遵循 **GitOps 原则**，所有状态变更源于 Git 提交：

```
┌───────────┐      1. Push Code     ┌───────────┐
│ Developer │ ────────────────────> │ GitLab Repo│
└───────────┘                       └─────┬─────┘
                                          │ 2. CI Pipeline Run
                                          ▼
                                    ┌───────────┐
                                    │ GitLab CI │
                                    └─────┬─────┘
                                          │ 3. Build & Push Image
                                          │ 4. Update Image Tag in Config Repo
                                          ▼
                                    ┌───────────┐
                                    │ Config    │
                                    │ Git Repo  │ <────────────────┐
                                    └─────┬─────┘                  │
                                          │ 5. Pull Changes        │
                                          ▼                        │
                                    ┌───────────┐                  │
                                    │  FluxCD   │                  │
                                    └─────┬─────┘                  │
                                          │ 6. Sync K8s Deployment │
                                          ▼                        │
                                    ┌───────────┐                  │ 8. Promote / Rollback
                                    │  Flagger  │ ─────────────────┘    (Update Git if needed)
                                    └─────┬─────┘
                                          │ 7. Gradual Traffic Shifting (10% -> 50%)
                                          ▼
                                    ┌───────────┐
                                    │   Istio   │ <─── [Prometheus Monitors Latency/Errors]
                                    └───────────┘
```

### 自动化流转步骤：
1. **开发者**提交代码到应用仓库。
2. **GitLab CI** 触发：
   - 构建新 Docker 镜像，推送到私有 Registry。
   - 自动拉取 **GitOps 配置仓库（Config Repo）**，修改 K8s Deployment 的 `image` 标签，并自动 `git commit & push`。
3. **FluxCD** 监控到 GitOps 仓库变更，自动拉取新清单并将集群中的应用 Deployment 更新为新镜像。
4. **Flagger** 监控到目标 Deployment 镜像版本发生变化，自动拦截该变更，进入灰度流：
   - 保留原 Pod 为 `primary`（承载 100% 流量）。
   - 创建 `canary` 版本的 Pod（部署新镜像）。
   - 控制 **Istio VirtualService**，将 10% 流量引入 `canary`。
   - 周期性（如每 60 秒）查询 **Prometheus** 采集的 Istio Envoy 指标（成功率、延迟等）。
   - 若指标异常达到阈值，**自动回滚**（流量切回 100% primary，报错报警）。
   - 若指标一直正常，逐步增加权重（如 10% -> 20% -> 50%）。
   - 验证通过后进行 **Promote**：将 primary 的镜像升级到新版本，然后将流量 100% 恢复到 primary，并销毁 canary 容器。

---

## 2. FluxCD 声明式清单配置

FluxCD 负责同步 K8s 资源。我们需要将 **Deployment**、**Istio 资源** 以及 **Flagger Canary** 放入 Flux 管理的 GitOps 目录中。

### 2.1 GitOps 仓库目录分类建议

```
infrastructure/                 # 基础设施层
├── istio/                      # Istio 部署与配置
│   ├── helmrelease.yaml
│   └── gateway.yaml
├── flagger/                    # Flagger 部署与全局配置
│   ├── helmrelease.yaml
│   └── flagger-grafana.yaml
apps/                           # 业务应用层
└── test-app/                   # 某具体的业务微服务
    ├── kustomization.yaml      # FluxCD 编排
    ├── deployment.yaml         # 只需配置基础镜像，无需手动配多个版本 Deployment
    ├── service.yaml            # 基础 Service
    └── canary.yaml             # Flagger 灰度发布控制器
```

### 2.2 `apps/test-app/deployment.yaml` （基础应用定义）

注意：在 Flagger 方案中，**不要**手动维护 stable 和 canary 两个 Deployment 资源。我们只需编写一个标准的 Deployment，Flagger 会自动根据它衍生出 `[name]-primary`。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: registry.example.com/my-app:1.0.0  # GitLab CI 将自动更新此标签
        ports:
        - containerPort: 8080
          name: http
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
```

### 2.3 `apps/test-app/canary.yaml` （Flagger 灰度控制定义）

FluxCD 将直接同步此配置，Flagger 看到此 CRD 后，将接管上面的 `my-app` Deployment：

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
  namespace: test
spec:
  # 目标 Deployment
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  # 生成的 Service 端口定义
  service:
    port: 80
    targetPort: 8080
    name: my-app
    portName: http
  # 使用 Istio 进行流量分割
  serviceMeshProvider: istio
  # 灰度流程控制
  analysis:
    interval: 1m         # 检查时间窗口
    threshold: 5         # 最大允许指标失败次数，超过则回滚
    maxWeight: 50        # 最大切分流量
    stepWeight: 10       # 每阶段递增流量（10% -> 20% -> 30% -> 40% -> 50%）
    metrics:
    # 1. 成功率指标
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    # 2. 延迟指标
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    # 3. 灰度集成测试 Webhook (可选：自动化触发接口压测)
    webhooks:
    - name: loadtest
      url: http://flagger-loadtester.test-system/
      timeout: 5s
      metadata:
        type: cmd
        cmd: "hey -z 1m -q 10 http://my-app-canary.test:80/"
```

---

## 3. GitLab CI 持续集成管道配置

GitLab CI 负责把新版镜像构建完成并推送到私有仓库，然后**利用安全凭证更新 GitOps 仓库**，从而触发 FluxCD 的拉取动作。

### 3.1 `.gitlab-ci.yml` 示例

```yaml
stages:
  - build
  - deploy

variables:
  REGISTRY: registry.example.com
  IMAGE_NAME: registry.example.com/test-group/my-app
  CONFIG_REPO_URL: "gitlab.example.com/gitops/cluster-config.git"

# 1. 镜像构建阶段
build_image:
  stage: build
  image: docker:24-git
  services:
    - docker:24-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $REGISTRY
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHORT_SHA -t $IMAGE_NAME:latest .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHORT_SHA
    - docker push $IMAGE_NAME:latest
  only:
    - main

# 2. 触发 GitOps 同步阶段 (更新 Git 标签)
trigger_gitops:
  stage: deploy
  image: line/kubectl-kustomize:latest # 带有 git & kustomize/yq 的轻量镜像
  before_script:
    # 配置 SSH 密钥以向 GitOps 配置仓库进行 push 变更
    - mkdir -p ~/.ssh
    - echo "$GITOPS_DEPLOY_KEY" | tr -d '\r' > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - ssh-keyscan gitlab.example.com >> ~/.ssh/known_hosts
    - git config --global user.email "ci-bot@example.com"
    - git config --global user.name "GitOps CI Bot"
  script:
    - git clone git@gitlab.example.com:gitops/cluster-config.git
    - cd cluster-config/apps/test-app
    # 使用 yq 或 sed 替换 deployment.yaml 中镜像的版本号为最新的 $CI_COMMIT_SHORT_SHA
    - sed -i "s|image: $IMAGE_NAME:.*|image: $IMAGE_NAME:$CI_COMMIT_SHORT_SHA|g" deployment.yaml
    # 提交变更
    - git add deployment.yaml
    - git commit -m "chore(gitops): release my-app version $CI_COMMIT_SHORT_SHA [skip ci]"
    - git push origin main
  only:
    - main
```

---

## 4. 关键技术点与踩坑避雷 (Best Practices)

1. **镜像拉取凭证与 Sidecar 注入：**
   在配置了 `istio-injection=enabled` 的命名空间中，由于 Sidecar 容器可能比应用容器启动更慢，可能引发网络初始化问题。确保使用 K8s 1.28+ 并在 Istio 中配置 `ENABLE_ENVOY_FILTER_SANS` 或启用原生的 Sidecar 容器生命周期支持。
   
2. **FluxCD 与 Flagger 状态对冲预防：**
   因为 Flagger 会在运行时修改 `VirtualService` 的权重，**绝对不要**将带有具体分流权重的 `VirtualService` 清单交给 FluxCD 或者是 `Kustomize` 同步，否则 FluxCD 会在定期同步（Reconciliation）时把流量重置回初始状态。
   - **解决方案**：只在 Git 仓库中管理应用的基础 `Deployment`、`Service` 和 `Canary` 声明，不要手工将由 Flagger 自动创建的 `[app]-primary-service`、`[app]-canary-service` 以及 `VirtualService` 提交到 Git。

3. **优雅停机与连接耗尽 (Connection Draining)：**
   灰度最后阶段进行 100% 流量接管（Promote）时，旧 Pod（Canary Pod）会被销毁。如果此时长连接或正在处理的请求未结束，会抛出 503。
   - **解决方案**：在容器配置中设置合理的 `terminationGracePeriodSeconds`（如 30-60s），并在应用代码中优雅拦截 `SIGTERM` 信号，确保处理完内存中的已有连接再退出。
