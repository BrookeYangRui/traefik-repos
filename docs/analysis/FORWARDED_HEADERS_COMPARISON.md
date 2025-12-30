# Forwarded Headers 安全配置对比：Traefik vs Nginx Ingress vs HAProxy

## 概述

HTTP Header Injection (CRLF Injection) 漏洞不仅存在于 Traefik，其他反向代理（如 Nginx Ingress Controller 和 HAProxy）也存在类似的配置问题。本文档对比分析这些反向代理的 forwarded headers 处理机制和安全配置。

---

## 1. Traefik

### 漏洞配置

```yaml
# 不安全的配置
entryPoints:
  web:
    forwardedHeaders:
      insecure: true  # ❌ 信任所有来源
      # 没有 trustedIPs
```

### 安全配置

```yaml
# 安全的配置
entryPoints:
  web:
    forwardedHeaders:
      insecure: false  # ✅ 默认不信任
      trustedIPs:
        - "10.0.0.0/8"
        - "192.168.0.0/16"
```

### Forward Auth 配置

```yaml
# 不安全的 Forward Auth 配置
http:
  middlewares:
    auth:
      forwardAuth:
        address: "http://auth:9091/verify"
        trustForwardHeader: true  # ❌ 需要配合 trustedIPs 使用
```

**问题**：如果 Traefik 本身没有配置 `forwardedHeaders.trustedIPs`，`trustForwardHeader: true` 会导致信任所有来源。

---

## 2. Nginx Ingress Controller

### 漏洞配置

Nginx Ingress Controller 也有类似的 forwarded headers 信任问题：

#### 配置 1: `use-forwarded-headers` 注解

```yaml
# 不安全的配置
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  annotations:
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"  # ❌ 可能不安全
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 80
```

**问题**：
- `use-forwarded-headers: "true"` 会使用请求中的 `X-Forwarded-*` 头
- **默认情况下，Nginx Ingress Controller 会信任所有来源**
- 需要配合 `compute-full-forwarded-for` 和 `forwarded-for-header` 使用

#### 配置 2: ConfigMap 全局配置

```yaml
# 不安全的全局配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"  # ❌ 全局启用，信任所有来源
  compute-full-forwarded-for: "true"
```

### 安全配置

#### 方案 1: 使用 `real-ip-header` 和 `set-real-ip-from`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  # ✅ 只信任特定 IP 范围
  set-real-ip-from: "10.0.0.0/8,192.168.0.0/16"
  real-ip-header: "X-Forwarded-For"
```

#### 方案 2: 使用 Proxy Protocol（如果使用负载均衡器）

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-proxy-protocol: "true"  # ✅ 使用 Proxy Protocol
  # 配置可信的 Proxy Protocol 来源
  proxy-real-ip-cidr: "10.0.0.0/8"
```

### Nginx Ingress Controller 的潜在问题

1. **默认信任所有来源**：
   - 如果只配置 `use-forwarded-headers: "true"` 而没有 `set-real-ip-from`
   - Nginx 会信任所有来源的 `X-Forwarded-For` 头

2. **`compute-full-forwarded-for` 的影响**：
   - 这个选项会追加而不是替换 `X-Forwarded-For`
   - 可能导致 IP 链被污染

3. **`forwarded-for-header` 配置**：
   - 可以自定义 forwarded-for 头的名称
   - 但如果配置不当，仍然可能被伪造

---

## 3. HAProxy

### 漏洞配置

HAProxy 使用 `option forwardfor` 来处理 forwarded headers：

```haproxy
# 不安全的配置
global
    # ...

defaults
    option forwardfor  # ❌ 信任所有来源
    # 没有配置 trusted source
```

**问题**：
- `option forwardfor` 默认会信任所有来源
- 需要配合 `option forwardfor except` 或 `option forwardfor header` 使用

### 安全配置

#### 方案 1: 使用 `option forwardfor except`

```haproxy
# 安全的配置
global
    # ...

defaults
    option forwardfor
    # ✅ 只信任特定 IP 范围
    option forwardfor except 10.0.0.0/8
    option forwardfor except 192.168.0.0/16
```

#### 方案 2: 使用 Proxy Protocol

```haproxy
# 使用 Proxy Protocol（更安全）
global
    # ...

defaults
    # ✅ 使用 Proxy Protocol 而不是 X-Forwarded-For
    option forwardfor header X-Real-IP
    # 配置可信的 Proxy Protocol 来源
    # （需要在 frontend 中配置）
```

#### 方案 3: 使用 `http-request set-header` 手动设置

