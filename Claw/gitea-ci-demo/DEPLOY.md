# Gitea CI/CD 部署指南

## 架构概览

```
代码推送 ──→ Gitea ──→ Actions Runner ──→ Kaniko ──→ 镜像仓库
              │              │
              │              ├── Go 编译
              │              ├── Java 编译 (Maven)
              │              └── 前端构建 (npm)
              │
              └── 触发条件：对应目录下的文件变更
```

**三个独立的工作流，按目录触发：**

| 工作流 | 触发目录 | 产出镜像 |
|--------|---------|----------|
| `ci-go-backend.yml` | `backend-go/**` | `registry/backend-go:{tag}` |
| `ci-java-backend.yml` | `backend-java/**` | `registry/backend-java:{tag}` |
| `ci-frontend.yml` | `frontend/**` | `registry/frontend:{tag}` |

每次推送同时打 `{branch}-{commit_sha}` 和 `latest` 两个标签。

---

## 第一步：部署 Gitea

### 方式 A：Docker Compose（推荐）

```bash
cd gitea-ci-demo
docker-compose up -d gitea
```

打开 http://localhost:3000，按引导完成初始化：
- 数据库选 **SQLite3**（最简单）
- 域名填你的实际域名或 IP
- 创建管理员账号

### 方式 B：已有 Gitea 实例

如果你已有 Gitea（1.19+），只需确保 `app.ini` 中启用了 Actions：

```ini
[actions]
ENABLED = true
```

重启 Gitea 后生效。

---

## 第二步：准备 Kaniko Runner

Kaniko 需要 `/kaniko/executor` 二进制文件。有两种方案：

### 方案一：使用含 Kaniko 的 Runner 镜像（推荐）

创建一个自定义 Runner 镜像，把 Kaniko 打进去：

**Dockerfile.runner：**

```dockerfile
FROM gitea/act_runner:0.2.11

# 安装 Kaniko executor
COPY --from=gcr.io/kaniko-project/executor:latest /kaniko/executor /kaniko/executor
COPY --from=gcr.io/kaniko-project/executor:latest /kaniko/ssl /kaniko/ssl
COPY --from=gcr.io/kaniko-project/executor:latest /kaniko/.docker /kaniko/.docker
```

构建：

```bash
docker build -f Dockerfile.runner -t gitea-runner-kaniko:latest .
```

### 方案二：裸机部署 Runner + 单独安装 Kaniko

**a) 下载 Runner 二进制：**

```bash
# 从 Gitea 官网下载
wget https://dl.gitea.com/act_runner/0.2.11/act_runner-0.2.11-linux-amd64
chmod +x act_runner-0.2.11-linux-amd64
mv act_runner-0.2.11-linux-amd64 /usr/local/bin/act_runner
```

**b) 下载 Kaniko executor：**

```bash
# 从 Kaniko 镜像中提取
docker pull gcr.io/kaniko-project/executor:latest
container_id=$(docker create gcr.io/kaniko-project/executor:latest)
docker cp ${container_id}:/kaniko/executor /usr/local/bin/kaniko-executor
docker cp ${container_id}:/kaniko/ssl /kaniko/ssl
docker rm ${container_id}
chmod +x /usr/local/bin/kaniko-executor

# 创建软链接
ln -s /usr/local/bin/kaniko-executor /kaniko/executor
```

---

## 第三步：注册 Runner

### 获取 Registration Token

1. 打开 Gitea Web → 你的仓库 → **Settings** → **Actions** → **Runners**
2. 点击 **Create new Runner**，复制显示的 Token

### 注册

```bash
act_runner register \
  --instance http://你的Gitea地址:3000 \
  --token 粘贴你的Token \
  --name kaniko-runner \
  --labels ubuntu-latest \
  --no-interactive
```

注册成功后，配置文件在 `~/.act_runner/config.yaml`。

### 启动 Runner

```bash
act_runner daemon
```

用 systemd 管理（可选）：

```ini
# /etc/systemd/system/gitea-runner.service
[Unit]
Description=Gitea Actions Runner
After=network.target

[Service]
Type=simple
User=runner
ExecStart=/usr/local/bin/act_runner daemon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## 第四步：配置镜像仓库

本方案中，你需要在 Secrets 中配置镜像仓库的认证信息。

支持任意 Docker 兼容的镜像仓库：
- **Docker Hub**：`docker.io/你的用户名`
- **Harbor**：`harbor.你的域名.com/项目名`
- **阿里云 ACR**：`registry.cn-hangzhou.aliyuncs.com/命名空间`
- **腾讯云 TCR**：`ccr.ccs.tencentyun.com/命名空间`
- **自建 Registry**：`你的IP:5000`

### 在 Gitea 中配置 Secrets

进入仓库 → **Settings** → **Actions** → **Secrets**，添加三个 Secret：

| Secret 名称 | 值 | 说明 |
|-------------|-----|------|
| `REGISTRY_URL` | `harbor.example.com/demo` | 镜像仓库地址（不含协议） |
| `REGISTRY_USER` | `admin` | 仓库用户名 |
| `REGISTRY_PASSWORD` | `你的密码` | 仓库密码 |

---

## 第五步：推送代码触发构建

```bash
# 初始化仓库
cd gitea-ci-demo
git init
git remote add origin http://你的Gitea地址:3000/你的用户/gitea-ci-demo.git

