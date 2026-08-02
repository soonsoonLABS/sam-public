#!/usr/bin/env bash
set +x
set -euo pipefail

# Self-contained bootstrap for the isolated SAM-Claude command.
# It never edits the user's official ~/.claude configuration.

SAM_HOME="$HOME/.sam"
CLAUDE_SAM_HOME="$HOME/.claude-sam"
BIN_DIR="$HOME/.local/bin"
ENV_FILE="$SAM_HOME/env"
WRAPPER="$BIN_DIR/sam-claude"
ZSHRC="$HOME/.zshrc"
MCP_CONFIG="$CLAUDE_SAM_HOME/.claude.json"
MCP_URL="https://sam.soonsoon.ai/mcp"
WRAPPER_URL="https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/templates/sam-claude"
WRAPPER_SHA256="0c908d05cab62d5d4f2690275e46fb6bae54f11f86b89a6c9b8dee711f0dd836"
MANAGED_START="# >>> SAM-Claude managed >>>"
MANAGED_END="# <<< SAM-Claude managed <<<"
zshrc_base_tmp=""
zshrc_output_tmp=""

fail() {
  printf 'SAM-Claude install failed: %s\n' "$1" >&2
  exit 1
}

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

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

mcp_config_status_python() {
  python3 - "$MCP_CONFIG" <<'PY'
import json
import os
import sys

path = sys.argv[1]
if not os.path.exists(path):
    print("absent")
    raise SystemExit
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    print("conflict")
    raise SystemExit
servers = data.get("mcpServers", {})
if "mcpServers" in data and not isinstance(servers, dict):
    print("conflict")
    raise SystemExit
if "sam-tools" not in servers:
    print("absent")
    raise SystemExit
server = servers["sam-tools"]
valid = (
    isinstance(server, dict)
    and server.get("type") == "http"
    and server.get("url") == "https://sam.soonsoon.ai/mcp"
    and isinstance(server.get("headers"), dict)
    and server["headers"].get("Authorization") == "Bearer ${SAM_API_KEY}"
)
print("valid" if valid else "conflict")
PY
}

mcp_config_status_node() {
  node - "$MCP_CONFIG" <<'JS'
const fs = require("fs");
const path = process.argv[2];
if (!fs.existsSync(path)) {
  process.stdout.write("absent\n");
  process.exit(0);
}
let data;
try {
  data = JSON.parse(fs.readFileSync(path, "utf8"));
} catch (_error) {
  process.stdout.write("conflict\n");
  process.exit(0);
}
if (!data || typeof data !== "object" || Array.isArray(data)) {
  process.stdout.write("conflict\n");
  process.exit(0);
}
const hasServers = Object.prototype.hasOwnProperty.call(data, "mcpServers");
const servers = hasServers ? data.mcpServers : {};
if (hasServers && (
    !servers || typeof servers !== "object" || Array.isArray(servers)
)) {
  process.stdout.write("conflict\n");
  process.exit(0);
}
if (!servers["sam-tools"]) {
  process.stdout.write("absent\n");
  process.exit(0);
}
const server = servers["sam-tools"];
const valid =
  server && typeof server === "object" &&
  server.type === "http" &&
  server.url === "https://sam.soonsoon.ai/mcp" &&
  server.headers && typeof server.headers === "object" &&
  server.headers.Authorization === "Bearer ${SAM_API_KEY}";
process.stdout.write(valid ? "valid\n" : "conflict\n");
JS
}

mcp_config_status() {
  if command -v python3 >/dev/null 2>&1; then
    mcp_config_status_python
  elif command -v node >/dev/null 2>&1; then
    mcp_config_status_node
  else
    return 1
  fi
}

write_managed_block() {
  local needs_newline
  touch "$ZSHRC"
  zshrc_base_tmp="$(mktemp "$HOME/.zshrc.sam-claude-base.XXXXXX")"
  zshrc_output_tmp="$(mktemp "$HOME/.zshrc.sam-claude.XXXXXX")"
  if grep -Fq "$MANAGED_START" "$ZSHRC"; then
    awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
      $0 == start { managed = 1; next }
      $0 == end { managed = 0; next }
      !managed { print }
    ' "$ZSHRC" >"$zshrc_base_tmp"
  else
    cp "$ZSHRC" "$zshrc_base_tmp"
  fi

  cp "$zshrc_base_tmp" "$zshrc_output_tmp"
  needs_newline=0
  if [ -s "$zshrc_output_tmp" ] &&
    [ "$(tail -c 1 "$zshrc_output_tmp" | wc -l | tr -d ' ')" -eq 0 ]; then
    needs_newline=1
  fi
  {
    [ "$needs_newline" -eq 0 ] || printf '\n'
    printf '%s\n' "$MANAGED_START"
    # shellcheck disable=SC2016
    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    printf 'sam-claude() {\n'
    # shellcheck disable=SC2016
    printf '  command "$HOME/.local/bin/sam-claude" "$@"\n'
    printf '}\n'
    printf '%s\n' "$MANAGED_END"
  } >>"$zshrc_output_tmp"
  mv "$zshrc_output_tmp" "$ZSHRC"
  zshrc_output_tmp=""
  rm -f "$zshrc_base_tmp"
  zshrc_base_tmp=""
}

