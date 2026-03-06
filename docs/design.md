# Skills Manager 设计方案

> 一个用于管理 Claude Code Skills 的云端同步系统，区分三方 Skills 和自研 Skills，实现智能导入和灵活部署。
>
> **设计版本: 1.2** | **最后更新: 2026-03-07**

## 设计变更记录

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.2 | 2026-03-07 | 改为两层架构：交互层 Skill + 实现层项目；明确安装和使用流程 |
| 1.1 | 2026-03-07 | 脚本实现从 Node.js 改为纯 Bash，增加 Claude Code Prompts 支持 |
| 1.0 | 2026-03-07 | 初始设计方案 |

## 设计目标

1. **双向同步**：支持从全局环境导入 Skills，也支持将 Skills 部署到全局环境
2. **来源分离**：清晰区分三方下载的 Skills 和自研 Skills
3. **更新策略**：三方 Skills 从官方渠道更新，自研 Skills 从本项目同步
4. **多机同步**：在新机器上可一次性恢复所有 Skills 配置
5. **零依赖**：核心脚本使用 Bash，无需 Node/Python 等运行时环境

## 架构设计：两层分离

本项目采用**两层架构**，兼顾交互便捷性和批量操作能力：

```
┌─────────────────────────────────────────────────────────────┐
│                      交互层（Skill）                         │
│                 ~/.claude/skills/skills-manager/            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  SKILL.md                                             │  │
│  │  - 自然语言理解                                        │  │
│  │  - 调用底层脚本                                        │  │
│  │  - 交互式确认                                          │  │
│  └───────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ 调用
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     实现层（项目）                           │
│              ~/projects/skills-manager/                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  scripts/   │  │  configs/   │  │     skills/         │  │
│  │  - import   │  │  - registry │  │  - local/           │  │
│  │  - install  │  │  - settings │  │  - remote/          │  │
│  │  - detect   │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 为什么这样设计？

| 层级 | 用途 | 使用场景 |
|------|------|----------|
| **交互层 (Skill)** | 自然语言触发，交互式操作 | 日常使用、快速同步 |
| **实现层 (项目)** | 完整脚本、数据存储、Git 版本控制 | 批量操作、CI/CD、数据备份 |

### 优势

1. **灵活使用**：既可以对 Claude 说"导入 skills"，也可以直接运行脚本
2. **数据安全**：核心数据和脚本在独立项目中，受 Git 保护
3. **易于更新**：Skill 层只是薄包装，更新项目即可更新功能
4. **批量操作**：脚本可直接用于自动化流程

## 安装流程

### 首次安装（新机器）

```bash
# 1. 克隆项目到工作目录
cd ~/projects
git clone <your-repo> skills-manager
cd skills-manager

# 2. 运行安装脚本（安装 Skill 到 Claude Code）
./scripts/setup.sh

