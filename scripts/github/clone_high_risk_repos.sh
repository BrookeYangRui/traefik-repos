#!/bin/bash
# 克隆没有白名单的高风险项目

# 不使用 set -e，允许继续执行即使某些命令失败

echo "=========================================="
echo "克隆高风险项目（没有白名单）"
echo "=========================================="
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_DIR="$SECURITY_DIR/vulnerable_repos_analysis"

# 创建目标目录
mkdir -p "$TARGET_DIR"

# 没有白名单的高风险项目列表（从白名单分析结果中提取）
REPOS=(
    "hmcts/cnp-flux-config"
    "tomMoulard/fail2ban"
    "SitecorePowerShell/Console"
    "deepsquare-io/ClusterFactory"
    "Azure-Samples/netai-chat-with-your-data"
    "cloudnativeapp/charts"
    "trajano/trajano-swarm"
    "Lepkem/traefik-plugin-response-code-override"
    "traefik/traefik"
    "vnghia/automation-lyoko-docker"
    "Grigorov-Georgi/midnightsun"
    "c445/traefik"
    "woniuzfb/iptv"
    "fbonalair/traefik-crowdsec-bouncer"
    "rishavnandi/ansible_homelab"
    "Artiume/docker"
    "smhaller/ldap-overleaf-sl"
    "traefikturkey/onramp"
    "msgbyte/tailchat"
    "stevegroom/traefikGateway"
    "homebase-garage/igecloudsdev-drupal"
    "hhftechnology/middleware-manager"  # 白名单范围过宽
)

echo "准备克隆 ${#REPOS[@]} 个高风险项目"
echo "目标目录: $TARGET_DIR"
echo ""

cd "$TARGET_DIR"

SUCCESS=0
FAILED=0
SKIPPED=0

for repo in "${REPOS[@]}"; do
    repo_name=$(basename "$repo")
    echo "[$((SUCCESS + FAILED + SKIPPED + 1))/${#REPOS[@]}] 克隆: $repo"
    
    # 检查是否已存在
    if [ -d "$repo_name" ]; then
        echo "  ⚠️  目录已存在，跳过"
        ((SKIPPED++))
        echo ""
        continue
    fi
    
    # 克隆仓库（使用 shallow clone 加快速度）
    if git clone "https://github.com/$repo.git" "$repo_name" --depth 1 --quiet 2>&1; then
        if [ -d "$repo_name" ]; then
            echo "  ✓ 克隆成功"
            ((SUCCESS++))
        else
            echo "  ✗ 克隆失败（目录不存在）"
            ((FAILED++))
        fi
    else
        # 即使命令失败，也检查目录是否存在（可能已经克隆成功）
        if [ -d "$repo_name" ]; then
            echo "  ✓ 克隆成功（可能有警告）"
            ((SUCCESS++))
        else
            echo "  ✗ 克隆失败"
            ((FAILED++))
        fi
    fi
    echo ""
    
    # 避免 GitHub API 限制
    sleep 1
done

echo "=========================================="
echo "克隆完成"
echo "=========================================="
echo "成功: $SUCCESS"
echo "失败: $FAILED"
echo "跳过: $SKIPPED"
echo ""
echo "项目位置: $TARGET_DIR"
echo ""
echo "已克隆的项目:"
ls -1 "$TARGET_DIR" 2>/dev/null | head -25
