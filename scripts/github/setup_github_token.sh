#!/bin/bash
# 设置 GitHub token 的辅助脚本

set -e

TOKEN_FILE=".github_token"

echo "=========================================="
echo "GitHub Token 设置工具"
echo "=========================================="
echo ""

# 如果提供了 token 作为参数
if [ -n "$1" ]; then
    TOKEN="$1"
else
    # 如果已经存在 token 文件
    if [ -f "$TOKEN_FILE" ]; then
        echo "当前 token 文件已存在"
        read -p "是否要更新？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "取消操作"
            exit 0
        fi
    fi
    
    # 提示输入 token
    read -sp "请输入 GitHub token: " TOKEN
    echo
fi

# 保存 token 到文件
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo ""
echo "✓ Token 已保存到 $TOKEN_FILE"
echo "✓ 文件权限已设置为 600 (仅所有者可读)"
echo ""
echo "现在可以直接运行:"
echo "  ./github_scan.sh"
echo "  ./github_search_direct.sh"
echo "  python3 github_search_traefik.py"
echo ""

# 验证 token
if [ -n "$TOKEN" ]; then
    echo "验证 token..."
    RESPONSE=$(curl -s -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user" 2>&1)
    
    if echo "$RESPONSE" | grep -q '"login"'; then
        USERNAME=$(echo "$RESPONSE" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
        echo "✓ Token 有效，用户: $USERNAME"
    else
        echo "⚠️  Token 验证失败，请检查 token 是否正确"
    fi
fi

