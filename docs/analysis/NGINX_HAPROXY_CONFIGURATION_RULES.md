# Ingress Nginx 和 HAProxy 的 Forwarded Headers 配置规则和策略

## 概述

本文档详细说明 Ingress Nginx Controller 和 HAProxy 处理 forwarded headers 的规则、默认行为、安全配置策略和最佳实践。

---

## 1. Ingress Nginx Controller

### 1.1 核心配置机制

Ingress Nginx Controller 通过 ConfigMap 和 Ingress 注解来配置 forwarded headers 的处理。

#### ConfigMap 配置（全局配置）

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  # 关键配置项
  use-forwarded-headers: "true"  # 是否使用 X-Forwarded-* 头
  compute-full-forwarded-for: "true"  # 是否追加而不是替换
  forwarded-for-header: "X-Forwarded-For"  # 自定义 header 名称
  set-real-ip-from: "10.0.0.0/8,192.168.0.0/16"  # 可信 IP 范围
  real-ip-header: "X-Forwarded-For"  # 用于设置真实 IP 的 header
  real-ip-recursive: "true"  # 是否递归查找真实 IP
```

#### Ingress 注解（单个 Ingress 配置）

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  annotations:
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
    nginx.ingress.kubernetes.io/forwarded-for-header: "X-Forwarded-For"
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

### 1.2 默认行为分析

#### 默认配置（未设置任何配置）

```yaml
# 默认情况下
use-forwarded-headers: "false"  # 默认不使用 forwarded headers
set-real-ip-from: ""  # 默认不设置可信 IP
```

**行为**：
- ✅ **默认安全**：不使用 forwarded headers
- ✅ **不会信任客户端的 `X-Forwarded-For`**
- ⚠️ **但如果后端需要真实客户端 IP，需要配置**

#### 启用 `use-forwarded-headers: "true"` 但未设置 `set-real-ip-from`

```yaml
use-forwarded-headers: "true"
# 没有 set-real-ip-from
```

**行为**：
- 🔴 **不安全**：会信任所有来源的 `X-Forwarded-For`
- 🔴 **攻击者可以伪造 IP 地址**
- 🔴 **这是常见的错误配置**

### 1.3 关键配置项详解

#### `use-forwarded-headers`

**作用**：是否使用请求中的 `X-Forwarded-*` 头。

**值**：
- `"true"`: 使用 forwarded headers
- `"false"`: 不使用 forwarded headers（默认）

**安全影响**：
- 如果设置为 `"true"`，必须配合 `set-real-ip-from` 使用
- 单独使用 `"true"` 会导致信任所有来源

#### `set-real-ip-from`

**作用**：指定可信的 IP 范围，只有来自这些 IP 的 `X-Forwarded-For` 才会被信任。

**格式**：CIDR 格式，多个 IP 范围用逗号分隔

**示例**：
```yaml
set-real-ip-from: "10.0.0.0/8,192.168.0.0/16,172.16.0.0/12"
```

**安全影响**：
- ✅ **关键安全配置**：必须配置才能安全使用 forwarded headers
- ⚠️ **如果范围过宽**（如 `0.0.0.0/0`），仍然不安全
- ✅ **应该只包含上游代理的 IP 范围**

#### `compute-full-forwarded-for`

**作用**：是否追加而不是替换 `X-Forwarded-For`。

**值**：
- `"true"`: 追加到现有的 `X-Forwarded-For`（保留原始值）
- `"false"`: 替换现有的 `X-Forwarded-For`（默认）

**示例**：

**`compute-full-forwarded-for: "false"`**（替换）：
```http
# 客户端发送
X-Forwarded-For: 127.0.0.1

# Nginx 处理后（如果来自可信 IP）
X-Forwarded-For: 203.0.113.1  # 替换为真实 IP
```

**`compute-full-forwarded-for: "true"`**（追加）：
```http
# 客户端发送
X-Forwarded-For: 127.0.0.1

