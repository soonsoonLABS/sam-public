#!/usr/bin/env bash
set +x
set -euo pipefail

# Self-contained SAM AionUI add-on installer for macOS.
# It only creates the SAM Codex ACP launcher used by the AionUI desktop app.
# It never edits ~/.codex, ~/.claude, ~/.sam/env, or the installed SAM wrappers.

SAM_HOME="$HOME/.sam"
ENV_FILE="$SAM_HOME/env"
BIN_DIR="$HOME/.local/bin"
SAM_CODEX="$BIN_DIR/sam-codex"
SAM_CLAUDE="$BIN_DIR/sam-claude"
LAUNCHER="$BIN_DIR/sam-codex-acp"
AIONUI_RUNTIME="$HOME/.aionui/runtime"
MANAGED_MARKER="# SAM_AIONUI_ADDON_MANAGED=1"

CLAUDE_BASE_URL="https://sam.soonsoon.ai/v2/claude"
CLAUDE_SAM_HOME="$HOME/.claude-sam"

fail() {
  printf 'SAM AionUI add-on install failed: %s\n' "$1" >&2
  exit 1
}

note() {
  printf '%s\n' "$1"
}

# --- Prerequisites ----------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || fail "this installer supports macOS only."

[ -d "$BIN_DIR" ] || fail "$BIN_DIR was not found. Install sam-codex first."
[ -L "$BIN_DIR" ] && fail "$BIN_DIR is a symbolic link. Resolve it before installing."

[ -x "$SAM_CODEX" ] || fail "sam-codex was not found. Install 02-Code-Agent-Codex first."
[ -x "$SAM_CLAUDE" ] || note "Notice: sam-claude was not found. Install 03-Code-Agent-Claude to use SAM Claude in AionUI."

if [ ! -r "$ENV_FILE" ]; then
  fail "$ENV_FILE was not found. Store the shared key with 00-sam-setup first."
fi

OFFICIAL_CODEX="$(command -v codex || true)"
[ -n "$OFFICIAL_CODEX" ] && [ -x "$OFFICIAL_CODEX" ] \
  || fail "the official codex executable was not found."

[ -d "$AIONUI_RUNTIME" ] \
  || fail "AionUI runtime was not found. Launch AionUI once, then run this installer again."

# --- Resolve the AionUI managed runtime -------------------------------------

NODE_BIN="$(
  find "$AIONUI_RUNTIME/node" -maxdepth 3 -type f -name node -perm -100 2>/dev/null \
    | sort -V | tail -1
)"
[ -n "$NODE_BIN" ] && [ -x "$NODE_BIN" ] \
  || fail "AionUI runtime was not found: managed Node is missing."

ACP_ENTRY="$(
  find "$AIONUI_RUNTIME/managed-tools/acp/codex-acp" -maxdepth 7 -type f \
    -path '*@agentclientprotocol/codex-acp/dist/index.js' 2>/dev/null \
    | sort -V | tail -1
)"
[ -n "$ACP_ENTRY" ] && [ -r "$ACP_ENTRY" ] \
  || fail "AionUI runtime was not found: open one built-in Codex CLI conversation in AionUI, then run this installer again."

# --- Protect a launcher this installer does not own --------------------------

if [ -L "$LAUNCHER" ]; then
  fail "$LAUNCHER is a symbolic link. Nothing was changed."
fi

if [ -e "$LAUNCHER" ] \
  && [ "$(grep -Fxc "$MANAGED_MARKER" "$LAUNCHER" || true)" -ne 1 ]; then
  fail "an unmanaged $LAUNCHER already exists. Back it up under another name first."
fi

# --- Write the launcher -----------------------------------------------------

LAUNCHER_TMP="$(mktemp "$BIN_DIR/.sam-codex-acp.XXXXXX")"

cat >"$LAUNCHER_TMP" <<EOF
#!/usr/bin/env bash
$MANAGED_MARKER
# Dedicated AionUI ACP launcher for SAM Codex.
# Managed by the SAM AionUI add-on installer. Official Codex remains in ~/.codex.
set -euo pipefail

NODE_BIN="$NODE_BIN"
ACP_ENTRY="$ACP_ENTRY"
SAM_CODEX="$SAM_CODEX"
OFFICIAL_CODEX="$OFFICIAL_CODEX"

[ -x "\$NODE_BIN" ] || {
  echo "AionUI managed Node executable was not found." >&2
  exit 1
}
[ -r "\$ACP_ENTRY" ] || {
  echo "AionUI codex-acp entrypoint was not found." >&2
  exit 1
}
[ -x "\$SAM_CODEX" ] || {
  echo "SAM Codex wrapper was not found." >&2
  exit 1
}
[ -x "\$OFFICIAL_CODEX" ] || {
  echo "Official Codex executable was not found." >&2
  exit 1
}

export CODEX_PATH="\$SAM_CODEX"
export MODEL_PROVIDER="sam"
export NO_BROWSER="1"
export SAM_CODEX_BIN="\$OFFICIAL_CODEX"

exec "\$NODE_BIN" "\$ACP_ENTRY" "\$@"
EOF

chmod 700 "$LAUNCHER_TMP"
mv "$LAUNCHER_TMP" "$LAUNCHER"

bash -n "$LAUNCHER" || fail "the generated launcher failed a syntax check."

# --- Report -----------------------------------------------------------------

cat <<EOF

SAM AionUI add-on installed successfully.
Launcher: $LAUNCHER

No key was stored. The wrappers authenticate through $ENV_FILE.

Next, register two agents in AionUI (Settings -> Agents). Leave key fields empty.

1. Add a custom agent
   Name    : SAM Codex Agent
   Command : $LAUNCHER

2. Repoint the existing Claude Code agent
   Command override : $SAM_CLAUDE
   ANTHROPIC_BASE_URL                          = $CLAUDE_BASE_URL
   CLAUDE_CONFIG_DIR                           = $CLAUDE_SAM_HOME
   CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY  = 1

Verify with no generation cost:
  sam-codex mcp list
  sam-claude mcp list
EOF
