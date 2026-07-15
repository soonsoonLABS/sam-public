#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="${SAM_HOME:-$HOME/.sam-code-agent}"
CODEX_SAM_HOME="${CODEX_SAM_HOME:-$HOME/.codex-sam}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI was not found on PATH."
  echo "Install Codex first, then rerun this installer."
  exit 1
fi

mkdir -p "$SAM_HOME" "$CODEX_SAM_HOME" "$BIN_DIR"

if [ -n "${SAM_API_KEY:-}" ]; then
  key="$SAM_API_KEY"
else
  printf "Enter your SAM API key: "
  stty -echo
  IFS= read -r key
  stty echo
  printf "\n"
fi

if [ -z "$key" ]; then
  echo "SAM API key is required."
  exit 1
fi

cat > "$SAM_HOME/env" <<EOF
export SAM_API_KEY='$key'
EOF
chmod 600 "$SAM_HOME/env"

cp "$SCRIPT_DIR/templates/codex-config.toml" "$CODEX_SAM_HOME/config.toml"
chmod 600 "$CODEX_SAM_HOME/config.toml"

cat > "$BIN_DIR/sam-codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="${SAM_HOME:-$HOME/.sam-code-agent}"
CODEX_SAM_HOME="${CODEX_SAM_HOME:-$HOME/.codex-sam}"

if [ ! -f "$SAM_HOME/env" ]; then
  echo "Missing $SAM_HOME/env. Run the SAM code-agent installer first."
  exit 1
fi

# shellcheck disable=SC1091
. "$SAM_HOME/env"
export CODEX_HOME="$CODEX_SAM_HOME"

exec codex "$@"
EOF
chmod +x "$BIN_DIR/sam-codex"

echo "SAM Codex setup complete."
echo "Config: $CODEX_SAM_HOME/config.toml"
echo "Runner: $BIN_DIR/sam-codex"

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
echo "Desktop command:"
echo "sam-codex app"
