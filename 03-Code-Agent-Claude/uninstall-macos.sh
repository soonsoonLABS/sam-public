#!/usr/bin/env bash
set +x
set -euo pipefail

CLAUDE_SAM_HOME="$HOME/.claude-sam"
WRAPPER="$HOME/.local/bin/sam-claude"
ZSHRC="$HOME/.zshrc"
MANAGED_START="# >>> SAM-Claude managed >>>"
MANAGED_END="# <<< SAM-Claude managed <<<"
PURGE_DATA=0

fail() {
  printf 'SAM-Claude uninstall failed: %s\n' "$1" >&2
  exit 1
}

case "${1:-}" in
  "") ;;
  --purge-data) PURGE_DATA=1 ;;
  *) fail "Usage: uninstall-macos.sh [--purge-data]" ;;
esac
[ "$#" -le 1 ] || fail "Usage: uninstall-macos.sh [--purge-data]"

validate_managed_block() {
  local start_count end_count
  [ -e "$ZSHRC" ] || return 0
  start_count="$(grep -Fxc "$MANAGED_START" "$ZSHRC" || true)"
  end_count="$(grep -Fxc "$MANAGED_END" "$ZSHRC" || true)"
  if [ "$start_count" -eq 0 ] && [ "$end_count" -eq 0 ]; then
    return 0
  fi
  if [ "$start_count" -eq 1 ] && [ "$end_count" -eq 1 ] &&
    awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
      $0 == start {
        if (seen_start || seen_end) exit 1
        seen_start = 1
        next
      }
      $0 == end {
        if (!seen_start || seen_end) exit 1
        seen_end = 1
      }
      END {
        if (!seen_start || !seen_end) exit 1
      }
    ' "$ZSHRC"; then
    return 0
  fi
  fail "Malformed or duplicate SAM-Claude block in $ZSHRC. No files were changed."
}

validate_managed_block
[ ! -L "$ZSHRC" ] ||
  fail "$ZSHRC is a symlink. Use the manual removal instructions."
[ ! -L "$CLAUDE_SAM_HOME" ] ||
  fail "$CLAUDE_SAM_HOME is a symlink. It was not changed."

if [ -e "$WRAPPER" ]; then
  [ ! -L "$WRAPPER" ] ||
    fail "$WRAPPER is a symlink. It was not changed."
  [ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' "$WRAPPER" || true)" -eq 1 ] ||
    fail "Unmanaged $WRAPPER was preserved. No files were changed."
fi

if [ -f "$ZSHRC" ] && grep -Fq "$MANAGED_START" "$ZSHRC"; then
  zshrc_tmp="$(mktemp "$HOME/.zshrc.sam-claude.XXXXXX")"
  trap 'rm -f "$zshrc_tmp"' EXIT
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$ZSHRC" >"$zshrc_tmp"
  mv "$zshrc_tmp" "$ZSHRC"
  trap - EXIT
fi

if [ -e "$WRAPPER" ]; then
  rm -f "$WRAPPER"
fi

if [ "$PURGE_DATA" -eq 1 ] && [ -d "$CLAUDE_SAM_HOME" ]; then
  trash_root="$HOME/.Trash"
  mkdir -p "$trash_root"
  trash_target="$trash_root/SAM-Claude-$(date +%Y%m%d-%H%M%S)"
  mv "$CLAUDE_SAM_HOME" "$trash_target"
  printf 'SAM-Claude data moved to Trash: %s\n' "$trash_target"
fi

printf '\nSAM-Claude command removed.\n'
printf 'Official claude, ~/.claude, and the shared ~/.sam/env key were not changed.\n'
if [ "$PURGE_DATA" -eq 0 ] && [ -d "$CLAUDE_SAM_HOME" ]; then
  printf 'SAM-Claude sessions and isolated MCP settings were preserved in %s.\n' \
    "$CLAUDE_SAM_HOME"
fi
# shellcheck disable=SC2016
printf 'Open a new terminal, or run: source "$HOME/.zshrc"\n'