# 3. 验证安装
# 重启 Claude Code 或等待技能刷新
# 输入: skills-manager
```

### setup.sh 执行步骤

```
📦 Skills Manager 安装流程
│
├─ 1. 检测环境
│   ├─ 检查 Claude Code 是否安装
│   ├─ 检查 ~/.claude/skills/ 目录是否存在
│   └─ 检查 jq 是否安装（可选依赖）
│
├─ 2. 创建 Skill 目录
│   └─ 创建 ~/.claude/skills/skills-manager/
│
├─ 3. 生成 SKILL.md
│   └─ 将项目路径注入 SKILL.md
│   └─ 写入 ~/.claude/skills/skills-manager/SKILL.md
│
├─ 4. 设置执行权限
│   └─ chmod +x scripts/*.sh
│
└─ 5. 创建项目结构（如不存在）
    ├─ mkdir -p skills/local
    ├─ mkdir -p skills/remote
    └─ 初始化 configs/skills-registry.json
```

### 安装验证

```bash
# 方式 1：通过 Claude Code
claude
# 然后输入: skills-manager

# 方式 2：直接测试脚本
./scripts/import-skills.sh --help
./scripts/install-skills.sh --help
```

## 目录结构

```
skills-manager/
├── README.md                       # 项目说明
├── docs/
│   └── design.md                   # 本设计文档
├── configs/
│   └── skills-registry.json        # Skills 注册表（核心配置）
├── scripts/                        # Bash 脚本（跨平台：Mac/Linux/Windows Git Bash）
│   ├── import-skills.sh            # 导入：全局 → 项目
│   ├── install-skills.sh           # 安装：项目 → 全局
│   └── detect-skill-source.sh      # Skill 来源检测工具
├── skills/
│   ├── local/                      # 自研 Skills（完整代码，Git 追踪）
│   │   └── .gitkeep
│   └── remote/                     # 三方 Skills（仅元数据）
│       └── .gitkeep
├── backups/                        # 备份目录（可选）
│   └── .gitkeep
└── .claude/
    └── prompts/                    # Claude Code Prompts（可选）
        └── skills-manager.md       # 便捷命令定义
```

## 核心配置：skills-registry.json

```json
{
  "version": "1.0",
  "lastUpdated": "2026-03-07T12:00:00Z",
  "skills": {
    "my-custom-tool": {
      "type": "local",
      "name": "my-custom-tool",
      "description": "我自己创建的自定义工具",
      "version": "1.0.0",
      "path": "skills/local/my-custom-tool",
      "detectedAt": "2026-03-07T10:30:00Z",
      "confirmedByUser": true,
      "metadata": {
        "author": "me",
        "tags": ["custom", "productivity"]
      }
    },
    "find-skills": {
      "type": "remote",
      "name": "find-skills",
      "description": "搜索和发现技能",
      "version": "latest",
      "source": "github/anthropics/skills",
      "installCommand": "npx skills add find-skills -g -y",
      "detectedAt": "2026-03-07T10:30:00Z",
      "confirmedByUser": true,
      "metadata": {
        "official": true,
        "category": "utility"
      }
    }
  },
  "settings": {
    "autoDetectOnImport": true,
    "promptOnUncertain": true,
    "defaultInstallMethod": "symlink"
  }
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | string | `local`（自研）或 `remote`（三方） |
| `path` | string | 仅 local 类型有效，指向本地代码路径 |
| `source` | string | 仅 remote 类型有效，来源标识 |
| `installCommand` | string | 仅 remote 类型有效，安装命令 |
| `confirmedByUser` | boolean | 是否经过用户确认 |
| `detectedAt` | string | 首次检测时间（ISO 8601 格式） |

## 脚本设计

### 为什么使用 Bash？

| 方案 | 依赖 | 跨平台 | 维护成本 |
|------|------|--------|----------|
| Node.js | 需要安装 Node | ✅ | 低 |
| Python | 需要安装 Python | ✅ | 低 |
| Bash | Git Bash（Claude Code 已内置） | ✅ Mac/Linux/Win | 最低 |
| PowerShell | Windows 原生 | ❌ Mac/Linux | 中 |

**选择 Bash 的原因**：
- Claude Code Windows 版已依赖 Git Bash，无需额外安装
- 纯文本处理、文件操作、符号链接等操作原生支持
- 脚本可直接在 Claude Code 终端中执行

### 1. import-skills.sh（导入脚本）

**功能**：扫描全局 `~/.claude/skills/`，识别并导入到本项目

**依赖**：`bash`, `jq`（可选，用于处理 JSON）

**工作流程**：

```bash
#!/bin/bash

SKILLS_DIR="$HOME/.claude/skills"
REGISTRY_FILE="configs/skills-registry.json"

echo "🔍 扫描 Skills 目录: $SKILLS_DIR"

# 遍历全局 skills 目录
for skill_path in "$SKILLS_DIR"/*; do
    [ -d "$skill_path" ] || continue

    skill_name=$(basename "$skill_path")
    echo "检查: $skill_name"

    # 1. 检查是否已在 registry 中
    if grep -q "\"$skill_name\"" "$REGISTRY_FILE" 2>/dev/null; then
        echo "  ✓ 已注册，跳过"
        continue
    fi

    # 2. 自动检测来源
    source_type=$(detect_skill_source "$skill_path")
    confidence=$(echo "$source_type" | cut -d':' -f1)
    type=$(echo "$source_type" | cut -d':' -f2)
    reason=$(echo "$source_type" | cut -d':' -f3-)

    echo "  检测结果: $type (置信度: $confidence%) - $reason"

    # 3. 根据置信度处理
    # >=70: 高置信度，自动处理
    # >=40: 中等置信度，自动处理
    # <40:  低置信度，询问用户
    if [ "$confidence" -lt 40 ]; then
        echo "  无法自动确定来源，请手动选择："
        echo "    [1] 这是我创建的 skill（local）"
        echo "    [2] 这是三方下载的 skill（remote）"
        echo "    [3] 跳过"
        read -p "  选择: " choice

        case $choice in
            1) type="local" ;;
            2) type="remote" ;;
            *) continue ;;
        esac
    fi

    # 4. 根据类型处理
    if [ "$type" = "local" ]; then
        # 复制完整代码
        cp -r "$skill_path" "skills/local/$skill_name"
        echo "  ✓ 已复制到 skills/local/$skill_name"
    else
        # 创建元数据
        mkdir -p "skills/remote/$skill_name"
        cat > "skills/remote/$skill_name/meta.json" << EOF
{
  "name": "$skill_name",
  "source": "unknown",
  "installCommand": "npx skills add $skill_name -g -y"
}
EOF
        echo "  ✓ 已创建元数据"
    fi

    # 5. 更新 registry
    update_registry "$skill_name" "$type"
done

echo "✅ 导入完成"
```

**交互示例**：

```
🔍 扫描 Skills 目录: /Users/admin/.claude/skills

检查: my-awesome-tool
  检测结果: unknown (置信度: 0%) - 无法识别来源 (remote信号:15)
  无法自动确定来源，请手动选择：
    [1] 这是我创建的 skill（local）
    [2] 这是三方下载的 skill（remote）
    [3] 跳过
  选择: 1
  ✓ 已复制到 skills/local/my-awesome-tool

检查: find-skills
  检测结果: remote (置信度: 65%) - 标准 frontmatter 格式; 提到 Skills CLI 或官方来源; 文档内容完整
  ✓ 已创建元数据

检查: skill-creator
  检测结果: remote (置信度: 70%) - 标准 frontmatter 格式; 文档内容完整; 包含开源许可证; 标准目录结构(5个)
  ✓ 已创建元数据

✅ 导入完成
```

### 2. install-skills.sh（安装脚本）

**功能**：读取本项目配置，部署 Skills 到全局环境

**工作流程**：

```bash
#!/bin/bash

REGISTRY_FILE="configs/skills-registry.json"
TARGET_DIR="$HOME/.claude/skills"

echo "📦 安装 Skills 到: $TARGET_DIR"

# 解析 registry 并处理每个 skill
# （使用 jq 或 grep/sed 解析 JSON）

# 示例：处理 local skills
install_local_skill() {
    local name=$1
    local source_path="$PWD/skills/local/$name"
    local target_path="$TARGET_DIR/$name"

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        echo "  ⚠️ 源目录不存在: $source_path"
        return 1
    fi

    # 如果目标已存在，备份
    if [ -e "$target_path" ]; then
        if [ -L "$target_path" ]; then
            # 已是符号链接，检查是否指向正确位置
            current_target=$(readlink "$target_path")
            if [ "$current_target" = "$source_path" ]; then
                echo "  ✓ $name (已链接)"
                return 0
            fi
        fi
        echo "  ⚠️ $name 已存在，备份为 $name.bak"
        mv "$target_path" "$target_path.bak"
    fi

    # 创建符号链接
    ln -s "$source_path" "$target_path"
    echo "  ✓ $name → $source_path"
}

# 处理 remote skills
install_remote_skill() {
    local name=$1
    local install_cmd=$2

    echo "  📥 $name (执行: $install_cmd)"
    eval "$install_cmd"
}

echo ""
echo "=== 安装报告 ==="
echo ""
```

**安装报告示例**：

```
📦 安装 Skills 到: /Users/admin/.claude/skills

Local Skills（符号链接）:
  ✓ my-custom-tool → /Users/admin/projects/skills-manager/skills/local/my-custom-tool
  ✓ my-helper → /Users/admin/projects/skills-manager/skills/local/my-helper

Remote Skills（官方下载）:
  📥 find-skills (执行: npx skills add find-skills -g -y)
  ✅ find-skills 安装成功

⚠️  冲突:
  my-old-skill: 全局已存在，来源不明
  建议: 运行 ./scripts/import-skills.sh 先识别来源

=== 安装完成 ===
```

### 3. detect-skill-source.sh（检测工具）

**功能**：独立工具，检测单个 skill 的来源类型

**输出格式**：`置信度:类型:原因`

```bash
#!/bin/bash
#
# 检测 Skill 来源类型
# 输出格式：置信度:类型:原因
#

detect_skill_source() {
    local skill_path="$1"
    local skill_name=$(basename "$skill_path")
    local remote_score=0
    local reasons=""

    # 获取当前用户名（兼容 Windows 和 Unix）
    local current_user="${USER:-${USERNAME:-$(whoami)}}"

    # ========== Local 特征检测 ==========

    # 1. 检查本地标记文件（最强 local 信号）
    if [ -f "$skill_path/.custom-skill" ]; then
        echo "100:local:本地标记文件 .custom-skill 存在"
        return
    fi

    # 2. 检查 SKILL.md 中的 author
    if [ -f "$skill_path/SKILL.md" ]; then
        local author
        author=$(grep -i "^author:" "$skill_path/SKILL.md" 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "")
        # 确保 author 非空且匹配当前用户
        if [ -n "$author" ] && { [ "$author" = "me" ] || [ "$author" = "$current_user" ]; }; then
            echo "95:local:作者匹配当前用户 ($author)"
            return
        fi
    fi

    # 3. 检查 git remote
    if [ -d "$skill_path/.git" ]; then
        local remote_url
        remote_url=$(cd "$skill_path" && git remote get-url origin 2>/dev/null || echo "")

        # 检查是否是用户自己的仓库
        local git_user
        git_user=$(git config --global user.name 2>/dev/null || echo "$current_user")

        if [ -n "$git_user" ] && echo "$remote_url" | grep -qi "$git_user"; then
            echo "95:local:Git remote 指向个人仓库"
            return
        fi

        # 检查是否是官方/知名仓库
        if echo "$remote_url" | grep -qiE "(anthropics|vercel-labs|github.com/(anthropics|vercel))"; then
            echo "90:remote:Git remote 指向官方仓库"
            return
        fi
    fi

    # 4. 检查是否是符号链接（指向本项目的 local skill）
    if [ -L "$skill_path" ]; then
        local link_target
        link_target=$(readlink "$skill_path")
        if echo "$link_target" | grep -q "$PROJECT_DIR"; then
            echo "85:local:符号链接指向本项目"
            return
        fi
    fi

    # ========== Remote 特征检测（评分制）==========

    # 5. 检查 SKILL.md 格式和内容
    if [ -f "$skill_path/SKILL.md" ]; then
        # 5.1 检查是否有标准 frontmatter（YAML 头部）
        if head -10 "$skill_path/SKILL.md" | grep -q "^---$"; then
            if head -10 "$skill_path/SKILL.md" | grep -q "^name:"; then
                remote_score=$((remote_score + 25))
                reasons="$reasons; 标准 frontmatter 格式"
            fi
        fi

        # 5.2 检查是否提到 Skills CLI 或官方网址
        if grep -qi "npx skills" "$skill_path/SKILL.md" || \
           grep -qi "skills.sh" "$skill_path/SKILL.md" || \
           grep -qi "github.com/anthropics" "$skill_path/SKILL.md"; then
            remote_score=$((remote_score + 30))
            reasons="$reasons; 提到 Skills CLI 或官方来源"
        fi

        # 5.3 检查内容长度和结构（remote skill 通常内容更完整）
        local line_count
        line_count=$(wc -l < "$skill_path/SKILL.md")
        if [ "$line_count" -gt 50 ]; then
            remote_score=$((remote_score + 10))
            reasons="$reasons; 文档内容完整"
        fi
    fi

    # 6. 检查开源许可证文件（remote skill 通常有 LICENSE）
    if [ -f "$skill_path/LICENSE" ] || [ -f "$skill_path/LICENSE.txt" ] || [ -f "$skill_path/LICENSE.md" ]; then
        remote_score=$((remote_score + 20))
        reasons="$reasons; 包含开源许可证"
    fi

    # 7. 检查标准目录结构（remote skill 通常有标准子目录）
    local standard_dirs=0
    for dir in agents eval-viewer scripts assets references; do
        if [ -d "$skill_path/$dir" ]; then
            standard_dirs=$((standard_dirs + 1))
        fi
    done
    if [ "$standard_dirs" -ge 2 ]; then
        remote_score=$((remote_score + 15))
        reasons="$reasons; 标准目录结构(${standard_dirs}个)"
    fi

    # ========== 综合判断 ==========

    # 去除 reasons 开头的分号和空格
    reasons=$(echo "$reasons" | sed 's/^; //')

    # 高置信度 remote (>=70)
    if [ "$remote_score" -ge 70 ]; then
        echo "${remote_score}:remote:${reasons}"
        return
    fi

    # 中等置信度 remote (>=40)
    if [ "$remote_score" -ge 40 ]; then
        echo "${remote_score}:remote:${reasons}"
        return
    fi

    # 无法确定
    echo "0:unknown:无法识别来源 (remote信号:${remote_score})"
}

## Claude Code Prompts 设计

为了更便捷地使用，可以创建 Claude Code Prompts，通过自然语言触发脚本。

### skills-manager.md（Prompt 定义）

```markdown
---
name: skills-manager
description: 管理 Skills 的便捷命令
---

## /import-skills

当用户输入 `/import-skills` 时：

1. 执行 `./scripts/import-skills.sh`
2. 如果脚本输出需要用户确认（低置信度检测），请交互式询问用户
3. 导入完成后，总结结果：
   - 新增了多少个 local skills
   - 新增了多少个 remote skills
   - 有多少个被跳过

## /install-skills

当用户输入 `/install-skills` 时：

1. 执行 `./scripts/install-skills.sh`
2. 显示安装报告
3. 如果有冲突，提供解决建议

## /detect-skill <skill-name>

当用户输入 `/detect-skill xxx` 时：

1. 检查 `~/.claude/skills/xxx` 是否存在
2. 如果存在，执行 `./scripts/detect-skill-source.sh ~/.claude/skills/xxx`
3. 显示检测结果和置信度

## /list-skills

当用户输入 `/list-skills` 时：

1. 读取 `configs/skills-registry.json`
2. 分类显示：
   - Local Skills（自研，带路径）
   - Remote Skills（三方，带来源）
3. 统计总数
```


## 使用流程

### 两种使用方式对比

| 场景 | 方式 | 命令/操作 |
|------|------|-----------|
| **日常交互** | Skill | 对 Claude 说"导入 skills"或"安装 skills" |
| **精确控制** | 脚本 | `./scripts/import-skills.sh --flags` |
| **批量操作** | 脚本 | 直接执行脚本，无交互 |
| **CI/CD** | 脚本 | `./scripts/install-skills.sh --auto` |
| **调试** | 脚本 | 直接看输出，加参数 |

### 场景 1：首次设置（新机器）

```bash
# 1. 克隆项目（包含所有自研 skills）
cd ~/projects
git clone <your-repo> skills-manager
cd skills-manager

# 2. 安装 Skill 到 Claude Code
./scripts/setup.sh

# 3. 安装所有 skills（两种方式任选）

# 方式 A：Skill 方式（交互式）
claude
# 然后输入: "安装所有 skills"

# 方式 B：脚本方式（批量）
./scripts/install-skills.sh
```

### 场景 2：添加新 Skill（全局 → 项目）

**情况 A：在全局安装了三方 skill，想记录到项目**

```bash
# 已在全局安装：npx skills add some-tool

# 导入到项目（两种方式）

# 方式 A：Skill 方式
claude
# 输入: "导入 skills"

# 方式 B：脚本方式
./scripts/import-skills.sh

# 提交到 git
git add .
git commit -m "添加三方 skill: some-tool"
git push
```

**情况 B：创建了新 skill，想同步到项目**

```bash
# 已在 ~/.claude/skills/my-new-skill/ 创建新 skill

# 导入到项目
./scripts/import-skills.sh
# 选择类型: local（自己创建的）

# 提交到 git
git add skills/local/my-new-skill/
git commit -m "添加自研 skill: my-new-skill"
git push
```

### 场景 3：在新机器恢复所有 Skills

```bash
# 1. 克隆项目
cd ~/projects
git clone <your-repo> skills-manager
cd skills-manager

# 2. 安装 Skill
./scripts/setup.sh

# 3. 一键恢复所有 skills
# Skill 方式
claude
# 输入: "安装所有 skills"

# 或脚本方式
./scripts/install-skills.sh
```

### 场景 4：修改自研 Skill

```bash
# 1. 直接编辑
vim skills/local/my-skill/SKILL.md

# 2. 测试（两种方式）
# Skill 方式："测试 my-skill"
# 脚本方式：直接运行 Claude Code 检查

# 3. 提交修改
git add skills/local/my-skill/
git commit -m "更新 my-skill: 修复 xxx"
git push

# 4. 在其他机器同步
# 直接 git pull 即可，符号链接实时生效
```

### 场景 5：更新三方 Skill

```bash
# 1. 在全局更新
npx skills update find-skills

# 2. 同步版本到项目（手动修改 registry）
vim configs/skills-registry.json
# 修改 version 字段

# 3. 提交
git commit -am "更新 find-skills 到 v2.0"
git push
```

## 跨平台注意事项

### Windows (Git Bash)

- 符号链接使用 `ln -s`，在 Git Bash 中正常工作
- 路径使用 `$HOME` 自动适配 (`C:\Users\<name>` 或 `/c/Users/<name>`)
- 脚本需要执行权限：`chmod +x scripts/*.sh`

### Mac / Linux

- 原生支持 Bash 脚本
- 符号链接行为一致

### 可选依赖：jq

虽然脚本尽量使用纯 Bash，但处理 JSON 时 `jq` 会更方便：

```bash
# 检查 jq 是否安装
if command -v jq &> /dev/null; then
    # 使用 jq 处理 JSON
    skills=$(jq -r '.skills | keys[]' "$REGISTRY_FILE")
else
    # 使用 grep/sed 作为降级方案
    skills=$(grep -o '"[^"]*":\s*{' "$REGISTRY_FILE" | grep -v 'version\|settings' | sed 's/":\s*{//g' | sed 's/"//g')
fi
```

## 最佳实践

### 对于自研 Skills

1. **创建标记**：在 skill 目录下创建 `.custom-skill` 文件
   ```bash
   echo '{"createdBy": "me", "createdAt": "'$(date -I)'"}' > my-skill/.custom-skill
   ```

2. **添加作者信息**：在 SKILL.md 中添加 `author: <your-name>`

3. **版本管理**：遵循语义化版本（semver）

4. **文档完善**：在 skill 目录添加 README.md

### 对于三方 Skills

1. **记录来源**：确保 `source` 和 `installCommand` 准确
2. **定期更新**：运行 `npx skills update` 后同步版本号
3. **避免修改**：需要定制时 fork 为 local

### Git 提交规范

```
添加新 skill: <skill-name>
更新 <skill-name>: <变更描述>
删除 <skill-name>: <原因>
重构: <描述>
```

## 扩展计划

### 第一阶段（MVP）
- [ ] 实现 `import-skills.sh`（基础导入）
- [ ] 实现 `install-skills.sh`（基础安装）
- [ ] 实现 `detect-skill-source.sh`（来源检测）
- [ ] 定义 `skills-registry.json` 格式

### 第二阶段（增强）
- [ ] 自动检测逻辑优化
- [ ] 添加 skill 版本对比功能
- [ ] 支持批量导入/导出
- [ ] Claude Code Prompts 完善

### 第三阶段（高级）
- [ ] Git Hooks 自动同步
- [ ] Skills 依赖管理
- [ ] 版本锁定（lock file）

## 附录：文件模板

### 自研 Skill 标记文件

**skills/local/<skill-name>/.custom-skill**
```json
{
  "createdBy": "me",
  "createdAt": "2026-03-07",
  "description": "这是我自定义的 skill"
}
```

### 三方 Skill 元数据

**skills/remote/<skill-name>/meta.json**
```json
{
  "name": "find-skills",
  "source": "github/anthropics/skills",
  "installCommand": "npx skills add find-skills -g -y",
  "homepage": "https://github.com/anthropics/skills/tree/main/find-skills",
  "license": "MIT"
}
```

### 快速初始化脚本

**scripts/init.sh**（可选）
```bash
#!/bin/bash
# 初始化项目目录结构

mkdir -p skills/local skills/remote backups configs

# 创建空的 registry 文件
if [ ! -f "configs/skills-registry.json" ]; then
    cat > configs/skills-registry.json << 'EOF'
{
  "version": "1.0",
  "lastUpdated": "$(date -Iseconds)",
  "skills": {},
  "settings": {
    "autoDetectOnImport": true,
    "promptOnUncertain": true,
    "defaultInstallMethod": "symlink"
  }
}
EOF
fi

echo "✅ 初始化完成"
```

---

*设计版本: 1.1*
*最后更新: 2026-03-07*
