#!/bin/bash
# 验证暴露的 Traefik 实例是否存在漏洞
# 用法: ./verify_exposed_traefik.sh <url>

set -e

if [ -z "$1" ]; then
    echo "用法: $0 <traefik_url>"
    echo "示例: $0 http://example.com:8080"
    exit 1
fi

TRAEFIK_URL=$1
echo "=========================================="
echo "验证 Traefik 实例: $TRAEFIK_URL"
echo "=========================================="
echo ""

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VULNERABLE=0

# 检查 1: API 是否可访问
echo "检查 1: API 可访问性"
echo "-----------------------------------"
API_RESPONSE=$(curl -s --max-time 5 "$TRAEFIK_URL/api/rawdata" 2>&1 || echo "ERROR")

if echo "$API_RESPONSE" | grep -q "ERROR\|timeout\|refused"; then
    echo -e "${YELLOW}⚠️  API 不可访问（可能需要认证或未启用）${NC}"
    echo "尝试其他端点..."
    
    # 尝试 Dashboard
    DASHBOARD=$(curl -s --max-time 5 "$TRAEFIK_URL/dashboard/" 2>&1 || echo "ERROR")
    if echo "$DASHBOARD" | grep -qi "traefik"; then
        echo -e "${YELLOW}  Dashboard 可访问，但 API 需要认证${NC}"
    fi
    echo ""
    exit 0
else
    echo -e "${GREEN}✓ API 可访问${NC}"
    echo ""
fi

# 检查 2: 获取配置
echo "检查 2: 获取配置"
echo "-----------------------------------"
CONFIG=$(curl -s --max-time 5 "$TRAEFIK_URL/api/rawdata" 2>/dev/null || echo "{}")

if [ "$CONFIG" = "{}" ] || [ -z "$CONFIG" ]; then
    echo -e "${YELLOW}⚠️  无法获取配置${NC}"
    exit 0
fi

echo -e "${GREEN}✓ 成功获取配置${NC}"
echo ""

# 检查 3: forwardedHeaders.insecure
echo "检查 3: forwardedHeaders.insecure"
echo "-----------------------------------"
if echo "$CONFIG" | jq -e '.entryPoints[] | select(.forwardedHeaders.insecure == true)' > /dev/null 2>&1; then
    echo -e "${RED}🔴 发现高风险配置: forwardedHeaders.insecure = true${NC}"
    echo "$CONFIG" | jq '.entryPoints[] | select(.forwardedHeaders.insecure == true) | {name: .name, insecure: .forwardedHeaders.insecure}'
    VULNERABLE=1
else
    echo -e "${GREEN}✓ 未发现 insecure: true${NC}"
fi
echo ""

# 检查 4: 过宽的 trustedIPs
echo "检查 4: trustedIPs 配置"
echo "-----------------------------------"
TRUSTED_IPS=$(echo "$CONFIG" | jq -r '.entryPoints[] | select(.forwardedHeaders.trustedIPs != null) | .forwardedHeaders.trustedIPs[]' 2>/dev/null || echo "")

if [ -n "$TRUSTED_IPS" ]; then
    RISKY_IPS=0
    while IFS= read -r ip; do
        if [[ "$ip" == *"0.0.0.0"* ]] || [[ "$ip" == *"/0"* ]] || [[ "$ip" == *"*"* ]]; then
            echo -e "${YELLOW}⚠️  发现过宽的 trustedIPs: $ip${NC}"
            RISKY_IPS=1
        fi
    done <<< "$TRUSTED_IPS"
    
    if [ $RISKY_IPS -eq 0 ]; then
        echo -e "${GREEN}✓ trustedIPs 配置合理${NC}"
    else
        VULNERABLE=1
    fi
else
    echo -e "${GREEN}✓ 未配置 trustedIPs（使用默认安全配置）${NC}"
fi
echo ""

# 检查 5: Forward Auth trustForwardHeader
echo "检查 5: Forward Auth trustForwardHeader"
echo "-----------------------------------"
if echo "$CONFIG" | jq -e '.middlewares[] | select(.forwardAuth != null) | select(.forwardAuth.trustForwardHeader == true)' > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  发现 Forward Auth 使用 trustForwardHeader: true${NC}"
    echo "$CONFIG" | jq '.middlewares[] | select(.forwardAuth != null) | select(.forwardAuth.trustForwardHeader == true) | {name: .name, trustForwardHeader: .forwardAuth.trustForwardHeader}'
    VULNERABLE=1
else
    echo -e "${GREEN}✓ 未发现 trustForwardHeader: true${NC}"
fi
echo ""

# 检查 6: 实际漏洞测试
echo "检查 6: CRLF 注入测试"
echo "-----------------------------------"
echo "测试 X-Forwarded-For CRLF 注入..."

TEST_RESPONSE=$(curl -s -v -H "X-Forwarded-For: 127.0.0.1$(printf '\r\n')X-Injected: test" \
    "$TRAEFIK_URL/" 2>&1)

if echo "$TEST_RESPONSE" | grep -qi "X-Injected"; then
    echo -e "${RED}🔴 检测到可能的 CRLF 注入漏洞${NC}"
    VULNERABLE=1
else
    echo -e "${GREEN}✓ 未检测到明显的 CRLF 注入${NC}"
fi
echo ""

# 总结
echo "=========================================="
echo "验证完成"
echo "=========================================="
if [ $VULNERABLE -eq 1 ]; then
    echo -e "${RED}⚠️  发现潜在风险配置${NC}"
    echo ""
    echo "建议:"
    echo "1. 验证这些配置是否真的存在漏洞"
    echo "2. 进行更深入的渗透测试"
    echo "3. 遵循负责任的披露流程"
else
    echo -e "${GREEN}✓ 未发现明显的风险配置${NC}"
fi
echo ""


