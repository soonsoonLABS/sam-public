#!/usr/bin/env bash
set -euo pipefail

# Fixed paths protect the user's normal OpenAI Codex home from caller overrides.
SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/../01-sam-skills/sam/SKILL.md"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/openai/models"

fail() {
  echo "Error: $1" >&2
  exit 1
}

command -v codex >/dev/null 2>&1 ||
  fail "Codex CLI is not on PATH. Install it first, then run: codex --version"
command -v curl >/dev/null 2>&1 || fail "curl is required."

mkdir -p \
  "$SAM_HOME/skills/sam" \
  "$CODEX_SAM_HOME/skills/sam" \
  "$BIN_DIR"
chmod 700 "$SAM_HOME"

if [ -n "${SAM_API_KEY:-}" ]; then
  key="$SAM_API_KEY"
elif [ -r "$SAM_HOME/env" ]; then
  # shellcheck disable=SC1091
  . "$SAM_HOME/env"
  key="${SAM_API_KEY:-}"
else
  IFS= read -r -s -p "Shared SAM API key: " key
  printf "\n"
fi

key="$(printf "%s" "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
[ -n "$key" ] || fail "SAM_API_KEY is required."

catalog_tmp="$(mktemp "$CODEX_SAM_HOME/.models.XXXXXX")"
trap 'rm -f "$catalog_tmp"' EXIT

if ! curl --fail --silent --show-error --max-time 20 \
  -H "Authorization: Bearer $key" \
  "$DISCOVERY_URL" > "$catalog_tmp"; then
  fail "SAM OpenAI discovery failed. Fix the key, grant, or runtime before installing."
fi

grep -Eq '"slug"[[:space:]]*:[[:space:]]*"azure\.gpt-5\.6-luna"' "$catalog_tmp" ||
  fail "The stable default azure.gpt-5.6-luna is not admitted for this key."

printf 'export SAM_API_KEY=%q\n' "$key" > "$SAM_HOME/env"
chmod 600 "$SAM_HOME/env"
unset key

mv "$catalog_tmp" "$CODEX_SAM_HOME/models.json"
chmod 600 "$CODEX_SAM_HOME/models.json"
trap - EXIT

install -m 600 "$SCRIPT_DIR/templates/codex-config.toml" "$CODEX_SAM_HOME/config.toml"
install -m 644 "$SKILL_SOURCE" "$SAM_HOME/skills/sam/SKILL.md"
install -m 644 "$SKILL_SOURCE" "$CODEX_SAM_HOME/skills/sam/SKILL.md"
install -m 755 "$SCRIPT_DIR/templates/sam-codex" "$BIN_DIR/sam-codex"

echo "SAM-Codex is ready."
echo "  shared key: $SAM_HOME/env"
echo "  config:     $CODEX_SAM_HOME/config.toml"
echo "  command:    sam-codex"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Add to your shell profile if needed: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

echo "Official Codex remains available as: codex"
