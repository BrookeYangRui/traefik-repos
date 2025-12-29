# Token 放置位置指南

## 📍 推荐位置：项目根目录的 `.env` 文件

### 位置
```
/home/rui/ci/security_research/
├── .env                    ← 把 token 放在这里（推荐）
├── scripts/
│   └── github/
│       └── ultra_fast_traefik_scanner.py
├── docs/
└── ...
```

### 创建步骤

```bash
# 1. 进入项目根目录
cd /home/rui/ci/security_research

# 2. 创建 .env 文件
cat > .env << 'EOF'
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# 3. 设置文件权限（保护 token）
chmod 600 .env

# 4. 验证文件内容（不要显示完整 token）
head -c 20 .env && echo "..."
```

### 文件内容格式

```bash
# .env 文件内容（单行）
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 或者多个 token（用逗号分隔）
GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3
```

## 🔍 代码如何读取 Token？

脚本会按以下顺序查找 token：

1. **`.env` 文件**（项目根目录）← **推荐**
2. **环境变量** `GITHUB_TOKEN`
3. **如果找不到，会报错**

代码逻辑：
```python
# scripts/github/ultra_fast_traefik_scanner.py
from dotenv import load_dotenv

# 自动加载 .env 文件
load_dotenv()

# 读取 token
self.github_token = os.getenv('GITHUB_TOKEN')
if not self.github_token:
    raise ValueError("Please set GITHUB_TOKEN in .env file")
```

## ✅ 完整设置流程

### 步骤 1: 创建 .env 文件

```bash
cd /home/rui/ci/security_research

# 方法 1: 使用 echo（推荐）
echo 'GITHUB_TOKEN=ghp_你的token在这里' > .env

# 方法 2: 使用编辑器
nano .env
# 然后输入：GITHUB_TOKEN=ghp_你的token在这里
```

### 步骤 2: 设置文件权限

```bash
chmod 600 .env
```

### 步骤 3: 验证设置

```bash
# 检查文件是否存在
ls -la .env

# 检查文件权限（应该是 -rw-------）
# 输出示例：-rw------- 1 user user 50 Jan 1 12:00 .env

# 检查文件内容（不显示完整 token）
grep -o 'GITHUB_TOKEN=ghp_[^,]*' .env | head -c 30 && echo "..."
```

### 步骤 4: 添加到 .gitignore（重要！）

```bash
# 确保 .env 不会被提交到 Git
echo ".env" >> .gitignore

# 验证
grep "^\.env$" .gitignore && echo "✓ .env 已在 .gitignore 中"
```

## 🚫 不要放在这些地方

### ❌ 不要放在代码文件中
```python
# ❌ 错误示例
token = "ghp_xxxxxxxxxxxx"  # 不要这样做！
```

### ❌ 不要提交到 Git
```bash
# ❌ 不要这样做
git add .env
git commit -m "Add token"  # 危险！
```

### ❌ 不要放在公共位置
```bash
# ❌ 不要放在这些地方
~/public/.env
/tmp/.env
```

## 🔄 多个 Token 设置

如果需要使用多个 token 提高速度：

```bash
# .env 文件内容
GITHUB_TOKEN=ghp_token1,ghp_token2,ghp_token3
```

脚本会自动：
- 解析多个 token
- 轮换使用
- 选择最佳可用 token

## 🧪 测试 Token 是否生效

```bash
# 方法 1: 使用 Python 测试
python3 << 'EOF'
import os
from dotenv import load_dotenv

load_dotenv()
token = os.getenv('GITHUB_TOKEN')
if token:
    print(f"✓ Token 已加载: {token[:10]}...")
else:
    print("✗ Token 未找到")
EOF

# 方法 2: 直接运行脚本（会显示 token 信息）
python3 scripts/github/ultra_fast_traefik_scanner.py --help
```

## 📝 完整示例

```bash
# 1. 进入项目目录
cd /home/rui/ci/security_research

# 2. 创建 .env 文件
cat > .env << 'EOF'
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# 3. 设置权限
chmod 600 .env

# 4. 添加到 .gitignore
echo ".env" >> .gitignore

# 5. 验证
ls -la .env
grep GITHUB_TOKEN .env | head -c 30 && echo "..."

# 6. 运行脚本
python3 scripts/github/ultra_fast_traefik_scanner.py
```

## 🔐 安全建议

1. **文件权限**
   ```bash
   chmod 600 .env  # 只有你可以读写
   ```

2. **不要分享**
   - 每个用户应该使用自己的 token
   - 不要通过聊天工具发送 token

3. **定期轮换**
   - 每 90 天更换一次 token
   - 旧 token 立即撤销

4. **Git 保护**
   ```bash
   # 确保 .env 在 .gitignore 中
   echo ".env" >> .gitignore
   
   # 如果已经提交，立即删除
   git rm --cached .env
   git commit -m "Remove .env from tracking"
   ```

## ❓ 常见问题

### Q: 可以放在其他位置吗？

**A**: 可以，但需要修改代码或使用环境变量：
```bash
# 使用环境变量
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
python3 scripts/github/ultra_fast_traefik_scanner.py
```

### Q: 文件名必须是 `.env` 吗？

**A**: 是的，`python-dotenv` 默认读取 `.env` 文件。如果要使用其他文件名，需要修改代码。

### Q: 可以放在子目录吗？

**A**: 可以，但需要确保在运行脚本的目录中有 `.env` 文件，或者使用绝对路径。

### Q: 多个项目可以共享同一个 token 吗？

**A**: 可以，但建议：
- 每个项目使用独立的 token
- 如果 token 泄露，影响范围更小
- 更容易管理和撤销

## 📋 快速检查清单

- [ ] 在项目根目录创建了 `.env` 文件
- [ ] 文件内容格式正确：`GITHUB_TOKEN=ghp_xxxxx`
- [ ] 文件权限设置为 600：`chmod 600 .env`
- [ ] `.env` 已添加到 `.gitignore`
- [ ] Token 已测试可用
- [ ] 没有将 token 提交到 Git

## 🎯 总结

**最简单的方法**：

```bash
cd /home/rui/ci/security_research
echo 'GITHUB_TOKEN=ghp_你的token' > .env
chmod 600 .env
echo ".env" >> .gitignore
```

就这么简单！🎉

