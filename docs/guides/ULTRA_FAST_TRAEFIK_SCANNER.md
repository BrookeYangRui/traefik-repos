# Ultra Fast Traefik Scanner 使用指南

## 概述

`ultra_fast_traefik_scanner.py` 是一个快速且全面的 Traefik 配置搜索工具，参考 `UltraFastScanner` 架构设计，专门针对 Traefik 配置优化。

## 核心特性

### 1. 多 Token 支持
- 支持多个 GitHub token 轮换使用
- 自动选择最佳可用 token（基于剩余请求数和最后使用时间）
- 自动处理 token 错误和重试

### 2. 高并发处理
- 使用 `ThreadPoolExecutor` 进行多线程处理
- 默认 16 个工作线程（可配置）
- 每个线程独立处理仓库

### 3. 快速克隆
- 使用 `--depth 1` 只克隆最新提交
- 使用 `--single-branch` 只克隆一个分支
- 使用 `--no-tags` 不下载标签
- 使用 `--quiet` 静默模式

### 4. 智能扫描
- 自动识别 YAML、TOML、JSON 配置文件
- 支持多种 Traefik 配置模式：
  - `forwardedHeaders.insecure: true` (高风险)
  - `trustForwardHeader: true` (中等风险)
  - `traefik docker-compose forwardedHeaders` (中等风险)
- 自动检测 `trustedIPs` 配置（减少误报）

### 5. 进度管理
- 支持断点续传
- 自动保存进度到 `progress.json`
- 跳过已处理的仓库

### 6. 结果输出
- CSV 格式：包含所有详细信息
- 统计信息：自动生成 `stats.json`
- 日志文件：完整的扫描日志

### 7. 内存管理
- 定期垃圾回收（每 5 分钟）
- 自动清理临时文件
- 每个仓库处理完后立即清理

## 安装依赖

```bash
pip install pygithub python-dotenv
```

## 配置

### 1. 创建 `.env` 文件

```bash
# 单个 token
GITHUB_TOKEN=your_github_token_here

# 多个 token（用逗号分隔）
GITHUB_TOKEN=token1,token2,token3

# 或者用换行符分隔
GITHUB_TOKEN=token1
token2
token3
```

### 2. 创建 `config.json`（可选）

```json
{
  "concurrency": {
    "max_workers": 16,
    "clone_timeout": 300
  },
  "search": {
    "min_stars": 0,
    "time_window": {
      "start_date": "2015-01-01",
      "end_date": "now",
      "window_size_days": 30
    }
  },
  "logging": {
    "level": "INFO",
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "date_format": "%Y-%m-%d %H:%M:%S"
  }
}
```

## 使用方法

### 基本用法

```bash
# 使用默认配置（16 个工作线程）
python3 scripts/github/ultra_fast_traefik_scanner.py

# 指定工作线程数
python3 scripts/github/ultra_fast_traefik_scanner.py --workers 32

# 使用自定义配置文件
python3 scripts/github/ultra_fast_traefik_scanner.py --config my_config.json
```

### 高级用法

```bash
# 使用 32 个工作线程，提高扫描速度
python3 scripts/github/ultra_fast_traefik_scanner.py --workers 32

# 使用自定义配置和工作线程数
python3 scripts/github/ultra_fast_traefik_scanner.py \
  --config custom_config.json \
  --workers 24
```

## 输出文件

### 1. CSV 结果文件

位置：`traefik_scan_results/traefik_results_YYYYMMDD_HHMMSS.csv`

格式：
```csv
Index,Repository,URL,Stars,Year,Vulnerability Type,Risk Level,Has TrustedIPs,File Path
1,owner/repo,https://github.com/owner/repo,100,2023,forwardedHeaders.insecure (YAML),high,No,path/to/file.yml
```

### 2. 统计文件

位置：`traefik_scan_results/stats.json`

内容：
```json
{
  "total_repos_processed": 1000,
  "total_matches": 50,
  "repos_by_stars": {...},
  "matches_by_type": {...},
  "duration_seconds": 3600.0,
  "last_updated": "2025-01-01 12:00:00"
}
```

### 3. 进度文件

位置：`traefik_scan_results/progress.json`

内容：
```json
{
  "processed_repos": ["owner/repo1", "owner/repo2", ...],
  "last_successful_search": "2025-01-01 12:00:00"
}
```

### 4. 日志文件

位置：`traefik_scan_results/traefik_scanner.log`

包含完整的扫描日志，包括：
- 搜索进度
- 匹配结果
- 错误信息
- 性能统计

## 搜索策略

### 1. 搜索查询

脚本使用以下 4 个主要搜索查询：

1. **forwardedHeaders.insecure (YAML)**
   - 查询：`forwardedHeaders insecure true language:yaml`
   - 风险等级：🔴 高风险
   - 文件扩展名：`.yml`, `.yaml`

2. **forwardedHeaders.insecure (TOML)**
   - 查询：`forwardedHeaders insecure true language:toml`
   - 风险等级：🔴 高风险
   - 文件扩展名：`.toml`

3. **trustForwardHeader (YAML)**
   - 查询：`trustForwardHeader true language:yaml`
   - 风险等级：⚠️ 中等风险
   - 文件扩展名：`.yml`, `.yaml`

