# Reverse Proxy Configuration Scanner

## 概述

这是一个通用的反向代理配置扫描器，支持扫描 Traefik、Ingress Nginx Controller 和 HAProxy 的不安全配置。

## 架构设计

### Filter 架构

扫描器采用 Filter 架构，将不同反向代理的扫描逻辑分离到独立的 Filter 中：

```
filters/
├── __init__.py          # Filter 导出
├── traefik_filter.py    # Traefik 配置过滤器
├── nginx_filter.py      # Nginx Ingress 配置过滤器
└── haproxy_filter.py    # HAProxy 配置过滤器
```

### 主扫描器

`ultra_fast_reverse_proxy_scanner.py` 是通用的扫描器，可以：
- 使用不同的 Filter 扫描不同的反向代理
- 保持扫描逻辑不变
- 支持同时扫描多种反向代理（`--proxy-type all`）

## 使用方法

### 1. 扫描 Traefik

```bash
cd scripts/github
python ultra_fast_reverse_proxy_scanner.py --proxy-type traefik
```

### 2. 扫描 Nginx Ingress Controller

```bash
python ultra_fast_reverse_proxy_scanner.py --proxy-type nginx-ingress
```

### 3. 扫描 HAProxy

```bash
python ultra_fast_reverse_proxy_scanner.py --proxy-type haproxy
```

### 4. 扫描所有反向代理

```bash
python ultra_fast_reverse_proxy_scanner.py --proxy-type all
```

### 5. 自定义配置

```bash
python ultra_fast_reverse_proxy_scanner.py \
    --proxy-type traefik \
    --workers 32 \
    --config custom_config.json
```

## Filter 配置说明

### Traefik Filter

**检测的配置模式**：
- `forwardedHeaders.insecure: true` (YAML/TOML)
- `trustForwardHeader: true` (YAML/TOML)
- Traefik docker-compose 配置

**搜索关键词**：
- `forwardedHeaders`
- `trustForwardHeader`
- `traefik`

### Nginx Ingress Filter

**检测的配置模式**：
- `use-forwarded-headers: "true"` 且没有 `set-real-ip-from`
- `set-real-ip-from: "0.0.0.0/0"` (范围过宽)
- `compute-full-forwarded-for: "true"` (追加模式)

**搜索关键词**：
- `use-forwarded-headers`
- `set-real-ip-from`
- `ingress-nginx`
- `nginx ingress`

### HAProxy Filter

**检测的配置模式**：
- `option forwardfor` 且没有 `except`
- `option forwardfor except 0.0.0.0/0` (范围过宽)

**搜索关键词**：
- `option forwardfor`
- `haproxy forwardfor`
- `haproxy configuration`

## 输出文件

扫描结果保存在 `reverse_proxy_scan_results_{proxy_type}/` 目录中：

- `reverse_proxy_results_{proxy_type}_{timestamp}.csv` - CSV 格式结果
- `reverse_proxy_scanner_{proxy_type}.log` - 日志文件
- `progress.json` - 进度文件
- `stats.json` - 统计信息

## CSV 输出格式

| 列名 | 说明 |
|------|------|
| Index | 结果索引 |
| Repository | 仓库名称 |
| URL | 仓库 URL |
| Stars | 星标数 |
| Year | 创建年份 |
| Proxy Type | 代理类型 (traefik/nginx-ingress/haproxy) |
| Vulnerability Type | 漏洞类型 |
| Risk Level | 风险等级 (high/medium) |
| Has TrustedIPs | 是否配置了可信 IP |
| File Path | 文件路径 |

## 配置示例

### config.json

```json
{
  "concurrency": {
    "max_workers": 16,
    "clone_timeout": 300
  },
  "search": {
    "min_stars": 50,
    "time_window": {
      "start_date": "2015-01-01",
      "end_date": "now",
      "window_size_days": 30
    }
  },
  "logging": {
    "level": "INFO",
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "date_format": "%Y-%m-%d %H:%M:%S"
  }
}
```

## 环境变量

### .env 文件

```bash
# 单个 token
GITHUB_TOKEN=your_github_token_here

# 多个 token（逗号分隔）
GITHUB_TOKEN=token1,token2,token3

# 多个 token（换行分隔）
GITHUB_TOKEN=token1
token2
token3
```

## 扩展 Filter

### 添加新的 Filter

1. 在 `filters/` 目录创建新的 filter 文件，例如 `caddy_filter.py`：

```python
class CaddyConfigFilter:
    FILTERS = [
        {
            'name': 'caddy insecure config',
            'keyword': 'caddy',
            'regex': r'caddy.*insecure',
            'risk_level': 'high',
            'file_extensions': ['.json', '.caddy'],
            'proxy_type': 'caddy'
        }
    ]
    
    SEARCH_KEYWORDS = ['caddy', 'caddyfile']
    
    @staticmethod
    def get_filters():
        return CaddyConfigFilter.FILTERS
    
    @staticmethod
    def get_search_keywords():
        return CaddyConfigFilter.SEARCH_KEYWORDS
    
    @staticmethod
    def get_proxy_type():
        return 'caddy'
```

2. 在 `filters/__init__.py` 中注册：

```python
from .caddy_filter import CaddyConfigFilter

FILTER_REGISTRY = {
    # ... existing filters
    'caddy': CaddyConfigFilter
}
```

3. 在 `FilterManager.FILTER_REGISTRY` 中添加：

```python
FILTER_REGISTRY = {
    # ... existing
    'caddy': CaddyConfigFilter
}
```

## 与旧扫描器的兼容性

旧的 `ultra_fast_traefik_scanner.py` 仍然可用，但建议使用新的 `ultra_fast_reverse_proxy_scanner.py`：

```bash
# 旧方式（仍然支持）
python ultra_fast_traefik_scanner.py

# 新方式（推荐）
python ultra_fast_reverse_proxy_scanner.py --proxy-type traefik
```

## 性能优化

- 使用多线程并发处理
- 支持多 GitHub token 自动轮换
- 时间窗口搜索策略
- 增量扫描（支持断点续传）
- 自动清理临时文件

## 注意事项

1. **GitHub API 限制**：
   - 认证用户：每分钟 30 次请求
   - 建议使用多个 token 以提高扫描速度

2. **磁盘空间**：
   - 扫描会克隆仓库到临时目录
   - 确保有足够的磁盘空间

3. **网络带宽**：
   - 大量克隆操作会消耗网络带宽
   - 建议在带宽充足的环境运行

## 故障排除

### 问题 1: ImportError

```bash
# 确保在 scripts/github 目录下运行
cd scripts/github
python ultra_fast_reverse_proxy_scanner.py --proxy-type traefik
```

### 问题 2: GitHub API Rate Limit

```bash
# 使用多个 token
GITHUB_TOKEN=token1,token2,token3 python ultra_fast_reverse_proxy_scanner.py
```

### 问题 3: 内存不足

```bash
# 减少并发数
python ultra_fast_reverse_proxy_scanner.py --workers 8
```

