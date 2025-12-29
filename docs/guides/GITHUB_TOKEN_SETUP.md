# GitHub Token 设置指南

## 为什么需要 Token？

`ultra_fast_traefik_scanner.py` 需要 GitHub token 来：

1. **使用 GitHub API 搜索代码**
   - 未认证用户：每分钟 10 次请求
   - 认证用户：每分钟 30 次请求
   - **使用 token 可以提高 3 倍速度**

2. **获取仓库详细信息**
   - Stars 数量
   - 创建年份
   - 仓库 URL
   - 克隆 URL

3. **克隆仓库**
   - 需要访问仓库的克隆权限
   - 私有仓库需要 token（虽然我们只搜索公开仓库）

## 如何获取 GitHub Token

### 方法 1: 创建 Personal Access Token (Classic)

1. **访问 GitHub 设置**
   - 打开：https://github.com/settings/tokens
   - 或者：GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)

2. **生成新 Token**
   - 点击 "Generate new token" → "Generate new token (classic)"
   - 输入 Token 名称（例如：`traefik_scanner`）
   - 选择过期时间（建议：90 天或自定义）

3. **选择权限（Scopes）**
   - ✅ **`public_repo`** - 访问公开仓库（必需）
   - ✅ **`repo`** - 完整仓库访问（如果需要访问私有仓库）
   - ❌ 其他权限不需要

4. **生成并复制 Token**
   - 点击 "Generate token"
   - **重要**：立即复制 token，因为之后无法再次查看
   - 格式：`ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 方法 2: 创建 Fine-grained Personal Access Token (推荐)

1. **访问 GitHub 设置**
   - 打开：https://github.com/settings/tokens
   - 点击 "Generate new token" → "Generate new token (fine-grained)"

2. **配置 Token**
   - **Token name**: `traefik_scanner`
   - **Expiration**: 90 days 或自定义
   - **Repository access**: All repositories（或选择特定仓库）

3. **选择权限**
   - **Repository permissions**:
     - ✅ **Contents**: Read-only
     - ✅ **Metadata**: Read-only
   - **Account permissions**: 不需要

4. **生成并复制 Token**
   - 点击 "Generate token"
   - 立即复制 token

## 如何设置 Token

### 方法 1: 使用 `.env` 文件（推荐）

1. **创建 `.env` 文件**
   ```bash
   cd /home/rui/ci/security_research
   touch .env
   ```

2. **添加 Token**
   ```bash
   # 单个 token
   GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   
   # 多个 token（用逗号分隔，提高速度）
   GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3
   ```

3. **保护 `.env` 文件**
   ```bash
   chmod 600 .env
   ```

### 方法 2: 使用环境变量

```bash
# 单个 token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 多个 token
export GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3
```

### 方法 3: 使用配置文件（不推荐，安全性较低）

```bash
# 创建 token 文件
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .github_token
chmod 600 .github_token
```

## 多个 Token 的优势

使用多个 token 可以：

1. **提高搜索速度**
   - 每个 token 每分钟 30 次请求
   - 3 个 token = 每分钟 90 次请求
   - **速度提升 3 倍**

2. **避免速率限制**
   - 如果一个 token 达到限制，自动切换到下一个
   - 减少等待时间

3. **提高可靠性**
   - 如果一个 token 失效，其他 token 仍可使用

## Token 安全建议

### ✅ 应该做的

1. **使用 `.env` 文件**
   - 不要将 token 提交到 Git
   - 将 `.env` 添加到 `.gitignore`

2. **限制权限**
   - 只授予必要的权限（`public_repo` 或 `Contents: Read-only`）
   - 使用 Fine-grained token 更安全

3. **定期轮换**
   - 每 90 天更换一次 token
   - 删除不再使用的 token

4. **保护文件权限**
   ```bash
   chmod 600 .env
   chmod 600 .github_token
   ```

### ❌ 不应该做的

1. **不要将 token 提交到 Git**
   ```bash
   # 确保 .env 在 .gitignore 中
   echo ".env" >> .gitignore
   echo ".github_token" >> .gitignore
   ```

2. **不要在代码中硬编码 token**
   ```python
   # ❌ 错误
   token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   
   # ✅ 正确
   token = os.getenv('GITHUB_TOKEN')
   ```

3. **不要分享 token**
   - 每个用户应该使用自己的 token
   - 如果 token 泄露，立即撤销

## 验证 Token 是否有效

```bash
# 使用 curl 测试
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user

# 应该返回你的用户信息
```

## 常见问题

### Q1: Token 过期了怎么办？

**A**: 重新生成一个新 token，更新 `.env` 文件。

### Q2: 如何撤销 Token？

**A**: 
1. 访问：https://github.com/settings/tokens
2. 找到对应的 token
3. 点击 "Revoke"

### Q3: 可以使用 GitHub CLI 的 token 吗？

**A**: 可以，但需要确保 token 有 `public_repo` 权限。

### Q4: 为什么需要多个 token？

**A**: 
- 单个 token：每分钟 30 次请求
- 多个 token：可以并行使用，提高速度
- 例如：3 个 token = 每分钟 90 次请求

### Q5: Token 有使用限制吗？

**A**: 
- **认证用户**：每分钟 30 次请求，每小时 5000 次请求
- **未认证用户**：每分钟 10 次请求，每小时 30 次请求
- 使用多个 token 可以绕过这些限制

## 快速开始

```bash
# 1. 创建 .env 文件
cat > .env << EOF
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# 2. 设置文件权限
chmod 600 .env

# 3. 验证 token
curl -H "Authorization: token $(grep GITHUB_TOKEN .env | cut -d= -f2)" \
     https://api.github.com/user

# 4. 运行扫描器
python3 scripts/github/ultra_fast_traefik_scanner.py
```

## 总结

- ✅ **需要 token**：使用 GitHub API 搜索代码和获取仓库信息
- ✅ **推荐使用 `.env` 文件**：安全且方便
- ✅ **多个 token 更好**：提高速度和可靠性
- ✅ **定期轮换**：每 90 天更换一次
- ❌ **不要提交到 Git**：保护 token 安全

