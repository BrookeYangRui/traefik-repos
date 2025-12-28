#!/usr/bin/env python3
"""
Traefik 潜在漏洞模式检测脚本
用于识别代码中可能存在安全问题的模式
"""

import os
import re
import sys
from pathlib import Path

# 危险模式定义
VULNERABLE_PATTERNS = {
    "unsafe_pointer": {
        "pattern": r"unsafe\.Pointer",
        "description": "使用 unsafe.Pointer 可能导致内存安全问题",
        "severity": "HIGH"
    },
    "reflect_unsafe": {
        "pattern": r"reflect\.ValueOf.*\.Interface\(\)",
        "description": "reflect 类型转换可能绕过类型检查",
        "severity": "MEDIUM"
    },
    "regex_user_input": {
        "pattern": r"regexp\.Compile\([^)]*req\.|regexp\.Compile\([^)]*user|regexp\.Compile\([^)]*input",
        "description": "使用用户输入编译正则表达式可能导致 ReDoS",
        "severity": "HIGH"
    },
    "header_injection": {
        "pattern": r"\.Set\([^,]+,\s*req\.Header\.Get\(|\.Set\([^,]+,\s*req\.URL\.Query\(\)",
        "description": "直接将用户输入设置到响应头可能导致头部注入",
        "severity": "HIGH"
    },
    "path_traversal": {
        "pattern": r"filepath\.Join\([^,]+,\s*req\.|path\.Join\([^,]+,\s*req\.|os\.Open\([^)]*req\.",
        "description": "使用用户输入构建文件路径可能导致路径遍历",
        "severity": "HIGH"
    },
    "command_injection": {
        "pattern": r"exec\.Command\([^,]+,\s*req\.|exec\.Command\([^,]+,\s*user",
        "description": "使用用户输入执行命令可能导致命令注入",
        "severity": "CRITICAL"
    },
    "template_injection": {
        "pattern": r"template\.Execute\([^,]+,\s*req\.|template\.Execute\([^,]+,\s*user",
        "description": "使用用户输入执行模板可能导致模板注入",
        "severity": "HIGH"
    },
    "integer_overflow": {
        "pattern": r"len\([^)]+\)\s*\+\s*len\(|int\([^)]+\)\s*\+\s*int\(",
        "description": "整数运算可能导致溢出",
        "severity": "MEDIUM"
    },
    "no_input_validation": {
        "pattern": r"req\.Header\.Get\([^)]+\)\s*$|req\.URL\.Query\(\)\.Get\([^)]+\)\s*$",
        "description": "获取用户输入后可能未进行验证",
        "severity": "LOW"
    },
    "unsafe_string_concat": {
        "pattern": r"fmt\.Sprintf\([^,]+req\.|fmt\.Sprintf\([^,]+user|strings\.Join\([^,]+req\.",
        "description": "字符串拼接可能包含未验证的用户输入",
        "severity": "MEDIUM"
    }
}

def scan_file(file_path):
    """扫描单个文件"""
    findings = []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
            for line_num, line in enumerate(lines, 1):
                for pattern_name, pattern_info in VULNERABLE_PATTERNS.items():
                    if re.search(pattern_info["pattern"], line, re.IGNORECASE):
                        findings.append({
                            "file": str(file_path),
                            "line": line_num,
                            "pattern": pattern_name,
                            "description": pattern_info["description"],
                            "severity": pattern_info["severity"],
                            "code": line.strip()
                        })
    except Exception as e:
        print(f"Error scanning {file_path}: {e}", file=sys.stderr)
    return findings

def scan_directory(directory):
    """递归扫描目录"""
    all_findings = []
    pkg_path = Path(directory) / "pkg"
    
    if not pkg_path.exists():
        print(f"Error: {pkg_path} does not exist")
        return all_findings
    
    # 只扫描 .go 文件
    for go_file in pkg_path.rglob("*.go"):
        # 跳过测试文件
        if "_test.go" in go_file.name:
            continue
        findings = scan_file(go_file)
        all_findings.extend(findings)
    
    return all_findings

def print_report(findings):
    """打印报告"""
    if not findings:
        print("✅ 未发现明显的漏洞模式")
        return
    
    # 按严重性分组
    by_severity = {"CRITICAL": [], "HIGH": [], "MEDIUM": [], "LOW": []}
    for finding in findings:
        by_severity[finding["severity"]].append(finding)
    
    print(f"\n{'='*80}")
    print(f"发现 {len(findings)} 个潜在安全问题")
    print(f"{'='*80}\n")
    
    for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        if by_severity[severity]:
            print(f"\n[{severity}] 严重性 ({len(by_severity[severity])} 个):")
            print("-" * 80)
            for finding in by_severity[severity]:
                print(f"\n文件: {finding['file']}")
                print(f"行号: {finding['line']}")
                print(f"模式: {finding['pattern']}")
                print(f"描述: {finding['description']}")
                print(f"代码: {finding['code']}")
                print()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        directory = sys.argv[1]
    else:
        directory = "."
    
    print("扫描 Traefik 代码库中的潜在漏洞模式...")
    print(f"目录: {directory}\n")
    
    findings = scan_directory(directory)
    print_report(findings)
    
    # 保存到文件
    if findings:
        with open("vulnerability_findings.txt", "w") as f:
            for finding in findings:
                f.write(f"{finding['file']}:{finding['line']} - {finding['pattern']} - {finding['description']}\n")
        print(f"\n详细结果已保存到: vulnerability_findings.txt")


