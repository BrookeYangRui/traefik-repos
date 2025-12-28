#!/bin/bash
# Traefik 配置检查脚本
# 用于检查实际部署中的不安全配置

set -e

echo "=========================================="
echo "Traefik 配置安全检查"
echo "=========================================="
echo ""

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

RISKS_FOUND=0

check_config_file() {
    local file=$1
    local risk_level=$2
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    echo "检查文件: $file"
    
    # 检查 insecure: true
    if grep -q "insecure.*true\|insecure:\s*true" "$file" 2>/dev/null; then
        echo -e "${RED}⚠️  发现不安全配置: insecure: true${NC}"
        grep -n "insecure.*true\|insecure:\s*true" "$file" | head -5
        ((RISKS_FOUND++))
    fi
    
    # 检查 trustForwardHeader: true
    if grep -qi "trustForwardHeader.*true\|trustForwardHeader:\s*true" "$file" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  发现潜在风险配置: trustForwardHeader: true${NC}"
        grep -ni "trustForwardHeader.*true\|trustForwardHeader:\s*true" "$file" | head -5
        ((RISKS_FOUND++))
    fi
    
    # 检查 forwardedHeaders.insecure
    if grep -qi "forwardedHeaders.*insecure.*true\|forwardedHeaders:.*insecure:\s*true" "$file" 2>/dev/null; then
        echo -e "${RED}⚠️  发现不安全配置: forwardedHeaders.insecure: true${NC}"
        grep -ni "forwardedHeaders.*insecure" "$file" | head -5
        ((RISKS_FOUND++))
    fi
    
    # 检查过宽的 trustedIPs
    if grep -qi "trustedIPs.*0\.0\.0\.0\|trustedIPs.*\*" "$file" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  发现过宽的 trustedIPs 配置${NC}"
        grep -ni "trustedIPs" "$file" | head -5
        ((RISKS_FOUND++))
    fi
    
    echo ""
}

# 方法 1: 检查本地配置文件
echo "方法 1: 检查本地配置文件"
echo "-----------------------------------"
for file in traefik*.yml traefik*.yaml traefik*.toml docker-compose*.yml docker-compose*.yaml; do
    check_config_file "$file" "high"
done

# 方法 2: 检查运行中的 Traefik（如果可访问）
echo "方法 2: 检查运行中的 Traefik 配置"
echo "-----------------------------------"
TRAEFIK_API="${TRAEFIK_API:-http://localhost:8080}"

if curl -s "$TRAEFIK_API/api/rawdata" > /dev/null 2>&1; then
    echo "连接到 Traefik API: $TRAEFIK_API"
    
    # 检查 entryPoints 配置
    ENTRYPOINTS=$(curl -s "$TRAEFIK_API/api/rawdata" | jq -r '.entryPoints // {}' 2>/dev/null || echo "{}")
    
    if echo "$ENTRYPOINTS" | jq -e '.[] | select(.forwardedHeaders.insecure == true)' > /dev/null 2>&1; then
        echo -e "${RED}⚠️  发现运行中的 Traefik 使用了 insecure: true${NC}"
        echo "$ENTRYPOINTS" | jq '.[] | select(.forwardedHeaders.insecure == true)'
        ((RISKS_FOUND++))
    fi
    
    # 检查是否有 forwardedHeaders 配置
    if echo "$ENTRYPOINTS" | jq -e '.[] | has("forwardedHeaders")' > /dev/null 2>&1; then
        echo "发现 forwardedHeaders 配置:"
        echo "$ENTRYPOINTS" | jq '.[] | select(has("forwardedHeaders")) | {name: .name, forwardedHeaders: .forwardedHeaders}'
    fi
else
    echo "无法连接到 Traefik API（$TRAEFIK_API）"
    echo "提示: 设置 TRAEFIK_API 环境变量指定 API 地址"
fi
echo ""

# 方法 3: 检查 Docker 容器配置
echo "方法 3: 检查 Docker 容器配置"
echo "-----------------------------------"
if command -v docker > /dev/null 2>&1; then
    TRAEFIK_CONTAINER=$(docker ps --filter "ancestor=traefik" --format "{{.Names}}" | head -1)
    
    if [ -n "$TRAEFIK_CONTAINER" ]; then
        echo "发现 Traefik 容器: $TRAEFIK_CONTAINER"
        
        # 检查启动参数
        ARGS=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{range .Args}}{{.}}{{"\n"}}{{end}}' 2>/dev/null || echo "")
        
        if echo "$ARGS" | grep -qi "insecure\|forwardedHeaders.insecure"; then
            echo -e "${RED}⚠️  发现容器启动参数包含 insecure 配置${NC}"
            echo "$ARGS" | grep -i "insecure\|forwardedHeaders"
            ((RISKS_FOUND++))
        fi
        
        # 检查环境变量
        ENV_VARS=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' 2>/dev/null || echo "")
        
        if echo "$ENV_VARS" | grep -qi "TRAEFIK.*INSECURE\|TRAEFIK.*FORWARDED"; then
            echo "发现相关环境变量:"
            echo "$ENV_VARS" | grep -i "TRAEFIK.*INSECURE\|TRAEFIK.*FORWARDED"
        fi
    else
        echo "未发现运行中的 Traefik 容器"
    fi
else
    echo "Docker 未安装或不可用"
fi
echo ""

# 方法 4: 检查 Kubernetes 配置
echo "方法 4: 检查 Kubernetes 配置"
echo "-----------------------------------"
if command -v kubectl > /dev/null 2>&1; then
    if kubectl cluster-info > /dev/null 2>&1; then
        # 检查 Traefik ConfigMap
        if kubectl get configmap traefik -o yaml 2>/dev/null | grep -qi "insecure.*true\|trustForwardHeader.*true"; then
            echo -e "${RED}⚠️  发现 Kubernetes ConfigMap 中的不安全配置${NC}"
            kubectl get configmap traefik -o yaml | grep -i "insecure\|trustForwardHeader" | head -10
            ((RISKS_FOUND++))
        fi
        
        # 检查 Traefik Deployment
        TRAEFIK_DEPLOYMENT=$(kubectl get deployment -o name | grep -i traefik | head -1)
        if [ -n "$TRAEFIK_DEPLOYMENT" ]; then
            echo "发现 Traefik Deployment: $TRAEFIK_DEPLOYMENT"
            kubectl get "$TRAEFIK_DEPLOYMENT" -o yaml | grep -i "insecure\|trustForwardHeader\|forwardedHeaders" | head -10
        fi
    else
        echo "无法连接到 Kubernetes 集群"
    fi
else
    echo "kubectl 未安装或不可用"
fi
echo ""

# 总结
echo "=========================================="
echo "检查完成"
echo "=========================================="
if [ $RISKS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ 未发现明显的不安全配置${NC}"
else
    echo -e "${RED}⚠️  发现 $RISKS_FOUND 个潜在风险配置${NC}"
    echo ""
    echo "建议:"
    echo "1. 检查这些配置是否必要"
    echo "2. 如果可能，使用 trustedIPs 替代 insecure: true"
    echo "3. 确保 trustForwardHeader 只在完全可信的环境中启用"
fi
echo ""


