#!/bin/bash
# GitHub 直接搜索 - 使用 curl 和 GitHub API
# 不需要 Python，只需要 curl 和 jq

set -e

echo "=========================================="
echo "GitHub Traefik 配置搜索（直接 API）"
echo "=========================================="
echo ""

# 检查依赖
if ! command -v curl > /dev/null 2>&1; then
    echo "错误: 需要 curl"
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    echo "警告: jq 未安装，某些功能可能不可用"
    echo "安装: sudo apt-get install jq 或 brew install jq"
    echo ""
fi

# 检查 token
if [ -z "$GITHUB_TOKEN" ]; then
    # 尝试从多个可能的位置读取
    TOKEN_FILE=""
    for path in "../../config/.github_token" ".github_token" "../../.github_token" "$HOME/.github_token"; do
        if [ -f "$path" ]; then
            TOKEN_FILE="$path"
            break
        fi
    done
    
    if [ -n "$TOKEN_FILE" ]; then
        GITHUB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
        export GITHUB_TOKEN
        echo "✓ 从 $TOKEN_FILE 文件读取 token"
    fi
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  未设置 GITHUB_TOKEN"
    echo ""
    echo "选项 1: 设置 token 后使用 API 搜索"
    echo "  export GITHUB_TOKEN=your_token"
    echo "  获取: https://github.com/settings/tokens"
    echo ""
    echo "选项 2: 创建 .github_token 文件"
    echo "  echo 'your_token' > .github_token"
    echo "  chmod 600 .github_token"
    echo ""
    echo "选项 3: 使用 Web 搜索（无需 token）"
    echo "  运行: ./github_scan.sh"
    echo ""
    exit 1
fi

# 创建结果目录
RESULTS_DIR="github_search_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

echo "结果将保存到: $RESULTS_DIR/"
echo ""

# 搜索查询
declare -A SEARCHES=(
    ["forwardedHeaders_insecure_yaml"]="forwardedHeaders+insecure+true+language:yaml"
    ["forwardedHeaders_insecure_toml"]="forwardedHeaders+insecure+true+language:toml"
    ["trustForwardHeader"]="trustForwardHeader+true+language:yaml"
    ["docker_compose"]="traefik+docker-compose+forwardedHeaders+language:yaml"
    ["kubernetes"]="traefik+kubernetes+forwardedHeaders+insecure"
)

TOTAL_FOUND=0
TOTAL_REPOS=0
declare -A REPO_COUNT

for search_name in "${!SEARCHES[@]}"; do
    query="${SEARCHES[$search_name]}"
    
    echo "搜索: $search_name"
    echo "查询: $query"
    echo "-----------------------------------"
    
    # URL 编码
    encoded_query=$(echo "$query" | sed 's/+/%2B/g; s/:/%3A/g; s/ /%20/g')
    
    # GitHub API 请求
    api_url="https://api.github.com/search/code?q=${encoded_query}&per_page=30&sort=indexed&order=desc"
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$api_url")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    # 检查 HTTP 状态
    if [ "$http_code" != "200" ]; then
        error_msg=$(echo "$body" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        echo "  错误 (HTTP $http_code): $error_msg"
        echo ""
        continue
    fi
    
    # 解析结果
    total_count=$(echo "$body" | jq -r '.total_count // 0' 2>/dev/null || echo "0")
    
    if [ "$total_count" = "0" ] || [ -z "$total_count" ]; then
        echo "  未找到结果"
        echo ""
        continue
    fi
    
    echo "  找到 $total_count 个结果"
    
    # 提取并显示结果
    count=0
    echo "$body" | jq -r '.items[] | "\(.repository.full_name)|\(.path)|\(.html_url)|\(.repository.stargazers_count // 0)"' 2>/dev/null | while IFS='|' read -r repo path url stars; do
        if [ $count -lt 10 ]; then
            echo "    $((count + 1)). $repo/$path (⭐ $stars)"
            echo "       $url"
            
            # 统计仓库
            if [ -z "${REPO_COUNT[$repo]}" ]; then
                REPO_COUNT[$repo]=1
                ((TOTAL_REPOS++))
            else
                REPO_COUNT[$repo]=$((${REPO_COUNT[$repo]} + 1))
            fi
        fi
        ((count++))
        ((TOTAL_FOUND++))
    done
    
    if [ "$total_count" -gt 10 ]; then
        echo "    ... 还有 $((total_count - 10)) 个结果"
    fi
    
    # 保存完整结果
    output_file="$RESULTS_DIR/${search_name}.json"
    echo "$body" > "$output_file"
    echo "  结果已保存: $output_file"
    echo ""
    
    # 避免速率限制
    sleep 2
done

# 生成摘要
echo "=========================================="
echo "搜索完成"
echo "=========================================="
echo "总共找到: $TOTAL_FOUND 个结果"
echo "涉及仓库: $TOTAL_REPOS 个"
echo "结果目录: $RESULTS_DIR/"
echo ""

# 保存摘要
{
    echo "GitHub Traefik 配置搜索摘要"
    echo "生成时间: $(date)"
    echo ""
    echo "总共找到: $TOTAL_FOUND 个结果"
    echo "涉及仓库: $TOTAL_REPOS 个"
    echo ""
    echo "按仓库统计:"
    for repo in "${!REPO_COUNT[@]}"; do
        echo "  $repo: ${REPO_COUNT[$repo]} 个文件"
    done
} > "$SUMMARY_FILE"

echo "摘要已保存: $SUMMARY_FILE"
echo ""
echo "查看详细结果:"
echo "  ls -la $RESULTS_DIR/"
echo "  cat $RESULTS_DIR/*.json | jq '.items[] | {repo: .repository.full_name, file: .path, url: .html_url}'"
echo ""

