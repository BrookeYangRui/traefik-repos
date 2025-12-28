# 如何找到存在潜在风险的 Traefik 部署

## 概述

本文档提供多种方法来发现使用不安全配置的 Traefik 部署（约 15-25% 的部署）。

---

## 方法 1: 本地/内网扫描

### 使用提供的脚本

```bash
# 扫描本地和内网 Traefik 实例
./find_vulnerable_deployments.sh
```

**功能：**
- 检查本地 Traefik (localhost:8080)
- 扫描内网常见 IP 段
- 检查配置文件
- 验证配置是否存在风险

### 手动检查

```bash
# 检查本地 Traefik
curl http://localhost:8080/api/rawdata | jq '.entryPoints'

# 检查特定 IP
curl http://192.168.1.100:8080/api/rawdata | jq '.entryPoints[] | select(.forwardedHeaders.insecure == true)'
```

---

## 方法 2: GitHub 代码搜索

### 使用 GitHub Web 界面

**搜索查询：**

1. **搜索 insecure: true 配置**
   ```
   https://github.com/search?q=forwardedHeaders+insecure+true+language:yaml
   https://github.com/search?q=forwardedHeaders+insecure+true+language:toml
   ```

2. **搜索 trustForwardHeader: true**
   ```
   https://github.com/search?q=trustForwardHeader+true+language:yaml
   ```

3. **搜索 docker-compose 配置**
   ```
   https://github.com/search?q=traefik+docker-compose+forwardedHeaders
   ```

4. **搜索 Kubernetes 配置**
   ```
   https://github.com/search?q=traefik+kubernetes+forwardedHeaders
   ```

### 使用 GitHub API（自动化）

```bash
# 设置 GitHub token
export GITHUB_TOKEN=your_token

# 使用 Python 脚本
python3 github_search_traefik.py $GITHUB_TOKEN
```

**Python 脚本功能：**
- 自动搜索多个查询
- 保存结果到 JSON 文件
- 分析结果统计

### 使用 GitHub CLI

```bash
# 安装: brew install gh 或 apt install gh
gh auth login

# 搜索代码
gh search code "forwardedHeaders insecure true" --language yaml
gh search code "trustForwardHeader true" --language yaml
```

---

## 方法 3: 网络扫描服务

### Shodan

**设置：**
```bash
pip install shodan
shodan init YOUR_API_KEY
```

**搜索查询：**

1. **Traefik Dashboard**
   ```
   http.title:"Traefik" http.status:200
   ```

2. **Traefik API 端点**
   ```
   http.html:"api/rawdata" http.title:"Traefik"
   ```

3. **特定端口**
   ```
   port:8080 http.title:"Traefik"
   port:80 http.title:"Traefik"
   ```

**使用脚本：**
```bash
./shodan_search_traefik.sh
```

### Censys

**搜索查询：**

1. **Traefik 服务**
   ```
   services.http.response.headers.server: Traefik
   ```

2. **Traefik Dashboard**
   ```
   services.http.response.body: "Traefik" AND services.http.response.status_code: 200
   ```

---

## 方法 4: 公开配置仓库

### GitHub Gist

```
https://gist.github.com/search?q=traefik+forwardedHeaders
```

### Pastebin 类似服务

- pastebin.com
- paste.ubuntu.com
- 其他配置分享网站

**搜索关键词：**
- `traefik forwardedHeaders`
- `traefik docker-compose`
- `traefik insecure`

---

## 方法 5: Docker Hub / 容器镜像

### 搜索包含 Traefik 配置的镜像

```bash
# 搜索镜像
docker search traefik

# 检查镜像配置
docker pull <image>
docker inspect <image>
docker run --rm <image> cat /path/to/config.yml
```

### 检查 Docker Compose 文件

许多项目在 GitHub 上公开了 docker-compose.yml 文件，可以直接搜索。

---

## 方法 6: 验证发现的实例

### 使用验证脚本

```bash
# 验证单个实例
./verify_exposed_traefik.sh http://example.com:8080
```

