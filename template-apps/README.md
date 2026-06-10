# templateApps Helm Chart

Helm chart for deploying `templateApps` on Kubernetes, with integrated FluxCD image automation support.

## Requirements

- Kubernetes 1.21+
- Helm 3.x
- FluxCD v2 (if `fluxcdImageUpdate.enabled: true`)

## Installation

```bash
helm install templateApps . -n <namespace>
```

## Configuration

### Image

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `imagerepository/starfire-dev-01-templateApps` |
| `image.tag` | Image tag (empty = chart appVersion) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.containerPort` | Container port (fallback to `service.port`) | — |
| `imagePullSecrets` | Image pull secret names | `[]` |

### Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Extra pod labels | `{}` |
| `podSecurityContext` | Pod-level security context | `{}` |
| `securityContext` | Container-level security context | `{}` |
| `resources` | CPU/memory resource requests and limits | `{}` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `volumes` | Extra volumes | `[]` |
| `volumeMounts` | Extra volume mounts | `[]` |

### Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe` | Liveness probe config | `httpGet /` |
| `readinessProbe` | Readiness probe config | `httpGet /` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.port` | Service port | `80` |

### ServiceAccount

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a ServiceAccount | `false` |
| `serviceAccount.automount` | Automount service account token | `false` |
| `serviceAccount.name` | ServiceAccount name override | `""` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |

### FluxCD Image Update Automation

Controls FluxCD `ImageRepository`, `ImagePolicy`, and `Receiver` resources for automated image updates.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `fluxcdImageUpdate.enabled` | Enable FluxCD image automation | `true` |
| `fluxcdImageUpdate.fluxcdNamespace` | Namespace where FluxCD resources are created | `flux-system` |
| `fluxcdImageUpdate.extraLabels` | Extra labels on FluxCD resources | `{}` |
| `fluxcdImageUpdate.imageRepository.interval` | Image scan interval | `3m0s` |
| `fluxcdImageUpdate.imageRepository.secretRef` | Secret name for registry auth | `harbor-registry-secret` |
| `fluxcdImageUpdate.imagePolicy.filterTags.pattern` | Regex pattern to filter image tags | semver + `.giteaci` suffix |
| `fluxcdImageUpdate.imagePolicy.policy.semver.range` | Semver range for policy | `>22.10.10-x` |
| `fluxcdImageUpdate.webhookReceiver.secretRef` | Secret name for webhook token | `webhook-token` |

FluxCD resources are only created when the corresponding sub-key is present and `enabled: true`:

- `ImageRepository` — created when `fluxcdImageUpdate.imageRepository` is set
- `ImagePolicy` — created when `fluxcdImageUpdate.imagePolicy` is set
- `Receiver` — created when `fluxcdImageUpdate.webhookReceiver` is set

## Naming Convention

FluxCD resources are named using the pattern `<namespace>-<appname>` to avoid conflicts across namespaces. The app name is resolved via the `trackableappname` helper (respects `nameOverride`).

## Chart Details

| Field | Value |
|-------|-------|
| Chart name | `templateApps` |
| Chart version | `0.1.14` |
| App version | `1.16.0` |
| Maintainer | ops@starfire.jp |
