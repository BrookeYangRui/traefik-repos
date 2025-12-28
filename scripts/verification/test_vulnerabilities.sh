#!/bin/bash
# Traefik 漏洞测试脚本
# 用于验证潜在的安全问题

set -e

TRAEFIK_URL="${TRAEFIK_URL:-http://localhost:8080}"
TEST_DIR="vulnerability_tests"
mkdir -p "$TEST_DIR"

echo "=========================================="
echo "Traefik 漏洞测试套件"
echo "=========================================="
echo "目标: $TRAEFIK_URL"
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试结果
PASSED=0
FAILED=0
WARNINGS=0

test_result() {
    local name=$1
    local result=$2
    local details=$3
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $name: PASS"
        ((PASSED++))
    elif [ "$result" = "FAIL" ]; then
        echo -e "${RED}✗${NC} $name: FAIL"
        echo "  详情: $details"
        ((FAILED++))
    else
        echo -e "${YELLOW}⚠${NC} $name: WARNING"
        echo "  详情: $details"
        ((WARNINGS++))
    fi
}

# 测试 1: HTTP Header Injection - X-Forwarded-For CRLF
echo "测试 1: HTTP Header Injection (X-Forwarded-For CRLF)"
echo "---------------------------------------------------"
CRLF_TEST=$(printf "GET / HTTP/1.1\r\nHost: localhost:8080\r\nX-Forwarded-For: 127.0.0.1\r\nX-Injected: test\r\n\r\n")
RESPONSE=$(echo -e "$CRLF_TEST" | nc -w 2 localhost 8080 2>/dev/null || echo "CONNECTION_FAILED")

if echo "$RESPONSE" | grep -q "X-Injected"; then
    test_result "Header Injection (CRLF)" "FAIL" "检测到头部注入 - 响应包含 X-Injected 头部"
else
    test_result "Header Injection (CRLF)" "PASS" "未检测到明显的头部注入"
fi
echo ""

# 测试 2: HTTP Header Injection - URL 编码
echo "测试 2: HTTP Header Injection (URL 编码)"
echo "---------------------------------------------------"
curl -s -v -H "X-Forwarded-For: 127.0.0.1%0d%0aX-Injected: test" \
    "$TRAEFIK_URL/" > "$TEST_DIR/header_injection_urlencoded.log" 2>&1

if grep -q "X-Injected" "$TEST_DIR/header_injection_urlencoded.log"; then
    test_result "Header Injection (URL编码)" "FAIL" "检测到 URL 编码的头部注入"
else
    test_result "Header Injection (URL编码)" "PASS" "未检测到 URL 编码的头部注入"
fi
echo ""

# 测试 3: HTTP Request Smuggling - CL.TE
echo "测试 3: HTTP Request Smuggling (CL.TE)"
echo "---------------------------------------------------"
CLTE_PAYLOAD=$(printf "POST / HTTP/1.1\r\nHost: localhost:8080\r\nContent-Length: 13\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\nSMUGGLED")
echo -e "$CLTE_PAYLOAD" | nc -w 2 localhost 8080 > "$TEST_DIR/request_smuggling_clte.log" 2>&1 || true

if grep -qi "SMUGGLED" "$TEST_DIR/request_smuggling_clte.log"; then
    test_result "Request Smuggling (CL.TE)" "WARNING" "检测到可能的请求走私 - 需要进一步验证"
else
    test_result "Request Smuggling (CL.TE)" "PASS" "未检测到明显的请求走私"
fi
echo ""

# 测试 4: HTTP Request Smuggling - TE.CL
echo "测试 4: HTTP Request Smuggling (TE.CL)"
echo "---------------------------------------------------"
TECL_PAYLOAD=$(printf "POST / HTTP/1.1\r\nHost: localhost:8080\r\nTransfer-Encoding: chunked\r\nContent-Length: 3\r\n\r\n0\r\n\r\nSMUGGLED")
echo -e "$TECL_PAYLOAD" | nc -w 2 localhost 8080 > "$TEST_DIR/request_smuggling_tecl.log" 2>&1 || true

if grep -qi "SMUGGLED" "$TEST_DIR/request_smuggling_tecl.log"; then
    test_result "Request Smuggling (TE.CL)" "WARNING" "检测到可能的请求走私 - 需要进一步验证"
else
    test_result "Request Smuggling (TE.CL)" "PASS" "未检测到明显的请求走私"
fi
echo ""

# 测试 5: 路径遍历
echo "测试 5: 路径遍历"
echo "---------------------------------------------------"
curl -s -o /dev/null -w "%{http_code}" "$TRAEFIK_URL/../../etc/passwd" > "$TEST_DIR/path_traversal.log" 2>&1
HTTP_CODE=$(cat "$TEST_DIR/path_traversal.log")

if [ "$HTTP_CODE" = "200" ]; then
    test_result "路径遍历 (基本)" "FAIL" "返回 200 - 可能存在路径遍历"
else
    test_result "路径遍历 (基本)" "PASS" "返回 $HTTP_CODE - 路径遍历被阻止"
fi
echo ""

# 测试 6: 路径遍历 (URL 编码)
echo "测试 6: 路径遍历 (URL 编码)"
echo "---------------------------------------------------"
curl -s -o /dev/null -w "%{http_code}" "$TRAEFIK_URL/%2e%2e%2f%2e%2e%2fetc%2fpasswd" > "$TEST_DIR/path_traversal_encoded.log" 2>&1
HTTP_CODE=$(cat "$TEST_DIR/path_traversal_encoded.log")

if [ "$HTTP_CODE" = "200" ]; then
    test_result "路径遍历 (URL编码)" "FAIL" "返回 200 - 可能存在路径遍历"
else
    test_result "路径遍历 (URL编码)" "PASS" "返回 $HTTP_CODE - 路径遍历被阻止"
fi
echo ""

# 测试 7: ReDoS - 恶意正则表达式（需要配置）
echo "测试 7: ReDoS (需要配置支持)"
echo "---------------------------------------------------"
test_result "ReDoS" "WARNING" "需要配置恶意正则表达式才能测试 - 跳过"
echo ""

# 测试 8: Forward Auth 头部注入（需要 Forward Auth 配置）
echo "测试 8: Forward Auth 头部注入（需要配置）"
echo "---------------------------------------------------"
test_result "Forward Auth Injection" "WARNING" "需要 Forward Auth 中间件配置 - 跳过"
echo ""

# 总结
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo -e "${YELLOW}警告: $WARNINGS${NC}"
echo ""
echo "详细日志保存在: $TEST_DIR/"
echo ""
echo "注意:"
echo "1. 这些测试是初步验证，不能完全确定是否存在漏洞"
echo "2. 某些测试需要特定配置才能触发"
echo "3. 建议进行更深入的手动测试和代码审查"
echo "4. 如果发现漏洞，请遵循负责任的披露流程"


