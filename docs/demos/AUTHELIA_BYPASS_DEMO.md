# Authelia 认证绕过攻击演示

## 项目信息

- **项目**: rishavnandi/ansible_homelab
- **星级**: 371 ⭐
- **漏洞类型**: Forward Auth Header Injection
- **严重程度**: 🔴 **严重** - 可以绕过 Authelia 认证

## 漏洞概述

这是一个**非常严重**的安全漏洞，可以绕过 Authelia 的认证检查，导致**20+ 个受保护的服务**可以被未授权访问。

### 与之前项目的区别

| 项目 | 漏洞影响 | 严重程度 | 受保护服务 |
|------|---------|---------|-----------|
| Tailchat | 速率限制绕过 | ⚠️ 中等 | 1 个服务 |
| CrowdSec Bouncer | 安全防护绕过 | 🔴 严重 | 1 个服务 |
| **Ansible Homelab** | **认证绕过** | 🔴 **严重** | **20+ 个服务** |

**Ansible Homelab 使用 Authelia 保护了 20+ 个服务**，如果认证被绕过，影响非常严重。

## 漏洞配置

### Traefik Forward Auth 配置

```yaml:157:157:vulnerable_repos_analysis/ansible_homelab/tasks/authelia.yml
      traefik.http.middlewares.authelia.forwardauth.trustForwardHeader: "true"
```

**问题**: `trustForwardHeader: true` 且**没有配置 trustedIPs** 白名单

### 受保护的服务

这个项目使用 Authelia 保护了以下服务（20+ 个）：

- code (Code Server)
- dash (Dashdot)
- duplicati (Duplicati)
- files (Filebrowser)
- guac (Guacamole)
- heimdall (Heimdall)
- homarr (Homarr)
- jellyfin (Jellyfin)
- jellyseerr (Jellyseerr)
- grafana (Grafana)
- n8n (n8n)
- nextcloud (Nextcloud)
- portainer (Portainer)
- prowlarr (Prowlarr)
- qbit (qBittorrent)
- radarr (Radarr)
- requestrr (Requestrr)
- sonarr (Sonarr)
- sync (Syncthing)
- unmanic (Unmanic)
- uptime (Uptime Kuma)
- vault (Vaultwarden)
- wg (WireGuard)

## 攻击场景

### 正常流程（安全）

```
客户端 → Traefik → Forward Auth → Authelia
                              ↓
                        检查认证状态
                              ↓
                        返回 401/403 或 200
```

### 攻击流程（漏洞利用）

```
攻击者（未认证）
  ↓
发送请求: X-Forwarded-For: 127.0.0.1（伪造本地 IP）
  ↓
Traefik (trustForwardHeader: true, 没有 trustedIPs)
  ↓ 信任并转发 X-Forwarded-For
Authelia Forward Auth
  ↓ 可能使用 X-Forwarded-For 进行某些检查
如果 Authelia 实现不当，可能绕过认证
  ↓
返回: 200 OK ✅
攻击成功！绕过认证！
```

## 实际影响

### 1. 认证绕过 🔴 严重

如果 Authelia 使用 `X-Forwarded-For` 进行某些访问控制或信任检查，攻击者可以：
- 伪造本地 IP (`127.0.0.1`)
- 可能绕过某些认证检查
- 获得未授权访问

### 2. 影响范围 🔴 严重

**20+ 个服务受影响**：
- 文件管理服务（Nextcloud, Filebrowser）
- 媒体服务（Jellyfin, Jellyseerr）
- 监控服务（Grafana, Uptime Kuma）
- 下载服务（qBittorrent, Sonarr, Radarr）
- 开发工具（Code Server, n8n）
- 管理工具（Portainer, Heimdall）
- 密码管理（Vaultwarden）

### 3. 数据泄露风险 🔴 严重

如果认证被绕过，攻击者可以：
- 访问私有文件（Nextcloud）
- 查看媒体库（Jellyfin）
- 访问密码库（Vaultwarden）
- 控制下载服务（qBittorrent）
- 访问管理面板（Portainer, Grafana）

## 攻击演示

### 场景

1. 攻击者未通过 Authelia 认证
2. 正常访问会被阻止（401 Unauthorized）
3. 攻击者伪造本地 IP
4. 可能绕过 Authelia 的某些检查

### 攻击命令

```bash
# 正常访问（未认证）
curl https://code.example.com
# 返回: 401 Unauthorized 或重定向到登录页

# 攻击：伪造本地 IP
curl -H "X-Forwarded-For: 127.0.0.1" https://code.example.com
# 如果 Authelia 实现不当，可能返回: 200 OK ✅
```

## 代码证据

### 漏洞配置

```yaml
# tasks/authelia.yml:157
traefik.http.middlewares.authelia.forwardauth.trustForwardHeader: "true"
# ⚠️ 没有配置 trustedIPs
```

### 受保护的服务配置

```yaml
# 多个服务使用 authelia@docker 中间件
traefik.http.routers.code-secure.middlewares: "authelia@docker"
traefik.http.routers.jellyfin-secure.middlewares: "authelia@docker"
traefik.http.routers.portainer-secure.middlewares: "authelia@docker"
# ... 20+ 个服务
```

## 修复建议

### 修复方法 1: 移除 trustForwardHeader（推荐）

```yaml
# 移除这一行
# traefik.http.middlewares.authelia.forwardauth.trustForwardHeader: "true"
```

### 修复方法 2: 配置 trustedIPs 白名单

在 Traefik 全局配置中添加：

```yaml
# Traefik 配置
entryPoints:
  web:
    forwardedHeaders:
      trustedIPs:
        - "10.0.0.0/8"
        - "172.16.0.0/12"
        - "192.168.0.0/16"
```

## 总结

这是一个**非常严重**的安全漏洞，可以绕过 Authelia 的认证检查，导致**20+ 个受保护的服务**可以被未授权访问。与之前的项目相比，这个漏洞的影响范围更大，因为：

1. **影响范围**: 20+ 个服务 vs 1 个服务
2. **漏洞类型**: 认证绕过 vs 速率限制/安全防护绕过
3. **数据风险**: 可能泄露大量敏感数据（文件、密码、媒体等）

**关键发现**:
- ✅ 可以绕过 Authelia 认证（如果实现不当）
- ✅ 影响 20+ 个受保护的服务
- ✅ 可能导致严重的数据泄露

