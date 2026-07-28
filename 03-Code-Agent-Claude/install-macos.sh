#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="$HOME/.sam"
CLAUDE_SAM_HOME="$HOME/.claude-sam"
BIN_DIR="$HOME/.local/bin"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/anthropic/v1/models"

fail() {
  echo "Error: $1" >&2
  exit 1
}

command -v claude >/dev/null 2>&1 ||
  fail "Claude Code is not on PATH. Follow https://code.claude.com/docs/en/setup first."
command -v curl >/dev/null 2>&1 || fail "curl is required."

mkdir -p "$SAM_HOME" "$CLAUDE_SAM_HOME" "$BIN_DIR"

if [ -z "${SAM_API_KEY:-}" ] && [ -r "$SAM_HOME/env" ]; then
  # shellcheck disable=SC1091
  . "$SAM_HOME/env"
fi

if [ -z "${SAM_API_KEY:-}" ]; then
  IFS= read -r -s -p "Enter the shared SAM API key: " SAM_API_KEY
  printf "\n"
  export SAM_API_KEY
fi

[ -n "${SAM_API_KEY:-}" ] || fail "SAM_API_KEY is required."

response_file="$(mktemp "${TMPDIR:-/tmp}/sam-anthropic-models.XXXXXX")"
trap 'rm -f "$response_file"' EXIT

http_status="$(
  curl -sS --max-time 20 -o "$response_file" -w "%{http_code}" \
    "$DISCOVERY_URL" \
    -H "Authorization: Bearer $SAM_API_KEY"
)"

[ "$http_status" = "200" ] ||
  fail "SAM Anthropic discovery returned HTTP $http_status. Fix the key/grant/runtime before installing."

for required_model in \
  anthropic.claude-haiku-4-5 \
  anthropic.claude-sonnet-5 \
  anthropic.claude-opus-5
do
  if command -v node >/dev/null 2>&1; then
    found="$(
      node -e '
        const fs = require("fs");
        const body = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const target = process.argv[2];
        process.stdout.write((body.data || []).some(item => item && item.id === target) ? "yes" : "no");
      ' "$response_file" "$required_model"
    )"
  elif command -v python3 >/dev/null 2>&1; then
    found="$(
      python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    body = json.load(handle)
print("yes" if any(item.get("id") == sys.argv[2] for item in body.get("data", [])) else "no", end="")
' "$response_file" "$required_model"
    )"
  else
    fail "Node.js or Python 3 is required to read the discovery response."
  fi

  [ "$found" = "yes" ] ||
    fail "Required backing model '$required_model' is absent from authenticated discovery. Check the SAM Claude role mapping."
done

printf 'export SAM_API_KEY=%q\n' "$SAM_API_KEY" > "$SAM_HOME/env"
chmod 600 "$SAM_HOME/env"

cat > "$CLAUDE_SAM_HOME/settings.json" <<'EOF'
{
  "model": "claude-sonnet-5"
}
EOF
chmod 600 "$CLAUDE_SAM_HOME/settings.json"

cat > "$BIN_DIR/sam-claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="$HOME/.sam"
CLAUDE_SAM_HOME="$HOME/.claude-sam"

if [ ! -r "$SAM_HOME/env" ]; then
  echo "Missing $SAM_HOME/env. Run the SAM installer first." >&2
  exit 1
fi

# shellcheck disable=SC1091
. "$SAM_HOME/env"

unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY

export CLAUDE_CONFIG_DIR="$CLAUDE_SAM_HOME"
export ANTHROPIC_BASE_URL="https://sam.soonsoon.ai/v2/anthropic"
export ANTHROPIC_AUTH_TOKEN="$SAM_API_KEY"
export ANTHROPIC_MODEL="claude-sonnet-5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-5"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-5"
export ANTHROPIC_SMALL_FAST_MODEL="claude-haiku"

mkdir -p "$CLAUDE_CONFIG_DIR"
exec claude "$@"
EOF
chmod +x "$BIN_DIR/sam-claude"

echo
echo "SAM-Claude installed."
echo "Config home: $CLAUDE_SAM_HOME"
echo "Command: $BIN_DIR/sam-claude"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "Add this line to your shell profile, then open a new terminal:"
    echo "export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo
echo "Official Claude Code remains: claude"
echo "SAM-Claude command:          sam-claude"
