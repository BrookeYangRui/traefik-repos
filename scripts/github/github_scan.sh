#!/bin/bash
# GitHub Traefik 配置扫描工具
# 支持两种模式：API 搜索（需要 token）和 Web 搜索（无需 token）

set -e

echo "=========================================="
echo "GitHub Traefik 配置扫描"
echo "=========================================="
echo ""

# 检查是否有 token
if [ -z "$GITHUB_TOKEN" ]; then
    # 尝试从多个可能的位置读取
    TOKEN_FILE=""
    for path in "config/.github_token" ".github_token" "../.github_token" "$HOME/.github_token"; do
        if [ -f "$path" ]; then
            TOKEN_FILE="$path"
            break
        fi
    done
    
    if [ -n "$TOKEN_FILE" ]; then
        GITHUB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
        export GITHUB_TOKEN
        echo "✓ 从 $TOKEN_FILE 文件读取 token"
        echo ""
    fi
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  未设置 GITHUB_TOKEN，将使用 Web 搜索模式"
    echo ""
    echo "提示: 如果有 GitHub token，可以设置:"
    echo "  1. 设置环境变量: export GITHUB_TOKEN=your_token"
    echo "  2. 创建 .github_token 文件: echo 'your_token' > .github_token"
    echo "  然后重新运行此脚本以使用 API 搜索（更快、更准确）"
    echo ""
    echo "获取 token: https://github.com/settings/tokens"
    echo "  权限: public_repo (只读)"
    echo ""
    echo "=========================================="
    echo ""
    
    # Web 搜索模式
    echo "GitHub Web 搜索链接（手动访问）:"
    echo "=========================================="
    echo ""
    
    echo "1. 搜索 forwardedHeaders.insecure: true (YAML)"
    echo "   https://github.com/search?q=forwardedHeaders+insecure+true+language:yaml&type=code"
    echo ""
    
    echo "2. 搜索 forwardedHeaders.insecure: true (TOML)"
    echo "   https://github.com/search?q=forwardedHeaders+insecure+true+language:toml&type=code"
    echo ""
    
    echo "3. 搜索 trustForwardHeader: true"
    echo "   https://github.com/search?q=trustForwardHeader+true+language:yaml&type=code"
    echo ""
    
    echo "4. 搜索 Traefik docker-compose with forwardedHeaders"
    echo "   https://github.com/search?q=traefik+docker-compose+forwardedHeaders+language:yaml&type=code"
    echo ""
    
    echo "5. 搜索 Traefik Kubernetes with forwardedHeaders"
    echo "   https://github.com/search?q=traefik+kubernetes+forwardedHeaders+insecure&type=code"
    echo ""
    
    echo "=========================================="
    echo "提示: 点击上述链接，在浏览器中打开搜索结果"
    echo "然后手动检查每个结果，查看配置详情"
    echo "=========================================="
    
    # 尝试打开浏览器（如果可能）
    if command -v xdg-open > /dev/null 2>&1; then
        echo ""
        read -p "是否在浏览器中打开第一个搜索链接？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            xdg-open "https://github.com/search?q=forwardedHeaders+insecure+true+language:yaml&type=code" 2>/dev/null || true
        fi
    fi
    
    exit 0
fi

# API 搜索模式
echo "✓ 检测到 GITHUB_TOKEN，使用 API 搜索模式"
echo ""

# 检查依赖
if ! command -v python3 > /dev/null 2>&1; then
    echo "错误: 需要 python3"
    exit 1
fi

# 运行 Python 脚本
echo "开始搜索..."
echo ""

python3 github_search_traefik.py "$GITHUB_TOKEN"

echo ""
echo "=========================================="
echo "扫描完成"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 查看生成的结果文件: traefik_github_results_*.json"
echo "2. 分析每个发现的配置"
echo "3. 验证是否真的存在漏洞"
echo ""

