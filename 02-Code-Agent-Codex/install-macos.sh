#!/usr/bin/env bash
set -euo pipefail

# Self-contained SAM-Codex installer for macOS.
# It never edits the user's normal ~/.codex home.

SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
BIN_DIR="$HOME/.local/bin"
ENV_FILE="$SAM_HOME/env"
WRAPPER="$BIN_DIR/sam-codex"
ZSHRC="$HOME/.zshrc"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/openai/models"
MCP_URL="https://sam.soonsoon.ai/mcp"
MANAGED_START="# >>> SAM-Codex managed >>>"
MANAGED_END="# <<< SAM-Codex managed <<<"

fail() {
  printf 'SAM-Codex install failed: %s\n' "$1" >&2
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

# Fail closed before creating or replacing any user file.
validate_managed_block

command -v codex >/dev/null 2>&1 ||
  fail "Codex CLI is missing. Install official Codex first: npm install -g @openai/codex@latest"
command -v curl >/dev/null 2>&1 || fail "curl is required."

umask 077
mkdir -p "$SAM_HOME" "$CODEX_SAM_HOME" "$BIN_DIR"
chmod 700 "$SAM_HOME" "$CODEX_SAM_HOME"

key=""
if [ -n "${SAM_API_KEY:-}" ]; then
  key="$SAM_API_KEY"
elif [ -r "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  key="${SAM_API_KEY:-}"
else
  [ -r /dev/tty ] || fail "Run this installer from an interactive terminal."
  IFS= read -r -s -p "SAM API key: " key </dev/tty
  printf '\n' >/dev/tty
fi

key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
[ -n "$key" ] || fail "SAM_API_KEY is required."

catalog_tmp="$(mktemp "$CODEX_SAM_HOME/.models.XXXXXX")"
zshrc_tmp=""
cleanup() {
  rm -f "$catalog_tmp"
  [ -z "$zshrc_tmp" ] || rm -f "$zshrc_tmp"
}
trap cleanup EXIT

if ! curl --fail --silent --show-error --max-time 25 \
  -H "Authorization: Bearer $key" \
  "$DISCOVERY_URL" >"$catalog_tmp"; then
  fail "SAM model discovery failed. Check the key and SAM Code Agent access."
fi

default_model=""
for candidate in \
  azure.gpt-5.6-luna \
  azure.gpt-5.6-terra \
  azure.gpt-5.6-sol
do
  if grep -Eq "\"slug\"[[:space:]]*:[[:space:]]*\"$candidate\"" "$catalog_tmp"; then
    default_model="$candidate"
    break
  fi
done
[ -n "$default_model" ] ||
  fail "No supported SAM Codex default model was returned by discovery."

printf 'export SAM_API_KEY=%q\n' "$key" >"$ENV_FILE"
chmod 600 "$ENV_FILE"
unset key SAM_API_KEY

mv "$catalog_tmp" "$CODEX_SAM_HOME/models.json"
catalog_tmp=""
chmod 600 "$CODEX_SAM_HOME/models.json"

cat >"$CODEX_SAM_HOME/config.toml" <<EOF
# Managed by the SAM-Codex installer. Official Codex remains in ~/.codex.
model = "$default_model"
model_provider = "sam"
model_catalog_json = "models.json"
web_search = "disabled"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/openai"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "$MCP_URL"
bearer_token_env_var = "SAM_API_KEY"
required = true
EOF
chmod 600 "$CODEX_SAM_HOME/config.toml"

cat >"$WRAPPER" <<'EOF'
#!/usr/bin/env bash
# SAM_CODEX_INSTALLER_MANAGED=1
set -euo pipefail

SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
ENV_FILE="$SAM_HOME/env"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/openai/models"

[ -r "$ENV_FILE" ] || {
  echo "Missing $ENV_FILE. Re-run the SAM-Codex installer." >&2
  exit 1
}

# shellcheck disable=SC1090
. "$ENV_FILE"
[ -n "${SAM_API_KEY:-}" ] || {
  echo "SAM_API_KEY is missing from $ENV_FILE." >&2
  exit 1
}

export CODEX_HOME="$CODEX_SAM_HOME"
mkdir -p "$CODEX_HOME"
umask 077

catalog_tmp="$(mktemp "$CODEX_HOME/.models.XXXXXX")"
if curl --fail --silent --show-error --max-time 15 \
  -H "Authorization: Bearer $SAM_API_KEY" \
  "$DISCOVERY_URL" >"$catalog_tmp" &&
  grep -q '"models"' "$catalog_tmp"; then
  mv "$catalog_tmp" "$CODEX_HOME/models.json"
else
  rm -f "$catalog_tmp"
  [ -s "$CODEX_HOME/models.json" ] || {
    echo "SAM model discovery failed and no cached catalog exists." >&2
    exit 1
  }
  echo "Warning: using the last verified SAM model catalog." >&2
fi

exec codex -c "model_catalog_json=\"$CODEX_HOME/models.json\"" "$@"
EOF
chmod 755 "$WRAPPER"

touch "$ZSHRC"
if ! grep -Fq "$MANAGED_START" "$ZSHRC"; then
  needs_newline=0
  if [ -s "$ZSHRC" ] &&
    [ "$(tail -c 1 "$ZSHRC" | wc -l | tr -d ' ')" -eq 0 ]; then
    needs_newline=1
  fi
  {
    if [ "$needs_newline" -eq 1 ]; then
      printf '\n'
    fi
    printf '%s\n' "$MANAGED_START"
    # shellcheck disable=SC2016
    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    printf '%s\n' "$MANAGED_END"
  } >>"$ZSHRC"
else
  zshrc_tmp="$(mktemp "$HOME/.zshrc.sam-codex.XXXXXX")"
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start { managed = 1; print start; print "export PATH=\"$HOME/.local/bin:$PATH\""; next }
    $0 == end { managed = 0; print end; next }
    !managed { print }
  ' "$ZSHRC" >"$zshrc_tmp"
  mv "$zshrc_tmp" "$ZSHRC"
  zshrc_tmp=""
fi

printf '\nSAM-Codex installed successfully.\n'
printf '  Official Codex: codex\n'
printf '  SAM Codex:      sam-codex\n'
printf '  SAM model:      %s\n' "$default_model"
printf '  SAM tools:      search, page reading, account usage\n\n'
# shellcheck disable=SC2016
printf 'Open a new terminal, or run: source "$HOME/.zshrc"\n'
