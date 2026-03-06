#!/bin/bash
#
# Skills Manager - Install Script
# 从项目安装 skills 到全局 ~/.claude/skills/
# 纯 Bash 实现，无外部依赖
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 路径定义
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"
REGISTRY_FILE="${PROJECT_DIR}/configs/skills-registry.json"
LOCAL_SKILLS_DIR="${PROJECT_DIR}/skills/local"
REMOTE_SKILLS_DIR="${PROJECT_DIR}/skills/remote"

# 统计
INSTALLED_LOCAL=0
INSTALLED_REMOTE=0
ALREADY_INSTALLED=0
FAILED=0
CONFLICTS=()

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

print_header() {
    echo -e "${CYAN}\n$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 获取 skill 类型（从 registry）
get_skill_type() {
    local skill_name="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        echo ""
        return
    fi

    # 纯 Bash 方案：解析 JSON 中的 type 字段
    local in_skill=0
    local skill_block=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 找到 skill 的开始
        if [[ "$line" =~ \"$skill_name\": ]]; then
            in_skill=1
            skill_block="$line"
            continue
        fi

        if [ $in_skill -eq 1 ]; then
            skill_block="$skill_block $line"

            # 检查是否结束（包含 }）
            if [[ "$line" =~ \} ]]; then
                # 提取 type 字段
                local skill_type
                skill_type=$(echo "$skill_block" | grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
                echo "$skill_type"
                return
            fi
        fi
    done < "$REGISTRY_FILE"

    echo ""
}

# 获取所有 skills（从 registry）
get_all_skills() {
    if [ ! -f "$REGISTRY_FILE" ]; then
        return
    fi

    # 提取所有 skill 名称（匹配 "name": { 格式）
    grep -o '"[^"]*":[[:space:]]*{' "$REGISTRY_FILE" | \
        sed 's/":[[:space:]]*{$//g' | \
        sed 's/"//g' | \
        grep -v "^version$" | \
        grep -v "^settings$" | \
        grep -v "^skills$" | \
        grep -v "^lastUpdated$"
}

# 从 meta.json 获取安装命令
get_install_command() {
    local skill_name="$1"
    local meta_file="${REMOTE_SKILLS_DIR}/${skill_name}/meta.json"

    if [ ! -f "$meta_file" ]; then
        echo "npx skills add $skill_name -g -y"
        return
    fi

    # 提取 installCommand 字段
    grep -o '"installCommand"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | \
        cut -d'"' -f4 || \
        echo "npx skills add $skill_name -g -y"
}

# 安装 local skill（创建符号链接）
install_local_skill() {
    local skill_name="$1"
    local source_path="${LOCAL_SKILLS_DIR}/${skill_name}"
    local target_path="${GLOBAL_SKILLS_DIR}/${skill_name}"

    print_info "安装 Local skill: $skill_name"

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        print_error "源目录不存在: $source_path"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # 检查目标是否已存在
    if [ -e "$target_path" ]; then
        if [ -L "$target_path" ]; then
            # 已是符号链接，检查是否指向正确位置
            local current_target
            current_target=$(readlink "$target_path")
            if [ "$current_target" = "$source_path" ]; then
                print_success "$skill_name (已链接)"
                ALREADY_INSTALLED=$((ALREADY_INSTALLED + 1))
                return 0
            else
                # 链接指向不同位置
                print_warning "$skill_name 已存在，但链接指向其他位置"
                echo "  当前: $current_target"
                echo "  期望: $source_path"

                if [ "$AUTO_CONFIRM" = true ]; then
                    rm "$target_path"
                else
                    read -p "是否重新链接? [y/N] " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        rm "$target_path"
                    else
                        CONFLICTS+=("$skill_name: 链接指向不同位置")
                        FAILED=$((FAILED + 1))
                        return 1
                    fi
                fi
            fi
        elif [ -d "$target_path" ]; then
            # 是目录，备份
            print_warning "$skill_name 已存在（目录），备份到 ${skill_name}.bak"
            mv "$target_path" "${target_path}.bak.$(date +%s)"
        else
            # 其他类型文件
            print_warning "$skill_name 已存在（文件），备份到 ${skill_name}.bak"
            mv "$target_path" "${target_path}.bak.$(date +%s)"
        fi
    fi

    # 创建符号链接
    if ln -s "$source_path" "$target_path"; then
        print_success "$skill_name → $source_path"
        INSTALLED_LOCAL=$((INSTALLED_LOCAL + 1))
        return 0
    else
        print_error "创建链接失败: $skill_name"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# 安装 remote skill（执行安装命令）
install_remote_skill() {
    local skill_name="$1"

    print_info "安装 Remote skill: $skill_name"

    # 获取安装命令
    local install_cmd
    install_cmd=$(get_install_command "$skill_name")

    # 检查是否已安装
    if [ -d "${GLOBAL_SKILLS_DIR}/${skill_name}" ]; then
        print_success "$skill_name (已安装)"
        ALREADY_INSTALLED=$((ALREADY_INSTALLED + 1))
        return 0
    fi

    # 执行安装命令
    echo "  执行: $install_cmd"
    if eval "$install_cmd"; then
        print_success "$skill_name 安装成功"
        INSTALLED_REMOTE=$((INSTALLED_REMOTE + 1))
        return 0
    else
        print_error "$skill_name 安装失败"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# 主安装逻辑
install_skills() {
    print_header "📦 安装 Skills 到: $GLOBAL_SKILLS_DIR"

    # 检查全局 skills 目录
    if [ ! -d "$GLOBAL_SKILLS_DIR" ]; then
        print_info "创建全局 skills 目录: $GLOBAL_SKILLS_DIR"
        mkdir -p "$GLOBAL_SKILLS_DIR"
    fi

    # 获取所有 skills
    local skills
    skills=$(get_all_skills)

    if [ -z "$skills" ]; then
        print_warning "Registry 中没有 skills"
        return
    fi

    # 分类统计
    local local_skills=()
    local remote_skills=()

    while IFS= read -r skill_name; do
        [ -n "$skill_name" ] || continue

        # 如果指定了特定 skills，检查是否匹配
        if [ ${#SPECIFIC_SKILLS[@]} -gt 0 ]; then
            local found=false
            for specific in "${SPECIFIC_SKILLS[@]}"; do
                if [ "$skill_name" = "$specific" ]; then
                    found=true
                    break
                fi
            done
            [ "$found" = true ] || continue
        fi

        local skill_type
        skill_type=$(get_skill_type "$skill_name")

        if [ "$skill_type" = "local" ]; then
            local_skills+=("$skill_name")
        elif [ "$skill_type" = "remote" ]; then
            remote_skills+=("$skill_name")
        fi
    done <<< "$skills"

    # 安装 Local Skills
    if [ ${#local_skills[@]} -gt 0 ] && [ "$REMOTE_ONLY" = false ]; then
        print_header "🔗 Local Skills（符号链接）"
        for skill_name in "${local_skills[@]}"; do
            install_local_skill "$skill_name"
        done
    fi

    # 安装 Remote Skills
    if [ ${#remote_skills[@]} -gt 0 ] && [ "$LOCAL_ONLY" = false ]; then
        print_header "📥 Remote Skills（官方下载）"
        for skill_name in "${remote_skills[@]}"; do
            install_remote_skill "$skill_name"
        done
    fi
}

# 打印报告
print_report() {
    print_header "📊 安装报告"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ${GREEN}Local Skills 安装:${NC}  $INSTALLED_LOCAL"
    echo "  ${YELLOW}Remote Skills 安装:${NC} $INSTALLED_REMOTE"
    echo "  已存在（跳过）:     $ALREADY_INSTALLED"
    if [ $FAILED -gt 0 ]; then
        echo "  ${RED}失败:${NC}              $FAILED"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 显示冲突详情
    if [ ${#CONFLICTS[@]} -gt 0 ]; then
        echo ""
        print_warning "冲突详情:"
        for conflict in "${CONFLICTS[@]}"; do
            echo "  - $conflict"
        done
        echo ""
        echo "建议: 运行 ./import-skills.sh 重新识别来源"
    fi

    # 总结
    if [ $FAILED -eq 0 ]; then
        echo ""
        print_success "所有 skills 安装完成！"
        echo ""
        echo "验证命令:"
        echo "  npx skills list"
    else
        echo ""
        print_warning "部分 skills 安装失败，请查看上方详情"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Skills Manager - 安装脚本

用法: $(basename "$0") [选项] [skill-name...]

选项:
  -h, --help      显示此帮助信息
  -y, --yes       自动确认（不询问冲突处理）
  --local-only    仅安装 local skills
  --remote-only   仅安装 remote skills

参数:
  skill-name      指定要安装的 skill（可多个），不指定则安装全部

说明:
  从项目安装 skills 到全局 ~/.claude/skills/
  - Local skills：创建符号链接
  - Remote skills：执行安装命令

示例:
  ./install-skills.sh              # 安装所有 skills
  ./install-skills.sh my-tool      # 仅安装 my-tool
  ./install-skills.sh --local-only # 仅安装 local skills

依赖:
  纯 Bash 实现，无需 jq 或 Python
EOF
}

# 解析参数
AUTO_CONFIRM=false
LOCAL_ONLY=false
REMOTE_ONLY=false
SPECIFIC_SKILLS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --remote-only)
            REMOTE_ONLY=true
            shift
            ;;
        -*)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            SPECIFIC_SKILLS+=("$1")
            shift
            ;;
    esac
done

# 主函数
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║         Skills Manager - 安装            ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    install_skills
    print_report
}

# 运行
main "$@"
