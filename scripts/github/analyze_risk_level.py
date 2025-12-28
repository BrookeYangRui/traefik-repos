#!/usr/bin/env python3
"""
分析 GitHub 搜索结果的风险等级和项目信息
"""

import json
import os
import sys
from datetime import datetime

try:
    from github import Github
except ImportError:
    print("错误: 需要安装 pygithub")
    print("安装: pip install pygithub")
    sys.exit(1)

def get_token():
    """获取 GitHub token"""
    token = os.getenv('GITHUB_TOKEN')
    if not token:
        # 尝试从文件读取
        possible_paths = [
            os.path.join(os.path.dirname(__file__), '../../config/.github_token'),
            os.path.join(os.path.dirname(__file__), '.github_token'),
            '.github_token',
        ]
        for path in possible_paths:
            if os.path.exists(path):
                with open(path, 'r') as f:
                    token = f.read().strip()
                    break
    return token

def analyze_repositories(results_file):
    """分析仓库的风险等级和项目信息"""
    
    token = get_token()
    if not token:
        print("错误: 需要 GitHub token")
        return
    
    g = Github(token)
    
    with open(results_file, 'r') as f:
        results = json.load(f)
    
    print("=" * 80)
    print("GitHub 搜索结果风险分析")
    print("=" * 80)
    print()
    
    # 按风险类型分类
    risk_categories = {
        "🔴 高风险": [],
        "⚠️  中等风险": [],
        "ℹ️  低风险/示例": []
    }
    
    analyzed_repos = {}
    
    for result in results:
        repo_name = result['repository']
        search_type = result['search_type']
        file_path = result['file']
        url = result['url']
        
        # 判断风险等级
        if "insecure: true" in search_type:
            risk_level = "🔴 高风险"
        elif "trustForwardHeader" in search_type:
            risk_level = "⚠️  中等风险"
        else:
            risk_level = "ℹ️  低风险/示例"
        
        # 检查是否是示例/测试文件
        if any(keyword in file_path.lower() for keyword in ['example', 'sample', 'test', 'fixture', 'demo', 'template']):
            risk_level = "ℹ️  低风险/示例"
        
        # 获取仓库信息
        if repo_name not in analyzed_repos:
            try:
                repo = g.get_repo(repo_name)
                analyzed_repos[repo_name] = {
                    'repo': repo,
                    'stars': repo.stargazers_count,
                    'forks': repo.forks_count,
                    'updated': repo.updated_at,
                    'is_archived': repo.archived,
                    'is_private': repo.private,
                    'language': repo.language,
                    'description': repo.description
                }
            except Exception as e:
                analyzed_repos[repo_name] = {
                    'error': str(e),
                    'stars': 0
                }
        
        repo_info = analyzed_repos[repo_name]
        
        risk_categories[risk_level].append({
            'repo': repo_name,
            'file': file_path,
            'url': url,
            'search_type': search_type,
            'stars': repo_info.get('stars', 0),
            'forks': repo_info.get('forks', 0),
            'updated': repo_info.get('updated'),
            'is_archived': repo_info.get('is_archived', False),
            'language': repo_info.get('language'),
            'description': repo_info.get('description', '')
        })
    
    # 输出分析结果
    for risk_level, items in risk_categories.items():
        if not items:
            continue
        
        print(f"\n{risk_level} ({len(items)} 个)")
        print("-" * 80)
        
        # 按 star 数排序
        items.sort(key=lambda x: x['stars'], reverse=True)
        
        for item in items:
            repo_name = item['repo']
            stars = item['stars']
            forks = item.get('forks', 0)
            updated = item.get('updated')
            is_archived = item.get('is_archived', False)
            language = item.get('language', 'N/A')
            
            # 判断是否真的有问题
            is_example = any(kw in item['file'].lower() for kw in ['example', 'sample', 'test', 'fixture', 'demo'])
            is_official = 'traefik/traefik' in repo_name
            
            status = ""
            if is_example:
                status = " [示例/测试文件]"
            elif is_official:
                status = " [官方项目]"
            elif is_archived:
                status = " [已归档]"
            
            print(f"\n📦 {repo_name}")
            print(f"   ⭐ Stars: {stars:,} | 🍴 Forks: {forks:,} | 📝 Language: {language}")
            if updated:
                print(f"   📅 最后更新: {updated.strftime('%Y-%m-%d')}")
            print(f"   📄 文件: {item['file']}")
            print(f"   🔗 URL: {item['url']}")
            print(f"   📊 风险类型: {item['search_type']}")
            if status:
                print(f"   ℹ️  {status}")
            
            # 评估实际风险
            if is_example or is_official:
                print(f"   ⚠️  评估: 可能是示例/测试文件，实际风险较低")
            elif stars > 100:
                print(f"   ⚠️  评估: 高星项目，可能在生产环境使用，需要关注")
            elif stars > 10:
                print(f"   ⚠️  评估: 中等活跃度项目，需要进一步验证")
            else:
                print(f"   ⚠️  评估: 低活跃度项目，可能是个人项目")
    
    # 统计信息
    print("\n" + "=" * 80)
    print("统计信息")
    print("=" * 80)
    
    total_stars = sum(item['stars'] for items in risk_categories.values() for item in items)
    high_star_repos = [item for items in risk_categories.values() for item in items if item['stars'] > 100]
    official_repos = [item for items in risk_categories.values() for item in items if 'traefik/traefik' in item['repo']]
    example_files = [item for items in risk_categories.values() for item in items if any(kw in item['file'].lower() for kw in ['example', 'sample', 'test', 'fixture'])]
    
    print(f"\n总项目数: {len(analyzed_repos)}")
    print(f"总 Star 数: {total_stars:,}")
    print(f"高星项目 (>100 stars): {len(high_star_repos)}")
    print(f"官方项目: {len(official_repos)}")
    print(f"示例/测试文件: {len(example_files)}")
    
    # 真正有风险的项目
    real_risk = [item for items in risk_categories["🔴 高风险"] + risk_categories["⚠️  中等风险"] 
                 for item in items 
                 if not any(kw in item['file'].lower() for kw in ['example', 'sample', 'test', 'fixture', 'demo'])
                 and 'traefik/traefik' not in item['repo']
                 and item['stars'] > 0]
    
    print(f"\n⚠️  真正需要关注的项目: {len(real_risk)}")
    print("   (排除示例文件、官方项目和 0 star 项目)")
    
    if real_risk:
        print("\n需要重点关注的项目:")
        for item in sorted(real_risk, key=lambda x: x['stars'], reverse=True)[:10]:
            print(f"  - {item['repo']} ({item['stars']} stars) - {item['file']}")

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
            print("用法: python3 analyze_risk_level.py <results_file.json>")
            sys.exit(1)
    else:
        results_file = sys.argv[1]
    
    analyze_repositories(results_file)

