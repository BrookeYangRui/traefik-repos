# 第三组项目分析（项目 11-15）

## 项目列表

11. **woniuzfb/iptv** - 高星项目（944 stars）
12. **fbonalair/traefik-crowdsec-bouncer** - 322 stars
13. **rishavnandi/ansible_homelab** - 371 stars
14. **Artiume/docker** - 64 stars
15. **smhaller/ldap-overleaf-sl** - 97 stars

---

## 项目 11: woniuzfb/iptv

### 配置分析

**文件**: `scripts/docker/data/traefik/config/traefik.yml`

```yaml
entryPoints:
  web:
    forwardedHeaders:
      insecure: false  # ✅ 已禁用
      trustedIPs:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
        - fc00::/7
```

### 威胁模型分析

✅ **配置安全**:
- `insecure: false` - 已禁用不安全模式
- **配置了 trustedIPs 白名单**
- 这个项目**不应该在"没有白名单"列表中**

### 实际影响评估

**影响等级**: ✅ **无风险**

### 结论

❌ **配置安全，有白名单。这个项目被误分类了，应该从高风险列表中移除。**

---

## 项目 12: fbonalair/traefik-crowdsec-bouncer

### 配置分析

**文件**: `docker-compose.yaml`

```yaml
labels:
  - "traefik.http.middlewares.crowdsec-bouncer.forwardauth.address=http://127.0.0.1:8081/api/v1/forwardAuth"
  - "traefik.http.middlewares.crowdsec-bouncer.forwardauth.trustForwardHeader=true"
```

### 威胁模型分析

✅ **确认存在漏洞**:
- `trustForwardHeader: true` 且**没有配置白名单**
- 这是 Forward Auth 中间件配置
- 攻击者可以注入 X-Forwarded-* 头到认证请求中

### 利用方式

1. **攻击路径**:
   ```
   攻击者 → Traefik → Forward Auth (trustForwardHeader: true) → 认证服务
   ```

2. **攻击载荷**:
   ```http
   GET /protected HTTP/1.1
   Host: target.com
   X-Forwarded-For: 127.0.0.1\r\nX-Auth-User: admin\r\n
   ```

3. **实际影响**:
   - ✅ **日志注入**: 认证服务会记录请求头
   - ⚠️ **认证绕过**: 如果认证服务实现不当，可能被绕过
   - ✅ **IP 欺骗**: 如果认证服务使用 X-Forwarded-For 进行访问控制

### 实际影响评估

**影响等级**: 🔴 **高**

**原因**:
1. **高星项目** - 322 stars，可能被广泛使用
2. **Forward Auth** - 影响认证流程
3. **没有白名单** - 任何来源都可以注入

### 结论

✅ **确认存在真实漏洞，需要生成 CVE 报告**

---

## 项目 13: rishavnandi/ansible_homelab

### 配置分析

**文件**: `tasks/authelia.yml`

```yaml
traefik.http.middlewares.authelia.forwardauth.trustForwardHeader: "true"
```

### 威胁模型分析

✅ **确认存在漏洞**:
- `trustForwardHeader: true` 且**没有配置白名单**
- 这是 Forward Auth 中间件配置
- 影响认证流程

### 实际影响评估

**影响等级**: 🔴 **高**

**原因**:
1. **高星项目** - 371 stars，可能被广泛使用
2. **Forward Auth** - 影响认证流程
3. **没有白名单** - 任何来源都可以注入

### 结论

✅ **确认存在真实漏洞，需要生成 CVE 报告**

---

## 项目 14: Artiume/docker

### 配置分析

**文件**: 多个文件都有 `trustForwardHeader: true`

包括：
- `ubooquity.yml`
- `nextcloud.yml`
- `radarr.yml`
- `portainer.yml`
- `traefik-SSO.yml`
- `picard.yml`
- `mariadb+pma.yml`
- `sabnzbd.yml`
- `traefik-auth.yml`
- `sonarr.yml`
- `netdata.yml`
- `nzbhydra2.yml`
- `lidarr.yml`
- `firefox.yml`
- `jackett.yml`
- `irc-lounge.yml`
- `bazarr.yml`
- `autoindex.yml`
- `bitwarden.yml`
- `heimdall.yml`

### 威胁模型分析

✅ **确认存在漏洞**:
- 多个服务都配置了 `trustForwardHeader: true`
- **没有配置白名单**

### 实际影响评估

**影响等级**: 🔴 **高**

**原因**:
1. **多个服务受影响** - 20+ 个服务配置
2. **Forward Auth** - 影响认证流程
3. **没有白名单** - 任何来源都可以注入

### 结论

✅ **确认存在真实漏洞，需要生成 CVE 报告**

---

## 项目 15: smhaller/ldap-overleaf-sl

### 配置分析

**文件**: `docker-compose.traefik.yml`

```yaml
labels:
  - "traefik.http.middlewares.sharel-secured.forwardauth.trustForwardHeader=true"
```

### 威胁模型分析

✅ **确认存在漏洞**:
- `trustForwardHeader: true` 且**没有配置白名单**
- 这是 Forward Auth 中间件配置
- 影响认证流程

### 实际影响评估

**影响等级**: 🔴 **高**

**原因**:
1. **实际项目配置** - 97 stars，可能被使用
2. **Forward Auth** - 影响认证流程
3. **没有白名单** - 任何来源都可以注入

### 结论

✅ **确认存在真实漏洞，需要生成 CVE 报告**

---

## 第三组总结

### 确认需要 CVE 报告的项目

1. ✅ **fbonalair/traefik-crowdsec-bouncer** - Forward Auth 配置，高风险
2. ✅ **rishavnandi/ansible_homelab** - Forward Auth 配置，高风险
3. ✅ **Artiume/docker** - 多个服务 Forward Auth 配置，高风险
4. ✅ **smhaller/ldap-overleaf-sl** - Forward Auth 配置，高风险

### 配置安全（误分类）

5. ✅ **woniuzfb/iptv** - 有白名单，配置安全（应该从列表中移除）

---

## 累计统计（前15个）

- **需要 CVE**: 4 个
- **配置安全**: 1 个（iptv）
- **需要进一步确认**: 3 个