4. **traefik docker-compose**
   - 查询：`traefik docker-compose forwardedHeaders`
   - 风险等级：⚠️ 中等风险
   - 文件扩展名：`.yml`, `.yaml`

### 2. 处理流程

1. **代码搜索**：使用 GitHub API 搜索代码
2. **去重**：移除重复的仓库
3. **克隆**：快速克隆每个仓库
4. **扫描**：扫描配置文件
5. **过滤**：检查是否配置了 `trustedIPs`
6. **保存**：保存结果到 CSV

### 3. 性能优化

- **并发处理**：16 个工作线程同时处理
- **快速克隆**：只克隆最新提交
- **智能清理**：每个仓库处理完后立即清理
- **内存管理**：定期垃圾回收
- **进度保存**：每 10 分钟自动保存进度

## 性能指标

### 预期性能

- **扫描速度**：约 20-50 仓库/分钟（取决于网络和 GitHub API 限制）
- **内存使用**：约 500MB-1GB（取决于并发数）
- **磁盘使用**：临时文件自动清理，最终结果约几 MB

### 影响因素

1. **GitHub API 限制**
   - 认证用户：每分钟 30 次请求
   - 使用多个 token 可以提高速度

2. **网络速度**
   - 克隆速度影响整体性能
   - 建议使用稳定的网络连接

3. **仓库大小**
   - 大仓库需要更多时间克隆和扫描
   - 脚本会自动跳过超大文件（>5MB）

## 故障排除

### 1. Token 错误

```
[ERROR] No valid GitHub tokens found
```

**解决方案**：
- 检查 `.env` 文件是否存在
- 检查 `GITHUB_TOKEN` 是否正确设置
- 检查 token 是否有效（未过期）

### 2. 速率限制

```
[RATE_LIMIT] GitHub API rate limit hit, waiting 60 seconds...
```

**解决方案**：
- 使用多个 token（在 `.env` 中用逗号分隔）
- 减少工作线程数
- 等待速率限制重置

### 3. 克隆失败

```
[FAIL] Failed to clone repo_name
```

**解决方案**：
- 检查网络连接
- 检查仓库是否仍然存在
- 增加 `clone_timeout` 配置

### 4. 内存不足

```
[ERROR] Memory error
```

**解决方案**：
- 减少工作线程数（`--workers 8`）
- 增加系统内存
- 定期重启脚本

## 最佳实践

### 1. 使用多个 Token

```bash
# .env
GITHUB_TOKEN=token1,token2,token3,token4
```

### 2. 合理设置工作线程数

- **网络快**：16-32 个工作线程
- **网络慢**：8-16 个工作线程
- **内存有限**：4-8 个工作线程

### 3. 定期保存进度

脚本会自动每 10 分钟保存进度，但也可以手动中断（Ctrl+C）后重新运行，会自动从上次停止的地方继续。

### 4. 监控日志

```bash
# 实时查看日志
tail -f traefik_scan_results/traefik_scanner.log

# 查看错误
grep ERROR traefik_scan_results/traefik_scanner.log
```

## 对比原有脚本

| 特性 | 原有脚本 | Ultra Fast Scanner |
|------|---------|-------------------|
| **搜索方式** | 代码搜索 | 代码搜索 + 仓库克隆 |
| **并发处理** | ❌ | ✅ 16 线程 |
| **多 Token** | ❌ | ✅ |
| **进度保存** | ❌ | ✅ |
| **结果验证** | ❌ | ✅ 检查 trustedIPs |
| **扫描速度** | 慢 | 快（20-50 仓库/分钟） |
| **结果准确性** | 中等 | 高（减少误报） |

## 示例输出

```
[START] Starting Ultra Fast Traefik Scanner
==================================================
[GITHUB] Loaded 3 GitHub tokens
[GITHUB] Token abc12345... - Rate limit: 5000/5000
[GITHUB] Token def67890... - Rate limit: 5000/5000
[GITHUB] Token ghi11111... - Rate limit: 5000/5000
[OK] Ultra Fast Traefik Scanner initialized with 16 temp directories
[CONFIG] 16 workers
[PROGRESS] Loaded 0 previously processed repositories
[OUTPUT] Results will be saved to Excel: ... and CSV: ...

[SEARCH] Starting repository search using GitHub code search...
[SEARCH] Searching: forwardedHeaders.insecure (YAML)
[FOUND] Found 150 code results
[PROGRESS] Loaded 50 repositories from forwardedHeaders.insecure (YAML)
[COMPLETE] Processed 150 repositories from forwardedHeaders.insecure (YAML)
...
[TOTAL] Found 500 unique repositories
[PROCESS] Processing 500 repositories with 16 workers
[PROGRESS] 20/500 repositories processed (25.3 repos/min)
[MATCH] owner/repo - 2 matches found
...
[STATS] Scan completed. Final statistics:
   Total repositories processed: 500
   Total matches: 25
   Duration: 1200.00 seconds
   Average speed: 25.0 repos/minute
```

## 总结

`ultra_fast_traefik_scanner.py` 是一个强大的 Traefik 配置搜索工具，具有以下优势：

1. **快速**：多线程并发处理，20-50 仓库/分钟
2. **全面**：搜索多种配置模式，自动验证
3. **可靠**：支持断点续传，自动错误处理
4. **易用**：简单的配置，清晰的输出

使用这个工具可以快速发现 GitHub 上存在潜在风险的 Traefik 配置！

