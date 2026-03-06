#!/bin/bash

# Skills 安装脚本
# 简化技能安装流程

set -e

SKILL_NAME=$1

if [ -z "$SKILL_NAME" ]; then
    echo "❌ 错误: 请提供技能名称"
    echo ""
    echo "用法:"
    echo "  ./install-skill.sh <owner/repo@skill>"
    echo ""
    echo "示例:"
    echo "  ./install-skill.sh github/awesome-copilot@git-commit"
    exit 1
fi

echo "🔧 正在安装技能: $SKILL_NAME"
echo "================================"
echo ""

# 安装技能
npx skills add "$SKILL_NAME" -g -y

echo ""
echo "✅ 安装完成!"
echo ""
echo "📝 更新技能清单..."

# 可选: 自动更新 skills-list.json
echo "提示: 记得更新 configs/skills-list.json 文件记录新安装的技能"
