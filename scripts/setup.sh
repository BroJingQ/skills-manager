#!/bin/bash
#
# Skills Manager Setup Script
# 安装 Skills Manager 到 Claude Code
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 路径定义
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="${HOME}/.claude/skills"
TARGET_SKILL_DIR="${SKILLS_DIR}/skills-manager"

# 打印函数
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${BLUE}\n📦 $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查环境
check_environment() {
    print_step "1. 检测环境"

    # 检查 Claude Code
    if ! command_exists claude; then
        print_warning "未检测到 Claude Code 命令"
        print_info "请确保已安装: npm install -g @anthropic-ai/claude-code"
    else
        print_success "Claude Code 已安装"
    fi

    # 检查 skills 目录
    if [ ! -d "$SKILLS_DIR" ]; then
        print_info "创建 Claude Code skills 目录: $SKILLS_DIR"
        mkdir -p "$SKILLS_DIR"
    else
        print_success "Skills 目录存在: $SKILLS_DIR"
    fi

    # 检查可选依赖 jq
    if command_exists jq; then
        print_success "jq 已安装（JSON 处理将使用 jq）"
    else
        print_warning "未安装 jq（JSON 处理将使用降级方案）"
        print_info "建议安装 jq 以获得更好的体验: https://stedolan.github.io/jq/"
    fi
}

# 创建 Skill 目录结构
create_skill_structure() {
    print_step "2. 创建 Skill 结构"

    if [ -d "$TARGET_SKILL_DIR" ]; then
        print_warning "Skill 已存在: $TARGET_SKILL_DIR"
        read -p "是否覆盖? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过 Skill 安装"
            return
        fi
        rm -rf "$TARGET_SKILL_DIR"
    fi

    mkdir -p "$TARGET_SKILL_DIR"
    print_success "创建目录: $TARGET_SKILL_DIR"
}

# 生成 SKILL.md
generate_skill_md() {
    print_step "3. 生成 SKILL.md"

    cat > "$TARGET_SKILL_DIR/SKILL.md" << 'EOF'
---
name: skills-manager
description: 管理 Claude Code Skills 的同步和安装，支持导入和部署 skills
---

## 配置

项目路径：{{PROJECT_DIR}}

## 当用户说"导入 skills"、"同步 skills"、"import skills"时：

1. 执行项目目录下的导入脚本：
   ```bash
   cd {{PROJECT_DIR}} && ./scripts/import-skills.sh
   ```

2. 如果脚本输出需要用户确认（检测到未知 skill 且置信度低）：
   - 交互式询问用户每个未知 skill 的类型
   - 选项：local（自研）/ remote（三方）/ skip（跳过）

3. 导入完成后，总结结果：
   - 新增了多少个 local skills（自研）
   - 新增了多少个 remote skills（三方）
   - 有多少个被跳过
   - 提示用户提交到 git：`git add . && git commit -m "更新 skills"`

## 当用户说"安装 skills"、"部署 skills"、"install skills"时：

1. 执行项目目录下的安装脚本：
   ```bash
   cd {{PROJECT_DIR}} && ./scripts/install-skills.sh
   ```

2. 脚本会自动处理：
   - Local skills：创建符号链接 ~/.claude/skills/<name> → 项目/skills/local/<name>
   - Remote skills：执行安装命令从官方渠道下载

3. 显示安装报告：
   - 成功的 local skills 列表
   - 成功的 remote skills 列表
   - 冲突/警告（如有）

## 当用户说"查看 skills"、"列出 skills"、"list skills"时：

1. 读取项目配置文件：
   ```bash
   cat {{PROJECT_DIR}}/configs/skills-registry.json
   ```

2. 分类显示：
   - Local Skills（自研）：显示名称、版本、路径
   - Remote Skills（三方）：显示名称、来源、安装命令
   - 统计：local 数量、remote 数量、总数

## 当用户说"帮助"、"怎么用"时：

介绍 Skills Manager 的基本用法：

**核心功能：**
- 导入（import）：从全局 ~/.claude/skills/ 导入到项目
- 安装（install）：从项目部署到全局 ~/.claude/skills/

**使用方式：**
1. 交互方式：直接对我说"导入 skills"或"安装 skills"
2. 脚本方式：直接运行 ./scripts/import-skills.sh 或 ./scripts/install-skills.sh

**目录结构：**
- skills/local/：自研 skills（完整代码，Git 追踪）
- skills/remote/：三方 skills（仅元数据）
- configs/skills-registry.json：技能注册表

## 当用户说"初始化"、"setup"时：

如果用户想重新安装或更新 Skills Manager：
1. 运行：cd {{PROJECT_DIR}} && ./scripts/setup.sh
2. 这会重新生成 SKILL.md 并检查环境
EOF

    # 替换项目路径
    sed -i "s|{{PROJECT_DIR}}|$PROJECT_DIR|g" "$TARGET_SKILL_DIR/SKILL.md"

    print_success "生成 SKILL.md: $TARGET_SKILL_DIR/SKILL.md"
}

# 设置脚本执行权限
set_permissions() {
    print_step "4. 设置执行权限"

    chmod +x "$PROJECT_DIR/scripts/"*.sh
    print_success "脚本已添加执行权限"
}

# 创建项目结构
create_project_structure() {
    print_step "5. 初始化项目结构"

    # 创建 .gitkeep 文件
    touch "$PROJECT_DIR/skills/local/.gitkeep"
    touch "$PROJECT_DIR/skills/remote/.gitkeep"
    touch "$PROJECT_DIR/backups/.gitkeep"

    # 初始化 registry（如果不存在）
    if [ ! -f "$PROJECT_DIR/configs/skills-registry.json" ]; then
        cat > "$PROJECT_DIR/configs/skills-registry.json" << EOF
{
  "version": "1.0",
  "lastUpdated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "skills": {},
  "settings": {
    "autoDetectOnImport": true,
    "promptOnUncertain": true,
    "defaultInstallMethod": "symlink"
  }
}
EOF
        print_success "初始化 skills-registry.json"
    else
        print_info "skills-registry.json 已存在，跳过初始化"
    fi
}

# 打印使用说明
print_usage() {
    print_step "安装完成"

    echo ""
    echo "🎉 Skills Manager 安装成功！"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 项目位置: $PROJECT_DIR"
    echo "📍 Skill 位置: $TARGET_SKILL_DIR"
    echo ""
    echo "🚀 使用方法："
    echo ""
    echo "  1. 交互方式（推荐日常）:"
    echo "     启动 Claude Code，然后输入："
    echo "       skills-manager"
    echo "     或："
    echo "       "导入 skills" / "安装 skills""
    echo ""
    echo "  2. 脚本方式（批量/自动化）:"
    echo "       cd $PROJECT_DIR"
    echo "       ./scripts/import-skills.sh    # 导入到项目"
    echo "       ./scripts/install-skills.sh   # 安装到全局"
    echo ""
    echo "📚 可用命令："
    echo "   - import-skills.sh    从全局导入 skills 到项目"
    echo "   - install-skills.sh   从项目安装 skills 到全局"
    echo "   - detect-skill-source.sh 检测单个 skill 来源"
    echo "   - setup.sh           重新安装/更新 Skill"
    echo ""
    echo "💡 提示："
    echo "   - 重启 Claude Code 或等待几分钟让技能生效"
    echo "   - 使用 'npx skills list' 查看已安装的 skills"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 主函数
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║       Skills Manager 安装程序            ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    check_environment
    create_skill_structure
    generate_skill_md
    set_permissions
    create_project_structure
    print_usage
}

# 运行主函数
main "$@"
