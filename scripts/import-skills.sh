#!/bin/bash
#
# Skills Manager - Import Script
# 从全局 ~/.claude/skills/ 导入到项目
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
IMPORTED_LOCAL=0
IMPORTED_REMOTE=0
SKIPPED=0

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

# 检测 skill 来源
detect_skill_source() {
    local skill_path="$1"
    local skill_name="$(basename "$skill_path")"
    local local_score=0
    local remote_score=0
    local reasons=""

    # 获取当前用户名（兼容 Windows 和 Unix）
    local current_user
    current_user="${USER:-${USERNAME:-$(whoami)}}"

    # ========== 检测 Local 特征 ==========

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

    # 4. 检查是否是符号链接（可能是 local skill 的链接）
    if [ -L "$skill_path" ]; then
        local link_target
        link_target=$(readlink "$skill_path")
        if echo "$link_target" | grep -q "$PROJECT_DIR"; then
            echo "85:local:符号链接指向本项目"
            return
        fi
    fi

    # ========== 检测 Remote 特征 ==========

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

    # 高置信度 remote
    if [ "$remote_score" -ge 70 ]; then
        echo "${remote_score}:remote:${reasons}"
        return
    fi

    # 中等置信度 remote
    if [ "$remote_score" -ge 40 ]; then
        echo "${remote_score}:remote:${reasons}"
        return
    fi

    # 无法确定
    echo "0:unknown:无法识别来源 (remote信号:${remote_score})"
}

# 检查 skill 是否已在 registry 中
is_skill_registered() {
    local skill_name="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        return 1
    fi

    # 纯 Bash 方案：检查文件中是否包含该 skill 名称
    # 注意：简单字符串匹配，可能误判
    if grep -q "\"$skill_name\"" "$REGISTRY_FILE" 2>/dev/null; then
        return 0
    fi
    return 1
}

# 添加 skill 到 registry（纯 Bash 实现）
add_to_registry() {
    local skill_name="$1"
    local skill_type="$2"
    local description="${3:-}"
    local source_url="${4:-}"
    local install_cmd="${5:-}"
    local detected_at
    detected_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 构建额外的字段（remote skill）
    local extra_fields=""
    if [ "$skill_type" = "remote" ] && [ -n "$source_url" ]; then
        extra_fields="\n      \"source\": \"$source_url\","
        if [ -n "$install_cmd" ]; then
            extra_fields="$extra_fields\n      \"installCommand\": \"$install_cmd\","
        fi
    fi

    # 确保目录存在
    mkdir -p "$(dirname "$REGISTRY_FILE")"

    # 如果 registry 不存在，创建基础结构
    if [ ! -f "$REGISTRY_FILE" ]; then
        cat > "$REGISTRY_FILE" << EOF
{
  "version": "1.0",
  "lastUpdated": "$detected_at",
  "skills": {
    "$skill_name": {
      "type": "$skill_type",
      "name": "$skill_name",
      "description": "$description",${extra_fields}
      "detectedAt": "$detected_at",
      "confirmedByUser": true
    }
  },
  "settings": {
    "autoDetectOnImport": true,
    "promptOnUncertain": true,
    "defaultInstallMethod": "symlink"
  }
}
EOF
        print_info "已创建 registry 并添加 $skill_name"
        return
    fi

    # 检查是否已存在
    if grep -q "\"$skill_name\"" "$REGISTRY_FILE" 2>/dev/null; then
        print_warning "$skill_name 已在 registry 中"
        return
    fi

    # 转义特殊字符（简单处理）
    local escaped_description
    escaped_description=$(echo "$description" | sed 's/"/\\"/g; s/\\/\\\\/g')

    # 创建临时文件
    local temp_file="${REGISTRY_FILE}.tmp.$$"

    # 构建 skill JSON
    local skill_json="    \"$skill_name\": {\n      \"type\": \"$skill_type\",\n      \"name\": \"$skill_name\",\n      \"description\": \"$escaped_description\","
    if [ -n "$extra_fields" ]; then
        # 移除末尾的逗号并添加 extra_fields
        skill_json="$skill_json$extra_fields"
    fi
    skill_json="$skill_json\n      \"detectedAt\": \"$detected_at\",\n      \"confirmedByUser\": true\n    },"

    # 方法：找到 "skills": { 或 "skills":{} 并在其后插入新 skill
    # 首先尝试匹配多行格式 "skills": {
    if grep -q '"skills":[[:space:]]*{$' "$REGISTRY_FILE"; then
        # 多行格式，在 "skills": { 后插入
        sed "/\"skills\":[[:space:]]*{$/a\\$skill_json" "$REGISTRY_FILE" > "$temp_file"
    elif grep -q '"skills":[[:space:]]*{}' "$REGISTRY_FILE"; then
        # 空对象格式 "skills": {}，替换为大括号内包含内容
        sed "s/\"skills\":[[:space:]]*{/\"skills\": {\n$skill_json/" "$REGISTRY_FILE" > "$temp_file"
    else
        # 默认：直接在文件中找到第一个 "skills": 后插入
        sed "0,/\"skills\":/s/\"skills\":/\"skills\":\n$skill_json/" "$REGISTRY_FILE" > "$temp_file"
    fi

    # 更新 lastUpdated
    sed -i "s/\"lastUpdated\": \"[^\"]*\"/\"lastUpdated\": \"$detected_at\"/" "$temp_file"

    # 替换原文件
    mv "$temp_file" "$REGISTRY_FILE"
    print_info "已更新 registry"
}

