"""
Reverse Proxy Configuration Filters
支持 Traefik, Ingress Nginx, HAProxy 的配置过滤器
"""

from .traefik_filter import TraefikConfigFilter
from .nginx_filter import NginxIngressConfigFilter
from .haproxy_filter import HAProxyConfigFilter


class FilterManager:
    """过滤器管理器"""
    
    FILTER_REGISTRY = {
        'traefik': TraefikConfigFilter,
        'nginx-ingress': NginxIngressConfigFilter,
        'haproxy': HAProxyConfigFilter,
        'all': None  # 特殊值，表示所有过滤器
    }
    
    @staticmethod
    def get_filter(proxy_type):
        """获取指定类型的过滤器"""
        if proxy_type == 'all':
            # 返回所有过滤器
            filters = []
            keywords = set()
            for key, filter_class in FilterManager.FILTER_REGISTRY.items():
                if key != 'all' and filter_class:
                    filters.extend(filter_class.get_filters())
                    keywords.update(filter_class.get_search_keywords())
            return filters, list(keywords)
        elif proxy_type in FilterManager.FILTER_REGISTRY:
            filter_class = FilterManager.FILTER_REGISTRY[proxy_type]
            if filter_class:
                return filter_class.get_filters(), filter_class.get_search_keywords()
        raise ValueError(f"Unknown proxy type: {proxy_type}")
    
    @staticmethod
    def get_available_types():
        """获取可用的代理类型"""
        return [k for k in FilterManager.FILTER_REGISTRY.keys() if k != 'all']


__all__ = [
    'TraefikConfigFilter',
    'NginxIngressConfigFilter',
    'HAProxyConfigFilter',
    'FilterManager'
]

