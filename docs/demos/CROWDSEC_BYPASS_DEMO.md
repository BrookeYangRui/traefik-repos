# CrowdSec IP 黑名单绕过攻击演示

## 项目信息

- **项目**: fbonalair/traefik-crowdsec-bouncer
- **星级**: 322 ⭐
- **漏洞类型**: Forward Auth Header Injection
- **严重程度**: 🔴 **严重** - 可以绕过安全防护系统

## 漏洞概述

这是一个**非常严重**的安全漏洞，可以绕过 CrowdSec 的 IP 黑名单检查，导致安全防护系统完全失效。

### 与 Tailchat 的区别

| 项目 | 漏洞影响 | 严重程度 |
|------|---------|---------|
| Tailchat | 速率限制绕过 | ⚠️ 中等 |
| **CrowdSec Bouncer** | **绕过安全防护系统** | 🔴 **严重** |

**CrowdSec 是一个安全防护系统**，用于阻止恶意 IP 访问。如果被绕过，意味着：
- 被 DDoS 攻击的 IP 仍然可以访问
- 被标记为恶意扫描的 IP 仍然可以访问
- 安全防护系统形同虚设

## 漏洞链分析

### 1. Traefik 配置漏洞

```yaml:24:24:vulnerable_repos_analysis/traefik-crowdsec-bouncer/docker-compose.yaml
      - "traefik.http.middlewares.crowdsec-bouncer.forwardauth.trustForwardHeader=true"
```

**问题**: `trustForwardHeader: true` 且**没有配置 trustedIPs** 白名单

### 2. Bouncer 配置漏洞

```go:16:16:vulnerable_repos_analysis/traefik-crowdsec-bouncer/bouncer.go
var trustedProxiesList = strings.Split(OptionalEnv("TRUSTED_PROXIES", "0.0.0.0/0"), ",")
```

**问题**: 默认信任所有代理 (`0.0.0.0/0`)

### 3. Bouncer 代码漏洞

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
- Gin 框架的 `ClientIP()` 会使用 `X-Forwarded-For`（因为设置了 trusted proxies）
- 使用伪造的 IP 查询 CrowdSec 黑名单

### 4. 攻击流程

```
攻击者 → Traefik (trustForwardHeader: true) 
      → 转发 X-Forwarded-For 
      → Bouncer (信任所有代理)
      → Gin ClientIP() 使用 X-Forwarded-For
      → 查询 CrowdSec 黑名单（使用伪造的 IP）
      → 绕过检查 ✅
```

## 攻击演示

### 场景

1. 攻击者的真实 IP 被 CrowdSec 加入黑名单
2. 正常访问会被阻止（403 Forbidden）
3. 攻击者伪造一个不在黑名单的 IP
4. 成功绕过 CrowdSec 的黑名单检查

### 攻击命令

```bash
# 正常访问（真实 IP，假设被黑名单）
curl http://localhost
# 返回: 403 Forbidden

# 攻击：伪造 IP 绕过黑名单
curl -H "X-Forwarded-For: 192.168.1.100" http://localhost
# 返回: 200 OK ✅ 攻击成功！
```

### 实际影响

1. **绕过安全防护系统** 🔴 严重
   - CrowdSec 是一个安全防护系统
   - 用于阻止恶意 IP 访问
   - 攻击者可以伪造 IP，绕过黑名单检查
   - 被黑名单的恶意 IP 仍然可以访问服务

2. **未授权访问** 🔴 严重
   - 攻击者可以访问被保护的服务
   - 即使 IP 被 CrowdSec 标记为恶意
   - 安全防护完全失效

3. **实际伤害** 🔴 严重
   - 被 DDoS 攻击的 IP 仍然可以访问
   - 被标记为恶意扫描的 IP 仍然可以访问
   - 安全防护系统形同虚设

## 代码证据

### 漏洞配置

```yaml
# docker-compose.yaml:24
- "traefik.http.middlewares.crowdsec-bouncer.forwardauth.trustForwardHeader=true"
# ⚠️ 没有配置 trustedIPs
```

### 漏洞代码

```go
// bouncer.go:16
var trustedProxiesList = strings.Split(OptionalEnv("TRUSTED_PROXIES", "0.0.0.0/0"), ",")
// ⚠️ 默认信任所有代理

// controler/controler.go:113
clientIP := c.ClientIP()  // ⚠️ 使用 X-Forwarded-For
isAuthorized, err := isIpAuthorized(clientIP)  // ⚠️ 使用伪造的 IP 查询
```

## 修复建议

### 修复方法 1: 修复 Traefik 配置（必须）

移除 `trustForwardHeader` 或配置 `trustedIPs`:

```yaml
# 移除这一行
# - "traefik.http.middlewares.crowdsec-bouncer.forwardauth.trustForwardHeader=true"

# 或者在 Traefik 全局配置中添加 trustedIPs
```

### 修复方法 2: 修复 Bouncer 配置（必须）

设置正确的 `TRUSTED_PROXIES`:

```bash
TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
# 不要使用 0.0.0.0/0
```

## 总结

这是一个**非常严重**的安全漏洞，可以绕过 CrowdSec 的 IP 黑名单检查，导致安全防护系统完全失效。与 Tailchat 的速率限制绕过相比，这个漏洞的影响更加严重，因为它直接导致安全防护系统失效。

**关键区别**:
- **Tailchat**: 速率限制绕过 → 中等影响
- **CrowdSec Bouncer**: 安全防护绕过 → **严重影响** 🔴