# All integrity and ownership checks happen before network or user-file writes.
validate_managed_block
[ ! -L "$ZSHRC" ] ||
  fail "$ZSHRC is a symlink. Use the manual setup instead."
[ ! -L "$SAM_HOME" ] ||
  fail "$SAM_HOME is a symlink. It was not changed."
[ ! -L "$ENV_FILE" ] ||
  fail "$ENV_FILE is a symlink. It was not changed."
[ ! -L "$CLAUDE_SAM_HOME" ] ||
  fail "$CLAUDE_SAM_HOME is a symlink. It was not changed."
[ ! -L "$BIN_DIR" ] ||
  fail "$BIN_DIR is a symlink. It was not changed."
[ ! -L "$MCP_CONFIG" ] ||
  fail "$MCP_CONFIG is a symlink. It was not changed."
[ ! -L "$CLAUDE_SAM_HOME/runtime-state.json" ] ||
  fail "The SAM-Claude runtime state is a symlink. It was not changed."
[ ! -L "$WRAPPER" ] ||
  fail "$WRAPPER is a symlink. It was not changed."
if [ -e "$WRAPPER" ] &&
  [ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' "$WRAPPER" || true)" -ne 1 ]; then
  fail "Unmanaged $WRAPPER already exists. It was not changed."
fi
[ ! -e "$ENV_FILE" ] || { [ -f "$ENV_FILE" ] && [ -r "$ENV_FILE" ]; } ||
  fail "Existing $ENV_FILE is not a readable regular file. It was not changed."
case "$(mcp_config_status)" in
  valid | absent) ;;
  conflict)
    fail "Existing sam-tools MCP entry is malformed or points elsewhere. It was not changed."
    ;;
  *) fail "Could not inspect the isolated Claude MCP configuration." ;;
esac

command -v claude >/dev/null 2>&1 ||
  fail "Official Claude Code is missing. Install it from https://code.claude.com/docs/en/setup."
command -v curl >/dev/null 2>&1 || fail "curl is required."
if ! command -v python3 >/dev/null 2>&1 &&
  ! command -v node >/dev/null 2>&1; then
  fail "Python 3 or Node.js is required to validate SAM discovery."
fi

