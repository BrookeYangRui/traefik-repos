#!/bin/bash
# Nginx Ingress 扫描器监控脚本

SCAN_DIR="/home/rui/ci/security_research/scripts/github"
PID_FILE="$SCAN_DIR/nginx_scan.pid"
LOG_FILE="$SCAN_DIR/nginx_scan.log"
RESULTS_DIR="$SCAN_DIR/reverse_proxy_scan_results_nginx-ingress"

cd "$SCAN_DIR"

echo "=========================================="
echo "Nginx Ingress 扫描器监控"
echo "=========================================="
echo ""

# 检查进程
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "✅ 进程运行中 (PID: $PID)"
    else
        echo "❌ 进程已停止 (PID: $PID)"
    fi
else
    echo "⚠️  未找到 PID 文件"
fi

echo ""

# 显示最近日志
if [ -f "$LOG_FILE" ]; then
    echo "最近 20 行日志:"
    echo "----------------------------------------"
    tail -20 "$LOG_FILE"
    echo ""
else
    echo "⚠️  日志文件不存在"
fi

# 检查结果文件
if [ -d "$RESULTS_DIR" ]; then
    echo "=========================================="
    echo "扫描结果统计"
    echo "=========================================="
    
    CSV_FILE=$(ls -t "$RESULTS_DIR"/*.csv 2>/dev/null | head -1)
    if [ -n "$CSV_FILE" ]; then
        TOTAL=$(tail -n +2 "$CSV_FILE" 2>/dev/null | wc -l)
        echo "✅ 已找到 $TOTAL 个匹配项"
        echo "   CSV 文件: $(basename "$CSV_FILE")"
    fi
    
    if [ -f "$RESULTS_DIR/stats.json" ]; then
        echo ""
        echo "统计信息:"
        cat "$RESULTS_DIR/stats.json" | python3 -m json.tool 2>/dev/null || cat "$RESULTS_DIR/stats.json"
    fi
fi

echo ""
