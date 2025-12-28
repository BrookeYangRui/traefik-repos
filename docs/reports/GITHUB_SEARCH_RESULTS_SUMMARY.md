# GitHub Traefik 配置搜索结果摘要

**搜索时间**: 2025-12-28  
**总结果数**: 36 个潜在风险配置

---

## 搜索结果分类

### 1. forwardedHeaders.insecure: true (YAML) - 10 个结果

**风险等级**: 🔴 **高风险**

这些配置允许未验证的 X-Forwarded-* 头，可能导致 Header Injection 漏洞。

#### 发现的配置：

1. **hmcts/cnp-flux-config** - Kubernetes 配置
   - 文件: `apps/admin/traefik2/ptl-intsvc/00.yaml`
   - URL: https://github.com/hmcts/cnp-flux-config/blob/ba4f16df154c6713ea65dff78bd49b85e815fc8d/apps/admin/traefik2/ptl-intsvc/00.yaml
   - **注意**: 这是英国司法部的配置（HMCTS）

2. **tomMoulard/fail2ban** - CI 配置
   - 文件: `ci/yamls/traefik-ci.yaml`
   - URL: https://github.com/tomMoulard/fail2ban/blob/428f6670b6fc0d9dbed2324eb98a5e6fcd4a3eb3/ci/yamls/traefik-ci.yaml

3. **SitecorePowerShell/Console** - Docker Compose
   - 文件: `docker-compose.yml`
   - URL: https://github.com/SitecorePowerShell/Console/blob/ee84b5c5cd45ba2522d6d4b75f417bdaa995f82a/docker-compose.yml

4. **CVJoint/traefik2** - Kubernetes 配置
   - 文件: `ymlfiles/traefik.yml`
   - URL: https://github.com/CVJoint/traefik2/blob/f316dec141f0d35a61b301970228e2da085cc973/ymlfiles/traefik.yml

5. **deepsquare-io/ClusterFactory** - Helm values
   - 文件: `core.example/traefik/values.yaml`
   - URL: https://github.com/deepsquare-io/ClusterFactory/blob/b1169087616aed50c7cb0a7ba434dc6223457691/core.example/traefik/values.yaml

6. **soulteary/traefik-v3-example** - Docker Compose
   - 文件: `docker-compose.acme.yml`
   - URL: https://github.com/soulteary/traefik-v3-example/blob/29063420a666358ffec1504ce3ccab282e9d416a/docker-compose.acme.yml

7. **Azure-Samples/netai-chat-with-your-data** - Azure 示例
   - 文件: `infra/uidocsmngr.tmpl.yaml`
   - URL: https://github.com/Azure-Samples/netai-chat-with-your-data/blob/0504aa6996b664441d152384ef85aab3bfe41651/infra/uidocsmngr.tmpl.yaml
   - **注意**: 这是 Azure 官方示例

8. **cloudnativeapp/charts** - Helm Chart
   - 文件: `curated/traefik/templates/configmap.yaml`
   - URL: https://github.com/cloudnativeapp/charts/blob/a12b40798671903ae8cf88d511d142bf19887800/curated/traefik/templates/configmap.yaml

9. **trajano/trajano-swarm** - Docker Swarm
   - 文件: `intranet.yml`
   - URL: https://github.com/trajano/trajano-swarm/blob/43baa650eddf963961430a8708c9aeece0cc71c2/intranet.yml

10. **Lepkem/traefik-plugin-response-code-override** - 插件配置
    - 文件: `config.yaml`
    - URL: https://github.com/Lepkem/traefik-plugin-response-code-override/blob/c270baa3a528c9114daef409a108993d7a923992/config.yaml

---

### 2. forwardedHeaders.insecure: true (TOML) - 10 个结果

**风险等级**: 🔴 **高风险**

#### 发现的配置：

1. **traefik/traefik** - 官方 Traefik 项目（示例文件）
   - 文件: `pkg/config/dynamic/fixtures/sample.toml`
   - URL: https://github.com/traefik/traefik/blob/6af404b9da0b6d933286fc2036dcdac3959003b8/pkg/config/dynamic/fixtures/sample.toml
   - **注意**: 这是 Traefik 官方项目的示例文件

2. **open-policy-agent/conftest** - 测试示例
   - 文件: `examples/traefik/traefik.toml`
   - URL: https://github.com/open-policy-agent/conftest/blob/08529c7174691f2c1d8325085e9489ce9e221cc2/examples/traefik/traefik.toml

