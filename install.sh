#!/usr/bin/env bash
# One-shot remote installer. Run via:
#   curl -fsSL https://raw.githubusercontent.com/chuccv/ddev-magento-performance-tuning/main/install.sh | bash
#
# Downloads SKILL.md into ~/.claude/skills/ddev-magento-performance-tuning/ — no git clone needed.
set -euo pipefail

SKILL_NAME="ddev-magento-performance-tuning"
RAW_URL="https://raw.githubusercontent.com/chuccv/${SKILL_NAME}/main/SKILL.md"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/$SKILL_NAME"
DEST="$DEST_DIR/SKILL.md"

mkdir -p "$DEST_DIR"
curl -fsSL "$RAW_URL" -o "$DEST"
echo "installed: $DEST"