# 导入 local skill
import_local_skill() {
    local skill_name="$1"
    local source_path="$2"
    local target_path="${LOCAL_SKILLS_DIR}/${skill_name}"

    print_info "导入 Local skill: $skill_name"

    # 检查目标是否已存在
    if [ -e "$target_path" ]; then
        print_warning "$skill_name 已存在于项目中"
        read -p "是否覆盖? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过 $skill_name"
            SKIPPED=$((SKIPPED + 1))
            return
        fi
        rm -rf "$target_path"
    fi

    # 复制目录
    cp -r "$source_path" "$target_path"

    # 添加标记文件（如果不存在）
    if [ ! -f "$target_path/.custom-skill" ]; then
        cat > "$target_path/.custom-skill" << EOF
{
  "createdBy": "me",
  "createdAt": "$(date +%Y-%m-%d)",
  "description": "本地自定义 skill"
}
EOF
    fi

    # 获取描述
    local description=""
    if [ -f "$source_path/SKILL.md" ]; then
        description=$(grep -m 1 "^description:" "$source_path/SKILL.md" | cut -d':' -f2- | sed 's/^[[:space:]]*//' || echo "")
    fi

    # 添加到 registry
    add_to_registry "$skill_name" "local" "$description"

    print_success "已导入: $skill_name → skills/local/$skill_name"
    IMPORTED_LOCAL=$((IMPORTED_LOCAL + 1))
}

# 导入 remote skill（记录元数据）
import_remote_skill() {
    local skill_name="$1"
    local source_path="$2"
    local target_dir="${REMOTE_SKILLS_DIR}/${skill_name}"

    print_info "导入 Remote skill: $skill_name"

    # 创建元数据目录
    mkdir -p "$target_dir"

    # 获取描述
    local description=""
    if [ -f "$source_path/SKILL.md" ]; then
        description=$(grep -m 1 "^description:" "$source_path/SKILL.md" | cut -d':' -f2- | sed 's/^[[:space:]]*//' || echo "")
    fi

    # 尝试从 SKILL.md 中检测来源仓库
    local source_url=""
    local install_command=""

    if [ -f "$source_path/SKILL.md" ]; then
        # 检测是否提到特定的官方来源
        if grep -qi "vercel" "$source_path/SKILL.md"; then
            source_url="https://github.com/vercel-labs/skills"
            install_command="npx skills add https://github.com/vercel-labs/skills --skill ${skill_name}"
        elif grep -qi "anthropics" "$source_path/SKILL.md" || \
             grep -qi "skills.sh" "$source_path/SKILL.md"; then
            source_url="https://github.com/anthropics/skills"
            install_command="npx skills add https://github.com/anthropics/skills --skill ${skill_name}"
        fi
    fi

    # 如果无法从内容检测，使用通用命令
    if [ -z "$source_url" ]; then
        source_url="unknown"
        install_command="npx skills add ${skill_name} -g -y"
    fi

    # 转义描述
    local escaped_description
    escaped_description=$(echo "$description" | sed 's/"/\\"/g')

    # 创建 meta.json
    cat > "$target_dir/meta.json" << EOF
{
  "name": "$skill_name",
  "source": "$source_url",
  "installCommand": "$install_command",
  "description": "$escaped_description",
  "detectedAt": "$(date +%Y-%m-%d)"
}
EOF

    # 添加到 registry
    add_to_registry "$skill_name" "remote" "$description" "$source_url" "$install_command"

    print_success "已记录元数据: $skill_name → skills/remote/$skill_name/"
    IMPORTED_REMOTE=$((IMPORTED_REMOTE + 1))
}

# 交互式询问用户
ask_user_for_type() {
    local skill_name="$1"
    local reason="$2"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 检测到未知 Skill: ${CYAN}$skill_name${NC}"
    echo "   检测原因: $reason"
    echo ""
    echo "这个 skill 是你自己创建的吗？"
    echo ""
    echo "  [1] 是，我创建的（作为 ${GREEN}local${NC} skill 导入）"
    echo "  [2] 否，三方下载的（作为 ${YELLOW}remote${NC} skill 记录）"
    echo "  [3] 跳过，暂时不处理"
    echo "  [4] 查看详情（显示文件内容）"
    echo ""

    while true; do
        read -p "选择 [1-4]: " choice
        case $choice in
            1)
                echo "local"
                return
                ;;
            2)
                echo "remote"
                return
                ;;
            3)
                echo "skip"
                return
                ;;
            4)
                echo "details"
                return
                ;;
            *)
                print_error "无效选择，请重试"
                ;;
        esac
    done
}

