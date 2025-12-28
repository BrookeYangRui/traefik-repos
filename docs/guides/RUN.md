# Traefik 直接运行指南

Traefik 可以完全独立运行，不需要 Docker 或其他容器环境。

## 快速开始

### 方式 1: 使用提供的脚本（推荐）

```bash
./run-traefik.sh
```

### 方式 2: 使用配置文件

```bash
# 使用 go run（从源码运行）
go run ./cmd/traefik --configFile=traefik-simple.yml

# 或如果已编译
./traefik --configFile=traefik-simple.yml
```

### 方式 3: 使用命令行参数（最简单）

```bash
go run ./cmd/traefik \
  --api.insecure=true \
  --entrypoints.web.address=:8080 \
  --log.level=INFO
```

## 访问服务

运行成功后，可以访问：

- **Dashboard（仪表板）**: http://localhost:8080/dashboard/
- **API 端点**: http://localhost:8080/api/rawdata
- **健康检查**: http://localhost:8080/ping

## 配置文件说明

`traefik-simple.yml` 是最简单的配置文件，包含：

- API 和 Dashboard（不安全模式，仅用于开发）
- 入口点配置（端口 8080）
- 文件提供者（可选）

## 编译二进制文件

如果需要编译独立的二进制文件：

```bash
# 1. 生成代码
make generate

# 2. 编译
make binary

# 3. 运行编译好的二进制
./dist/linux/amd64/traefik --configFile=traefik-simple.yml
```

## 注意事项

1. **端口权限**: 
   - 端口 80/443 需要 root 权限
   - 使用 8080 等非特权端口不需要 root

2. **安全警告**: 
   - `api.insecure=true` 仅用于开发测试
   - 生产环境请配置认证和 TLS

3. **提供者配置**: 
   - 不配置提供者也能运行
   - 但无法自动发现服务
   - 可以手动配置路由规则

## 停止 Traefik

按 `Ctrl+C` 停止运行

## 更多配置

查看 `traefik.sample.yml` 或 `traefik.sample.toml` 了解完整配置选项。