# Nginx 处理后（如果来自可信 IP）
X-Forwarded-For: 127.0.0.1, 203.0.113.1  # 追加真实 IP
```

**安全影响**：
- ⚠️ **追加模式可能保留伪造的 IP**：如果后端只取第一个值，可能使用伪造的 IP
- ✅ **替换模式更安全**：完全替换为真实 IP

#### `real-ip-header`

**作用**：指定用于设置真实 IP 的 header 名称。

**默认值**：`"X-Forwarded-For"`

**可选值**：
- `"X-Forwarded-For"`: 使用 `X-Forwarded-For` 头
- `"X-Real-IP"`: 使用 `X-Real-IP` 头
- 自定义 header 名称

**安全影响**：
- ⚠️ **如果使用 `X-Forwarded-For` 且配置不当，可能被伪造**
- ✅ **使用 `X-Real-IP` 相对更安全**（但需要正确配置 `set-real-ip-from`）

#### `real-ip-recursive`

**作用**：是否递归查找真实 IP（在 IP 链中查找）。

**值**：
- `"true"`: 递归查找（在 IP 链中查找第一个不在 `set-real-ip-from` 中的 IP）
- `"false"`: 不递归查找（默认）

**示例**：

**`real-ip-recursive: "false"`**：
```http
# 如果 X-Forwarded-For: 10.0.0.1, 203.0.113.1
# 且 set-real-ip-from: 10.0.0.0/8
# 结果：使用 10.0.0.1（第一个 IP，即使它在可信范围内）
```

**`real-ip-recursive: "true"`**：
```http
# 如果 X-Forwarded-For: 10.0.0.1, 203.0.113.1
# 且 set-real-ip-from: 10.0.0.0/8
# 结果：使用 203.0.113.1（第一个不在可信范围内的 IP）
```

**安全影响**：
- ✅ **递归模式更安全**：可以正确处理多层代理
- ⚠️ **但需要正确配置 `set-real-ip-from`**

### 1.4 安全配置策略

#### 策略 1: 最小配置（最安全，但可能不适用）

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  # 不设置 use-forwarded-headers（默认 false）
  # 不使用 forwarded headers
```

**适用场景**：
- 不需要真实客户端 IP
- 或者使用其他方式获取客户端 IP（如 Proxy Protocol）

**优点**：
- ✅ 最安全
- ✅ 不会信任任何 forwarded headers

**缺点**：
- ⚠️ 后端无法获取真实客户端 IP

#### 策略 2: 使用 `set-real-ip-from`（推荐）

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "10.0.0.0/8"  # 只信任内网 IP
  real-ip-header: "X-Forwarded-For"
  compute-full-forwarded-for: "false"  # 替换而不是追加
  real-ip-recursive: "true"  # 递归查找真实 IP
```

**适用场景**：
- 需要真实客户端 IP
- 部署在负载均衡器后面

**优点**：
- ✅ 只信任特定 IP 范围
- ✅ 替换模式更安全
- ✅ 递归查找可以正确处理多层代理

**配置要点**：
1. **`set-real-ip-from` 必须配置**：只包含上游代理的 IP 范围
2. **不要使用 `0.0.0.0/0`**：这会信任所有来源
3. **使用替换模式**：`compute-full-forwarded-for: "false"`

#### 策略 3: 使用 Proxy Protocol（最安全，如果支持）

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-proxy-protocol: "true"
  proxy-real-ip-cidr: "10.0.0.0/8"  # 可信的 Proxy Protocol 来源
```

**适用场景**：
- 使用支持 Proxy Protocol 的负载均衡器（如 AWS ALB、GCP LB）
- 需要最安全的配置

**优点**：
- ✅ 比 `X-Forwarded-For` 更安全
- ✅ 无法被客户端伪造
- ✅ 由连接层提供，不是 HTTP 头

**缺点**：
- ⚠️ 需要负载均衡器支持 Proxy Protocol
- ⚠️ 配置相对复杂

### 1.5 常见错误配置

#### 错误 1: 只设置 `use-forwarded-headers: "true"`

```yaml
# ❌ 不安全的配置
use-forwarded-headers: "true"
# 没有 set-real-ip-from
```

**问题**：
- 🔴 会信任所有来源的 `X-Forwarded-For`
- 🔴 攻击者可以伪造任何 IP 地址

#### 错误 2: `set-real-ip-from` 范围过宽

```yaml
# ❌ 不安全的配置
use-forwarded-headers: "true"
set-real-ip-from: "0.0.0.0/0"  # 信任所有来源
```

**问题**：
- 🔴 等同于没有配置 `set-real-ip-from`
- 🔴 攻击者可以伪造任何 IP 地址

#### 错误 3: 使用追加模式且后端取第一个值

```yaml
# ⚠️ 可能不安全的配置
use-forwarded-headers: "true"
set-real-ip-from: "10.0.0.0/8"
compute-full-forwarded-for: "true"  # 追加模式
```

**问题**：
- ⚠️ 如果后端只取 `X-Forwarded-For` 的第一个值，可能使用伪造的 IP
- ⚠️ 应该使用替换模式或确保后端正确处理 IP 链

