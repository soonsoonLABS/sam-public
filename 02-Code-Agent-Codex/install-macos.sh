#!/usr/bin/env bash
set +x
set -euo pipefail

# Self-contained SAM-Codex installer for macOS.
# It never edits the user's normal ~/.codex home.

SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
BIN_DIR="$HOME/.local/bin"
ENV_FILE="$SAM_HOME/env"
WRAPPER="$BIN_DIR/sam-codex"
ZSHRC="$HOME/.zshrc"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/codex/models"
MCP_URL="https://sam.soonsoon.ai/mcp"
MANAGED_START="# >>> SAM-Codex managed >>>"
MANAGED_END="# <<< SAM-Codex managed <<<"

fail() {
  printf 'SAM-Codex install failed: %s\n' "$1" >&2
  exit 1
}

codex_client_version() {
  local version_output
  version_output="$(codex --version 2>/dev/null)" || return 1
  [[ "$version_output" != *$'\n'* ]] || return 1
  if [[ "$version_output" =~ ^codex-cli\ ([0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.-]+)?)$ ]]; then
    case "${BASH_REMATCH[1]}" in
      0.145.* | 0.146.0) printf '%s\n' "${BASH_REMATCH[1]}" ;;
    esac
  fi
}

catalog_is_verified() {
  local catalog_path expected_version fetched_at etag actual_version
  local model_count index slug visibility supported visible_count visible_slugs
  local hidden_count hidden_slugs
  catalog_path="$1"
  expected_version="${2:-}"
  [ -s "$catalog_path" ] || return 1

  fetched_at="$(
    /usr/bin/plutil -extract fetched_at raw -expect string -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  etag="$(
    /usr/bin/plutil -extract etag raw -expect string -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  actual_version="$(
    /usr/bin/plutil -extract client_version raw -expect string -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  model_count="$(
    /usr/bin/plutil -extract models raw -expect array -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1

  [[ "$fetched_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$ ]] ||
    return 1
  [ "$etag" = "sam-v2-unified-codex-catalog" ] || return 1
  [ -n "$actual_version" ] || return 1
  if [ -n "$expected_version" ]; then
    [ "$actual_version" = "$expected_version" ] || return 1
  fi
  case "$model_count" in
    '' | *[!0-9]*) return 1 ;;
  esac
  [ "$model_count" -gt 0 ] || return 1

  index=0
  visible_count=0
  visible_slugs=""
  hidden_count=0
  hidden_slugs=""
  while [ "$index" -lt "$model_count" ]; do
    slug="$(
      /usr/bin/plutil -extract "models.$index.slug" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    visibility="$(
      /usr/bin/plutil -extract "models.$index.visibility" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    supported="$(
      /usr/bin/plutil -extract "models.$index.supported_in_api" raw -expect bool -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    case "$slug" in
      gpt-5.6-sol | gpt-5.6-terra | gpt-5.6-luna | gpt-5.5 | gpt-5.4 | \
        gpt-5.4-mini | gpt-5.2 | codex-auto-review)
        [ "$visibility" = "hide" ] && [ "$supported" = "false" ] ||
          return 1
        case "
$hidden_slugs
" in
          *"
$slug
"*) return 1 ;;
        esac
        hidden_slugs="${hidden_slugs}${hidden_slugs:+
}$slug"
        hidden_count=$((hidden_count + 1))
        ;;
    esac

    if [ "$visibility" = "list" ]; then
      [ "$supported" = "true" ] || return 1
      case "$slug" in
        [A-Za-z0-9]*)
          case "$slug" in
            *[!A-Za-z0-9._-]*) return 1 ;;
          esac
          ;;
        *) return 1 ;;
      esac
      case "
$visible_slugs
" in
        *"
$slug
"*) return 1 ;;
      esac
      visible_slugs="${visible_slugs}${visible_slugs:+
}$slug"
      visible_count=$((visible_count + 1))
    fi
    index=$((index + 1))
  done
  [ "$hidden_count" -eq 8 ] && [ "$visible_count" -gt 0 ]
}

