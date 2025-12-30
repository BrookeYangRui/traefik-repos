"""
Nginx Ingress Controller Configuration Filter
Nginx Ingress Controller 配置过滤器
"""

import re


class NginxIngressConfigFilter:
    """Nginx Ingress Controller 配置过滤器"""
    
    FILTERS = [
        {
            'name': 'use-forwarded-headers without set-real-ip-from (ConfigMap)',
            'keyword': 'use-forwarded-headers',
            'regex': r'use-forwarded-headers.*true',
            'risk_level': 'high',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'nginx-ingress',
            'requires_check': 'set-real-ip-from'  # 需要检查是否有 set-real-ip-from
        },
        {
            'name': 'use-forwarded-headers annotation',
            'keyword': 'use-forwarded-headers',
            'regex': r'nginx\.ingress\.kubernetes\.io/use-forwarded-headers.*true',
            'risk_level': 'high',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'nginx-ingress',
            'requires_check': 'set-real-ip-from'
        },
        {
            'name': 'set-real-ip-from too wide (0.0.0.0/0)',
            'keyword': 'set-real-ip-from',
            'regex': r'set-real-ip-from.*0\.0\.0\.0/0',
            'risk_level': 'high',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'nginx-ingress'
        },
        {
            'name': 'compute-full-forwarded-for (append mode)',
            'keyword': 'compute-full-forwarded-for',
            'regex': r'compute-full-forwarded-for.*true',
            'risk_level': 'medium',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'nginx-ingress',
            'note': '追加模式可能保留伪造的 IP'
        },
        {
            'name': 'nginx ingress configuration',
            'keyword': 'ingress-nginx',
            'regex': r'ingress-nginx.*use-forwarded-headers',
            'risk_level': 'medium',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'nginx-ingress'
        }
    ]
    
    SEARCH_KEYWORDS = [
        'use-forwarded-headers',
        'set-real-ip-from',
        'ingress-nginx',
        'nginx ingress'
    ]
    
    @staticmethod
    def get_filters():
        """获取所有过滤器"""
        return NginxIngressConfigFilter.FILTERS
    
    @staticmethod
    def get_search_keywords():
        """获取搜索关键词"""
        return NginxIngressConfigFilter.SEARCH_KEYWORDS
    
    @staticmethod
    def get_proxy_type():
        """获取代理类型"""
        return 'nginx-ingress'
    
    @staticmethod
    def check_has_trusted_ips(content):
        """检查是否有可信 IP 配置（set-real-ip-from）"""
        # 检查是否有 set-real-ip-from 配置
        has_set_real_ip_from = bool(
            re.search(r'set-real-ip-from', content, re.IGNORECASE) and
            not re.search(r'set-real-ip-from.*0\.0\.0\.0/0', content, re.IGNORECASE)
        )
        return has_set_real_ip_from

