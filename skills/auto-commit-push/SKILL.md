---
name: auto-commit-push
description: Automatically create one Git commit and push it after substantial repository edits. Use this whenever the user asks for auto-commit/auto-push behavior (including phrases like "每次大修改后自动 commit 并 push", "改完后直接推上去", or "完成后帮我提交"), especially when they already configured GitHub auth/token and want the task to finish with commit+push by default.
---

# Auto Commit Push

Use this skill to reliably convert a large local change set into one commit and one push, with guardrails for conflicts, missing auth setup, and low-change noise.

## One-time setup (before first auto push)

1. Configure git identity.
- `git config --global user.name "<your-name>"`
- `git config --global user.email "<your-email>"`

2. Configure GitHub authentication (pick one).
- `gh auth login` (recommended).
- Or set HTTPS credential helper / PAT flow for your environment.

3. Ensure the target repo has a remote.
- `git remote -v`
- If needed: `git remote add origin <repo-url>`

## Workflow

1. Validate repository state.
- Run `git rev-parse --is-inside-work-tree`.
- Abort if merge conflicts exist (`git diff --name-only --diff-filter=U`).

2. Evaluate whether the change is "major".
- Measure changed file count with `git status --porcelain`.
- Measure line churn from unstaged + staged diffs, and include untracked files.
- Treat as major when either threshold is met:
`changed_files >= 5` or `insertions + deletions >= 150`.
- Allow override with `--force`.

3. Build commit message.
- Prefer user-provided message.
- Otherwise auto-generate:
`chore: update <files> files (+<insertions>/-<deletions>) [auto]`.

4. Commit and push via bundled script.
- Run `scripts/auto_commit_push.sh` from any path inside the target repo.
- In normal use, run this once at the end of a substantial implementation task.
- Use `--dry-run` when user asks for preview only.
- If upstream is missing, set it during push (`git push -u <remote> <branch>`).

5. Report completion.
- Return commit SHA, branch, and push destination.
- If skipped for small diff, return measured values and mention `--force`.
- If push fails due auth, report the exact git error and ask user to fix token/auth before retry.

## Command Reference

```bash
SKILL_DIR="/home/test/skills/auto-commit-push"

# Auto mode (major-change gated)
bash "$SKILL_DIR/scripts/auto_commit_push.sh"

# Force commit/push even when below thresholds
bash "$SKILL_DIR/scripts/auto_commit_push.sh" --force

# Provide custom commit message
bash "$SKILL_DIR/scripts/auto_commit_push.sh" --message "feat: implement batch import"

# Tune thresholds
bash "$SKILL_DIR/scripts/auto_commit_push.sh" --min-files 8 --min-lines 300

# Preview actions without committing/pushing
bash "$SKILL_DIR/scripts/auto_commit_push.sh" --dry-run
```

## Resources

### scripts/auto_commit_push.sh
Use this script as the default execution path. Keep commit/push safety checks centralized here instead of re-implementing ad-hoc shell sequences.