visible_sam_model() {
  local catalog_path preferred model_count index slug visibility supported first
  catalog_path="$1"
  preferred="${2:-}"
  model_count="$(
    /usr/bin/plutil -extract models raw -expect array -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  index=0
  first=""
  while [ "$index" -lt "$model_count" ]; do
    slug="$(
      /usr/bin/plutil -extract "models.$index.slug" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    visibility="$(
      /usr/bin/plutil -extract "models.$index.visibility" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    supported="$(
      /usr/bin/plutil -extract "models.$index.supported_in_api" raw -expect bool -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    case "$slug" in
      [A-Za-z0-9]*)
        case "$slug" in
          *[!A-Za-z0-9._-]*) return 1 ;;
        esac
        ;;
      *) return 1 ;;
    esac
    if [ "$visibility" = "list" ] && [ "$supported" = "true" ]; then
      [ -n "$first" ] || first="$slug"
      if [ -n "$preferred" ] && [ "$slug" = "$preferred" ]; then
        printf '%s\n' "$slug"
        return 0
      fi
    fi
    index=$((index + 1))
  done
  [ -z "$preferred" ] || return 1
  [ -n "$first" ] || return 1
  printf '%s\n' "$first"
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

  fail "Malformed or duplicate SAM-Codex block in $ZSHRC. No files were changed."
}

# Fail closed before creating or replacing any user file.
validate_managed_block

command -v codex >/dev/null 2>&1 ||
  fail "Codex CLI is missing. Install official Codex first: npm install -g @openai/codex@latest"
command -v curl >/dev/null 2>&1 || fail "curl is required."
[ -x /usr/bin/plutil ] || fail "/usr/bin/plutil is required on macOS."
client_version="$(codex_client_version)" || client_version=""
[ -n "$client_version" ] ||
  fail "SAM-Codex currently requires one exact Codex 0.145.x or 0.146.0 version line."

umask 077
mkdir -p "$SAM_HOME" "$CODEX_SAM_HOME" "$BIN_DIR"
chmod 700 "$SAM_HOME" "$CODEX_SAM_HOME"

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

catalog_tmp="$(mktemp "$CODEX_SAM_HOME/.models.XXXXXX")"
zshrc_tmp=""
cleanup() {
  rm -f "$catalog_tmp"
  [ -z "$zshrc_tmp" ] || rm -f "$zshrc_tmp"
}
trap cleanup EXIT

if curl --fail --silent --show-error --max-time 25 \
  --get \
  --data-urlencode "client_version=$client_version" \
  -H "Authorization: Bearer $key" \
  -H "x-sam-codex-cache: 1" \
  "$DISCOVERY_URL" >"$catalog_tmp" &&
  catalog_is_verified "$catalog_tmp" "$client_version"; then
  mv "$catalog_tmp" "$CODEX_SAM_HOME/models.json"
  catalog_tmp=""
  chmod 600 "$CODEX_SAM_HOME/models.json"
else
  rm -f "$catalog_tmp"
  catalog_tmp=""
  if catalog_is_verified "$CODEX_SAM_HOME/models.json"; then
    fail "Discovery refresh failed. The last verified cache was preserved, but install stopped to avoid using removed selections."
  else
    fail "SAM model discovery failed and no verified cache exists. Check the key and Code Agent access."
  fi
fi

default_model=""
configured_model=""
if [ -r "$CODEX_SAM_HOME/config.toml" ]; then
  configured_model="$(
    sed -n 's/^model = "\([^"]*\)"$/\1/p' \
      "$CODEX_SAM_HOME/config.toml" | head -n 1
  )"
  if [ -n "$configured_model" ]; then
    default_model="$(
      visible_sam_model "$CODEX_SAM_HOME/models.json" "$configured_model"
    )" || default_model=""
  fi
fi
if [ -z "$default_model" ]; then
  default_model="$(
    visible_sam_model \
      "$CODEX_SAM_HOME/models.json" \
      "azure.gpt-5.6-luna"
  )" || default_model=""
fi
if [ -z "$default_model" ]; then
  default_model="$(visible_sam_model "$CODEX_SAM_HOME/models.json")" ||
    default_model=""
fi
[ -n "$default_model" ] ||
  fail "The verified SAM catalog has no visible selected model."

if [ "$key_from_existing_file" -eq 0 ]; then
  printf 'export SAM_API_KEY=%q\n' "$key" >"$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi
unset key SAM_API_KEY

cat >"$CODEX_SAM_HOME/config.toml" <<EOF
# Managed by the SAM-Codex installer. Official Codex remains in ~/.codex.
model = "$default_model"
model_provider = "sam"
model_catalog_json = "models.json"
web_search = "disabled"
project_root_markers = [".git", ".sam-codex-root"]

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/codex"
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
set +x
set -euo pipefail

SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
ENV_FILE="$SAM_HOME/env"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/codex/models"
DEFAULT_WORKSPACE="$HOME/SAM-Codex"

codex_client_version() {
  local version_output
  version_output="$(codex --version 2>/dev/null)" || return 1
  [[ "$version_output" != *$'\n'* ]] || return 1
  if [[ "$version_output" =~ ^codex-cli\ ([0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.-]+)?)$ ]]; then
    case "${BASH_REMATCH[1]}" in
      0.145.* | 0.146.0) printf '%s\n' "${BASH_REMATCH[1]}" ;;
    esac
  fi
}