---

## 2. HAProxy

### 2.1 核心配置机制

HAProxy 通过 `option forwardfor` 和相关选项来配置 forwarded headers 的处理。

#### 基础配置

```haproxy
global
    # 全局配置

defaults
    # 默认配置
    option forwardfor  # 启用 forwarded headers 处理
    option forwardfor except 10.0.0.0/8  # 可信 IP 范围
    option forwardfor header X-Forwarded-For  # 自定义 header 名称
```

#### Frontend 配置

```haproxy
frontend web
    bind *:80
    option forwardfor
    option forwardfor except 10.0.0.0/8
    option forwardfor except 192.168.0.0/16
    default_backend servers
```

### 2.2 默认行为分析

#### 默认配置（未设置 `option forwardfor`）

```haproxy
defaults
    # 没有 option forwardfor
```

**行为**：
- ✅ **默认安全**：不处理 forwarded headers
- ✅ **不会设置或信任 `X-Forwarded-For`**
- ⚠️ **但如果后端需要真实客户端 IP，需要配置**

#### 启用 `option forwardfor` 但未设置 `except`

```haproxy
defaults
    option forwardfor  # ❌ 没有 except 配置
```

**行为**：
- 🔴 **不安全**：会信任所有来源的 `X-Forwarded-For`
- 🔴 **会追加客户端的 `X-Forwarded-For` 到请求中**
- 🔴 **攻击者可以伪造 IP 地址**

### 2.3 关键配置项详解

#### `option forwardfor`

**作用**：启用 forwarded headers 处理，会在请求中添加 `X-Forwarded-For` 头。

**默认行为**：
- 追加客户端的 IP 地址到 `X-Forwarded-For` 头
- 如果请求中已有 `X-Forwarded-For`，会追加而不是替换

**安全影响**：
- ⚠️ **必须配合 `except` 使用**：否则会信任所有来源
- ⚠️ **默认追加模式**：可能保留伪造的 IP

#### `option forwardfor except`

**作用**：指定可信的 IP 范围，来自这些 IP 的请求不会添加 `X-Forwarded-For`。

**格式**：CIDR 格式，可以多次使用

**示例**：
```haproxy
option forwardfor except 10.0.0.0/8
option forwardfor except 192.168.0.0/16
```

**安全影响**：
- ✅ **关键安全配置**：必须配置才能安全使用 forwarded headers
- ⚠️ **逻辑是"除了这些 IP"**：来自这些 IP 的请求不会添加 `X-Forwarded-For`
- ⚠️ **如果范围过宽**，可能不安全

**注意**：`except` 的逻辑可能有些反直觉：
- 来自 `except` 列表中的 IP 的请求：**不会**添加 `X-Forwarded-For`
- 来自 `except` 列表外的 IP 的请求：**会**添加 `X-Forwarded-For`

**实际使用**：
```haproxy
# 如果上游代理在 10.0.0.0/8 范围内
# 来自上游代理的请求不会添加 X-Forwarded-For
# 来自客户端的请求会添加 X-Forwarded-For
option forwardfor except 10.0.0.0/8
```

#### `option forwardfor header`

**作用**：自定义 forwarded-for header 的名称。

**默认值**：`X-Forwarded-For`

**示例**：
```haproxy
option forwardfor header X-Real-IP
```

**安全影响**：
- ⚠️ **如果使用自定义名称，需要确保后端也使用相同的名称**
- ✅ **使用 `X-Real-IP` 相对更安全**（但需要正确配置 `except`）

### 2.4 安全配置策略

#### 策略 1: 最小配置（最安全，但可能不适用）

```haproxy
defaults
    # 不设置 option forwardfor
    # 不使用 forwarded headers
```

**适用场景**：
- 不需要真实客户端 IP
- 或者使用其他方式获取客户端 IP（如 Proxy Protocol）

**优点**：
- ✅ 最安全
- ✅ 不会设置或信任 forwarded headers

**缺点**：
- ⚠️ 后端无法获取真实客户端 IP

#### 策略 2: 使用 `except`（推荐）

```haproxy
defaults
    option forwardfor
    option forwardfor except 10.0.0.0/8  # 上游代理的 IP 范围
    option forwardfor except 192.168.0.0/16
```

**适用场景**：
- 需要真实客户端 IP
- 部署在负载均衡器后面

**配置要点**：
1. **`except` 必须配置**：只包含上游代理的 IP 范围
2. **不要使用 `0.0.0.0/0`**：这会信任所有来源
3. **理解 `except` 的逻辑**：来自这些 IP 的请求不会添加 `X-Forwarded-For`

