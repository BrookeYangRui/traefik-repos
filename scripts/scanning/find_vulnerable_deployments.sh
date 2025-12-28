#!/bin/bash
# 查找存在潜在风险的 Traefik 部署
# 用于发现使用不安全配置的 Traefik 实例

set -e

echo "=========================================="
echo "Traefik 不安全配置扫描工具"
echo "=========================================="
echo ""

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VULNERABLE_FOUND=0
TOTAL_CHECKED=0

# 方法 1: 扫描本地/内网 Traefik 实例
scan_local_traefik() {
    echo -e "${BLUE}方法 1: 扫描本地/内网 Traefik 实例${NC}"
    echo "-----------------------------------"
    
    # 检查本地 Traefik
    if curl -s http://localhost:8080/api/rawdata > /dev/null 2>&1; then
        echo "发现本地 Traefik (localhost:8080)"
        check_traefik_instance "http://localhost:8080"
    fi
    
    # 扫描常见内网 IP 段
    echo ""
    echo "扫描内网常见端口 (8080, 80, 443)..."
    echo "提示: 这可能需要一些时间，按 Ctrl+C 可跳过"
    
    # 扫描 192.168.1.0/24 (示例)
    for ip in $(seq 1 254); do
        for port in 8080 80 443; do
            if timeout 1 bash -c "echo >/dev/tcp/192.168.1.$ip/$port" 2>/dev/null; then
                if curl -s --max-time 2 "http://192.168.1.$ip:$port/api/rawdata" > /dev/null 2>&1; then
                    echo "发现 Traefik: http://192.168.1.$ip:$port"
                    check_traefik_instance "http://192.168.1.$ip:$port"
                fi
            fi
        done
    done
    echo ""
}

# 检查单个 Traefik 实例
check_traefik_instance() {
    local url=$1
    ((TOTAL_CHECKED++))
    
    echo "检查: $url"
    
    # 获取配置
    CONFIG=$(curl -s --max-time 5 "$url/api/rawdata" 2>/dev/null || echo "{}")
    
    if [ "$CONFIG" = "{}" ] || [ -z "$CONFIG" ]; then
        echo -e "${YELLOW}  ⚠️  无法获取配置（可能需要认证或 API 未启用）${NC}"
        return
    fi
    
    # 检查 entryPoints 配置
    ENTRYPOINTS=$(echo "$CONFIG" | jq -r '.entryPoints // {}' 2>/dev/null || echo "{}")
    
    # 检查 insecure: true
    if echo "$ENTRYPOINTS" | jq -e '.[] | select(.forwardedHeaders.insecure == true)' > /dev/null 2>&1; then
        echo -e "${RED}  🔴 发现高风险配置: forwardedHeaders.insecure = true${NC}"
        echo "$ENTRYPOINTS" | jq '.[] | select(.forwardedHeaders.insecure == true) | {name: .name, insecure: .forwardedHeaders.insecure}'
        ((VULNERABLE_FOUND++))
    fi
    
    # 检查过宽的 trustedIPs
    if echo "$ENTRYPOINTS" | jq -e '.[] | select(.forwardedHeaders.trustedIPs != null) | select(.forwardedHeaders.trustedIPs | length > 0)' > /dev/null 2>&1; then
        TRUSTED_IPS=$(echo "$ENTRYPOINTS" | jq -r '.[] | select(.forwardedHeaders.trustedIPs != null) | .forwardedHeaders.trustedIPs[]' 2>/dev/null)
        for ip in $TRUSTED_IPS; do
            # 检查是否是过宽的范围
            if [[ "$ip" == *"0.0.0.0"* ]] || [[ "$ip" == *"/0"* ]] || [[ "$ip" == *"*"* ]]; then
                echo -e "${YELLOW}  ⚠️  发现过宽的 trustedIPs: $ip${NC}"
                ((VULNERABLE_FOUND++))
            fi
        done
    fi
    
    # 检查 Forward Auth 配置
    MIDDLEWARES=$(echo "$CONFIG" | jq -r '.middlewares // {}' 2>/dev/null || echo "{}")
    if echo "$MIDDLEWARES" | jq -e '.[] | select(.forwardAuth != null) | select(.forwardAuth.trustForwardHeader == true)' > /dev/null 2>&1; then
        echo -e "${YELLOW}  ⚠️  发现 Forward Auth 使用 trustForwardHeader: true${NC}"
        echo "$MIDDLEWARES" | jq '.[] | select(.forwardAuth != null) | select(.forwardAuth.trustForwardHeader == true) | {name: .name, trustForwardHeader: .forwardAuth.trustForwardHeader}'
        ((VULNERABLE_FOUND++))
    fi
    
    echo ""
}

# 方法 2: 搜索 GitHub 上的配置
search_github_configs() {
    echo -e "${BLUE}方法 2: 搜索 GitHub 上的配置${NC}"
    echo "-----------------------------------"
    echo ""
    echo "GitHub 搜索查询（需要手动执行）:"
    echo ""
    echo "1. 搜索 insecure: true 配置:"
    echo "   ${GREEN}https://github.com/search?q=forwardedHeaders+insecure+true+language:yaml${NC}"
    echo "   ${GREEN}https://github.com/search?q=forwardedHeaders+insecure+true+language:toml${NC}"
    echo ""
    echo "2. 搜索 trustForwardHeader: true 配置:"
    echo "   ${GREEN}https://github.com/search?q=trustForwardHeader+true+language:yaml${NC}"
    echo ""
    echo "3. 搜索 docker-compose 中的 Traefik 配置:"
    echo "   ${GREEN}https://github.com/search?q=traefik+docker-compose+forwardedHeaders${NC}"
    echo ""
    echo "4. 搜索 Kubernetes Traefik 配置:"
    echo "   ${GREEN}https://github.com/search?q=traefik+kubernetes+forwardedHeaders${NC}"
    echo ""
    echo "提示: 使用 GitHub API 可以自动化搜索（需要 API token）"
    echo ""
}