catalog_is_verified() {
  local catalog_path expected_version fetched_at etag actual_version
  local model_count index slug visibility supported visible_count visible_slugs
  local hidden_count hidden_slugs description comp_hash priority
  catalog_path="$1"
  expected_version="${2:-}"
  [[ -s "$catalog_path" ]] || return 1
  [[ "$(wc -c <"$catalog_path")" -le 1048576 ]] || return 1

  fetched_at="$(
    /usr/bin/plutil -extract fetched_at raw -expect string -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  etag="$(
    /usr/bin/plutil -extract etag raw -expect string -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  actual_version="$(
    /usr/bin/plutil -extract client_version raw -expect string -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  model_count="$(
    /usr/bin/plutil -extract models raw -expect array -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1

  [[ "$fetched_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$ ]] ||
    return 1
  [[ "$etag" == "sam-v2-unified-codex-catalog" ]] || return 1
  [[ -n "$actual_version" ]] || return 1
  if [[ -n "$expected_version" ]]; then
    [[ "$actual_version" == "$expected_version" ]] || return 1
  fi
  [[ "$model_count" =~ ^[0-9]+$ ]] || return 1
  ((model_count > 0 && model_count <= 256)) || return 1

  index=0
  visible_count=0
  visible_slugs=""
  hidden_count=0
  hidden_slugs=""
  while ((index < model_count)); do
    slug="$(
      /usr/bin/plutil -extract "models.$index.slug" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    visibility="$(
      /usr/bin/plutil -extract "models.$index.visibility" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    supported="$(
      /usr/bin/plutil -extract "models.$index.supported_in_api" raw -expect bool -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    case "$slug" in
      gpt-5.6-sol | gpt-5.6-terra | gpt-5.6-luna | gpt-5.5 | gpt-5.4 | \
        gpt-5.4-mini | gpt-5.2 | codex-auto-review)
        [[ "$visibility" == "hide" && "$supported" == "false" ]] ||
          return 1
        case "
$hidden_slugs
" in
          *"
$slug
"*) return 1 ;;
        esac
        hidden_slugs="${hidden_slugs}${hidden_slugs:+
}$slug"
        hidden_count=$((hidden_count + 1))
        index=$((index + 1))
        continue
        ;;
    esac

    [[ "$visibility" == "list" && "$supported" == "true" ]] || return 1
    ((${#slug} >= 1 && ${#slug} <= 128)) || return 1
    [[ "$slug" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || return 1
    case "$slug" in
      azure.* | aws.*) ;;
      *)
        description="$(
          /usr/bin/plutil -extract "models.$index.description" raw \
            -expect string -o - "$catalog_path" 2>/dev/null
        )" || return 1
        comp_hash="$(
          /usr/bin/plutil -extract "models.$index.comp_hash" raw \
            -expect string -o - "$catalog_path" 2>/dev/null
        )" || return 1
        priority="$(
          /usr/bin/plutil -extract "models.$index.priority" raw \
            -expect integer -o - "$catalog_path" 2>/dev/null
        )" || return 1
        [[ "$description" == *"(not V2 provider-native)" ]] || return 1
        [[ "$comp_hash" == "sam-compat-$slug" ]] || return 1
        [[ "$priority" =~ ^[0-9]+$ && "$priority" -ge 100 ]] || return 1
        ;;
    esac
    case "
$visible_slugs
" in
      *"
$slug
"*) return 1 ;;
    esac
    visible_slugs="${visible_slugs}${visible_slugs:+
}$slug"
    visible_count=$((visible_count + 1))
    index=$((index + 1))
  done
  ((hidden_count == 8 && visible_count > 0))
}

visible_sam_model() {
  local catalog_path preferred model_count index slug visibility supported first
  catalog_path="$1"
  preferred="${2:-}"
  model_count="$(
    /usr/bin/plutil -extract models raw -expect array -o - \
      "$catalog_path" 2>/dev/null
  )" || return 1
  index=0
  first=""
  while ((index < model_count)); do
    slug="$(
      /usr/bin/plutil -extract "models.$index.slug" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    visibility="$(
      /usr/bin/plutil -extract "models.$index.visibility" raw -expect string -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    supported="$(
      /usr/bin/plutil -extract "models.$index.supported_in_api" raw -expect bool -o - \
        "$catalog_path" 2>/dev/null
    )" || return 1
    if [[ "$visibility" == "list" && "$supported" == "true" ]]; then
      [[ -n "$first" ]] || first="$slug"
      if [[ -n "$preferred" && "$slug" == "$preferred" ]]; then
        printf '%s\n' "$slug"
        return 0
      fi
    fi
    index=$((index + 1))
  done
  [[ -z "$preferred" ]] || return 1
  [[ -n "$first" ]] || return 1
  printf '%s\n' "$first"
}

