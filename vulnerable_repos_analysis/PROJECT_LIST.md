# 高风险项目清单

## 克隆统计

- **总项目数**: 22 个
- **成功克隆**: 20 个
- **失败**: 0 个
- **跳过**: 2 个（已存在）

## 项目列表

### 🔴 最高优先级（必须关注）

1. **cnp-flux-config** (hmcts/cnp-flux-config)
   - ⭐ 32 stars
   - 风险: **英国司法部配置**
   - 文件: `apps/admin/traefik2/ptl-intsvc/00.yaml`
   - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

2. **netai-chat-with-your-data** (Azure-Samples/netai-chat-with-your-data)
   - ⭐ 52 stars
   - 风险: **Azure 官方示例**
   - 文件: `infra/uidocsmngr.tmpl.yaml`
   - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

3. **iptv** (woniuzfb/iptv)
   - ⭐ 944 stars（最高）
   - 风险: 高活跃度项目
   - 文件: `scripts/docker/docker-compose.yml`
   - 配置: `trustForwardHeader: true`，**没有白名单**

### ⭐ 高星项目（>100 stars）

4. **fail2ban** (tomMoulard/fail2ban)
   - ⭐ 253 stars
   - 文件: `ci/yamls/traefik-ci.yaml`
   - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

5. **Console** (SitecorePowerShell/Console)
   - ⭐ 114 stars
   - 文件: `docker-compose.yml`
   - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

6. **traefik-crowdsec-bouncer** (fbonalair/traefik-crowdsec-bouncer)
   - ⭐ 322 stars
   - 文件: `docker-compose.yaml`
   - 配置: `trustForwardHeader: true`，**没有白名单**

7. **ansible_homelab** (rishavnandi/ansible_homelab)
   - ⭐ 371 stars
   - 文件: `tasks/authelia.yml`
   - 配置: `trustForwardHeader: true`，**没有白名单**

8. **charts** (cloudnativeapp/charts)
   - ⭐ 417 stars
   - 文件: `curated/traefik/templates/configmap.yaml`
   - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

9. **tailchat** (msgbyte/tailchat)
   - ⭐ 3,491 stars（非常高）
   - 文件: `docker-compose.yml`
   - 配置: `forwardedHeaders`，**没有白名单**

### 中等活跃度项目

10. **ClusterFactory** (deepsquare-io/ClusterFactory)
    - ⭐ 32 stars
    - 文件: `core.example/traefik/values.yaml`
    - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

11. **trajano-swarm** (trajano/trajano-swarm)
    - ⭐ 15 stars
    - 文件: `intranet.yml`
    - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

12. **traefik-plugin-response-code-override** (Lepkem/traefik-plugin-response-code-override)
    - ⭐ 9 stars
    - 文件: `config.yaml`
    - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

13. **docker** (Artiume/docker)
    - ⭐ 64 stars
    - 文件: `ombi.yml`
    - 配置: `trustForwardHeader: true`，**没有白名单**

14. **ldap-overleaf-sl** (smhaller/ldap-overleaf-sl)
    - ⭐ 97 stars
    - 文件: `docker-compose.traefik.yml`
    - 配置: `trustForwardHeader: true`，**没有白名单**

15. **onramp** (traefikturkey/onramp)
    - ⭐ 113 stars
    - 文件: `services-available/authentik.yml`
    - 配置: `trustForwardHeader: true`，**没有白名单**

16. **traefikGateway** (stevegroom/traefikGateway)
    - ⭐ 56 stars
    - 文件: `traefik/docker-compose.yaml`
    - 配置: `forwardedHeaders`，**没有白名单**

17. **igecloudsdev-drupal** (homebase-garage/igecloudsdev-drupal)
    - ⭐ 0 stars
    - 文件: `docker/docker-compose.nfs.yml`
    - 配置: `forwardedHeaders`，**没有白名单**

### 示例/测试文件（风险较低但仍需检查）

18. **traefik** (traefik/traefik)
    - ⭐ 60,780 stars（官方项目）
    - 文件: `integration/fixtures/x_forwarded_for_fastproxy.toml`
    - 配置: `forwardedHeaders.insecure: true`，**没有白名单**
    - **注意**: 这是官方测试文件，可能不是实际部署配置

19. **automation-lyoko-docker** (vnghia/automation-lyoko-docker)
    - ⭐ 1 star
    - 文件: `traefik/static.toml`
    - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

20. **midnightsun** (Grigorov-Georgi/midnightsun)
    - ⭐ 0 stars
    - 文件: `eDocker/ecart/traefik/traefik.toml`
    - 配置: `forwardedHeaders.insecure: true`，**没有白名单**

### ⚠️ 白名单范围过宽（等同于没有白名单）

21. **middleware-manager** (hhftechnology/middleware-manager)
    - ⭐ 410 stars
    - 文件: `config/templates.yaml`
    - 配置: `trustForwardHeader: true`，白名单: `0.0.0.0/0`（等同于没有）

## 分析建议

### 优先级 1: 立即分析
- cnp-flux-config（政府机构）
- netai-chat-with-your-data（Azure 官方示例）
- iptv（高星项目）
- tailchat（非常高星项目）

### 优先级 2: 详细分析
- fail2ban, traefik-crowdsec-bouncer, ansible_homelab, charts（高星项目）

### 优先级 3: 快速检查
- 其他中等活跃度项目

## 快速查找命令

```bash
# 查找所有 Traefik 配置文件
find . -type f \( -name "*.yml" -o -name "*.yaml" -o -name "*.toml" \) | xargs grep -l "traefik\|forwardedHeaders\|trustForwardHeader" 2>/dev/null

# 查找 insecure: true
find . -type f \( -name "*.yml" -o -name "*.yaml" \) | xargs grep -l "insecure.*true" 2>/dev/null

# 查找 trustForwardHeader: true
find . -type f \( -name "*.yml" -o -name "*.yaml" \) | xargs grep -l "trustForwardHeader.*true" 2>/dev/null

# 检查是否有 trustedIPs
find . -type f \( -name "*.yml" -o -name "*.yaml" -o -name "*.toml" \) | xargs grep -l "trustedIPs" 2>/dev/null
```

