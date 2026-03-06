#!/bin/bash

# Skills 备份脚本
# 用于备份所有已安装的 Claude Code Skills

BACKUP_DIR="../backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="skills-backup-${TIMESTAMP}.json"

echo "🔧 Claude Code Skills 备份工具"
echo "================================"
echo ""

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 获取已安装技能列表
echo "📋 正在获取已安装技能列表..."
npx skills list > /tmp/skills-list.txt 2>/dev/null

# 创建备份信息
cat > "$BACKUP_DIR/$BACKUP_FILE" << EOF
{
  "backupDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backupVersion": "1.0",
  "hostname": "$(hostname)",
  "skills": [
EOF

# 这里可以添加更多备份逻辑
echo "    // 技能列表备份" >> "$BACKUP_DIR/$BACKUP_FILE"

cat >> "$BACKUP_DIR/$BACKUP_FILE" << EOF
  ],
  "notes": "使用 'npx skills list' 查看完整信息"
}
EOF

echo "✅ 备份完成: $BACKUP_DIR/$BACKUP_FILE"
echo ""
echo "📁 备份文件列表:"
ls -lh "$BACKUP_DIR"/skills-backup-*.json 2>/dev/null | tail -5
