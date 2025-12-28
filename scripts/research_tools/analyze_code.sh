#!/bin/bash
# 代码安全分析脚本

echo "=== Traefik 代码安全分析 ==="
echo ""

echo "1. 搜索危险函数调用..."
echo "--- exec.Command ---"
grep -rn "exec\.Command\|os/exec" pkg/ 2>/dev/null | head -10

echo ""
echo "--- unsafe 包使用 ---"
grep -rn "unsafe\." pkg/ 2>/dev/null | head -10

echo ""
echo "--- reflect 包使用 ---"
grep -rn "reflect\." pkg/ 2>/dev/null | head -10

echo ""
echo "2. 搜索正则表达式编译..."
echo "--- regexp.Compile ---"
grep -rn "regexp\.Compile" pkg/ 2>/dev/null | head -20

echo ""
echo "3. 搜索用户输入处理..."
echo "--- HTTP 请求处理 ---"
grep -rn "req\.Header\|req\.Body\|req\.URL" pkg/ | grep -v test | head -20

echo ""
echo "4. 搜索文件操作..."
echo "--- 文件操作 ---"
grep -rn "os\.Open\|ioutil\.ReadFile\|os\.ReadFile" pkg/ 2>/dev/null | head -10

echo ""
echo "5. 搜索模板处理..."
echo "--- 模板处理 ---"
grep -rn "template\.\|text/template\|html/template" pkg/ 2>/dev/null | head -10

echo ""
echo "6. 搜索路径处理..."
echo "--- 路径处理 ---"
grep -rn "filepath\.Join\|path\.Join\|\.\./" pkg/ 2>/dev/null | head -10

echo ""
echo "7. 搜索字符串操作..."
echo "--- 字符串拼接 ---"
grep -rn "fmt\.Sprintf\|strings\.Join\|strings\.Replace" pkg/ | grep -v test | head -20

echo ""
echo "8. 搜索认证相关..."
echo "--- 认证处理 ---"
grep -rn "auth\|Auth\|token\|Token" pkg/middlewares/auth/ 2>/dev/null | head -10

echo ""
echo "分析完成！"


