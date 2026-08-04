#!/usr/bin/env bash
set +x
set -euo pipefail

# Removes only the launcher created by the SAM AionUI add-on installer.
# It preserves sam-codex, sam-claude, ~/.codex-sam, ~/.claude-sam, and ~/.sam/env.

BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/sam-codex-acp"
MANAGED_MARKER="# SAM_AIONUI_ADDON_MANAGED=1"
TRASH_DIR="$HOME/.Trash"

fail() {
  printf 'SAM AionUI add-on removal failed: %s\n' "$1" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "this script supports macOS only."

if [ ! -e "$LAUNCHER" ]; then
  printf 'Nothing to remove: %s was not found.\n' "$LAUNCHER"
  exit 0
fi

if [ -L "$LAUNCHER" ]; then
  fail "$LAUNCHER is a symbolic link. Nothing was removed."
fi

if [ "$(grep -Fxc "$MANAGED_MARKER" "$LAUNCHER" || true)" -ne 1 ]; then
  fail "$LAUNCHER is not managed by this installer. Nothing was removed."
fi

mkdir -p "$TRASH_DIR"
mv "$LAUNCHER" "$TRASH_DIR/sam-codex-acp-$(date +%Y%m%d-%H%M%S)"

cat <<'EOF'
The SAM AionUI launcher was moved to the Trash.
Preserved: sam-codex, sam-claude, ~/.codex-sam, ~/.claude-sam, ~/.sam/env.

Finish in AionUI (Settings -> Agents):
  1. Delete the custom "SAM Codex Agent".
  2. Clear the command override and environment variables on "Claude Code".
EOF
