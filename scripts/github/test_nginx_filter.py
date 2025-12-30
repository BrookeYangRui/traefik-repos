#!/usr/bin/env python3
"""
测试 Nginx Ingress Filter
验证 filter 逻辑是否正确
"""

import re
from filters.nginx_filter import NginxIngressConfigFilter

def test_nginx_filter():
    """测试 Nginx Ingress Filter"""
    
    print("=" * 60)
    print("测试 Nginx Ingress Filter")
    print("=" * 60)
    print()
    
    # 获取 filters
    filters = NginxIngressConfigFilter.get_filters()
    keywords = NginxIngressConfigFilter.get_search_keywords()
    
    print(f"✅ 加载了 {len(filters)} 个 filters")
    print(f"✅ 搜索关键词: {keywords}")
    print()
    
    # 测试用例
    test_cases = [
        {
            'name': '不安全的配置 - use-forwarded-headers 没有 set-real-ip-from',
            'content': '''
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
data:
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
''',
            'expected_match': True,
            'expected_has_trusted_ips': False
        },
        {
            'name': '安全的配置 - use-forwarded-headers 有 set-real-ip-from',
            'content': '''
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "10.0.0.0/8,192.168.0.0/16"
  real-ip-header: "X-Forwarded-For"
''',
            'expected_match': True,
            'expected_has_trusted_ips': True
        },
        {
            'name': '不安全的配置 - set-real-ip-from 范围过宽',
            'content': '''
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
data:
  use-forwarded-headers: "true"
  set-real-ip-from: "0.0.0.0/0"
''',
            'expected_match': True,
            'expected_has_trusted_ips': False  # 0.0.0.0/0 被视为不安全
        },
        {
            'name': 'Ingress 注解配置',
            'content': '''
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  annotations:
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
spec:
  rules:
    - host: example.com
''',
            'expected_match': True,
            'expected_has_trusted_ips': False
        },
        {
            'name': 'compute-full-forwarded-for 追加模式',
            'content': '''
apiVersion: v1
kind: ConfigMap
data:
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  set-real-ip-from: "10.0.0.0/8"
''',
            'expected_match': True,
            'expected_has_trusted_ips': True
        }
    ]
    
    print("测试用例:")
    print("-" * 60)
    
    all_passed = True
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n测试 {i}: {test_case['name']}")
        print("-" * 60)
        
        content = test_case['content']
        matches = []
        
        # 使用 filter 扫描内容
        for filter_item in filters:
            # 检查文件扩展名（这里假设是 YAML）
            if '.yml' not in filter_item['file_extensions'] and '.yaml' not in filter_item['file_extensions']:
                continue
            
            hit = False
            
            # Keyword matching
            if filter_item['keyword'] and filter_item['keyword'] in content:
                hit = True
            
            # Regex matching
            if filter_item.get('regex') and re.search(filter_item['regex'], content, re.IGNORECASE | re.MULTILINE):
                hit = True
            
            if hit:
                # 检查可信 IP
                has_trusted_ips = NginxIngressConfigFilter.check_has_trusted_ips(content)
                
                matches.append({
                    'filter_name': filter_item['name'],
                    'risk_level': filter_item['risk_level'],
                    'has_trusted_ips': has_trusted_ips
                })
        
        # 验证结果
        has_match = len(matches) > 0
        has_trusted_ips = any(m['has_trusted_ips'] for m in matches) if matches else False
        
        print(f"  匹配结果: {has_match} (期望: {test_case['expected_match']})")
        print(f"  可信 IP: {has_trusted_ips} (期望: {test_case['expected_has_trusted_ips']})")
        
        if matches:
            print(f"  匹配的 filters:")
            for m in matches:
                trusted_status = "✅ 有可信 IP" if m['has_trusted_ips'] else "❌ 无可信 IP"
                print(f"    - {m['filter_name']} ({m['risk_level']}) - {trusted_status}")
        
        # 验证
        if has_match == test_case['expected_match'] and has_trusted_ips == test_case['expected_has_trusted_ips']:
            print(f"  ✅ 测试通过")
        else:
            print(f"  ❌ 测试失败")
            all_passed = False
    
    print()
    print("=" * 60)
    if all_passed:
        print("✅ 所有测试通过！")
    else:
        print("❌ 部分测试失败")
    print("=" * 60)
    
    return all_passed

if __name__ == "__main__":
    test_nginx_filter()

