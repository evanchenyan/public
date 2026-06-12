# FluxCD + GitLab CI + Flagger + Istio 生产级自动化部署落地

本文件说明如何在集群中分步执行此自动化灰度部署方案。

---

## 1. 基础设施自动化安装准备

在 GitOps (FluxCD) 下，所有的基础设施（Istio、Flagger、Prometheus）应作为 **HelmRelease** 和 **HelmRepository** 资源来声明。

我们为您创建了这些完整的 FluxCD Helm 声明文件，放在基础设施目录中：

- **GitOps 配置目录建议**：
  `/Users/leo/WorkBuddy/public/infrastructure/my-cluster/flagger-istio-canary/gitops-infra/`

---

### 1.1 HelmRepository 声明 (`gitops-infra/repos.yaml`)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: istio
  namespace: flux-system
spec:
  interval: 1h
  url: https://istio-release.storage.googleapis.com/charts
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: flagger
  namespace: flux-system
spec:
  interval: 1h
  url: https://flagger.app
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
```

---

### 1.2 Istio 声明 (`gitops-infra/istio.yaml`)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istio-base
  namespace: istio-system
spec:
  chart:
    spec:
      chart: base
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: istio
        namespace: flux-system
  interval: 1h
  install:
    crds: CreateReplace
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istiod
  namespace: istio-system
spec:
  dependsOn:
    - name: istio-base
  chart:
    spec:
      chart: istiod
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: istio
        namespace: flux-system
  interval: 1h
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istio-ingress
  namespace: istio-system
spec:
  dependsOn:
    - name: istiod
  chart:
    spec:
      chart: gateway
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: istio
        namespace: flux-system
  interval: 1h
```

---

### 1.3 Flagger 声明 (`gitops-infra/flagger.yaml`)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: flagger
  namespace: flagger-system
spec:
  chart:
    spec:
      chart: flagger
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: flagger
        namespace: flux-system
  interval: 1h
  values:
    meshProvider: istio
    metricsServer: http://prometheus-operated.test:9090
```

---

## 2. GitLab CI 自动化回写与鉴权配制

要在 GitLab CI 中实现自动化回写，需要如下设置：

### 2.1 凭证准备
1. 生成一对 SSH 密钥（或 GitLab Project Access Token）。
2. 将 **私钥** 作为名为 `GITOPS_DEPLOY_KEY` 的 **GitLab CI/CD Variable** 注入到应用构建仓库中（确保勾选 Masked/Protected）。
3. 将 **公钥** 作为 **Deploy Key (带有 Write access)** 配置到您的 **GitOps 配置仓库（Cluster Config Repo）** 中。

### 2.2 多环境控制与手动审批
在生产环境中，自动触发灰度可能需要手动触发，可以在 `.gitlab-ci.yml` 中添加 `when: manual` 来加入人工确认环节：

```yaml
trigger_gitops_prod:
  stage: deploy
  image: line/kubectl-kustomize:latest
  script:
    - git clone git@gitlab.example.com:gitops/cluster-config.git
    - cd cluster-config/apps/prod-app
    - sed -i "s|image: $IMAGE_NAME:.*|image: $IMAGE_NAME:$CI_COMMIT_SHORT_SHA|g" deployment.yaml
    - git commit -am "chore(gitops): promote prod-app to $CI_COMMIT_SHORT_SHA"
    - git push origin main
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual  # 在生产环境启用手动审批按钮
```

---

## 3. 下一步操作指引

通过将以上 `gitops-infra/` 目录和应用目录一并推送到您的 FluxCD 管理的 GitOps 仓库中，FluxCD 将自动为您在 K8s 中安装并拉起这整套发布链路！
