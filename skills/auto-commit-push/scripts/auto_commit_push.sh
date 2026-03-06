#!/usr/bin/env bash
set -euo pipefail

MIN_FILES=5
MIN_LINES=150
FORCE=0
DRY_RUN=0
REMOTE=""
MESSAGE=""

usage() {
  cat <<'EOF'
Usage: auto_commit_push.sh [options]

Options:
  -m, --message <text>   Use a custom commit message
      --min-files <n>    Minimum changed files threshold (default: 5)
      --min-lines <n>    Minimum changed lines threshold (default: 150)
      --remote <name>    Remote to use when no upstream exists (default: origin or first remote)
      --force            Commit/push even when below thresholds
      --dry-run          Print planned actions without committing or pushing
  -h, --help             Show help
EOF
}

err() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

is_non_negative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

extract_value() {
  local text="$1"
  local regex="$2"
  local out=0
  if [[ "$text" =~ $regex ]]; then
    out="${BASH_REMATCH[1]}"
  fi
  printf '%s\n' "$out"
}

parse_shortstat() {
  local text="$1"
  local files insertions deletions
  files=$(extract_value "$text" '([0-9]+)[[:space:]]+file[s]?[[:space:]]+changed')
  insertions=$(extract_value "$text" '([0-9]+)[[:space:]]+insertion[s]?\(\+\)')
  deletions=$(extract_value "$text" '([0-9]+)[[:space:]]+deletion[s]?\(-\)')
  printf '%s %s %s\n' "$files" "$insertions" "$deletions"
}

count_untracked_insertions() {
  local total=0
  local file numstat add

  while IFS= read -r -d '' file; do
    numstat="$(git diff --numstat --no-index -- /dev/null "$file" 2>/dev/null || true)"
    add="${numstat%%$'\t'*}"
    if is_non_negative_int "$add"; then
      total="$((total + add))"
    fi
  done < <(git ls-files --others --exclude-standard -z)

  printf '%s\n' "$total"
}

resolve_push_target() {
  local selected_remote="$REMOTE"
  local upstream=""

  if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}')"
    printf 'upstream\t%s\n' "$upstream"
    return 0
  fi

  if [[ -z "$selected_remote" ]]; then
    if git remote get-url origin >/dev/null 2>&1; then
      selected_remote="origin"
    else
      selected_remote="$(git remote | head -n1 || true)"
    fi
  fi

  [[ -n "$selected_remote" ]] || return 1
  printf 'remote\t%s\n' "$selected_remote"
}

ensure_git_identity() {
  local author_name author_email
  author_name="$(git config user.name || true)"
  author_email="$(git config user.email || true)"

  if [[ -z "$author_name" ]] || [[ -z "$author_email" ]]; then
    err "Missing git identity. Configure user.name and user.email (repo-local or global) before auto commit/push."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      [[ $# -ge 2 ]] || err "Missing value for $1"
      MESSAGE="$2"
      shift 2
      ;;
    --min-files)
      [[ $# -ge 2 ]] || err "Missing value for $1"
      is_non_negative_int "$2" || err "--min-files must be a non-negative integer"
      MIN_FILES="$2"
      shift 2
      ;;
    --min-lines)
      [[ $# -ge 2 ]] || err "Missing value for $1"
      is_non_negative_int "$2" || err "--min-lines must be a non-negative integer"
      MIN_LINES="$2"
      shift 2
      ;;
    --remote)
      [[ $# -ge 2 ]] || err "Missing value for $1"
      REMOTE="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      ;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || err "Not inside a git repository"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
  err "Unresolved merge conflicts detected"
fi

status_output="$(git status --porcelain)"
if [[ -z "$status_output" ]]; then
  printf 'No changes detected. Nothing to commit.\n'
  exit 0
fi

changed_files="$(printf '%s\n' "$status_output" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"

unstaged_shortstat="$(git diff --shortstat || true)"
staged_shortstat="$(git diff --cached --shortstat || true)"

read -r _ unstaged_insertions unstaged_deletions < <(parse_shortstat "$unstaged_shortstat")
read -r _ staged_insertions staged_deletions < <(parse_shortstat "$staged_shortstat")
untracked_insertions="$(count_untracked_insertions)"

total_insertions="$((unstaged_insertions + staged_insertions + untracked_insertions))"
total_deletions="$((unstaged_deletions + staged_deletions))"
total_changed_lines="$((total_insertions + total_deletions))"

if [[ "$FORCE" -ne 1 ]] && [[ "$changed_files" -lt "$MIN_FILES" ]] && [[ "$total_changed_lines" -lt "$MIN_LINES" ]]; then
  printf 'Skipped: change is below thresholds (files=%s, lines=%s, min_files=%s, min_lines=%s).\n' \
    "$changed_files" "$total_changed_lines" "$MIN_FILES" "$MIN_LINES"
  printf 'Use --force to commit and push anyway.\n'
  exit 0
fi

if [[ -z "$MESSAGE" ]]; then
  MESSAGE="chore: update ${changed_files} files (+${total_insertions}/-${total_deletions}) [auto]"
fi

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  err "Detached HEAD state; checkout a branch before pushing"
fi

push_mode=""
push_target=""
if push_info="$(resolve_push_target)"; then
  IFS=$'\t' read -r push_mode push_target <<<"$push_info"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Dry run:\n'
  printf '  repo: %s\n' "$repo_root"
  printf '  branch: %s\n' "$branch"
  printf '  changed_files: %s\n' "$changed_files"
  printf '  changed_lines: %s (+%s/-%s)\n' "$total_changed_lines" "$total_insertions" "$total_deletions"
  printf '  commit_message: %s\n' "$MESSAGE"
  if [[ "$push_mode" == "upstream" ]]; then
    printf '  push: git push (upstream %s)\n' "$push_target"
  elif [[ "$push_mode" == "remote" ]]; then
    printf '  push: git push -u %s %s\n' "$push_target" "$branch"
  else
    printf '  push: cannot determine remote\n'
  fi
  exit 0
fi

ensure_git_identity
if [[ -z "$push_mode" ]] || [[ -z "$push_target" ]]; then
  err "No git remote/upstream found; configure remote before auto commit/push"
fi

git add -A
if git diff --cached --quiet; then
  printf 'No staged changes after git add -A. Nothing to commit.\n'
  exit 0
fi

git commit -m "$MESSAGE"
commit_sha="$(git rev-parse --short HEAD)"

if [[ "$push_mode" == "upstream" ]]; then
  git push
  printf 'Committed %s and pushed to %s.\n' "$commit_sha" "$push_target"
  exit 0
fi

git push -u "$push_target" "$branch"
printf 'Committed %s and pushed to %s/%s (upstream set).\n' "$commit_sha" "$push_target" "$branch"
