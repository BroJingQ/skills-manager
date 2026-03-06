# 技能安装指南

## 搜索技能

```bash
npx skills find <关键词>
```

常用关键词：
- `git` - Git 相关技能
- `commit` - 提交辅助
- `pr` 或 `pull request` - PR 管理
- `react` - React 开发
- `test` - 测试相关

## 安装技能

### 方式 1: 直接安装
```bash
npx skills add <owner/repo@skill> -g -y
```

### 方式 2: 使用本项目的脚本
```bash
cd scripts
./install-skill.sh github/awesome-copilot@git-commit
```

## 查看已安装技能

```bash
npx skills list
```

## 更新技能

```bash
npx skills update
```

## 删除技能

```bash
npx skills remove <skill-name>
```

## 创建自己的技能

```bash
npx skills init my-skill
```
