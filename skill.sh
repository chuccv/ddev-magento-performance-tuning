#!/usr/bin/env bash
# skill.sh — install / sync helper for the ddev-magento-performance-tuning skill.
#
# Usage:
#   ./skill.sh install              copy SKILL.md to ~/.claude/skills/<name>/
#   ./skill.sh link                 symlink instead of copy
#   ./skill.sh uninstall            remove ~/.claude/skills/<name>/
#   ./skill.sh push "<message>"     git add -u && commit && push to origin
#   ./skill.sh status               show install + git status
set -euo pipefail

SKILL_NAME="ddev-magento-performance-tuning"
SKILL_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SKILL_SRC_DIR/SKILL.md"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST_DIR="$CLAUDE_SKILLS_DIR/$SKILL_NAME"
DEST="$DEST_DIR/SKILL.md"

cmd="${1:-}"

case "$cmd" in
  install)
    mkdir -p "$DEST_DIR"
    cp "$SKILL_SRC" "$DEST"
    echo "installed: $DEST"
    ;;
  link)
    mkdir -p "$DEST_DIR"
    ln -sfn "$SKILL_SRC" "$DEST"
    echo "linked:    $DEST -> $SKILL_SRC"
    ;;
  uninstall)
    if [ -e "$DEST" ] || [ -L "$DEST" ]; then
      rm -f "$DEST"
      echo "removed:   $DEST"
    else
      echo "not installed: $DEST"
    fi
    # only drop the dir if it is now empty (preserves any sibling files the user added)
    if [ -d "$DEST_DIR" ] && [ -z "$(ls -A "$DEST_DIR")" ]; then
      rmdir "$DEST_DIR"
      echo "removed:   $DEST_DIR (was empty)"
    fi
    ;;
  push)
    msg="${2:-Update skill}"
    cd "$SKILL_SRC_DIR"
    git add -A
    if git diff --cached --quiet; then
      echo "nothing to commit"
      exit 0
    fi
    git commit -m "$msg"
    git push origin HEAD
    ;;
  status)
    echo "source:    $SKILL_SRC"
    if [ -L "$DEST" ]; then
      echo "installed: $DEST (symlink -> $(readlink "$DEST"))"
    elif [ -f "$DEST" ]; then
      echo "installed: $DEST (copy)"
    else
      echo "installed: NO"
    fi
    cd "$SKILL_SRC_DIR" && git status --short
    ;;
  *)
    sed -n '2,9p' "$0"
    exit 1
    ;;
esac
