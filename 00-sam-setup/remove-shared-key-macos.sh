#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="$HOME/.sam"
BIN_DIR="$HOME/.local/bin"

if [ -e "$BIN_DIR/sam-codex" ] || [ -e "$BIN_DIR/sam-claude" ]; then
  echo "A SAM wrapper is still installed in $BIN_DIR."
  echo "Remove both wrappers before deleting their shared key."
  exit 1
fi

rm -f "$SAM_HOME/env"
rmdir "$SAM_HOME" 2>/dev/null || true

echo "Removed the installed shared SAM key file."
echo "Run 'unset SAM_API_KEY' in each already-open terminal."
