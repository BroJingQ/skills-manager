---
name: proxy-local
description: 当用户需要开启、关闭或查看本地 Clash 代理状态时触发。包括 "开启代理"、"关闭代理"、"代理状态"、"使用代理"、"不用代理"、"设置代理"、"取消代理"等相关请求。
---

# 本地 Clash 代理管理

这个 skill 帮助用户管理本地 Clash 代理，自动在网络命令中添加或移除代理环境变量。

## 代理配置

- **默认地址**: `http://127.0.0.1:7890`
- **协议**: HTTP/HTTPS
- **状态文件**: `~/.claude_proxy_state`

## 使用方法

### 查看当前状态

**用户说**: "代理状态" / "查看代理" / "proxy status"

**Claude 执行**:
```bash
bash ~/.claude/skills/proxy-local/scripts/proxy.sh status
```

### 开启代理

**用户说**: "开启代理" / "使用代理" / "proxy on"

**Claude 执行**:
```bash
bash ~/.claude/skills/proxy-local/scripts/proxy.sh on
```

然后显示状态确认:
```bash
bash ~/.claude/skills/proxy-local/scripts/proxy.sh status
```

### 关闭代理

**用户说**: "关闭代理" / "取消代理" / "不用代理了" / "proxy off"

**Claude 执行**:
```bash
bash ~/.claude/skills/proxy-local/scripts/proxy.sh off
```

### 测试代理连接

**用户说**: "测试代理" / "代理能用吗" / "检查代理"

**Claude 执行**:
```bash
bash ~/.claude/skills/proxy-local/scripts/proxy.sh test
```

## 自动代理功能

当代理模式**开启**时，Claude 在执行以下网络命令时会自动添加代理环境变量：

**网络工具**:
- `curl` → `HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 curl ...`
- `wget` → `HTTP_PROXY=... wget ...`

**包管理器**:
- `npm install` → `HTTP_PROXY=... npm install ...`
- `yarn` → `HTTP_PROXY=... yarn ...`
- `pnpm` → `HTTP_PROXY=... pnpm ...`
- `pip install` → `HTTP_PROXY=... pip install ...`
- `gem install` → `HTTP_PROXY=... gem install ...`

**Git 操作**:
- `git clone` → `HTTP_PROXY=... git clone ...`
- `git pull/fetch/push` → `HTTP_PROXY=... git ...`

**GitHub CLI**:
- `gh` 命令 → 自动使用 `gh config` 配置的代理
- `gh repo clone` → 通过 gh 配置的代理连接
- `gh pr list/create` → 通过 gh 配置的代理连接
- `gh auth` → 通过 gh 配置的代理连接

当代理开启时，GitHub CLI 会自动配置 http_proxy 和 https_proxy。关闭代理时会自动清除这些配置。

**其他工具**:
- `docker pull/build` → `HTTP_PROXY=... docker ...`
- `npx` → `HTTP_PROXY=... npx ...`
- `cargo` → `HTTP_PROXY=... cargo ...`

### 如何检查代理状态

在执行网络命令前，Claude 应该检查代理状态：

```bash
if [ -f "$HOME/.claude_proxy_state" ]; then
    PROXY_URL=$(cat "$HOME/.claude_proxy_state")
    echo "代理已开启: $PROXY_URL"
else
    echo "代理未开启"
fi
```

### 如何添加代理到命令

如果代理已开启，在执行网络相关命令前添加环境变量：

```bash
PROXY_URL=$(cat "$HOME/.claude_proxy_state" 2>/dev/null || echo "")
if [ -n "$PROXY_URL" ]; then
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
fi
```

## 使用示例

### 场景1: 开启代理并安装 npm 包

```
用户: 开启代理
Claude: ✓ 代理模式已开启
        代理地址: http://127.0.0.1:7890

用户: 帮我安装 express
Claude: [检测到代理已开启，自动使用代理]
        执行: npm install express
        → HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 npm install express
```

### 场景2: 关闭代理

```
用户: 关闭代理
Claude: ✓ 代理模式已关闭
        后续命令将不再使用代理

用户: 帮我安装 lodash
Claude: [代理已关闭]
        执行: npm install lodash
```

### 场景3: 使用 GitHub CLI

```
用户: 开启代理
Claude: ✓ 代理模式已开启
        代理地址: http://127.0.0.1:7890
        GitHub CLI: 已配置代理

用户: 查看我的 PR 列表
Claude: 执行: gh pr list
        → 自动使用 gh config 中配置的代理
```

### 场景4: 检查代理状态

```
用户: 代理状态
Claude: 状态: 开启
        代理地址: http://127.0.0.1:7890
        连接测试: ✓ 正常
```

## 手动使用代理脚本

用户也可以直接在终端使用代理脚本：

```bash
# 开启代理
bash ~/.claude/skills/proxy-local/scripts/proxy.sh on

# 在当前 shell 会话中使用代理
source <(bash ~/.claude/skills/proxy-local/scripts/proxy.sh env)

# 然后执行网络命令
curl -I https://github.com
npm install axios

# 关闭代理
bash ~/.claude/skills/proxy-local/scripts/proxy.sh off
```

## 自定义代理地址

如果需要使用不同的代理地址：

```bash
export CLASH_PROXY_URL=http://127.0.0.1:1080
bash ~/.claude/skills/proxy-local/scripts/proxy.sh on
```

## 注意事项

1. **代理状态只在当前用户会话有效**，不会自动应用到新终端窗口
2. 确保 Clash 客户端正在运行且监听 7890 端口（或自定义端口）
3. 本地地址（localhost, 127.0.0.1）通常会自动绕过代理
4. 如果代理连接失败，脚本会提示错误

## 故障排除

### 代理开启但无法连接

```bash
# 测试代理连接
bash ~/.claude/skills/proxy-local/scripts/proxy.sh test

# 检查 Clash 是否运行
curl -x http://127.0.0.1:7890 -I https://github.com
```

### 某些命令不走代理

某些工具可能需要额外的配置：
- **Git**: `git config --global http.proxy http://127.0.0.1:7890`
- **GitHub CLI**: 开启代理时会自动配置，手动设置可用 `gh config set http_proxy http://127.0.0.1:7890`
- **npm**: `npm config set proxy http://127.0.0.1:7890`
- **pip**: 使用 `--proxy` 参数或环境变量

### 验证 GitHub CLI 代理配置

```bash
# 查看当前 gh 代理配置
gh config get http_proxy
gh config get https_proxy

# 手动清除 gh 代理配置
gh config set http_proxy ""
gh config set https_proxy ""
```
