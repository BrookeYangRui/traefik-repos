# Filter 架构说明

## 概述

扫描器采用 Filter 架构设计，将不同反向代理的扫描逻辑分离到独立的 Filter 中，主扫描器逻辑保持不变。

## 架构图

```
┌─────────────────────────────────────────────────┐
│  ultra_fast_reverse_proxy_scanner.py           │
│  (主扫描器 - 通用逻辑)                          │
└─────────────────┬───────────────────────────────┘
                  │
                  │ 使用 FilterManager
                  │
┌─────────────────▼───────────────────────────────┐
│  FilterManager                                   │
│  - get_filter(proxy_type)                       │
│  - get_available_types()                         │
└─────────────────┬───────────────────────────────┘
                  │
        ┌─────────┼─────────┐
        │         │         │
┌───────▼───┐ ┌──▼──────┐ ┌▼────────┐
│ Traefik   │ │ Nginx   │ │ HAProxy │
│ Filter    │ │ Filter  │ │ Filter  │
└───────────┘ └─────────┘ └─────────┘
```

## Filter 接口规范

每个 Filter 必须实现以下接口：

```python
class XxxConfigFilter:
    FILTERS = [
        {
            'name': 'filter name',
            'keyword': 'search keyword',
            'regex': r'regex pattern',
            'risk_level': 'high|medium',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'xxx',
            # 可选字段
            'requires_check': 'trusted-ips',  # 需要检查的配置项
            'note': 'additional note'
        }
    ]
    
    SEARCH_KEYWORDS = ['keyword1', 'keyword2']
    
    @staticmethod
    def get_filters():
        """返回所有过滤器"""
        return XxxConfigFilter.FILTERS
    
    @staticmethod
    def get_search_keywords():
        """返回搜索关键词"""
        return XxxConfigFilter.SEARCH_KEYWORDS
    
    @staticmethod
    def get_proxy_type():
        """返回代理类型"""
        return 'xxx'
    
    @staticmethod
    def check_has_trusted_ips(content):
        """检查是否有可信 IP 配置（可选）"""
        # 返回 True/False
        pass
```

## Filter 详细说明

### 1. Traefik Filter

**文件**: `filters/traefik_filter.py`

**检测模式**:
- `forwardedHeaders.insecure: true` (YAML/TOML)
- `trustForwardHeader: true` (YAML/TOML)
- Traefik docker-compose 配置

**搜索关键词**:
- `forwardedHeaders`
- `trustForwardHeader`
- `traefik`

**可信 IP 检查**:
- 检查 `trustedIPs` 配置

### 2. Nginx Ingress Filter

**文件**: `filters/nginx_filter.py`

**检测模式**:
- `use-forwarded-headers: "true"` 且没有 `set-real-ip-from`
- `set-real-ip-from: "0.0.0.0/0"` (范围过宽)
- `compute-full-forwarded-for: "true"` (追加模式)

**搜索关键词**:
- `use-forwarded-headers`
- `set-real-ip-from`
- `ingress-nginx`
- `nginx ingress`

**可信 IP 检查**:
- 检查 `set-real-ip-from` 配置（且不是 `0.0.0.0/0`）

### 3. HAProxy Filter

**文件**: `filters/haproxy_filter.py`

**检测模式**:
- `option forwardfor` 且没有 `except`
- `option forwardfor except 0.0.0.0/0` (范围过宽)

**搜索关键词**:
- `option forwardfor`
- `haproxy forwardfor`
- `haproxy configuration`

**可信 IP 检查**:
- 检查 `option forwardfor except` 配置（且不是 `0.0.0.0/0`）

## 主扫描器逻辑

主扫描器 (`ultra_fast_reverse_proxy_scanner.py`) 的扫描逻辑保持不变：

1. **搜索阶段**: 使用 Filter 提供的搜索关键词搜索 GitHub 仓库
2. **克隆阶段**: 克隆匹配的仓库
3. **扫描阶段**: 使用 Filter 提供的过滤器扫描文件
4. **结果写入**: 记录匹配结果，包括代理类型信息

## 使用示例

### 扫描单个代理类型

```bash
# Traefik
python ultra_fast_reverse_proxy_scanner.py --proxy-type traefik

# Nginx Ingress
python ultra_fast_reverse_proxy_scanner.py --proxy-type nginx-ingress

# HAProxy
python ultra_fast_reverse_proxy_scanner.py --proxy-type haproxy
```

### 扫描所有代理类型

```bash
python ultra_fast_reverse_proxy_scanner.py --proxy-type all
```

## 扩展 Filter

### 添加新的 Filter

1. **创建 Filter 文件** (`filters/xxx_filter.py`):

```python
import re

class XxxConfigFilter:
    FILTERS = [
        {
            'name': 'xxx insecure config',
            'keyword': 'xxx',
            'regex': r'xxx.*insecure',
            'risk_level': 'high',
            'file_extensions': ['.conf'],
            'proxy_type': 'xxx'
        }
    ]
    
    SEARCH_KEYWORDS = ['xxx', 'xxx-config']
    
    @staticmethod
    def get_filters():
        return XxxConfigFilter.FILTERS
    
    @staticmethod
    def get_search_keywords():
        return XxxConfigFilter.SEARCH_KEYWORDS
    
    @staticmethod
    def get_proxy_type():
        return 'xxx'
    
    @staticmethod
    def check_has_trusted_ips(content):
        # 实现可信 IP 检查逻辑
        return bool(re.search(r'trusted-ips', content, re.IGNORECASE))
```

2. **在 `filters/__init__.py` 中注册**:

```python
from .xxx_filter import XxxConfigFilter

FILTER_REGISTRY = {
    # ... existing
    'xxx': XxxConfigFilter
}
```

3. **使用新 Filter**:

```bash
python ultra_fast_reverse_proxy_scanner.py --proxy-type xxx
```

## 优势

1. **模块化**: 每个代理类型的扫描逻辑独立
2. **可扩展**: 轻松添加新的代理类型支持
3. **可维护**: 修改某个代理类型的逻辑不影响其他
4. **代码复用**: 主扫描器逻辑保持不变
5. **类型安全**: 每个 Filter 都有明确的接口规范

## 输出格式

CSV 输出包含以下列：

- `Index`: 结果索引
- `Repository`: 仓库名称
- `URL`: 仓库 URL
- `Stars`: 星标数
- `Year`: 创建年份
- `Proxy Type`: 代理类型 (traefik/nginx-ingress/haproxy)
- `Vulnerability Type`: 漏洞类型
- `Risk Level`: 风险等级
- `Has TrustedIPs`: 是否配置了可信 IP
- `File Path`: 文件路径

