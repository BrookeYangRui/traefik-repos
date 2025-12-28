package main

import (
	"fmt"
	"net/http"
	"strings"
)

// 测试 Go 标准库如何处理包含 CRLF 的头部值
func main() {
	fmt.Println("=== Go 标准库头部处理测试 ===\n")

	// 测试 1: 直接设置包含 CRLF 的头部值
	fmt.Println("测试 1: 设置包含 CRLF 的 X-Forwarded-For")
	req, _ := http.NewRequest("GET", "http://example.com/", nil)
	maliciousValue := "127.0.0.1\r\nX-Injected: test\r\n"
	req.Header.Set("X-Forwarded-For", maliciousValue)
	
	fmt.Printf("原始值: %q\n", maliciousValue)
	fmt.Printf("Header.Get(): %q\n", req.Header.Get("X-Forwarded-For"))
	fmt.Printf("Header 值: %v\n", req.Header["X-Forwarded-For"])
	
	// 检查是否被分割为多个头部
	if len(req.Header["X-Forwarded-For"]) > 1 {
		fmt.Println("⚠️  警告: 头部值被分割为多个值")
	}
	
	// 检查是否包含换行符
	if strings.Contains(req.Header.Get("X-Forwarded-For"), "\r\n") {
		fmt.Println("⚠️  警告: 头部值包含 CRLF 字符")
	} else {
		fmt.Println("✓ 头部值中的 CRLF 被处理/移除")
	}
	fmt.Println()

	// 测试 2: 使用 Add 方法
	fmt.Println("测试 2: 使用 Add 方法添加包含 CRLF 的头部")
	req2, _ := http.NewRequest("GET", "http://example.com/", nil)
	req2.Header.Add("X-Forwarded-For", "127.0.0.1\r\nX-Injected: test\r\n")
	fmt.Printf("Header.Get(): %q\n", req2.Header.Get("X-Forwarded-For"))
	fmt.Println()

	// 测试 3: 多个 X-Forwarded-For 值
	fmt.Println("测试 3: 多个 X-Forwarded-For 值（模拟 Traefik 的行为）")
	req3, _ := http.NewRequest("GET", "http://example.com/", nil)
	req3.Header.Add("X-Forwarded-For", "192.168.1.1")
	req3.Header.Add("X-Forwarded-For", "127.0.0.1\r\nX-Injected: test")
	
	values := req3.Header["X-Forwarded-For"]
	fmt.Printf("Header[\"X-Forwarded-For\"]: %v\n", values)
	joined := strings.Join(values, ", ")
	fmt.Printf("strings.Join(values, \", \"): %q\n", joined)
	
	if strings.Contains(joined, "\r\n") {
		fmt.Println("⚠️  警告: Join 后的值包含 CRLF")
	} else {
		fmt.Println("✓ Join 后的值不包含 CRLF")
	}
	fmt.Println()

	// 测试 4: 检查写入响应头
	fmt.Println("测试 4: 写入响应头（模拟可能的注入点）")
	resp := &http.Response{
		Header: make(http.Header),
	}
	resp.Header.Set("X-Forwarded-For", "127.0.0.1\r\nX-Injected: test\r\n")
	fmt.Printf("响应头: %v\n", resp.Header)
	
	// 尝试将头部写入字符串（模拟 HTTP 响应）
	var headerLines []string
	for k, v := range resp.Header {
		for _, val := range v {
			headerLines = append(headerLines, fmt.Sprintf("%s: %s", k, val))
		}
	}
	headerString := strings.Join(headerLines, "\r\n")
	fmt.Printf("头部字符串: %q\n", headerString)
	
	if strings.Contains(headerString, "\r\nX-Injected:") {
		fmt.Println("⚠️  警告: 响应头字符串包含注入的头部")
	} else {
		fmt.Println("✓ 响应头字符串不包含注入的头部")
	}
	fmt.Println()

	// 测试 5: URL 编码的 CRLF
	fmt.Println("测试 5: URL 编码的 CRLF (%0d%0a)")
	req5, _ := http.NewRequest("GET", "http://example.com/", nil)
	urlEncodedCRLF := "127.0.0.1%0d%0aX-Injected: test"
	req5.Header.Set("X-Forwarded-For", urlEncodedCRLF)
	fmt.Printf("原始值: %q\n", urlEncodedCRLF)
	fmt.Printf("Header.Get(): %q\n", req5.Header.Get("X-Forwarded-For"))
	
	// Go 标准库不会自动解码 URL 编码的头部值
	if strings.Contains(req5.Header.Get("X-Forwarded-For"), "%0d%0a") {
		fmt.Println("⚠️  警告: URL 编码的 CRLF 保留在头部值中")
		fmt.Println("   如果后端解码，可能导致注入")
	} else {
		fmt.Println("✓ URL 编码的 CRLF 被处理")
	}
	fmt.Println()

	fmt.Println("=== 测试完成 ===")
	fmt.Println("\n结论:")
	fmt.Println("1. Go 标准库的 net/http 会保留头部值中的 CRLF 字符")
	fmt.Println("2. 如果直接使用 strings.Join 连接多个头部值，CRLF 会被保留")
	fmt.Println("3. 写入 HTTP 响应时，CRLF 可能导致头部注入")
	fmt.Println("4. URL 编码的 CRLF 不会被自动解码，但如果后端解码可能有问题")
}

