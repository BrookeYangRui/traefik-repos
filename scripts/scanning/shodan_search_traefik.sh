#!/bin/bash
# Shodan 搜索脚本 - 查找暴露的 Traefik 实例
# 需要: Shodan CLI (pip install shodan)

set -e

echo "=========================================="
echo "Shodan Traefik 搜索"
echo "=========================================="
echo ""

if ! command -v shodan > /dev/null 2>&1; then
    echo "错误: Shodan CLI 未安装"
    echo "安装: pip install shodan"
    echo "配置: shodan init YOUR_API_KEY"
    exit 1
fi

if [ -z "$SHODAN_API_KEY" ]; then
    echo "提示: 设置 SHODAN_API_KEY 环境变量"
    echo "或运行: shodan init YOUR_API_KEY"
    echo ""
fi

echo "搜索查询:"
echo "-----------------------------------"
echo ""

# 查询 1: Traefik Dashboard
echo "1. 搜索 Traefik Dashboard (可能暴露 API):"
echo "   shodan search 'http.title:\"Traefik\" http.status:200'"
echo ""

# 查询 2: Traefik API 端点
echo "2. 搜索 Traefik API 端点:"
echo "   shodan search 'http.html:\"api/rawdata\" http.title:\"Traefik\"'"
echo ""

# 查询 3: Traefik 特定版本
echo "3. 搜索特定 Traefik 版本:"
echo "   shodan search 'server:\"Traefik\"'"
echo ""

# 查询 4: Traefik 在常见端口
echo "4. 搜索 Traefik 在常见端口:"
echo "   shodan search 'port:8080 http.title:\"Traefik\"'"
echo "   shodan search 'port:80 http.title:\"Traefik\"'"
echo ""

echo "执行搜索（需要 Shodan API key）..."
echo ""

# 如果设置了 API key，执行搜索
if [ -n "$SHODAN_API_KEY" ] || shodan info > /dev/null 2>&1; then
    echo "执行查询 1..."
    shodan search --limit 10 'http.title:"Traefik" http.status:200' 2>/dev/null || echo "需要 Shodan API key"
    
    echo ""
    echo "执行查询 2..."
    shodan search --limit 10 'http.html:"api/rawdata" http.title:"Traefik"' 2>/dev/null || echo "需要 Shodan API key"
    
    echo ""
    echo "提示: 使用 --fields 参数获取更多信息:"
    echo "  shodan search --fields ip_str,port,hostnames 'http.title:\"Traefik\"'"
else
    echo "跳过搜索（需要配置 Shodan API key）"
fi

echo ""
echo "=========================================="
echo "搜索完成"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 对发现的 IP 进行进一步验证"
echo "2. 检查是否暴露了 API"
echo "3. 验证配置是否存在漏洞"
echo ""


