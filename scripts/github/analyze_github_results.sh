#!/bin/bash
# 分析 GitHub 搜索结果

set -e

if [ -z "$1" ]; then
    echo "用法: $0 <results_directory>"
    echo "示例: $0 github_search_results_20250101_120000"
    exit 1
fi

RESULTS_DIR="$1"

if [ ! -d "$RESULTS_DIR" ]; then
    echo "错误: 目录不存在: $RESULTS_DIR"
    exit 1
fi

echo "=========================================="
echo "分析 GitHub 搜索结果"
echo "=========================================="
echo "目录: $RESULTS_DIR"
echo ""

if ! command -v jq > /dev/null 2>&1; then
    echo "错误: 需要 jq"
    exit 1
fi

# 收集所有结果
ALL_RESULTS=()
REPO_SET=()
declare -A REPO_FILES
declare -A RISK_TYPES

for json_file in "$RESULTS_DIR"/*.json; do
    if [ ! -f "$json_file" ]; then
        continue
    fi
    
    search_name=$(basename "$json_file" .json)
    
    # 解析 JSON
    while IFS='|' read -r repo path url stars; do
        ALL_RESULTS+=("$repo|$path|$url|$stars|$search_name")
        
        # 统计仓库
        if [[ ! " ${REPO_SET[@]} " =~ " ${repo} " ]]; then
            REPO_SET+=("$repo")
        fi
        
        if [ -z "${REPO_FILES[$repo]}" ]; then
            REPO_FILES[$repo]=1
        else
            REPO_FILES[$repo]=$((${REPO_FILES[$repo]} + 1))
        fi
        
        # 统计风险类型
        if [ -z "${RISK_TYPES[$search_name]}" ]; then
            RISK_TYPES[$search_name]=1
        else
            RISK_TYPES[$search_name]=$((${RISK_TYPES[$search_name]} + 1))
        fi
    done < <(jq -r '.items[] | "\(.repository.full_name)|\(.path)|\(.html_url)|\(.repository.stargazers_count // 0)"' "$json_file" 2>/dev/null)
done

echo "统计信息:"
echo "-----------------------------------"
echo "总结果数: ${#ALL_RESULTS[@]}"
echo "涉及仓库数: ${#REPO_SET[@]}"
echo ""

echo "按风险类型分类:"
echo "-----------------------------------"
for risk_type in "${!RISK_TYPES[@]}"; do
    echo "  $risk_type: ${RISK_TYPES[$risk_type]}"
done
echo ""

echo "最活跃的仓库（按文件数）:"
echo "-----------------------------------"
for repo in "${!REPO_FILES[@]}"; do
    echo "  $repo: ${REPO_FILES[$repo]} 个文件"
done | sort -t: -k2 -nr | head -10
echo ""

echo "高星仓库（可能更值得关注）:"
echo "-----------------------------------"
printf '%s\n' "${ALL_RESULTS[@]}" | sort -t'|' -k4 -nr | head -10 | while IFS='|' read -r repo path url stars type; do
    echo "  ⭐ $stars - $repo/$path"
    echo "    $url"
done
echo ""

# 生成详细报告
REPORT_FILE="$RESULTS_DIR/detailed_report.txt"
{
    echo "GitHub Traefik 配置搜索详细报告"
    echo "生成时间: $(date)"
    echo ""
    echo "=========================================="
    echo "所有发现的配置"
    echo "=========================================="
    echo ""
    
    for result in "${ALL_RESULTS[@]}"; do
        IFS='|' read -r repo path url stars type <<< "$result"
        echo "仓库: $repo"
        echo "文件: $path"
        echo "URL: $url"
        echo "星标: $stars"
        echo "类型: $type"
        echo "---"
    done
} > "$REPORT_FILE"

echo "详细报告已保存: $REPORT_FILE"
echo ""

