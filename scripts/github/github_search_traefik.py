#!/usr/bin/env python3
"""
GitHub 搜索工具 - 查找存在潜在风险的 Traefik 配置
需要: pip install pygithub
"""

import os
import sys
import json
from datetime import datetime

try:
    from github import Github
except ImportError:
    print("错误: 需要安装 pygithub")
    print("安装: pip install pygithub")
    sys.exit(1)

def search_github_configs(token=None):
    """搜索 GitHub 上的 Traefik 不安全配置"""
    
    if not token:
        # 首先尝试从环境变量读取
        token = os.getenv('GITHUB_TOKEN')
        
        # 如果环境变量没有，尝试从文件读取
        if not token:
            # 尝试多个可能的位置
            possible_paths = [
                os.path.join(os.path.dirname(__file__), '../../config/.github_token'),
                os.path.join(os.path.dirname(__file__), '.github_token'),
                '.github_token',
                os.path.expanduser('~/.github_token')
            ]
            token_file = None
            for path in possible_paths:
                if os.path.exists(path):
                    token_file = path
                    break
            
            if token_file:
                try:
                    with open(token_file, 'r') as f:
                        token = f.read().strip()
                except Exception as e:
                    print(f"警告: 无法读取 token 文件: {e}")
        
        if not token:
            print("错误: 需要 GitHub token")
            print("设置方法:")
            print("  1. 设置环境变量: export GITHUB_TOKEN=your_token")
            print("  2. 创建 .github_token 文件: echo 'your_token' > .github_token")
            print("  3. 作为参数传递: python3 github_search_traefik.py <token>")
            return
    
    g = Github(token)
    
    print("=" * 50)
    print("GitHub Traefik 配置搜索")
    print("=" * 50)
    print()
    
    # 搜索查询列表
    searches = [
        {
            "name": "forwardedHeaders.insecure: true (YAML)",
            "query": "forwardedHeaders insecure true language:yaml",
            "file_extensions": [".yml", ".yaml"]
        },
        {
            "name": "forwardedHeaders.insecure: true (TOML)",
            "query": "forwardedHeaders insecure true language:toml",
            "file_extensions": [".toml"]
        },
        {
            "name": "trustForwardHeader: true",
            "query": "trustForwardHeader true language:yaml",
            "file_extensions": [".yml", ".yaml"]
        },
        {
            "name": "Traefik docker-compose with forwardedHeaders",
            "query": "traefik docker-compose forwardedHeaders",
            "file_extensions": [".yml", ".yaml"]
        }
    ]
    
    results = []
    
    for search in searches:
        print(f"搜索: {search['name']}")
        print("-" * 50)
        
        try:
            # GitHub API 限制: 每分钟 30 次请求（认证用户）
            code_results = g.search_code(
                query=search['query'],
                sort='indexed',
                order='desc'
            )
            
            count = 0
            for item in code_results[:20]:  # 限制前 20 个结果
                # 检查文件扩展名
                if any(item.name.endswith(ext) for ext in search['file_extensions']):
                    result = {
                        "repository": item.repository.full_name,
                        "file": item.path,
                        "url": item.html_url,
                        "search_type": search['name']
                    }
                    results.append(result)
                    
                    print(f"  {count + 1}. {item.repository.full_name}/{item.path}")
                    print(f"     URL: {item.html_url}")
                    count += 1
                    
                    if count >= 10:  # 每个搜索最多 10 个结果
                        break
            
            print(f"  找到 {count} 个结果")
            print()
            
        except Exception as e:
            print(f"  错误: {e}")
            print()
    
    # 保存结果
    if results:
        output_file = f"traefik_github_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"结果已保存到: {output_file}")
        print(f"总共找到 {len(results)} 个潜在风险配置")
    else:
        print("未找到结果")
    
    return results

def analyze_results(results_file):
    """分析搜索结果"""
    with open(results_file, 'r') as f:
        results = json.load(f)
    
    print("=" * 50)
    print("结果分析")
    print("=" * 50)
    print()
    
    # 按仓库分组
    repos = {}
    for result in results:
        repo = result['repository']
        if repo not in repos:
            repos[repo] = []
        repos[repo].append(result)
    
    print(f"涉及 {len(repos)} 个仓库:")
    for repo, files in sorted(repos.items(), key=lambda x: len(x[1]), reverse=True):
        print(f"  {repo}: {len(files)} 个文件")
    
    print()
    print("按风险类型分类:")
    risk_types = {}
    for result in results:
        risk_type = result['search_type']
        if risk_type not in risk_types:
            risk_types[risk_type] = 0
        risk_types[risk_type] += 1
    
    for risk_type, count in sorted(risk_types.items(), key=lambda x: x[1], reverse=True):
        print(f"  {risk_type}: {count}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        token = sys.argv[1]
    else:
        token = None
    
    results = search_github_configs(token)
    
    if results and len(sys.argv) > 2 and sys.argv[2] == "--analyze":
        # 查找最新的结果文件
        import glob
        files = glob.glob("traefik_github_results_*.json")
        if files:
            latest = max(files, key=os.path.getctime)
            analyze_results(latest)


