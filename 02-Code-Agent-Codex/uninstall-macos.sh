#!/usr/bin/env bash
set -euo pipefail

CODEX_SAM_HOME="$HOME/.codex-sam"
BIN_DIR="$HOME/.local/bin"

rm -f "$BIN_DIR/sam-codex"
rm -f "$CODEX_SAM_HOME/config.toml"

if rmdir "$CODEX_SAM_HOME" 2>/dev/null; then
  echo "Removed the empty SAM-Codex home."
elif [ -d "$CODEX_SAM_HOME" ]; then
  echo "Preserved existing SAM-Codex session data in $CODEX_SAM_HOME."
fi

echo "Removed sam-codex. Official codex and the shared SAM key were not changed."
