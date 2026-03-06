# Skills Manager

管理 Claude Code Skills 的云端同步系统，区分三方 Skills 和自研 Skills，实现智能导入和灵活部署。

## 特性

- **双向同步**：支持从全局环境导入 Skills，也支持将 Skills 部署到全局环境
- **来源分离**：清晰区分三方下载的 Skills 和自研 Skills
- **两层架构**：交互层 Skill + 实现层项目，兼顾便捷性和灵活性
- **零依赖**：核心脚本使用 Bash，无需 Node/Python 等运行时环境
- **跨平台**：支持 Mac、Linux 和 Windows (Git Bash)

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                      交互层（Skill）                         │
│                 ~/.claude/skills/skills-manager/            │
│                      - 自然语言理解                          │
│                      - 调用底层脚本                          │
└────────────────────┬────────────────────────────────────────┘
                     │
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

## 快速开始

### 1. 安装

```bash
# 克隆项目
cd ~/projects
git clone <your-repo> skills-manager
cd skills-manager

# 运行安装脚本（安装 Skill 到 Claude Code）
./scripts/setup.sh
```

### 2. 使用

**方式一：自然语言（推荐日常）**

```
启动 Claude Code，然后输入：
- "导入 skills" - 从全局导入到项目
- "安装 skills" - 从项目部署到全局
- "查看 skills" - 列出所有 skills
```

**方式二：直接运行脚本**

```bash
# 导入（全局 → 项目）
./scripts/import-skills.sh

# 安装（项目 → 全局）
./scripts/install-skills.sh

# 检测单个 skill 来源
./scripts/detect-skill-source.sh <skill-name>
```

## 目录结构

```
skills-manager/
├── README.md                       # 本文件
├── docs/
│   └── design.md                   # 详细设计文档
├── configs/
│   └── skills-registry.json        # Skills 注册表
├── scripts/                        # 核心脚本
│   ├── setup.sh                    # 安装 Skill 到 Claude Code
│   ├── import-skills.sh            # 导入：全局 → 项目
│   ├── install-skills.sh           # 安装：项目 → 全局
│   └── detect-skill-source.sh      # 来源检测工具
├── skills/
│   ├── local/                      # 自研 Skills（完整代码）
│   └── remote/                     # 三方 Skills（仅元数据）
└── backups/                        # 备份目录
```

## 使用场景

### 场景 1：首次设置（新机器）

```bash
cd ~/projects
git clone <your-repo> skills-manager
cd skills-manager
./scripts/setup.sh

# 然后使用 Skill 或脚本安装所有 skills
claude
# 输入: "安装所有 skills"
```

### 场景 2：添加新 Skill（全局 → 项目）

```bash
# 在全局安装了三方 skill
npx skills add some-tool

# 导入到项目
./scripts/import-skills.sh

# 提交到 git
git add .
git commit -m "添加三方 skill: some-tool"
git push
```

### 场景 3：创建自研 Skill

```bash
# 在 ~/.claude/skills/my-skill/ 创建新 skill

# 导入到项目（选择 local 类型）
./scripts/import-skills.sh

# 提交到 git
git add skills/local/my-skill/
git commit -m "添加自研 skill: my-skill"
git push
```

### 场景 4：在新机器恢复所有 Skills

```bash
cd ~/projects
git clone <your-repo> skills-manager
cd skills-manager
./scripts/setup.sh
./scripts/install-skills.sh
```

## 脚本说明

### setup.sh

安装 Skills Manager 到 Claude Code。

```bash
./scripts/setup.sh
```

执行内容：
1. 检测环境（Claude Code、jq 等）
2. 创建 Skill 目录 `~/.claude/skills/skills-manager/`
3. 生成 SKILL.md（注入项目路径）
4. 设置脚本执行权限
5. 初始化项目结构

### import-skills.sh

从全局 `~/.claude/skills/` 导入到项目。

```bash
./scripts/import-skills.sh          # 交互式导入
./scripts/import-skills.sh -y       # 自动模式（跳过不确定的）
./scripts/import-skills.sh --help   # 查看帮助
```

功能：
- 扫描全局 skills 目录
- 自动检测来源（local/remote）
- 低置信度时交互式询问
- Local skills：复制到 `skills/local/`
- Remote skills：记录元数据到 `skills/remote/`
- 更新 `skills-registry.json`

### install-skills.sh

从项目安装到全局 `~/.claude/skills/`。

```bash
./scripts/install-skills.sh              # 安装所有
./scripts/install-skills.sh --local-only # 仅安装 local
./scripts/install-skills.sh skill-name   # 安装指定 skill
```

功能：
- Local skills：创建符号链接
- Remote skills：执行安装命令
- 处理冲突（备份已有文件）
- 生成安装报告

### detect-skill-source.sh

检测单个 skill 的来源类型。

```bash
./scripts/detect-skill-source.sh my-skill           # 检测
./scripts/detect-skill-source.sh -d my-skill        # 显示详情
./scripts/detect-skill-source.sh /path/to/skill     # 指定路径
```

## 自动检测逻辑

导入时会自动检测 skill 来源：

| 优先级 | 检查项 | 置信度 | 结果 |
|--------|--------|--------|------|
| 1 | `.custom-skill` 标记文件 | 100% | local |
| 2 | `SKILL.md` author 匹配当前用户 | 90% | local |
| 3 | Git remote 指向个人仓库 | 95% | local |
| 4 | Git remote 指向官方仓库 | 90% | remote |
| 5 | `SKILL.md` source 标记 | 80% | remote |
| 6 | 无法识别 | 0% | unknown（询问用户）|

## 最佳实践

### 对于自研 Skills

1. **创建标记文件**：
   ```bash
   echo '{"createdBy": "me", "createdAt": "'$(date -I)'"}' > my-skill/.custom-skill
   ```

2. **添加作者信息**（在 SKILL.md 中）：
   ```yaml
   ---
   name: my-skill
   author: me
   description: 我的自定义 skill
   ---
   ```

3. **版本管理**：遵循语义化版本（semver）

### 对于三方 Skills

1. 不要直接修改，需要定制时 fork 为 local
2. 定期更新并同步版本号到 registry
3. 记录准确的 `installCommand`

### Git 提交规范

```
添加新 skill: <skill-name>
更新 <skill-name>: <变更描述>
删除 <skill-name>: <原因>
重构: <描述>
```

## 跨平台支持

### Windows (Git Bash)

- 符号链接使用 `ln -s`，在 Git Bash 中正常工作
- 路径使用 `$HOME` 自动适配
- 脚本需要执行权限：`chmod +x scripts/*.sh`

### Mac / Linux

- 原生支持 Bash 脚本
- 符号链接行为一致

## 依赖

**必需**：
- Bash（Mac/Linux 自带，Windows 需 Git Bash）

**可选**（提升体验）：
- `jq`：JSON 处理更高效

安装 jq：
```bash
# Mac
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (Git Bash)
# 下载 jq.exe 放到 PATH 中
```

## 文档

- [详细设计文档](docs/design.md)

## License

MIT
