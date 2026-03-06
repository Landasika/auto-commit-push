# Auto Commit & Push Skill

让 Codex 在“大改动完成后”自动执行一次 `commit + push`，并在小改动时自动跳过（可强制执行）。

## 功能

- 变更阈值判断：默认 `>= 5` 个文件或 `>= 150` 行变更才执行
- 安全检查：冲突检测、分支检测、Git 身份检测
- 支持 `--dry-run` 预览
- 支持 `--force` 强制提交推送
- 支持自定义 commit message

## 目录结构

```text
skills/auto-commit-push/
├── SKILL.md
├── agents/openai.yaml
└── scripts/auto_commit_push.sh
```

## 前置条件

1. 安装 Git（以及可选的 GitHub CLI：`gh`）
2. 配置 Git 身份：

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

3. 配置 GitHub 认证（任选其一）：
- `gh auth login`（推荐）
- PAT + git credential helper

## 使用方式

在“目标仓库根目录”执行：

```bash
SKILL_SCRIPT="/path/to/skills/auto-commit-push/scripts/auto_commit_push.sh"

# 预览（不提交不推送）
bash "$SKILL_SCRIPT" --dry-run

# 默认模式：仅大改动执行 commit+push
bash "$SKILL_SCRIPT"

# 强制执行
bash "$SKILL_SCRIPT" --force

# 自定义提交信息
bash "$SKILL_SCRIPT" --message "feat: your message"
```

## 安装到本地 Codex（可选）

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME/skills"
cp -r skills/auto-commit-push "$CODEX_HOME/skills/"
```

安装后脚本路径：

```bash
$CODEX_HOME/skills/auto-commit-push/scripts/auto_commit_push.sh
```

## 发布到 GitHub

### 方式 A：用 `gh` 一条命令创建并推送（推荐）

```bash
git init
git add .
git commit -m "chore: initial auto-commit-push skill"
gh repo create <your-repo-name> --public --source=. --remote=origin --push
```

### 方式 B：手动创建仓库后推送

```bash
git init
git add .
git commit -m "chore: initial auto-commit-push skill"
git branch -M main
git remote add origin git@github.com:<your-username>/<your-repo-name>.git
git push -u origin main
```

## 在 Codex 对话中触发

可直接说：

- “每次大修改后自动 commit 并 push”
- “改完后直接帮我提交并推送”
- “完成后自动 push 到远端”

## 常见问题

1. `Missing git identity`
- 先配置 `user.name` / `user.email`

2. `No git remote/upstream found`
- 先配置并推送一次上游分支：

```bash
git remote add origin <repo-url>
git push -u origin <branch>
```

3. Push 认证失败（token/权限问题）
- 重新 `gh auth login`，或检查 PAT 是否有仓库写权限（`repo` scope）
# auto-commit-push
