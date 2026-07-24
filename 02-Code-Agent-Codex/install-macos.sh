#!/usr/bin/env bash
set -euo pipefail

# Deliberately fixed paths: SAM must never inherit a caller's CODEX_HOME or
# CODEX_SAM_HOME and accidentally overwrite the user's normal OpenAI Codex.
SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/../01-sam-skills/sam/SKILL.md"

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI was not found on PATH." >&2
  echo "Install Codex first, then run: codex --version" >&2
  exit 1
fi

mkdir -p "$SAM_HOME/skills/sam" "$CODEX_SAM_HOME/skills/sam" "$BIN_DIR"
chmod 700 "$SAM_HOME"

if [ -n "${SAM_CODEX_API:-}" ]; then
  key="$SAM_CODEX_API"
else
  read -r -s "SAM_CODEX_API?SAM Code Agent API key: " key
  echo
fi

key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [ -z "$key" ]; then
  echo "A SAM Code Agent API key is required." >&2
  exit 1
fi

printf 'export SAM_CODEX_API=%q\nexport SAM_API_KEY="$SAM_CODEX_API"\n' "$key" > "$SAM_HOME/env"
chmod 600 "$SAM_HOME/env"
unset key

install -m 600 "$SCRIPT_DIR/templates/codex-config.toml" "$CODEX_SAM_HOME/config.toml"
install -m 644 "$SKILL_SOURCE" "$SAM_HOME/skills/sam/SKILL.md"
install -m 644 "$SKILL_SOURCE" "$CODEX_SAM_HOME/skills/sam/SKILL.md"
install -m 755 "$SCRIPT_DIR/templates/sam-codex" "$BIN_DIR/sam-codex"

echo "SAM Codex CLI is ready."
echo "  key:    $SAM_HOME/env"
echo "  config: $CODEX_SAM_HOME/config.toml"
echo "  run:    sam-codex"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Add to your shell profile if needed: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
echo "Run 'sam-codex', then ask: sam_account_usage를 사용해서 이번 달 사용량을 요약해줘"