3. **traefik/traefik** - 集成测试文件
   - 文件: `integration/fixtures/x_forwarded_for_fastproxy.toml`
   - URL: https://github.com/traefik/traefik/blob/6af404b9da0b6d933286fc2036dcdac3959003b8/integration/fixtures/x_forwarded_for_fastproxy.toml
   - **注意**: 这是 Traefik 官方测试文件

4. **vnghia/automation-lyoko-docker** - Docker 配置
   - 文件: `traefik/static.toml`
   - URL: https://github.com/vnghia/automation-lyoko-docker/blob/e499d0c43e9ce2afde6ad35ab930600e4f39bfc6/traefik/static.toml

5. **Grigorov-Georgi/midnightsun** - Docker 配置
   - 文件: `eDocker/ecart/traefik/traefik.toml`
   - URL: https://github.com/Grigorov-Georgi/midnightsun/blob/822953156824228e0f190d67a819156bd767a029/eDocker/ecart/traefik/traefik.toml

6. **jittering/traefik-kop** - 测试文件
   - 文件: `fixtures/sample.toml`
   - URL: https://github.com/jittering/traefik-kop/blob/f6bbd38b597e4343e5d274fcec8b7cd7b4c28e78/fixtures/sample.toml

7. **ilmoraunio/conjtest** - 测试示例
   - 文件: `examples/toml/traefik/traefik.toml`
   - URL: https://github.com/ilmoraunio/conjtest/blob/9bc86ecbc283c73ac9e30a551fdbe4a0248b4193/examples/toml/traefik/traefik.toml

8. **ambroisemaupate/docker-server-env** - 示例配置
   - 文件: `compose/traefik/traefik.sample.toml`
   - URL: https://github.com/ambroisemaupate/docker-server-env/blob/c291466284981fb6af264966f9dd956fcb5edf95/compose/traefik/traefik.sample.toml

9. **c445/traefik** - 集成测试
   - 文件: `integration/fixtures/simple_whitelist.toml`
   - URL: https://github.com/c445/traefik/blob/06df6017dfc4464b81106e22bd7fcc61de5c3786/integration/fixtures/simple_whitelist.toml

10. **yn-project/bright** - 文档示例
    - 文件: `tools/traefik/docs/content/reference/static-configuration/file.toml`
    - URL: https://github.com/yn-project/bright/blob/2595d5110e9fe18022b7f6db219fdd1e2a7ea806/tools/traefik/docs/content/reference/static-configuration/file.toml

---

### 3. trustForwardHeader: true - 10 个结果

**风险等级**: ⚠️ **中等风险**

这些配置在 Forward Auth 中信任转发头，可能导致 Header Injection。

#### 发现的配置：

1. **woniuzfb/iptv** - Docker Compose
   - 文件: `scripts/docker/docker-compose.yml`
   - URL: https://github.com/woniuzfb/iptv/blob/086a9b4c8036503ccdb4ea1857124a3b1de92f92/scripts/docker/docker-compose.yml

2. **cloudnativeapp/charts** - Helm Chart
   - 文件: `curated/traefik/values.yaml`
   - URL: https://github.com/cloudnativeapp/charts/blob/a12b40798671903ae8cf88d511d142bf19887800/curated/traefik/values.yaml

3. **fbonalair/traefik-crowdsec-bouncer** - Docker Compose
   - 文件: `docker-compose.yaml`
   - URL: https://github.com/fbonalair/traefik-crowdsec-bouncer/blob/a4d570e0df58944230d88db529a869812f304f14/docker-compose.yaml

4. **rishavnandi/ansible_homelab** - Ansible 配置
   - 文件: `tasks/authelia.yml`
   - URL: https://github.com/rishavnandi/ansible_homelab/blob/8f2a5469d7f6396ffc710b332c176b4f85e775d8/tasks/authelia.yml

5. **hhftechnology/middleware-manager** - 模板配置
   - 文件: `config/templates.yaml`
   - URL: https://github.com/hhftechnology/middleware-manager/blob/4c4258f78d3d3d02c88b4fb21e0793620f40948d/config/templates.yaml

6. **Artiume/docker** - Docker Compose
   - 文件: `ombi.yml`
   - URL: https://github.com/Artiume/docker/blob/3d9c39b383df64d271030061486951e10900cd7c/ombi.yml

