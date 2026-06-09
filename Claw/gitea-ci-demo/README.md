# Gitea CI/CD 前后端分离 Demo

一个完整的 Gitea Actions CI/CD 示例，支持 Go/Java 后端 + 前端，使用 Kaniko 构建并推送镜像。

## 项目结构

```
gitea-ci-demo/
├── .gitea/workflows/        # Gitea Actions 工作流
│   ├── ci-go-backend.yml     # Go 后端 CI
│   ├── ci-java-backend.yml  # Java 后端 CI
│   └── ci-frontend.yml      # 前端 CI
├── backend-go/               # Go 后端
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── backend-java/             # Java 后端
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── frontend/                 # 前端（React + Vite）
│   ├── src/
│   ├── vite.config.js
│   ├── package.json
│   └── Dockerfile
├── scripts/
│   └── kaniko-build.sh      # 通用 Kaniko 构建脚本
├── docker-compose.yml        # 本地 Gitea + Runner 编排
└── DEPLOY.md                # 完整部署指南
```

## 快速开始

1. 阅读 `DEPLOY.md` 完成 Gitea、Runner、镜像仓库的准备
2. 在 Gitea 仓库中配置三个 Secrets：
   - `REGISTRY_URL` — 镜像仓库地址
   - `REGISTRY_USER` — 仓库用户名
   - `REGISTRY_PASSWORD` — 仓库密码
3. `git push` 触发 CI，在 Gitea 的 Actions 标签页查看进度

## CI 触发规则

| 修改目录 | 触发工作流 | 产出镜像 |
|---------|-----------|---------|
| `backend-go/**` | Go 后端 CI | `registry/backend-go:{tag}` |
| `backend-java/**` | Java 后端 CI | `registry/backend-java:{tag}` |
| `frontend/**` | 前端 CI | `registry/frontend:{tag}` |

## 技术栈

- **Go 后端**：Go 1.22 + 标准库 HTTP
- **Java 后端**：Spring Boot 3.2 + Java 17
- **前端**：React 18 + Vite 5 + Nginx
- **CI 引擎**：Gitea Actions + Kaniko
- **镜像仓库**：任意 Docker Registry 兼容仓库
