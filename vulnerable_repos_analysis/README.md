# 高风险项目分析目录

本目录包含所有**没有白名单**的高风险 Traefik 配置项目。

## 项目列表

这些项目都设置了 `insecure: true` 或 `trustForwardHeader: true`，但**没有配置 trustedIPs 白名单**，存在实际安全风险。

### 最高优先级项目

1. **hmcts/cnp-flux-config** - 英国司法部配置
2. **Azure-Samples/netai-chat-with-your-data** - Azure 官方示例
3. **woniuzfb/iptv** - 944 stars，高活跃度

### 高星项目

- tomMoulard/fail2ban (253 stars)
- CVJoint/traefik2 (223 stars)
- SitecorePowerShell/Console (114 stars)
- fbonalair/traefik-crowdsec-bouncer (322 stars)
- rishavnandi/ansible_homelab (371 stars)
- cloudnativeapp/charts (417 stars)

### 白名单范围过宽

- hhftechnology/middleware-manager (0.0.0.0/0 - 等同于没有白名单)

## 分析重点

对于每个项目，重点关注：

1. **配置文件位置**
   - 查找 Traefik 配置文件
   - 检查 `forwardedHeaders.insecure` 或 `trustForwardHeader` 设置
   - 确认是否真的没有白名单

2. **实际使用情况**
   - 检查是否在生产环境使用
   - 查看部署文档
   - 检查 CI/CD 配置

3. **潜在影响**
   - 评估实际风险
   - 检查后端服务是否使用 X-Forwarded-For
   - 评估日志注入风险

## 快速查找配置文件

```bash
# 查找所有 Traefik 配置文件
find . -name "*.yml" -o -name "*.yaml" -o -name "*.toml" | xargs grep -l "traefik\|forwardedHeaders\|trustForwardHeader"

# 查找 insecure: true 配置
find . -name "*.yml" -o -name "*.yaml" | xargs grep -l "insecure.*true"

# 查找 trustForwardHeader: true 配置
find . -name "*.yml" -o -name "*.yaml" | xargs grep -l "trustForwardHeader.*true"
```

## 注意事项

1. 这些项目都是公开的 GitHub 仓库
2. 仅用于安全研究和分析
3. 遵循负责任的披露流程
4. 不要进行未授权的测试

