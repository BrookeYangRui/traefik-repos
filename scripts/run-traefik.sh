#!/bin/bash
# Traefik 直接运行脚本

echo "=========================================="
echo "Traefik 直接运行测试"
echo "=========================================="

# 检查是否有编译好的二进制文件
if [ -f "./dist/linux/amd64/traefik" ]; then
    echo "找到编译好的二进制文件，使用它运行..."
    ./dist/linux/amd64/traefik --configFile=traefik-simple.yml
elif [ -f "./traefik" ]; then
    echo "找到 traefik 二进制文件，使用它运行..."
    ./traefik --configFile=traefik-simple.yml
else
    echo "未找到编译好的二进制文件，尝试使用 go run..."
    echo ""
    echo "方式 1: 使用配置文件"
    echo "go run ./cmd/traefik --configFile=traefik-simple.yml"
    echo ""
    echo "方式 2: 使用命令行参数（推荐用于快速测试）"
    echo "go run ./cmd/traefik \\"
    echo "  --api.insecure=true \\"
    echo "  --entrypoints.web.address=:8080 \\"
    echo "  --log.level=INFO"
    echo ""
    echo "运行后可以访问："
    echo "  - Dashboard: http://localhost:8080/dashboard/"
    echo "  - API: http://localhost:8080/api/rawdata"
    echo ""
    echo "按 Ctrl+C 停止 Traefik"
    echo ""
    
    # 尝试运行
    go run ./cmd/traefik \
      --api.insecure=true \
      --entrypoints.web.address=:8080 \
      --log.level=INFO
fi