# 显示 skill 详情
show_skill_details() {
    local skill_path="$1"

    echo ""
    echo "📂 Skill 详情:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 显示目录结构
    echo "目录结构:"
    ls -la "$skill_path" | head -20

    # 显示 SKILL.md 前 30 行
    if [ -f "$skill_path/SKILL.md" ]; then
        echo ""
        echo "SKILL.md (前 30 行):"
        head -30 "$skill_path/SKILL.md"
    fi

    # 显示 .git 信息
    if [ -d "$skill_path/.git" ]; then
        echo ""
        echo "Git 信息:"
        (cd "$skill_path" && git remote -v 2>/dev/null || echo "  无 remote")
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 主导入逻辑
import_skills() {
    print_header "🔍 扫描 Skills 目录: $GLOBAL_SKILLS_DIR"

    # 检查全局 skills 目录
    if [ ! -d "$GLOBAL_SKILLS_DIR" ]; then
        print_error "全局 skills 目录不存在: $GLOBAL_SKILLS_DIR"
        exit 1
    fi

    # 确保项目结构存在
    mkdir -p "$LOCAL_SKILLS_DIR" "$REMOTE_SKILLS_DIR"

    # 遍历全局 skills
    local found_count=0
    for skill_path in "$GLOBAL_SKILLS_DIR"/*; do
        # 跳过非目录项
        [ -d "$skill_path" ] || continue

        # 跳过 skills-manager 自身
        local skill_name
        skill_name=$(basename "$skill_path")
        if [ "$skill_name" = "skills-manager" ]; then
            print_info "跳过: skills-manager（管理工具本身）"
            continue
        fi

        found_count=$((found_count + 1))
        echo ""
        echo "[$found_count] 检查: ${CYAN}$skill_name${NC}"

        # 检查是否已在 registry 中
        if is_skill_registered "$skill_name"; then
            print_success "已注册，跳过"
            continue
        fi

        # 检测来源
        local detection_result
        detection_result=$(detect_skill_source "$skill_path")
        local confidence=$(echo "$detection_result" | cut -d':' -f1)
        local detected_type=$(echo "$detection_result" | cut -d':' -f2)
        local reason=$(echo "$detection_result" | cut -d':' -f3-)

        print_info "检测结果: $detected_type (置信度: $confidence%) - $reason"

        # 根据置信度决定处理方式
        local skill_type=""

        if [ "$confidence" -ge 80 ]; then
            # 高置信度，直接使用检测结果
            skill_type="$detected_type"
        else
            # 低置信度，询问用户
            while true; do
                local user_choice
                user_choice=$(ask_user_for_type "$skill_name" "$reason")

                if [ "$user_choice" = "details" ]; then
                    show_skill_details "$skill_path"
                    # 循环继续，再次询问
                elif [ "$user_choice" = "skip" ]; then
                    print_info "跳过 $skill_name"
                    SKIPPED=$((SKIPPED + 1))
                    skill_type=""
                    break
                else
                    skill_type="$user_choice"
                    break
                fi
            done
        fi

        # 执行导入
        if [ "$skill_type" = "local" ]; then
            import_local_skill "$skill_name" "$skill_path"
        elif [ "$skill_type" = "remote" ]; then
            import_remote_skill "$skill_name" "$skill_path"
        fi
    done
}

# 打印报告
print_report() {
    print_header "📊 导入报告"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ${GREEN}Local Skills 导入:${NC}  $IMPORTED_LOCAL"
    echo "  ${YELLOW}Remote Skills 记录:${NC} $IMPORTED_REMOTE"
    echo "  跳过:              $SKIPPED"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $((IMPORTED_LOCAL + IMPORTED_REMOTE)) -gt 0 ]; then
        echo ""
        print_success "导入完成！建议执行以下命令提交到 git："
        echo ""
        echo "  cd $PROJECT_DIR"
        echo "  git add ."
        echo "  git commit -m \"更新 skills: 导入 $(($IMPORTED_LOCAL + $IMPORTED_REMOTE)) 个技能\""
        echo "  git push"
        echo ""
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Skills Manager - 导入脚本

用法: $(basename "$0") [选项]

选项:
  -h, --help      显示此帮助信息
  -y, --yes       自动确认（不询问低置信度的 skill）
  --dry-run       模拟运行，不实际导入

说明:
  从全局 ~/.claude/skills/ 目录扫描 skills，识别来源并导入到项目。
  - Local skills：复制完整代码到 skills/local/
  - Remote skills：记录元数据到 skills/remote/

示例:
  ./import-skills.sh          # 交互式导入
  ./import-skills.sh -y       # 自动模式（跳过不确定的）
  ./import-skills.sh --dry-run # 模拟运行

依赖:
  纯 Bash 实现，无需 jq 或 Python
EOF
}

# 解析参数
AUTO_CONFIRM=false
DRY_RUN=false

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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主函数
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║         Skills Manager - 导入            ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        print_warning "模拟运行模式，不会实际修改文件"
    fi

    import_skills
    print_report
}

# 运行
main "$@"
