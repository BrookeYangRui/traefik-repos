#!/usr/bin/env python3
"""
检查 GitHub 项目是否配置了 trustedIPs 白名单
即使设置了 insecure: true 或 trustForwardHeader: true，如果有白名单，风险会降低
"""

import json
import os
import sys
import re
import requests
from urllib.parse import quote

def get_raw_content_url(github_url):
    """将 GitHub URL 转换为 raw content URL"""
    # https://github.com/user/repo/blob/branch/path/file
    # -> https://raw.githubusercontent.com/user/repo/branch/path/file
    pattern = r'https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)'
    match = re.match(pattern, github_url)
    if match:
        user, repo, branch, path = match.groups()
        return f"https://raw.githubusercontent.com/{user}/{repo}/{branch}/{path}"
    return None

def check_config_content(raw_url):
    """检查配置文件内容，查找 trustedIPs 配置"""
    try:
        response = requests.get(raw_url, timeout=10)
        if response.status_code == 200:
            content = response.text
            return content
    except Exception as e:
        return None
    return None

def analyze_config(content, file_path):
    """分析配置内容，查找安全设置"""
    result = {
        'has_insecure': False,
        'has_trustForwardHeader': False,
        'has_trustedIPs': False,
        'trustedIPs_value': None,
        'is_wide_open': False,
        'risk_level': 'unknown'
    }
    
    content_lower = content.lower()
    
    # 检查 insecure
    if 'insecure' in content_lower and 'true' in content_lower:
        # 检查是否是 forwardedHeaders.insecure
        if 'forwardedheaders' in content_lower or 'forwarded_headers' in content_lower:
            result['has_insecure'] = True
    
    # 检查 trustForwardHeader
    if 'trustforwardheader' in content_lower and 'true' in content_lower:
        result['has_trustForwardHeader'] = True
    
    # 检查 trustedIPs
    # 匹配各种格式：trustedIPs, trustedIPs:, trustedIPs =, etc.
    trusted_ips_patterns = [
        r'trustedIPs\s*[:=]\s*\[(.*?)\]',
        r'trustedIPs\s*[:=]\s*(.*?)(?:\n|$)',
        r'trustedIPs:\s*(.*?)(?:\n|$)',
        r'trustedips\s*[:=]\s*\[(.*?)\]',
    ]
    
    for pattern in trusted_ips_patterns:
        match = re.search(pattern, content, re.IGNORECASE | re.MULTILINE | re.DOTALL)
        if match:
            result['has_trustedIPs'] = True
            ips_value = match.group(1).strip()
            result['trustedIPs_value'] = ips_value
            
            # 检查是否是过宽的范围
            if any(wide in ips_value.lower() for wide in ['0.0.0.0', '/0', '*', 'all', 'any']):
                result['is_wide_open'] = True
            break
    
    # 评估风险等级
    if result['has_insecure'] or result['has_trustForwardHeader']:
        if result['has_trustedIPs']:
            if result['is_wide_open']:
                result['risk_level'] = 'high'  # 有白名单但范围过宽
            else:
                result['risk_level'] = 'medium'  # 有白名单且范围合理
        else:
            result['risk_level'] = 'high'  # 没有白名单
    else:
        result['risk_level'] = 'low'
    
    return result

def analyze_repositories(results_file):
    """分析所有仓库的配置"""
    
    with open(results_file, 'r') as f:
        results = json.load(f)
    
    print("=" * 80)
    print("检查配置中的 trustedIPs 白名单")
    print("=" * 80)
    print()
    
    analyzed = []
    no_whitelist = []
    has_whitelist = []
    wide_open = []
    
    for i, result in enumerate(results, 1):
        repo_name = result['repository']
        file_path = result['file']
        url = result['url']
        search_type = result['search_type']
        
        print(f"[{i}/{len(results)}] 检查: {repo_name}/{file_path}")
        
        raw_url = get_raw_content_url(url)
        if not raw_url:
            print(f"  ⚠️  无法获取 raw URL")
            continue
        
        content = check_config_content(raw_url)
        if not content:
            print(f"  ⚠️  无法获取文件内容")
            continue
        
        analysis = analyze_config(content, file_path)
        analysis['repo'] = repo_name
        analysis['file'] = file_path
        analysis['url'] = url
        analysis['search_type'] = search_type
        analyzed.append(analysis)
        
        # 分类
        if analysis['has_insecure'] or analysis['has_trustForwardHeader']:
            if analysis['has_trustedIPs']:
                if analysis['is_wide_open']:
                    wide_open.append(analysis)
                    print(f"  ⚠️  有白名单但范围过宽: {analysis['trustedIPs_value']}")
                else:
                    has_whitelist.append(analysis)
                    print(f"  ✓ 有白名单: {analysis['trustedIPs_value'][:50]}...")
            else:
                no_whitelist.append(analysis)
                print(f"  🔴 没有白名单 - 高风险！")
        else:
            print(f"  ℹ️  未发现相关配置")
        
        print()
    
    # 统计
    print("=" * 80)
    print("统计结果")
    print("=" * 80)
    print()
    
    print(f"总检查数: {len(analyzed)}")
    print(f"🔴 没有白名单 (高风险): {len(no_whitelist)}")
    print(f"⚠️  有白名单但范围过宽: {len(wide_open)}")
    print(f"✓ 有白名单且范围合理 (中等风险): {len(has_whitelist)}")
    print()
    
    # 详细列表
    if no_whitelist:
        print("=" * 80)
        print("🔴 没有白名单的项目 (高风险)")
        print("=" * 80)
        for item in no_whitelist:
            print(f"\n📦 {item['repo']}")
            print(f"   文件: {item['file']}")
            print(f"   配置: {item['search_type']}")
            print(f"   URL: {item['url']}")
    
    if wide_open:
        print("\n" + "=" * 80)
        print("⚠️  有白名单但范围过宽的项目")
        print("=" * 80)
        for item in wide_open:
            print(f"\n📦 {item['repo']}")
            print(f"   文件: {item['file']}")
            print(f"   白名单: {item['trustedIPs_value']}")
            print(f"   URL: {item['url']}")
    
    if has_whitelist:
        print("\n" + "=" * 80)
        print("✓ 有白名单且范围合理的项目 (风险较低)")
        print("=" * 80)
        for item in has_whitelist:
            print(f"\n📦 {item['repo']}")
            print(f"   文件: {item['file']}")
            print(f"   白名单: {item['trustedIPs_value'][:100]}")
            print(f"   URL: {item['url']}")
    
    # 保存结果
    output = {
        'total': len(analyzed),
        'no_whitelist': len(no_whitelist),
        'wide_open': len(wide_open),
        'has_whitelist': len(has_whitelist),
        'details': {
            'no_whitelist': no_whitelist,
            'wide_open': wide_open,
            'has_whitelist': has_whitelist
        }
    }
    
    output_file = results_file.replace('.json', '_whitelist_analysis.json')
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\n结果已保存到: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # 查找最新的结果文件
        results_dir = os.path.join(os.path.dirname(__file__), '../../results')
        json_files = [f for f in os.listdir(results_dir) if f.startswith('traefik_github_results_') and f.endswith('.json')]
        if json_files:
            latest = max(json_files, key=lambda f: os.path.getctime(os.path.join(results_dir, f)))
            results_file = os.path.join(results_dir, latest)
            print(f"使用最新的结果文件: {latest}")
        else:
            print("错误: 未找到结果文件")
            print("用法: python3 check_trusted_ips.py <results_file.json>")
            sys.exit(1)
    else:
        results_file = sys.argv[1]
    
    analyze_repositories(results_file)

