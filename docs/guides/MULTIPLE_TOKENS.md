# 多个 Token 使用指南

## Token 数量限制

### 理论上限
- **没有硬编码限制**：代码中没有限制 token 数量
- **实际建议**：5-10 个 token 最合适
- **最大推荐**：不超过 20 个 token

### 为什么有建议上限？

1. **GitHub API 限制**
   - 每个 token：每分钟 30 次请求
   - 10 个 token = 每分钟 300 次请求
   - 20 个 token = 每分钟 600 次请求
   - **超过这个速度意义不大**（网络和克隆速度成为瓶颈）

2. **管理复杂度**
   - 太多 token 难以管理
   - 需要定期轮换和维护

3. **资源消耗**
   - 每个 token 需要初始化 GitHub 客户端
   - 内存占用增加

## 如何设置多个 Token

### 方法 1: 在 .env 文件中（推荐）

```bash
# 用逗号分隔
GITHUB_TOKEN=token1,token2,token3,token4,token5
```

### 方法 2: 换行分隔（也支持）

```bash
# .env 文件内容
GITHUB_TOKEN=token1
token2
token3
token4
token5
```

## 性能提升对比

| Token 数量 | 每分钟请求数 | 速度提升 | 推荐场景 |
|-----------|------------|---------|---------|
| 1 个 | 30 次 | 基准 | 测试/小规模扫描 |
| 3 个 | 90 次 | 3x | 中等规模扫描 |
| 5 个 | 150 次 | 5x | **推荐配置** |
| 10 个 | 300 次 | 10x | 大规模扫描 |
| 20 个 | 600 次 | 20x | 极限性能（不推荐） |

## 实际使用建议

### 推荐配置：5 个 Token

```bash
# .env 文件
GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3,ghp_token4,ghp_token5
```

**为什么 5 个？**
- ✅ 速度提升明显（5 倍）
- ✅ 管理简单
- ✅ 资源消耗合理
- ✅ 足够应对大多数场景

### 高性能配置：10 个 Token

```bash
# .env 文件
GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3,ghp_token4,ghp_token5,ghp_token6,ghp_token7,ghp_token8,ghp_token9,ghp_token10
```

**适用场景**：
- 大规模扫描（数千个仓库）
- 需要快速完成扫描
- 有足够的 token 资源

## 如何添加多个 Token

### 步骤 1: 获取多个 Token

1. 访问：https://github.com/settings/tokens
2. 为每个 token 创建不同的名称（便于管理）：
   - `traefik_scanner_1`
   - `traefik_scanner_2`
   - `traefik_scanner_3`
   - ...

### 步骤 2: 更新 .env 文件

```bash
cd /home/rui/ci/security_research

# 编辑 .env 文件
nano .env

# 或者使用 echo（替换为你的实际 token）
cat > .env << 'EOF'
GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3,ghp_token4,ghp_token5
EOF

# 设置权限
chmod 600 .env
```

### 步骤 3: 验证设置

```bash
# 检查 token 数量
python3 << 'EOF'
import os
from dotenv import load_dotenv

load_dotenv()
token = os.getenv('GITHUB_TOKEN')
if token:
    tokens = [t.strip() for t in token.replace('\n', ',').split(',') if t.strip()]
    print(f"✓ 检测到 {len(tokens)} 个 token")
    for i, t in enumerate(tokens, 1):
        print(f"  Token {i}: {t[:10]}...")
else:
    print("✗ 未找到 token")
EOF
```

## 代码如何工作

### Token 解析逻辑

```python
# 代码会自动解析
if ',' in self.github_token:
    # 逗号分隔
    self.github_tokens = [token.strip() for token in self.github_token.split(',')]
elif '\n' in self.github_token:
    # 换行分隔
    self.github_tokens = [token.strip() for token in self.github_token.split('\n') if token.strip()]
else:
    # 单个 token
    self.github_tokens = [self.github_token]
```

### Token 选择策略

脚本会自动：
1. **选择最佳 token**：基于剩余请求数和最后使用时间
2. **自动轮换**：避免单个 token 过载
3. **错误处理**：如果某个 token 出错，自动切换到其他 token

## 性能测试

### 测试不同 Token 数量的效果

```bash
# 1 个 token
time python3 scripts/github/ultra_fast_traefik_scanner.py --workers 8

# 5 个 token
time python3 scripts/github/ultra_fast_traefik_scanner.py --workers 16

# 10 个 token
time python3 scripts/github/ultra_fast_traefik_scanner.py --workers 32
```

## 注意事项

### 1. Token 管理

- **命名规范**：使用有意义的名称（如 `traefik_scanner_1`）
- **定期轮换**：每 90 天更换一次
- **及时撤销**：不用的 token 立即撤销

### 2. 速率限制

即使有多个 token，也要注意：
- **搜索 API**：每分钟 30 次（每个 token）
- **其他 API**：可能有不同限制
- **网络速度**：可能成为瓶颈

### 3. 成本考虑

- **免费账户**：可以创建多个 token，无额外成本
- **组织账户**：可能有 token 数量限制

## 常见问题

### Q1: 最多可以放多少个 token？

**A**: 理论上没有限制，但建议：
- **推荐**：5-10 个
- **最大**：不超过 20 个
- **超过 20 个**：收益递减，管理复杂

### Q2: 多个 token 会提高多少速度？

**A**: 
- 3 个 token ≈ 3 倍速度
- 5 个 token ≈ 5 倍速度
- 10 个 token ≈ 10 倍速度
- **但实际速度还受网络和克隆速度限制**

### Q3: 所有 token 都需要相同权限吗？

**A**: 是的，所有 token 都需要 `public_repo` 权限。

### Q4: 可以混合使用不同类型的 token 吗？

**A**: 可以，但建议使用相同类型的 token（都是 Classic 或都是 Fine-grained）。

### Q5: 如果某个 token 失效了怎么办？

**A**: 脚本会自动跳过失效的 token，使用其他可用的 token。但建议定期检查所有 token 的有效性。

## 最佳实践

### 推荐配置

```bash
# .env 文件
# 5 个 token - 平衡性能和复杂度
GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3,ghp_token4,ghp_token5
```

### 工作线程数建议

| Token 数量 | 推荐工作线程数 |
|-----------|--------------|
| 1-3 个 | 8-16 |
| 5 个 | 16-24 |
| 10 个 | 24-32 |
| 20 个 | 32-48 |

### 监控和优化

```bash
# 查看日志中的 token 使用情况
grep "GITHUB.*Token" traefik_scan_results/traefik_scanner.log

# 查看速率限制信息
grep "Rate limit" traefik_scan_results/traefik_scanner.log
```

## 总结

- ✅ **推荐数量**：5 个 token（平衡性能和复杂度）
- ✅ **最大推荐**：10 个 token（大规模扫描）
- ✅ **理论上限**：无限制，但超过 20 个收益递减
- ✅ **设置方法**：在 `.env` 文件中用逗号分隔
- ✅ **自动管理**：脚本自动轮换和选择最佳 token

