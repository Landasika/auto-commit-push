## Auto Commit/Push Rule

When working inside a Git repository under `/home/test`, apply this default behavior unless the user explicitly opts out:

1. After substantial code/content changes are completed, run:
`bash /home/test/skills/auto-commit-push/scripts/auto_commit_push.sh`
2. Treat changes as substantial using the script's default thresholds:
- changed files >= 5, or
- changed lines (insertions + deletions) >= 150
3. Do not force commit/push for small changes unless the user requests `--force`.
4. If git auth/token or remote is missing, stop and report the exact error.