**工作原理**：
```
客户端 (203.0.113.1) → 负载均衡器 (10.0.0.1) → HAProxy → 后端

# 在 HAProxy 处：
# - 来自 10.0.0.1 的请求：不会添加 X-Forwarded-For（因为 10.0.0.1 在 except 列表中）
# - 来自 203.0.113.1 的请求：会添加 X-Forwarded-For: 203.0.113.1
```

#### 策略 3: 手动设置 Header（更精确控制）

```haproxy
frontend web
    bind *:80
    
    # 定义可信的 IP 范围
    acl trusted src 10.0.0.0/8
    acl trusted src 192.168.0.0/16
    
    # 只对来自可信 IP 的请求设置 X-Forwarded-For
    http-request set-header X-Forwarded-For %[src] if trusted
    
    # 或者使用 X-Real-IP
    http-request set-header X-Real-IP %[src] if trusted
    
    default_backend servers
```

**适用场景**：
- 需要更精确的控制
- 需要自定义 header 名称

**优点**：
- ✅ 更精确的控制
- ✅ 可以自定义 header 名称
- ✅ 可以添加额外的逻辑

**缺点**：
- ⚠️ 配置相对复杂

#### 策略 4: 使用 Proxy Protocol（最安全，如果支持）

```haproxy
global
    # 启用 Proxy Protocol
    # 需要在 bind 中指定

frontend web
    bind *:80 accept-proxy  # 接受 Proxy Protocol
    default_backend servers
```

**适用场景**：
- 使用支持 Proxy Protocol 的负载均衡器
- 需要最安全的配置

**优点**：
- ✅ 比 `X-Forwarded-For` 更安全
- ✅ 无法被客户端伪造
- ✅ 由连接层提供

**缺点**：
- ⚠️ 需要负载均衡器支持 Proxy Protocol
- ⚠️ 配置相对复杂

### 2.5 常见错误配置

#### 错误 1: 只设置 `option forwardfor`

```haproxy
# ❌ 不安全的配置
defaults
    option forwardfor
    # 没有 except 配置
```

**问题**：
- 🔴 会信任所有来源的 `X-Forwarded-For`
- 🔴 会追加客户端的 IP，可能保留伪造的 IP

#### 错误 2: `except` 范围过宽

```haproxy
# ❌ 不安全的配置
defaults
    option forwardfor
    option forwardfor except 0.0.0.0/0  # 信任所有来源
```

**问题**：
- 🔴 等同于没有配置 `except`
- 🔴 攻击者可以伪造任何 IP 地址

#### 错误 3: 误解 `except` 的逻辑

```haproxy
# ⚠️ 可能不安全的配置
defaults
    option forwardfor
    option forwardfor except 203.0.113.0/24  # 误解：以为这是信任的 IP
```

**问题**：
- ⚠️ `except` 的意思是"除了这些 IP"
- ⚠️ 来自这些 IP 的请求**不会**添加 `X-Forwarded-For`
- ⚠️ 应该配置上游代理的 IP 范围，而不是客户端的 IP 范围

---

## 3. 对比总结

### 3.1 配置对比表

| 特性 | Ingress Nginx | HAProxy |
|------|---------------|---------|
| **默认行为** | 不使用 forwarded headers（安全） | 不使用 forwarded headers（安全） |
| **启用配置** | `use-forwarded-headers: "true"` | `option forwardfor` |
| **可信 IP 配置** | `set-real-ip-from` | `option forwardfor except` |
| **默认模式** | 替换（如果配置正确） | 追加 |
| **逻辑** | 只信任来自可信 IP 的 forwarded headers | 来自可信 IP 的请求不添加 forwarded headers |
| **Proxy Protocol 支持** | ✅ 支持 | ✅ 原生支持 |

### 3.2 安全配置对比

#### Ingress Nginx（安全配置）

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "10.0.0.0/8"  # 上游代理的 IP 范围
  real-ip-header: "X-Forwarded-For"
  compute-full-forwarded-for: "false"  # 替换模式
  real-ip-recursive: "true"
```

#### HAProxy（安全配置）

```haproxy
defaults
    option forwardfor
    option forwardfor except 10.0.0.0/8  # 上游代理的 IP 范围
    option forwardfor header X-Forwarded-For
