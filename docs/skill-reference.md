# 技能参考手册

## 已安装技能

### 1. find-skills
- **来源**: 内置
- **用途**: 搜索和发现 Claude Code 技能
- **使用方法**: `npx skills find <关键词>`

### 2. proxy-local
- **来源**: 内置
- **用途**: 本地 Clash 代理管理
- **使用方法**:
  - `/proxy-local` 查看代理状态
  - `/proxy-local on` 开启代理
  - `/proxy-local off` 关闭代理

### 3. skill-creator
- **来源**: 内置
- **用途**: 创建和管理自定义技能
- **使用方法**: `npx skills init <skill-name>`

## 推荐技能

### Git 相关
| 技能 | 来源 | 说明 |
|-----|------|------|
| git-commit | github/awesome-copilot | GitHub 官方提交辅助 |
| conventional-commit | github/awesome-copilot | 规范化提交信息 |
| my-pull-requests | github/awesome-copilot | PR 管理 |
| create-github-pull-request-from-specification | github/awesome-copilot | 从规范创建 PR |

### 开发相关
| 技能 | 来源 | 说明 |
|-----|------|------|
| vercel-react-best-practices | vercel-labs/agent-skills | Vercel React 最佳实践 |

## 技能目录

所有技能存储在:
- Windows: `%USERPROFILE%\.agents\skills\`
- Git Bash: `~/.agents/skills/`