**脚本功能：**
- 检查 API 可访问性
- 获取配置
- 检查不安全配置
- 测试 CRLF 注入

### 手动验证

```bash
# 1. 检查配置
curl http://target:8080/api/rawdata | jq '.entryPoints[] | select(.forwardedHeaders.insecure == true)'

# 2. 测试 CRLF 注入
curl -v -H "X-Forwarded-For: 127.0.0.1$(printf '\r\n')X-Injected: test" \
    http://target:8080/

# 3. 检查 Forward Auth
curl http://target:8080/api/rawdata | jq '.middlewares[] | select(.forwardAuth.trustForwardHeader == true)'
```

---

## 方法 7: 自动化扫描工具

### 创建扫描列表

```bash
# 从 Shodan 导出 IP 列表
shodan search --fields ip_str,port 'http.title:"Traefik"' > traefik_ips.txt

# 批量验证
while read ip port; do
    ./verify_exposed_traefik.sh "http://$ip:$port"
done < traefik_ips.txt
```

### 使用 nmap 扫描

```bash
# 扫描内网 Traefik
nmap -p 8080,80,443 --script http-title 192.168.1.0/24 | grep -i traefik

# 扫描特定服务
nmap -p 8080 --script http-enum 192.168.1.0/24
```

---

## 方法 8: 监控和持续扫描

### 设置定期扫描

```bash
# 创建 cron 任务
0 0 * * * /path/to/find_vulnerable_deployments.sh >> /var/log/traefik_scan.log 2>&1
```

### 使用监控工具

- **GreyNoise**: 监控暴露的服务
- **BinaryEdge**: 网络资产扫描
- **Censys**: 持续监控

---

## 搜索策略总结

### 高优先级搜索

1. **GitHub 代码搜索** - 最容易找到配置
2. **Shodan/Censys** - 找到暴露的实例
3. **内网扫描** - 发现内部部署

### 中优先级搜索

4. **Docker Hub** - 检查公开镜像
5. **配置分享网站** - Gist, Pastebin
6. **文档和教程** - 可能包含示例配置

### 验证步骤

1. **初步检查**: 使用脚本快速扫描
2. **详细验证**: 手动检查配置
3. **漏洞测试**: 使用测试脚本验证
4. **影响评估**: 评估实际风险

---

## 注意事项

### 法律和道德

1. **只扫描你有权限的系统**
2. **遵循负责任的披露流程**
3. **不要进行未授权的访问**
4. **遵守当地法律法规**

### 技术限制

1. **API 可能需要认证**
2. **某些配置可能被隐藏**
3. **需要验证实际影响**
4. **误报可能**

---

## 工具清单

已创建的工具：

1. **`find_vulnerable_deployments.sh`** - 综合扫描工具
2. **`github_search_traefik.py`** - GitHub API 搜索
3. **`shodan_search_traefik.sh`** - Shodan 搜索
4. **`verify_exposed_traefik.sh`** - 实例验证
5. **`check_traefik_config.sh`** - 配置检查

---

## 示例工作流

### 完整扫描流程

```bash
# 1. 本地扫描
./find_vulnerable_deployments.sh

# 2. GitHub 搜索
python3 github_search_traefik.py $GITHUB_TOKEN

# 3. Shodan 搜索（如果有 API key）
./shodan_search_traefik.sh

# 4. 验证发现的实例
for url in $(cat discovered_instances.txt); do
    ./verify_exposed_traefik.sh $url
done

# 5. 生成报告
# 汇总所有发现的结果
```

---

## 结果分析

### 统计信息

- 扫描的实例数
- 发现的风险配置数
- 按风险类型分类
- 按部署类型分类（Docker, K8s, 等）

### 报告格式

建议保存以下信息：
- 发现时间
- 目标 URL/IP
- 配置详情
- 风险等级
- 验证结果

---

**记住：** 始终遵循负责任的披露流程，不要进行未授权的访问或攻击。


