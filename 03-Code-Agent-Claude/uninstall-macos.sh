#!/usr/bin/env bash
set -euo pipefail

CLAUDE_SAM_HOME="$HOME/.claude-sam"
BIN_DIR="$HOME/.local/bin"

rm -f "$BIN_DIR/sam-claude"

echo "Removed sam-claude."
echo "Official claude, the shared SAM key, and sessions in $CLAUDE_SAM_HOME were not changed."