# 方法 3: 搜索 Docker Hub / 公开镜像
search_docker_configs() {
    echo -e "${BLUE}方法 3: 搜索 Docker Hub 和公开配置${NC}"
    echo "-----------------------------------"
    echo ""
    echo "Docker Hub 搜索:"
    echo "1. 搜索包含 Traefik 配置的镜像:"
    echo "   ${GREEN}docker search traefik${NC}"
    echo ""
    echo "2. 检查镜像的 README 和配置:"
    echo "   ${GREEN}docker pull <image> && docker inspect <image>${NC}"
    echo ""
    echo "3. 搜索公开的 docker-compose.yml:"
    echo "   - Pastebin"
    echo "   - Gist"
    echo "   - 各种配置分享网站"
    echo ""
}

# 方法 4: 网络扫描（Shodan/Censys）
search_network_scans() {
    echo -e "${BLUE}方法 4: 使用网络扫描服务${NC}"
    echo "-----------------------------------"
    echo ""
    echo "Shodan 搜索查询:"
    echo "1. 搜索 Traefik Dashboard:"
    echo "   ${GREEN}http.title:\"Traefik\" AND http.status:200${NC}"
    echo ""
    echo "2. 搜索 Traefik API:"
    echo "   ${GREEN}http.title:\"Traefik\" AND \"api/rawdata\"${NC}"
    echo ""
    echo "3. 搜索特定版本:"
    echo "   ${GREEN}http.title:\"Traefik\" AND \"X-Content-Type-Options\"${NC}"
    echo ""
    echo "Censys 搜索查询:"
    echo "1. 搜索 Traefik:"
    echo "   ${GREEN}services.http.response.headers.server: Traefik${NC}"
    echo ""
    echo "提示: 需要 Shodan/Censys API key"
    echo ""
}

# 方法 5: 检查公开的配置仓库
check_public_configs() {
    echo -e "${BLUE}方法 5: 检查公开的配置仓库${NC}"
    echo "-----------------------------------"
    echo ""
    echo "常见位置:"
    echo "1. GitHub Gist:"
    echo "   ${GREEN}https://gist.github.com/search?q=traefik+forwardedHeaders${NC}"
    echo ""
    echo "2. Pastebin 类似服务:"
    echo "   - pastebin.com"
    echo "   - paste.ubuntu.com"
    echo "   - gist.github.com"
    echo ""
    echo "3. 配置分享网站:"
    echo "   - docker-compose 示例网站"
    echo "   - Kubernetes 配置示例"
    echo ""
}

# 方法 6: 自动化 GitHub 搜索（需要 API token）
github_api_search() {
    echo -e "${BLUE}方法 6: 使用 GitHub API 自动化搜索${NC}"
    echo "-----------------------------------"
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}提示: 设置 GITHUB_TOKEN 环境变量以使用 GitHub API${NC}"
        echo ""
        echo "示例命令:"
        echo "  export GITHUB_TOKEN=your_token"
        echo "  curl -H \"Authorization: token \$GITHUB_TOKEN\" \\"
        echo "    'https://api.github.com/search/code?q=forwardedHeaders+insecure+true+language:yaml'"
        echo ""
        return
    fi
    
    echo "搜索 GitHub 代码库..."
    
    # 搜索 insecure: true
    echo "1. 搜索 forwardedHeaders.insecure: true"
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/search/code?q=forwardedHeaders+insecure+true+language:yaml&per_page=10" \
        | jq -r '.items[] | "\(.repository.full_name): \(.path)"' 2>/dev/null || echo "无结果或需要认证"
    
    echo ""
}

# 方法 7: 检查本地配置文件
check_local_configs() {
    echo -e "${BLUE}方法 7: 检查本地配置文件${NC}"
    echo "-----------------------------------"
    echo ""
    
    # 检查当前目录
    echo "检查当前目录的配置文件..."
    for file in $(find . -name "*.yml" -o -name "*.yaml" -o -name "*.toml" 2>/dev/null | head -20); do
        if grep -qi "traefik\|forwardedHeaders\|trustForwardHeader" "$file" 2>/dev/null; then
            echo "发现配置文件: $file"
            if grep -qi "insecure.*true\|trustForwardHeader.*true" "$file" 2>/dev/null; then
                echo -e "${RED}  ⚠️  发现潜在风险配置${NC}"
                grep -ni "insecure\|trustForwardHeader" "$file" | head -5
                ((VULNERABLE_FOUND++))
            fi
        fi
    done
    echo ""
}

# 主函数
main() {
    # 检查依赖
    if ! command -v jq > /dev/null 2>&1; then
        echo -e "${YELLOW}警告: jq 未安装，某些功能可能不可用${NC}"
        echo "安装: sudo apt-get install jq 或 brew install jq"
        echo ""
    fi
    
    # 执行各种扫描方法
    check_local_configs
    scan_local_traefik
    search_github_configs
    search_docker_configs
    search_network_scans
    check_public_configs
    
    if [ -n "$GITHUB_TOKEN" ]; then
        github_api_search
    fi
    
    # 总结
    echo "=========================================="
    echo "扫描完成"
    echo "=========================================="
    echo "检查的实例数: $TOTAL_CHECKED"
    echo -e "发现的风险配置: ${RED}$VULNERABLE_FOUND${NC}"
    echo ""
    echo "建议:"
    echo "1. 对于发现的实例，进行进一步验证"
    echo "2. 使用提供的测试脚本验证漏洞"
    echo "3. 遵循负责任的披露流程"
    echo ""
}

# 运行主函数
main


