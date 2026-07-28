#!/usr/bin/env bash
set -euo pipefail

CODEX_SAM_HOME="$HOME/.codex-sam"
WRAPPER="$HOME/.local/bin/sam-codex"
ZSHRC="$HOME/.zshrc"
MANAGED_START="# >>> SAM-Codex managed >>>"
MANAGED_END="# <<< SAM-Codex managed <<<"

fail() {
  printf 'SAM-Codex uninstall failed: %s\n' "$1" >&2
  exit 1
}

validate_managed_block() {
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

  fail "Malformed or duplicate SAM-Codex block in $ZSHRC. No files were changed."
}

# Fail closed before removing or moving any user file.
validate_managed_block

if [ -e "$WRAPPER" ]; then
  if grep -Fq "SAM_CODEX_INSTALLER_MANAGED=1" "$WRAPPER"; then
    rm -f "$WRAPPER"
  else
    printf 'Preserved unmanaged command: %s\n' "$WRAPPER" >&2
  fi
fi

if [ -d "$CODEX_SAM_HOME" ]; then
  trash_root="$HOME/.Trash"
  mkdir -p "$trash_root"
  trash_target="$trash_root/SAM-Codex-$(date +%Y%m%d-%H%M%S)"
  mv "$CODEX_SAM_HOME" "$trash_target"
  printf 'SAM-Codex data moved to Trash: %s\n' "$trash_target"
fi

if [ -f "$ZSHRC" ] && grep -Fq "$MANAGED_START" "$ZSHRC"; then
  zshrc_tmp="$(mktemp "$HOME/.zshrc.sam-codex.XXXXXX")"
  trap 'rm -f "$zshrc_tmp"' EXIT
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$ZSHRC" >"$zshrc_tmp"
  mv "$zshrc_tmp" "$ZSHRC"
  trap - EXIT
fi

printf '\nSAM-Codex removed.\n'
printf 'Official codex, ~/.codex, and the shared ~/.sam/env key were not changed.\n'
# shellcheck disable=SC2016
printf 'Open a new terminal, or run: source "$HOME/.zshrc"\n'
