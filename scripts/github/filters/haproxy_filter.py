"""
HAProxy Configuration Filter
HAProxy 配置过滤器
"""

import re


class HAProxyConfigFilter:
    """HAProxy 配置过滤器"""
    
    FILTERS = [
        {
            'name': 'option forwardfor without except',
            'keyword': 'option forwardfor',
            'regex': r'option\s+forwardfor(?!\s+except)',
            'risk_level': 'high',
            'file_extensions': ['.cfg', '.conf', '.haproxy'],
            'proxy_type': 'haproxy',
            'requires_check': 'except'  # 需要检查是否有 except 配置
        },
        {
            'name': 'option forwardfor except too wide',
            'keyword': 'option forwardfor except',
            'regex': r'option\s+forwardfor\s+except\s+0\.0\.0\.0/0',
            'risk_level': 'high',
            'file_extensions': ['.cfg', '.conf', '.haproxy'],
            'proxy_type': 'haproxy'
        },
        {
            'name': 'option forwardfor except (needs verification)',
            'keyword': 'option forwardfor',
            'regex': r'option\s+forwardfor',
            'risk_level': 'medium',
            'file_extensions': ['.cfg', '.conf', '.haproxy'],
            'proxy_type': 'haproxy',
            'requires_check': 'except',
            'note': '需要检查 except 配置是否正确'
        },
        {
            'name': 'haproxy configuration',
            'keyword': 'haproxy',
            'regex': r'haproxy.*forwardfor',
            'risk_level': 'medium',
            'file_extensions': ['.cfg', '.conf', '.haproxy', '.yml', '.yaml'],
            'proxy_type': 'haproxy'
        }
    ]
    
    SEARCH_KEYWORDS = [
        'option forwardfor',
        'haproxy forwardfor',
        'haproxy configuration'
    ]
    
    @staticmethod
    def get_filters():
        """获取所有过滤器"""
        return HAProxyConfigFilter.FILTERS
    
    @staticmethod
    def get_search_keywords():
        """获取搜索关键词"""
        return HAProxyConfigFilter.SEARCH_KEYWORDS
    
    @staticmethod
    def get_proxy_type():
        """获取代理类型"""
        return 'haproxy'
    
    @staticmethod
    def check_has_trusted_ips(content):
        """检查是否有可信 IP 配置（except）"""
        # 检查是否有 except 配置，且不是 0.0.0.0/0
        has_except = bool(
            re.search(r'option\s+forwardfor\s+except', content, re.IGNORECASE) and
            not re.search(r'option\s+forwardfor\s+except\s+0\.0\.0\.0/0', content, re.IGNORECASE)
        )
        return has_except

