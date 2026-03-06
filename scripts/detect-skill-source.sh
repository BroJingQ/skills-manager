#!/bin/bash
#
# Skills Manager - Skill Source Detection Tool
# 检测单个 skill 的来源类型
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

print_result() {
    local confidence="$1"
    local type="$2"
    local reason="$3"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  检测结果: ${CYAN}$type${NC}"
    echo "  置信度: ${YELLOW}$confidence%${NC}"
    echo "  原因: $reason"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 检测 skill 来源
detect_skill_source() {
    local skill_path="$1"
    local skill_name
    skill_name=$(basename "$skill_path")

    # 检查路径是否存在
    if [ ! -d "$skill_path" ]; then
        print_error "Skill 目录不存在: $skill_path"
        return 1
    fi

    echo ""
    echo "🔍 检测 Skill: ${CYAN}$skill_name${NC}"
    echo "路径: $skill_path"

    # 1. 检查本地标记文件
    if [ -f "$skill_path/.custom-skill" ]; then
        print_result "100" "local" "本地标记文件 .custom-skill 存在"
        return 0
    fi

    # 2. 检查 SKILL.md 中的 author
    if [ -f "$skill_path/SKILL.md" ]; then
        local author
        author=$(grep -i "^author:" "$skill_path/SKILL.md" 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "")
        if [ "$author" = "me" ] || [ "$author" = "$USER" ]; then
            print_result "90" "local" "作者匹配当前用户 ($author)"
            return 0
        fi

        # 检查 source 字段
        local source
        source=$(grep -i "^source:" "$skill_path/SKILL.md" 2>/dev/null | cut -d':' -f2- | tr -d ' ' || echo "")
        if echo "$source" | grep -qiE "(github|gitlab|bitbucket)"; then
            print_result "80" "remote" "来源标记为代码托管平台"
            return 0
        fi
    fi

    # 3. 检查 git remote
    if [ -d "$skill_path/.git" ]; then
        local remote_url
        remote_url=$(cd "$skill_path" && git remote get-url origin 2>/dev/null || echo "")

        if [ -n "$remote_url" ]; then
            # 检查是否是用户自己的仓库
            local git_user
            git_user=$(git config --global user.name 2>/dev/null || echo "$USER")

            if echo "$remote_url" | grep -qi "$git_user"; then
                print_result "95" "local" "Git remote 指向个人仓库"
                return 0
            fi

            # 检查是否是官方仓库
            if echo "$remote_url" | grep -qiE "(anthropics|claude-code|claude|skills)"; then
                print_result "90" "remote" "Git remote 指向官方/社区仓库"
                return 0
            fi

            # 其他 Git 仓库
            print_result "85" "remote" "Git remote 指向第三方仓库"
            return 0
        fi
    fi

    # 4. 检查目录特征
    # 如果有复杂的目录结构，可能是三方 skill
    local file_count
    file_count=$(find "$skill_path" -type f 2>/dev/null | wc -l)
    if [ "$file_count" -gt 10 ]; then
        print_result "60" "remote" "文件数量较多，可能是三方 skill（需确认）"
        return 0
    fi

    # 5. 无法确定
    print_result "0" "unknown" "无法识别来源（建议手动检查）"
    return 0
}

# 显示详细信息
show_details() {
    local skill_path="$1"

    echo ""
    echo "📂 Skill 详细信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 基本信息
    echo "路径: $skill_path"
    echo "大小: $(du -sh "$skill_path" 2>/dev/null | cut -f1)"
    echo "文件数: $(find "$skill_path" -type f 2>/dev/null | wc -l)"
    echo ""

    # 目录结构
    echo "目录结构:"
    ls -la "$skill_path" | head -20
    echo ""

    # SKILL.md 内容
    if [ -f "$skill_path/SKILL.md" ]; then
        echo "SKILL.md 内容:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$skill_path/SKILL.md"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    # Git 信息
    if [ -d "$skill_path/.git" ]; then
        echo ""
        echo "Git 信息:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        (cd "$skill_path" && {
            echo "Remote:"
            git remote -v 2>/dev/null || echo "  无 remote"
            echo ""
            echo "最近提交:"
            git log --oneline -5 2>/dev/null || echo "  无提交记录"
        })
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    # 标记文件
    if [ -f "$skill_path/.custom-skill" ]; then
        echo ""
        echo "本地标记文件 (.custom-skill):"
        cat "$skill_path/.custom-skill"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Skills Manager - 来源检测工具

