# Skills Manager

管理所有 Claude Code Skills 的仓库

## 目录结构

```
skills-manager/
├── README.md              # 项目说明
├── docs/                  # 文档目录
│   ├── installation-guide.md    # 安装指南
│   └── skill-reference.md       # 技能参考手册
├── scripts/               # 脚本目录
│   ├── install-skill.sh         # 安装技能脚本
│   └── backup-skills.sh         # 备份技能脚本
├── configs/               # 配置文件
│   └── skills-list.json         # 技能清单
└── backups/               # 备份目录
```

## 快速开始

### 查看已安装的技能
```bash
npx skills list
```

### 搜索技能
```bash
npx skills find <关键词>
```

### 安装技能
```bash
npx skills add <owner/repo@skill> -g -y
```

## 已安装的技能清单

| 技能名称 | 来源 | 安装日期 | 说明 |
|---------|------|---------|------|
| find-skills | 内置 | - | 搜索和发现技能 |
| proxy-local | 内置 | - | 本地代理管理 |
| skill-creator | 内置 | - | 创建和管理技能 |

## 备份与恢复

### 备份所有技能
```bash
./scripts/backup-skills.sh
```

### 从备份恢复
```bash
# 从 backups 目录恢复
npx skills install-from backups/<备份文件>
```

## 相关链接

- [Skills 官网](https://skills.sh/)
- [Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code)
