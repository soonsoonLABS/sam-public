#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="${SAM_HOME:-$HOME/.sam-code-agent}"
CODEX_SAM_HOME="${CODEX_SAM_HOME:-$HOME/.codex-sam}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI was not found on PATH."
  echo "Install Node.js LTS and Codex first, then rerun this installer:"
  echo "  npm install -g @openai/codex@latest"
  echo "  codex --version"
  echo "See docs/macos.en.md for the full prerequisite setup."
  exit 1
fi

mkdir -p "$SAM_HOME" "$CODEX_SAM_HOME" "$BIN_DIR" "$HOME/Desktop"

if [ -n "${SAM_CODE_API_KEY:-}" ]; then
  key="$SAM_CODE_API_KEY"
else
  printf "Enter your dedicated Code Agent SAM API key: "
  stty -echo
  IFS= read -r key
  stty echo
  printf "\n"
fi

key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

if [ -z "$key" ]; then
  echo "SAM Code Agent API key is required."
  exit 1
fi

cat > "$SAM_HOME/env" <<EOF
export SAM_CODE_API_KEY='$key'
EOF
chmod 600 "$SAM_HOME/env"

cp "$SCRIPT_DIR/templates/codex-config.toml" "$CODEX_SAM_HOME/config.toml"
chmod 600 "$CODEX_SAM_HOME/config.toml"

cat > "$BIN_DIR/sam-codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="${SAM_HOME:-$HOME/.sam-code-agent}"
CODEX_SAM_HOME="${CODEX_SAM_HOME:-$HOME/.codex-sam}"
WORKDIR="${SAM_CODEX_WORKDIR:-/private/tmp/sam-codex-cli}"

if [ ! -f "$SAM_HOME/env" ]; then
  echo "Missing $SAM_HOME/env. Run the SAM Code Agent installer first."
  exit 1
fi

# shellcheck disable=SC1091
. "$SAM_HOME/env"
export CODEX_HOME="$CODEX_SAM_HOME"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

exec codex \
  -c 'model="sam-codex-agent"' \
  -c 'model_provider="sam"' \
  -c 'model_reasoning_effort="medium"' \
  -c 'model_providers.sam.name="SAM"' \
  -c 'model_providers.sam.base_url="https://sam.soonsoon.ai/openai/v1"' \
  -c 'model_providers.sam.env_key="SAM_CODE_API_KEY"' \
  -c 'model_providers.sam.wire_api="responses"' \
  -c 'model_providers.sam.request_max_retries=4' \
  -c 'model_providers.sam.stream_max_retries=5' \
  -c 'model_providers.sam.stream_idle_timeout_ms=300000' \
  "$@"
EOF
chmod +x "$BIN_DIR/sam-codex"

cat > "$BIN_DIR/sam-codex-desktop" <<'EOF'
#!/bin/zsh
set -euo pipefail

ENV_FILE="$HOME/.sam-code-agent/env"
CODEX_HOME_DIR="$HOME/.codex-sam"
USER_DATA_DIR="$HOME/Library/Application Support/SAM Codex Desktop"
WORKSPACE="${1:-/private/tmp/sam-codex-desktop}"

fail() {
  /usr/bin/osascript -e "display alert \"SAM Codex\" message \"$1\" as critical" >/dev/null 2>&1 || true
  echo "$1" >&2
  exit 1
}

[[ -r "$ENV_FILE" ]] || fail "Key file not found: $ENV_FILE"

set -a
source "$ENV_FILE"
set +a

[[ -n "${SAM_CODE_API_KEY:-}" ]] || fail "SAM_CODE_API_KEY is not set."
[[ -d /Applications/Codex.app ]] || fail "/Applications/Codex.app was not found."

mkdir -p "$USER_DATA_DIR" "$CODEX_HOME_DIR" "$WORKSPACE"
umask 077
printf 'SAM_CODE_API_KEY=%s\n' "$SAM_CODE_API_KEY" > "$CODEX_HOME_DIR/.env"
chmod 600 "$CODEX_HOME_DIR/.env"

launchctl setenv SAM_CODE_API_KEY "$SAM_CODE_API_KEY"
launchctl setenv CODEX_HOME "$CODEX_HOME_DIR"
open -n -a Codex --args --user-data-dir="$USER_DATA_DIR" "$WORKSPACE"
EOF
chmod +x "$BIN_DIR/sam-codex-desktop"

cat > "$HOME/Desktop/SAM-Codex.command" <<EOF
#!/bin/zsh
exec "$BIN_DIR/sam-codex-desktop" "\$@"
EOF
chmod +x "$HOME/Desktop/SAM-Codex.command"

echo "SAM Codex setup complete."
echo "Config: $CODEX_SAM_HOME/config.toml"
echo "CLI runner: $BIN_DIR/sam-codex"
echo "Desktop runner: $BIN_DIR/sam-codex-desktop"
echo "Desktop shortcut: $HOME/Desktop/SAM-Codex.command"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "Add this to your shell profile if sam-codex is not found:"
    echo "export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo
echo "Test command:"
echo "sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral 'Reply with exactly: SAM-CODEX-OK'"
echo
echo "Use plain codex for ~/.codex, and sam-codex for ~/.codex-sam."
echo "Desktop command:"
echo "sam-codex-desktop"