用法: $(basename "$0") [选项] <skill-path>

选项:
  -h, --help      显示此帮助信息
  -d, --details   显示详细信息
  -q, --quiet     静默模式，只输出结果（格式: 置信度:类型:原因）

参数:
  skill-path      Skill 目录路径（绝对或相对路径）
                  或 skill 名称（从 ~/.claude/skills/ 查找）

说明:
  检测 skill 的来源类型（local 自研 / remote 三方 / unknown 未知）

检测逻辑:
  1. 检查 .custom-skill 标记文件
  2. 检查 SKILL.md 中的 author/source
  3. 检查 git remote URL
  4. 综合判断

示例:
  $(basename "$0") /path/to/my-skill    # 检测指定路径
  $(basename "$0") my-skill             # 从 ~/.claude/skills/ 查找
  $(basename "$0") -d my-skill          # 显示详细信息
  $(basename "$0") -q my-skill          # 静默模式
EOF
}

# 查找 skill 路径
find_skill_path() {
    local input="$1"

    # 如果是绝对路径或相对路径
    if [ -d "$input" ]; then
        echo "$(cd "$input" && pwd)"
        return 0
    fi

    # 从全局 skills 目录查找
    local global_path="${HOME}/.claude/skills/${input}"
    if [ -d "$global_path" ]; then
        echo "$global_path"
        return 0
    fi

    # 从项目本地 skills 查找
    local project_path="$(dirname "$(dirname "$0")")/skills/local/${input}"
    if [ -d "$project_path" ]; then
        echo "$project_path"
        return 0
    fi

    return 1
}

# 主函数
main() {
    local show_details_flag=false
    local quiet_mode=false
    local skill_input=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--details)
                show_details_flag=true
                shift
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            -*)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                skill_input="$1"
                shift
                ;;
        esac
    done

    # 检查参数
    if [ -z "$skill_input" ]; then
        print_error "请提供 skill 路径或名称"
        show_help
        exit 1
    fi

    # 查找 skill 路径
    local skill_path
    if ! skill_path=$(find_skill_path "$skill_input"); then
        print_error "找不到 skill: $skill_input"
        print_info "搜索路径:"
        print_info "  - $skill_input"
        print_info "  - ~/.claude/skills/$skill_input"
        exit 1
    fi

    # 执行检测
    if [ "$quiet_mode" = true ]; then
        # 静默模式：直接输出 machine-readable 格式
        detect_skill_source "$skill_path" 2>/dev/null | grep -E "^\s+置信度:" | head -1 | \
            sed 's/.*置信度: \([0-9]*\)%.*/\1/' | tr -d '\n'
        echo -n ":"
        detect_skill_source "$skill_path" 2>/dev/null | grep -E "^\s+检测结果:" | head -1 | \
            sed 's/.*检测结果: \([^ ]*\).*/\1/' | tr -d '\n'
        echo -n ":"
        detect_skill_source "$skill_path" 2>/dev/null | grep -E "^\s+原因:" | head -1 | \
            sed 's/.*原因: //' | tr -d '\n'
        echo
    else
        # 正常模式
        echo ""
        echo "╔══════════════════════════════════════════╗"
        echo "║         Skills Manager - 检测            ║"
        echo "╚══════════════════════════════════════════╝"

        detect_skill_source "$skill_path"

        if [ "$show_details_flag" = true ]; then
            show_details "$skill_path"
        fi
    fi
}

# 运行
main "$@"