```haproxy
frontend web
    bind *:80
    # ✅ 手动设置 X-Forwarded-For，只信任特定来源
    acl trusted src 10.0.0.0/8
    acl trusted src 192.168.0.0/16
    http-request set-header X-Forwarded-For %[src] if trusted
    http-request set-header X-Forwarded-For %[src] if !trusted
    default_backend servers
```

### HAProxy 的潜在问题

1. **`option forwardfor` 默认行为**：
   - 默认会追加 `X-Forwarded-For` 头
   - 如果没有配置 `except`，会信任所有来源

2. **`option forwardfor header` 配置**：
   - 可以自定义 header 名称
   - 但如果配置不当，仍然可能被伪造

3. **Proxy Protocol 配置**：
   - 更安全，但需要负载均衡器支持
   - 需要正确配置可信来源

---

## 4. 对比总结

| 特性 | Traefik | Nginx Ingress | HAProxy |
|------|---------|---------------|---------|
| **默认行为** | 不信任（安全） | 信任所有（不安全） | 信任所有（不安全） |
| **安全配置选项** | `trustedIPs` | `set-real-ip-from` | `option forwardfor except` |
| **Forward Auth 支持** | ✅ `trustForwardHeader` | ⚠️ 需要额外配置 | ⚠️ 需要额外配置 |
| **Proxy Protocol 支持** | ✅ 原生支持 | ✅ 支持 | ✅ 原生支持 |
| **配置复杂度** | 低 | 中 | 中 |

### 安全配置建议

#### Traefik
```yaml
entryPoints:
  web:
    forwardedHeaders:
      trustedIPs:
        - "10.0.0.0/8"
        - "192.168.0.0/16"
```

#### Nginx Ingress Controller
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "10.0.0.0/8,192.168.0.0/16"
  real-ip-header: "X-Forwarded-For"
```

#### HAProxy
```haproxy
defaults
    option forwardfor
    option forwardfor except 10.0.0.0/8
    option forwardfor except 192.168.0.0/16
```

---

## 5. 通用攻击场景

所有反向代理都存在类似的攻击场景：

### 场景 1: IP 白名单绕过

```http
GET /admin HTTP/1.1
Host: target.com
X-Forwarded-For: 127.0.0.1
```

如果反向代理配置不当，攻击者可以伪造 IP 地址绕过 IP 白名单。

### 场景 2: 日志注入

```http
GET / HTTP/1.1
Host: target.com
X-Forwarded-For: 127.0.0.1\r\n[INJECTED] malicious log entry\r\n
```

如果后端服务记录 `X-Forwarded-For` 到日志，攻击者可以注入恶意内容。

### 场景 3: 速率限制绕过

```http
GET /api/endpoint HTTP/1.1
Host: target.com
X-Forwarded-For: 192.168.1.100,192.168.1.101,192.168.1.102
```

如果速率限制基于 `X-Forwarded-For`，攻击者可以通过伪造多个 IP 来绕过限制。

---

## 6. 检测和修复建议

### 检测方法

1. **检查配置文件中是否有不安全的配置**：
   - Traefik: 查找 `forwardedHeaders.insecure: true` 且没有 `trustedIPs`
   - Nginx Ingress: 查找 `use-forwarded-headers: "true"` 且没有 `set-real-ip-from`
   - HAProxy: 查找 `option forwardfor` 且没有 `except` 配置

2. **测试验证**：
   ```bash
   # 发送包含恶意 X-Forwarded-For 头的请求
   curl -H "X-Forwarded-For: 127.0.0.1" http://target.com/
   
   # 检查后端日志是否记录了伪造的 IP
   ```

### 修复建议

1. **配置可信 IP 白名单**：
   - 只信任已知的代理 IP 范围
   - 不要使用 `0.0.0.0/0` 或 `*`

2. **使用 Proxy Protocol**（如果可能）：
   - 比 X-Forwarded-For 更安全
   - 需要负载均衡器支持

3. **后端验证**：
   - 后端服务不应该直接信任 `X-Forwarded-For`
   - 应该使用 `X-Real-IP` 或 `Remote-Addr`

---

## 7. 结论

**所有反向代理都存在类似的 forwarded headers 信任问题**：

- ✅ **Traefik**: 默认不信任（更安全），但需要正确配置 `trustedIPs`
- ⚠️ **Nginx Ingress Controller**: 默认信任所有来源（不安全），需要配置 `set-real-ip-from`
- ⚠️ **HAProxy**: 默认信任所有来源（不安全），需要配置 `option forwardfor except`

**关键要点**：
1. 永远不要信任所有来源的 forwarded headers
2. 始终配置可信 IP 白名单
3. 优先使用 Proxy Protocol（如果可能）
4. 后端服务应该验证 forwarded headers 的来源