7. **smhaller/ldap-overleaf-sl** - Docker Compose
   - 文件: `docker-compose.traefik.yml`
   - URL: https://github.com/smhaller/ldap-overleaf-sl/blob/0fd1a2765edf5bdffc1f8cc8b922f2e53f3dd3c3/docker-compose.traefik.yml

8. **traefikturkey/onramp** - Docker Compose
   - 文件: `services-available/authentik.yml`
   - URL: https://github.com/traefikturkey/onramp/blob/6ab73d2c04d9cf7f981f2a660242da4141fc61eb/services-available/authentik.yml

9. **denniszielke/container_demos** - Terraform 配置
   - 文件: `terraform/traefik.yaml`
   - URL: https://github.com/denniszielke/container_demos/blob/c71172d1bafe4f2f6e20602378116f8bf29f1062/terraform/traefik.yaml

10. **ovrclk/disco** - 配置
    - 文件: `layer1/traefik/config.yml`
    - URL: https://github.com/ovrclk/disco/blob/b8de6d1f57e66967a97c01f123c7005404602400/layer1/traefik/config.yml

---

### 4. Traefik docker-compose with forwardedHeaders - 6 个结果

这些是包含 forwardedHeaders 的 docker-compose 配置，需要进一步检查是否使用了不安全设置。

1. **msgbyte/tailchat** - Docker Compose
   - 文件: `docker-compose.yml`
   - URL: https://github.com/msgbyte/tailchat/blob/5a21d630e508c12f2474af28854b54fe06d5ac49/docker-compose.yml

2. **stevegroom/traefikGateway** - Docker Compose
   - 文件: `traefik/docker-compose.yaml`
   - URL: https://github.com/stevegroom/traefikGateway/blob/2d44a5e7bc3fc1d66c6c9cc253373af0d6cd5fb8/traefik/docker-compose.yaml

3. **TheBinaryNinja/tvapp2** - Traefik 配置
   - 文件: `examples/traefik/traefik.yml`
   - URL: https://github.com/TheBinaryNinja/tvapp2/blob/c5c2f741f0025ae0a248f450e6470318454d9939/examples/traefik/traefik.yml

4. **p-/PyroDocker** - Docker Compose
   - 文件: `compose/traefik/docker-traefik/docker-compose-t2-web.yml`
   - URL: https://github.com/p-/PyroDocker/blob/73b5e57693888628a4373a38de8ded7c09fd2b83/compose/traefik/docker-traefik/docker-compose-t2-web.yml

5. **demyxsh/code-server** - Docker Compose
   - 文件: `archive/tag-sage/docker-compose.yml`
   - URL: https://github.com/demyxsh/code-server/blob/b7ee127f8a58f78e0bc68ac9d5a10f00945af64f/archive/tag-sage/docker-compose.yml

6. **homebase-garage/igecloudsdev-drupal** - Docker Compose
   - 文件: `docker/docker-compose.nfs.yml`
   - URL: https://github.com/homebase-garage/igecloudsdev-drupal/blob/2ff6696f462a465bf89feba4526e19596261b86d/docker/docker-compose.nfs.yml

---

## 重要发现

### 高价值目标

1. **hmcts/cnp-flux-config** - 英国司法部配置
   - 这是政府机构的配置，值得关注
   - 可能在生产环境使用

2. **Azure-Samples/netai-chat-with-your-data** - Azure 官方示例
   - 这是 Microsoft Azure 的官方示例
   - 可能被很多用户复制使用

3. **traefik/traefik** - 官方 Traefik 项目
   - 这是 Traefik 官方项目的示例和测试文件
   - 虽然可能是测试文件，但可能被用户参考

### 配置类型分布

- **Kubernetes/Helm**: 约 30%
- **Docker Compose**: 约 40%
- **示例/测试文件**: 约 20%
- **其他**: 约 10%

---

## 下一步行动

1. **详细分析**: 检查每个配置文件，确认是否真的存在漏洞
2. **验证影响**: 评估这些配置是否在生产环境使用
3. **负责任披露**: 如果发现真实漏洞，遵循负责任披露流程
4. **扩展搜索**: 可以搜索更多变体和组合

---

## 统计信息

- **总结果数**: 36
- **高风险配置** (insecure: true): 20
- **中等风险配置** (trustForwardHeader: true): 10
- **需要进一步检查**: 6

---

**注意**: 这些结果需要进一步验证，某些可能是示例文件或测试配置，不一定在生产环境使用。