[[ -r "$ENV_FILE" ]] || {
  echo "Missing $ENV_FILE. Re-run the SAM-Codex installer." >&2
  exit 1
}

# shellcheck disable=SC1090
. "$ENV_FILE"
set +x
[[ -n "${SAM_API_KEY:-}" ]] || {
  echo "SAM_API_KEY is missing from $ENV_FILE." >&2
  exit 1
}

client_version="$(codex_client_version)" || client_version=""
[[ -n "$client_version" ]] || {
  echo "SAM-Codex currently requires one exact Codex 0.145.x or 0.146.0 version line." >&2
  exit 1
}

for argument in "$@"; do
  case "$argument" in
    -c | --config | -m | --model | -p | --profile | --oss | \
      --local-provider | --search | -c?* | -m?* | -p?* | \
      --config=* | --model=* | --profile=* | --local-provider=*)
      echo "SAM-Codex blocks model/provider/config override options. Use /model inside SAM-Codex." >&2
      exit 2
      ;;
  esac
done

export CODEX_HOME="$CODEX_SAM_HOME"
mkdir -p "$CODEX_HOME"
umask 077

catalog_tmp="$(mktemp "$CODEX_HOME/.models.XXXXXX")"
if curl --fail --silent --show-error --max-time 15 \
  --get \
  --data-urlencode "client_version=$client_version" \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H "x-sam-codex-cache: 1" \
  "$DISCOVERY_URL" >"$catalog_tmp" &&
  catalog_is_verified "$catalog_tmp" "$client_version"; then
  mv "$catalog_tmp" "$CODEX_HOME/models.json"
  chmod 600 "$CODEX_HOME/models.json"
else
  rm -f "$catalog_tmp"
  if catalog_is_verified "$CODEX_HOME/models.json"; then
    echo "SAM model refresh failed. The verified cache was preserved, but SAM-Codex will not start." >&2
  else
    echo "SAM model discovery failed and no verified cache exists." >&2
  fi
  exit 1
fi

configured_model=""
if [[ -r "$CODEX_HOME/config.toml" ]]; then
  configured_model="$(
    sed -n 's/^model = "\([^"]*\)"$/\1/p' \
      "$CODEX_HOME/config.toml" | head -n 1
  )"
fi
default_model=""
if [[ -n "$configured_model" ]]; then
  default_model="$(
    visible_sam_model "$CODEX_HOME/models.json" "$configured_model"
  )" || default_model=""
fi
if [[ -z "$default_model" ]]; then
  default_model="$(
    visible_sam_model \
      "$CODEX_HOME/models.json" \
      "azure.gpt-5.6-luna"
  )" || default_model=""
fi
if [[ -z "$default_model" ]]; then
  default_model="$(visible_sam_model "$CODEX_HOME/models.json")" ||
    default_model=""
fi
[[ -n "$default_model" ]] || {
  echo "The verified SAM catalog has no visible selected model." >&2
  exit 1
}

if command -v git >/dev/null 2>&1 &&
  git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  :
elif [[ -e "$PWD/.sam-codex-root" ]]; then
  :
else
  mkdir -p "$DEFAULT_WORKSPACE"
  : >"$DEFAULT_WORKSPACE/.sam-codex-root"
  cd "$DEFAULT_WORKSPACE"
  echo "SAM-Codex workspace: $DEFAULT_WORKSPACE" >&2
fi

exec codex \
  -c 'model_provider="sam"' \
  -c "model=\"$default_model\"" \
  -c "model_catalog_json=\"$CODEX_HOME/models.json\"" \
  -c 'web_search="disabled"' \
  "$@"
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
    printf 'sam-codex() {\n'
    # shellcheck disable=SC2016
    printf '  command "$HOME/.local/bin/sam-codex" "$@"\n'
    printf '}\n'
    printf '%s\n' "$MANAGED_END"
  } >>"$ZSHRC"
else
  zshrc_tmp="$(mktemp "$HOME/.zshrc.sam-codex.XXXXXX")"
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start {
      managed = 1
      print start
      print "export PATH=\"$HOME/.local/bin:$PATH\""
      print "sam-codex() {"
      print "  command \"$HOME/.local/bin/sam-codex\" \"$@\""
      print "}"
      next
    }
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
