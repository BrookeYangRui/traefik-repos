"""
Traefik Configuration Filter
Traefik 配置过滤器
"""


class TraefikConfigFilter:
    """Traefik 配置过滤器"""
    
    FILTERS = [
        {
            'name': 'forwardedHeaders.insecure (YAML)',
            'keyword': 'forwardedHeaders',
            'regex': r'forwardedHeaders.*insecure.*true',
            'risk_level': 'high',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'traefik'
        },
        {
            'name': 'forwardedHeaders.insecure (TOML)',
            'keyword': 'forwardedHeaders',
            'regex': r'forwardedHeaders.*insecure.*=.*true',
            'risk_level': 'high',
            'file_extensions': ['.toml'],
            'proxy_type': 'traefik'
        },
        {
            'name': 'trustForwardHeader (YAML)',
            'keyword': 'trustForwardHeader',
            'regex': r'trustForwardHeader.*true',
            'risk_level': 'medium',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'traefik'
        },
        {
            'name': 'trustForwardHeader (TOML)',
            'keyword': 'trustForwardHeader',
            'regex': r'trustForwardHeader.*=.*true',
            'risk_level': 'medium',
            'file_extensions': ['.toml'],
            'proxy_type': 'traefik'
        },
        {
            'name': 'traefik docker-compose',
            'keyword': 'traefik',
            'regex': r'traefik.*forwardedHeaders',
            'risk_level': 'medium',
            'file_extensions': ['.yml', '.yaml'],
            'proxy_type': 'traefik'
        }
    ]
    
    SEARCH_KEYWORDS = [
        'forwardedHeaders',
        'trustForwardHeader',
        'traefik'
    ]
    
    @staticmethod
    def get_filters():
        """获取所有过滤器"""
        return TraefikConfigFilter.FILTERS
    
    @staticmethod
    def get_search_keywords():
        """获取搜索关键词"""
        return TraefikConfigFilter.SEARCH_KEYWORDS
    
    @staticmethod
    def get_proxy_type():
        """获取代理类型"""
        return 'traefik'