# 添加所有文件
git add .
git commit -m "feat: 初始化 Gitea CI 项目"

# 推送到远程
git push -u origin main
```

推送后，在 Gitea Web → **Actions** 标签页可以看到三个工作流同时运行。

### 触发规则

- **推送到 main/develop 分支**：触发 CI，标签为 `{branch}-{sha}`
- **推送 tag（如 v1.0.0）**：触发 CI，标签为 `v1.0.0`
- **创建 Pull Request**：触发 CI 但不推送镜像（仅构建验证）
- **修改谁的代码就触发谁的 CI**：只改 `frontend/` 就不会重建 Go/Java

---

## 第六步：镜像标签说明

| 场景 | 标签格式 | 示例 |
|------|---------|------|
| 推送到 main | `main-{短sha}` + `latest` | `main-a1b2c3d`, `latest` |
| 推送到 develop | `develop-{短sha}` | `develop-e4f5g6h` |
| 推送 tag v1.0.0 | `v1.0.0` | `v1.0.0` |

最终镜像地址：

```
harbor.example.com/demo/backend-go:latest
harbor.example.com/demo/backend-java:latest
harbor.example.com/demo/frontend:latest
```

---

## 第七步：拉取镜像部署

### 应用编排示例（docker-compose.prod.yml）

```yaml
version: '3.8'
services:
  frontend:
    image: harbor.example.com/demo/frontend:latest
    ports:
      - "80:80"
    depends_on:
      - backend-go
      - backend-java

  backend-go:
    image: harbor.example.com/demo/backend-go:latest
    ports:
      - "8081:8080"
    environment:
      - APP_VERSION=latest

  backend-java:
    image: harbor.example.com/demo/backend-java:latest
    ports:
      - "8082:8080"
    environment:
      - APP_VERSION=latest
```

拉取并启动：

```bash
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

---

## 完整部署时间线

```
1. 部署 Gitea                    ← 10 分钟
2. 准备 Runner（含 Kaniko）       ← 5 分钟
3. 注册 Runner                   ← 1 分钟
4. 配置 Secrets（镜像仓库认证）    ← 2 分钟
5. git push 代码                  ← 30 秒
6. 等待 Actions 完成              ← 3-8 分钟（首次）
                                  ← 1-3 分钟（有缓存）
7. docker pull 镜像 → docker run   ← 1 分钟
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总计                              ≈ 30 分钟
```

---

## 高级配置

### 自签名证书仓库

如果镜像仓库用了自签名证书，修改 `scripts/kaniko-build.sh`，取消注释：

```bash
--skip-tls-verify
```

或在 Runner 上挂载 CA 证书：

```bash
docker run ... \
  -v /etc/ssl/certs/your-ca.crt:/kaniko/ssl/certs/ca-certificates.crt:ro
```

### 使用 HTTP 仓库

```bash
# kaniko-build.sh 中取消注释
--insecure
--insecure-registry=你的仓库地址:端口
```

### 缓存优化

Kaniko 默认启用了 `--cache=true`（层缓存）和 `--cache-ttl=24h`。如果需要持久化缓存目录：

```bash
# 在 Runner 上挂载缓存卷
docker run ... -v /data/kaniko-cache:/cache

# kaniko-build.sh 中添加
--cache-dir=/cache
```

### 多架构构建

Kaniko 本身不直接支持多架构构建（需要 manifest tool）。如果要构建 ARM + AMD64 镜像：

1. 部署不同架构的 Runner
2. 各自构建不同架构的镜像
3. 用 `docker manifest` 合并

---

## 故障排查

### Runner 状态是 Offline

```bash
# 检查 Runner 是否在运行
ps aux | grep act_runner

# 查看 Runner 日志
journalctl -u gitea-runner -f
```

### Kaniko 报 "executor not found"

Runner 镜像里没有 Kaniko。用方案一的 Dockerfile 重新构建 Runner 镜像。

### 镜像推送失败 401/403

检查 Secrets 配置是否正确：
1. `REGISTRY_URL` 不含 `http://` 或 `https://`
2. 用户名密码是否正确
3. 仓库中是否已创建对应的项目/命名空间

### 首次构建特别慢

首次没有 Maven/npm/Go 缓存，正常现象。第二次构建会快很多。

### Java 构建 OOM

Maven 构建吃内存，在 Runner 配置中增加资源限制：

```yaml
# ~/.act_runner/config.yaml
runner:
  envs:
    MAVEN_OPTS: "-Xmx1024m -XX:MaxMetaspaceSize=256m"
```
