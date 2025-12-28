#!/bin/bash
# GitHub 搜索脚本 - 使用 curl 和 GitHub API
# 不需要 Python 依赖，只需要 curl 和 jq

set -e

echo "=========================================="
echo "GitHub Traefik 配置搜索"
echo "=========================================="
echo ""

# 检查 GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "提示: 未设置 GITHUB_TOKEN"
    echo ""
    echo "选项 1: 使用 GitHub Web 搜索（无需 token）"
    echo "  访问以下链接进行搜索:"
    echo ""
    echo "  1. forwardedHeaders insecure true:"
    echo "     https://github.com/search?q=forwardedHeaders+insecure+true+language:yaml"
    echo ""
    echo "  2. trustForwardHeader true:"
    echo "     https://github.com/search?q=trustForwardHeader+true+language:yaml"
    echo ""
    echo "  3. Traefik docker-compose:"
    echo "     https://github.com/search?q=traefik+docker-compose+forwardedHeaders"
    echo ""
    echo "选项 2: 获取 GitHub token 后使用此脚本"
    echo "  1. 访问: https://github.com/settings/tokens"
    echo "  2. 创建 Personal Access Token (classic)"
    echo "  3. 设置权限: public_repo (只读)"
    echo "  4. 运行: export GITHUB_TOKEN=your_token"
    echo "  5. 再次运行此脚本"
    echo ""
    exit 0
fi

echo "使用 GitHub API 进行搜索..."
echo ""

# 创建结果目录
RESULTS_DIR="github_search_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# 搜索查询列表
declare -a SEARCHES=(
    "forwardedHeaders+insecure+true+language:yaml"
    "forwardedHeaders+insecure+true+language:toml"
    "trustForwardHeader+true+language:yaml"
    "traefik+docker-compose+forwardedHeaders+language:yaml"
    "traefik+kubernetes+forwardedHeaders+insecure"
)

declare -a SEARCH_NAMES=(
    "forwardedHeaders.insecure: true (YAML)"
    "forwardedHeaders.insecure: true (TOML)"
    "trustForwardHeader: true (YAML)"
    "Traefik docker-compose with forwardedHeaders"
    "Traefik Kubernetes with forwardedHeaders"
)

TOTAL_RESULTS=0

for i in "${!SEARCHES[@]}"; do
    SEARCH="${SEARCHES[$i]}"
    NAME="${SEARCH_NAMES[$i]}"
    
    echo "搜索: $NAME"
    echo "-----------------------------------"
    
    # URL 编码
    ENCODED_QUERY=$(echo "$SEARCH" | sed 's/+/%2B/g; s/:/%3A/g')
    
    # GitHub API 搜索
    API_URL="https://api.github.com/search/code?q=${ENCODED_QUERY}&per_page=10&sort=indexed&order=desc"
    
    RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_URL" 2>&1)
    
    # 检查错误
    if echo "$RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message')
        echo "  错误: $ERROR_MSG"
        echo ""
        continue
    fi
    
    # 解析结果
    COUNT=$(echo "$RESPONSE" | jq -r '.total_count // 0' 2>/dev/null || echo "0")
    
    if [ "$COUNT" = "0" ] || [ -z "$COUNT" ]; then
        echo "  未找到结果"
        echo ""
        continue
    fi
    
    echo "  找到 $COUNT 个结果（显示前 10 个）"
    echo ""
    
    # 提取结果
    echo "$RESPONSE" | jq -r '.items[] | "\(.repository.full_name)|\(.path)|\(.html_url)"' 2>/dev/null | while IFS='|' read -r repo path url; do
        echo "    - $repo/$path"
        echo "      $url"
        ((TOTAL_RESULTS++))
    done
    
    # 保存到文件
    OUTPUT_FILE="$RESULTS_DIR/${i}_$(echo "$NAME" | tr ' ' '_' | tr ':' '_').json"
    echo "$RESPONSE" > "$OUTPUT_FILE"
    
    echo ""
    
    # 避免速率限制（每分钟最多 30 次请求）
    sleep 2
done

echo "=========================================="
echo "搜索完成"
echo "=========================================="
echo "结果保存在: $RESULTS_DIR/"
echo "总共找到: $TOTAL_RESULTS 个结果"
echo ""
echo "查看结果:"
echo "  ls -la $RESULTS_DIR/"
echo "  cat $RESULTS_DIR/*.json | jq '.items[] | {repo: .repository.full_name, file: .path, url: .html_url}'"
echo ""