key=""
key_from_existing_file=0
if [ -r "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +x
  key="${SAM_API_KEY:-}"
  key_from_existing_file=1
elif [ -n "${SAM_API_KEY:-}" ]; then
  key="$SAM_API_KEY"
else
  [ -r /dev/tty ] || fail "Run this installer from an interactive terminal."
  IFS= read -r -s -p "SAM API key: " key </dev/tty
  printf '\n' >/dev/tty
fi
key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
[ -n "$key" ] || fail "SAM_API_KEY is required."

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/sam-claude-install.XXXXXX")"
wrapper_tmp="$temp_root/sam-claude"
state_tmp="$temp_root/runtime-state.json"
mcp_backup="$temp_root/mcp-config.backup"
wrapper_backup="$temp_root/wrapper.backup"
state_backup="$temp_root/runtime-state.backup"
zshrc_backup="$temp_root/zshrc.backup"
mcp_existed=0
wrapper_existed=0
state_existed=0
zshrc_existed=0
transaction_active=0
cleanup() {
  if [ "$transaction_active" -eq 1 ]; then
    if [ "$mcp_existed" -eq 1 ]; then
      cp "$mcp_backup" "$MCP_CONFIG" 2>/dev/null || true
    else
      rm -f "$MCP_CONFIG"
    fi
    if [ "$wrapper_existed" -eq 1 ]; then
      cp "$wrapper_backup" "$WRAPPER" 2>/dev/null || true
      chmod 755 "$WRAPPER" 2>/dev/null || true
    else
      rm -f "$WRAPPER"
    fi
    if [ "$state_existed" -eq 1 ]; then
      cp "$state_backup" "$CLAUDE_SAM_HOME/runtime-state.json" 2>/dev/null || true
    else
      rm -f "$CLAUDE_SAM_HOME/runtime-state.json"
    fi
    if [ "$zshrc_existed" -eq 1 ]; then
      cp "$zshrc_backup" "$ZSHRC" 2>/dev/null || true
    else
      rm -f "$ZSHRC"
    fi
    if [ "$key_from_existing_file" -eq 0 ]; then
      rm -f "$ENV_FILE"
    fi
  fi
  unset key SAM_API_KEY
  [ -z "$zshrc_base_tmp" ] || rm -f "$zshrc_base_tmp"
  [ -z "$zshrc_output_tmp" ] || rm -f "$zshrc_output_tmp"
  rm -rf "$temp_root"
}
trap cleanup EXIT

curl --fail --silent --show-error --max-time 20 \
  -o "$wrapper_tmp" "$WRAPPER_URL" ||
  fail "Could not download the verified SAM-Claude wrapper."
actual_wrapper_sha="$(sha256_file "$wrapper_tmp")" ||
  fail "A SHA-256 utility is required."
[ "$actual_wrapper_sha" = "$WRAPPER_SHA256" ] ||
  fail "Downloaded SAM-Claude wrapper checksum mismatch."
[ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' "$wrapper_tmp" || true)" -eq 1 ] ||
  fail "Downloaded wrapper ownership marker is missing."
chmod 755 "$wrapper_tmp"

SAM_API_KEY="$key" \
SAM_CLAUDE_STATE_PATH="$state_tmp" \
SAM_CLAUDE_PREFLIGHT_ONLY=1 \
  "$wrapper_tmp" >/dev/null ||
  fail "Authenticated SAM-Claude discovery or role mapping validation failed."
[ -s "$state_tmp" ] || fail "Verified runtime state was not created."

umask 077
mkdir -p "$SAM_HOME" "$CLAUDE_SAM_HOME" "$BIN_DIR"
chmod 700 "$SAM_HOME" "$CLAUDE_SAM_HOME"

if [ -e "$MCP_CONFIG" ]; then
  cp "$MCP_CONFIG" "$mcp_backup"
  mcp_existed=1
fi
if [ -e "$WRAPPER" ]; then
  cp "$WRAPPER" "$wrapper_backup"
  wrapper_existed=1
fi
if [ -e "$CLAUDE_SAM_HOME/runtime-state.json" ]; then
  cp "$CLAUDE_SAM_HOME/runtime-state.json" "$state_backup"
  state_existed=1
fi
if [ -e "$ZSHRC" ]; then
  cp "$ZSHRC" "$zshrc_backup"
  zshrc_existed=1
fi
transaction_active=1
if [ "$(mcp_config_status)" = "absent" ]; then
  # Keep the environment-variable reference literal in the isolated MCP file.
  # shellcheck disable=SC2016
  if ! CLAUDE_CONFIG_DIR="$CLAUDE_SAM_HOME" \
    SAM_API_KEY="$key" \
    claude mcp add --transport http --scope user \
      sam-tools "$MCP_URL" \
      --header 'Authorization: Bearer ${SAM_API_KEY}' >/dev/null ||
    [ "$(mcp_config_status)" != "valid" ]; then
    if [ "$mcp_existed" -eq 1 ]; then
      cp "$mcp_backup" "$MCP_CONFIG"
    else
      rm -f "$MCP_CONFIG"
    fi
    fail "Could not add the isolated sam-tools MCP entry."
  fi
fi

if [ "$key_from_existing_file" -eq 0 ]; then
  env_tmp="$(mktemp "$SAM_HOME/.env.XXXXXX")"
  printf 'export SAM_API_KEY=%q\n' "$key" >"$env_tmp"
  chmod 600 "$env_tmp"
  mv "$env_tmp" "$ENV_FILE"
fi

wrapper_install_tmp="$(mktemp "$BIN_DIR/.sam-claude.XXXXXX")"
cp "$wrapper_tmp" "$wrapper_install_tmp"
chmod 755 "$wrapper_install_tmp"
mv "$wrapper_install_tmp" "$WRAPPER"

state_install_tmp="$(mktemp "$CLAUDE_SAM_HOME/.runtime-state.XXXXXX")"
cp "$state_tmp" "$state_install_tmp"
chmod 600 "$state_install_tmp"
mv "$state_install_tmp" "$CLAUDE_SAM_HOME/runtime-state.json"

write_managed_block
transaction_active=0
unset key SAM_API_KEY

printf '\nSAM-Claude installed successfully.\n'
printf '  Official Claude Code: claude\n'
printf '  SAM Claude:           sam-claude\n'
printf '  SAM gateway:          /v2/claude\n'
printf '  SAM tools:            search, page reading, account usage\n\n'
# shellcheck disable=SC2016
printf 'Open a new terminal, or run: source "$HOME/.zshrc"\n'
printf 'Then start with: sam-claude\n'