```

### 3.3 关键差异

#### 差异 1: 逻辑方向

- **Ingress Nginx**: `set-real-ip-from` = "只信任来自这些 IP 的 forwarded headers"
- **HAProxy**: `except` = "来自这些 IP 的请求不添加 forwarded headers"

**结果**：两者逻辑相反，但效果类似。

#### 差异 2: 默认模式

- **Ingress Nginx**: 默认替换模式（如果配置正确）
- **HAProxy**: 默认追加模式

**影响**：
- Ingress Nginx 的替换模式更安全
- HAProxy 的追加模式可能保留伪造的 IP

#### 差异 3: 配置复杂度

- **Ingress Nginx**: 需要理解多个配置项的关系
- **HAProxy**: 配置相对简单，但 `except` 逻辑可能反直觉

---

## 4. 最佳实践总结

### 4.1 通用原则

1. **永远不要信任所有来源**：
   - Ingress Nginx: 必须配置 `set-real-ip-from`
   - HAProxy: 必须配置 `except`

2. **只信任上游代理的 IP 范围**：
   - 不要使用 `0.0.0.0/0`
   - 只包含已知的代理 IP

3. **使用替换模式（如果可能）**：
   - Ingress Nginx: `compute-full-forwarded-for: "false"`
   - HAProxy: 考虑手动设置 header

4. **优先使用 Proxy Protocol（如果支持）**：
   - 比 `X-Forwarded-For` 更安全
   - 无法被客户端伪造

### 4.2 检测方法

#### Ingress Nginx

```bash
# 检查 ConfigMap
kubectl get configmap nginx-configuration -n ingress-nginx -o yaml

# 检查是否有不安全的配置
# ❌ use-forwarded-headers: "true" 且没有 set-real-ip-from
# ❌ set-real-ip-from: "0.0.0.0/0"
```

#### HAProxy

```bash
# 检查配置文件
grep -E "option forwardfor" /etc/haproxy/haproxy.cfg

# 检查是否有不安全的配置
# ❌ option forwardfor 且没有 except
# ❌ option forwardfor except 0.0.0.0/0
```

### 4.3 修复建议

#### Ingress Nginx

```yaml
# 修复：添加 set-real-ip-from
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "10.0.0.0/8"  # ✅ 添加可信 IP 范围
  compute-full-forwarded-for: "false"  # ✅ 使用替换模式
```

#### HAProxy

```haproxy
# 修复：添加 except
defaults
    option forwardfor
    option forwardfor except 10.0.0.0/8  # ✅ 添加可信 IP 范围
```

---

## 5. 实际部署建议

### 5.1 标准云架构

```
Internet → Cloud Load Balancer → Ingress Nginx/HAProxy → Application
```

**配置要点**：
1. **Load Balancer 层**：自动覆盖 `X-Forwarded-For`（提供第一层防护）
2. **Ingress Nginx/HAProxy 层**：配置可信 IP 范围（提供第二层防护）
3. **Application 层**：使用 `X-Real-IP` 或 `Remote-Addr`（提供第三层防护）

### 5.2 多层防护配置

#### Ingress Nginx

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "10.0.0.0/8"  # Load Balancer 的 IP 范围
  compute-full-forwarded-for: "false"
  real-ip-recursive: "true"
```

#### HAProxy

```haproxy
defaults
    option forwardfor
    option forwardfor except 10.0.0.0/8  # Load Balancer 的 IP 范围
```

### 5.3 后端应用配置

```python
# 后端应用应该使用 X-Real-IP 或 Remote-Addr
def get_client_ip(request):
    # ✅ 优先使用 X-Real-IP（由反向代理设置）
    if 'X-Real-IP' in request.headers:
        return request.headers['X-Real-IP']
    
    # ✅ 使用 Remote-Addr（最可靠）
    return request.remote_addr
    
    # ❌ 不要直接使用 X-Forwarded-For
```

---

## 6. 总结

### 6.1 关键规则

1. **Ingress Nginx**：
   - 默认不使用 forwarded headers（安全）
   - 启用时必须配置 `set-real-ip-from`
   - 使用替换模式更安全

2. **HAProxy**：
   - 默认不使用 forwarded headers（安全）
   - 启用时必须配置 `except`
   - 理解 `except` 的逻辑（"除了这些 IP"）

### 6.2 安全策略

1. **最小权限原则**：只信任必要的 IP 范围
2. **防御深度**：多层防护，不依赖单一层
3. **默认安全**：默认不使用 forwarded headers
4. **优先使用 Proxy Protocol**：如果负载均衡器支持

### 6.3 检测和修复

1. **检测**：检查配置文件中是否有不安全的配置
2. **修复**：添加可信 IP 范围配置
3. **验证**：测试配置是否正确工作

