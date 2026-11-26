#!/usr/bin/env bash
set -euo pipefail

SKIP_PULL=0
KEEP_CONFLICTING=0
for arg in "$@"; do
  case "$arg" in
    --skip-pull) SKIP_PULL=1 ;;
    --keep-conflicting) KEEP_CONFLICTING=1 ;;
  esac
done

AGENTS_SKILLS_DIR="$HOME/.agents/skills"
PLAIN_DEV_DIR="$AGENTS_SKILLS_DIR/plain-dev"
SOBER_DIR="$AGENTS_SKILLS_DIR/sober"
SCRIPT_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLAIN_DEV_REPO="https://github.com/jeffcwj/plain-dev.git"
SOBER_REPO="https://github.com/jeffcwj/sober.git"

ensure_git_repo() {
  local target="$1"
  local url="$2"
  if [ -d "$target/.git" ]; then
    if [ "$SKIP_PULL" -eq 0 ]; then
      if [ -z "$(git -C "$target" status --porcelain)" ]; then
        echo "[sync] git pull $target"
        git -C "$target" pull --ff-only >/dev/null
      else
        echo "[skip] $target 有未提交改动，跳过 pull"
      fi
    fi
  else
    mkdir -p "$(dirname "$target")"
    echo "[clone] $url -> $target"
    git clone "$url" "$target"
  fi
}

ensure_skill_link() {
  local claude_skills="$HOME/.claude/skills"
  if [ ! -e "$claude_skills" ]; then
    mkdir -p "$(dirname "$claude_skills")"
    ln -s "$AGENTS_SKILLS_DIR" "$claude_skills"
    echo "[link] $claude_skills -> $AGENTS_SKILLS_DIR"
  elif [ -L "$claude_skills" ]; then
    echo "[ok] $claude_skills 已软链到 $AGENTS_SKILLS_DIR"
  else
    for name in plain-dev sober; do
      if [ ! -e "$claude_skills/$name" ]; then
        ln -s "$AGENTS_SKILLS_DIR/$name" "$claude_skills/$name"
        echo "[link] $claude_skills/$name -> $AGENTS_SKILLS_DIR/$name"
      fi
    done
  fi
}

merge_managed_block() {
  local target="$1"
  local template="$2"
  mkdir -p "$(dirname "$target")"
  python3 - "$target" "$template" <<'PY'
import pathlib, re, sys

target = pathlib.Path(sys.argv[1])
content = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").strip()
start, end = "<!-- plain-dev:START -->", "<!-- plain-dev:END -->"
managed = f"{start}\n{content}\n{end}"

if not target.exists():
    target.write_text(f"# 全局规则\n\n{managed}\n", encoding="utf-8")
    print(f"[write] {target}")
else:
    existing = target.read_text(encoding="utf-8")
    pat = re.escape(start) + r"[\s\S]*?" + re.escape(end)
    if re.search(pat, existing):
        updated = re.sub(pat, lambda _: managed, existing, count=1)
    elif not existing.strip():
        updated = f"# 全局规则\n\n{managed}\n"
    else:
        updated = f"{managed}\n\n{existing.lstrip()}"
    target.write_text(updated, encoding="utf-8")
    print(f"[sync] {target}")
PY
}

disable_skill_if_present() {
  local skill_path="$1"
  local backup_dir="$2"
  if [ -e "$skill_path" ]; then
    local name
    name="$(basename "$skill_path")"
    mkdir -p "$backup_dir"
    rm -rf "$backup_dir/$name"
    mv "$skill_path" "$backup_dir/$name"
    echo "[isolate] $skill_path -> $backup_dir/$name"
  fi
}

mkdir -p "$AGENTS_SKILLS_DIR"
ensure_git_repo "$PLAIN_DEV_DIR" "$PLAIN_DEV_REPO"
ensure_git_repo "$SOBER_DIR" "$SOBER_REPO"
ensure_skill_link

TEMPLATE="$PLAIN_DEV_DIR/global/AGENTS.md"
[ -f "$TEMPLATE" ] || TEMPLATE="$SCRIPT_REPO_DIR/global/AGENTS.md"

merge_managed_block "$HOME/.claude/AGENTS.md" "$TEMPLATE"
merge_managed_block "$HOME/.config/opencode/AGENTS.md" "$TEMPLATE"
merge_managed_block "$HOME/.codex/AGENTS.md" "$TEMPLATE"

if [ -f "$HOME/.claude/CLAUDE.md" ]; then
  echo "[notice] 检测到旧文件 $HOME/.claude/CLAUDE.md（最新 Claude Code 已统一读 AGENTS.md），请确认无需保留后手动删除"
fi

if [ "$KEEP_CONFLICTING" -eq 0 ]; then
  disable_skill_if_present "$AGENTS_SKILLS_DIR/pua" "$HOME/.agents/skills-disabled"
  disable_skill_if_present "$HOME/.config/opencode/skills/verification-planning" "$HOME/.config/opencode/skills-disabled"
fi

echo
echo "部署完成：plain-dev + sober 及全局 AGENTS.md 已全部就绪。"
