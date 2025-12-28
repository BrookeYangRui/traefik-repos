# 快速开始指南

## 目录结构

所有安全研究相关的文件已整理到 `security_research/` 目录：

```
security_research/
├── config/              # 配置文件
│   ├── traefik-simple.yml
│   └── .github_token
│
├── scripts/             # 脚本工具
│   ├── github/         # GitHub 搜索
│   ├── scanning/       # 扫描工具
│   ├── verification/  # 验证工具
│   └── research_tools/ # 研究工具
│
├── docs/               # 文档
│   ├── analysis/       # 分析文档
│   ├── guides/        # 指南文档
│   └── reports/       # 报告文档
│
└── results/            # 搜索结果
```

## 常用命令

### GitHub 搜索

```bash
cd security_research/scripts/github
python3 github_search_traefik.py
```

### 扫描暴露的实例

```bash
cd security_research/scripts/scanning
./find_vulnerable_deployments.sh
```

### 验证配置

```bash
cd security_research/scripts/verification
./check_traefik_config.sh /path/to/config.yml
```

## 重要文档

- **详细漏洞分析**: `docs/analysis/DETAILED_VULNERABILITY_ANALYSIS.md`
- **GitHub 搜索结果**: `docs/reports/GITHUB_SEARCH_RESULTS_SUMMARY.md`
- **如何找到风险部署**: `docs/guides/HOW_TO_FIND_VULNERABLE_DEPLOYMENTS.md`

