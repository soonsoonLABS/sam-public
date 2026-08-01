#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
trap 'printf "FAIL: test-install-macos.sh line %s\n" "$LINENO" >&2' ERR

TEST_HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$TEST_HOME" "$FAKE_BIN"

export WRAPPER_SOURCE="$SCRIPT_DIR/templates/sam-claude"
export CURL_MODE_FILE="$TEST_ROOT/curl-mode"
export CLAUDE_VERSION_FILE="$TEST_ROOT/claude-version"
export CURL_LOG="$TEST_ROOT/curl.log"
export CLAUDE_LOG="$TEST_ROOT/claude.log"
printf 'success\n' >"$CURL_MODE_FILE"
printf '2.1.220 (Claude Code)\n' >"$CLAUDE_VERSION_FILE"
: >"$CURL_LOG"
: >"$CLAUDE_LOG"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
arguments="$*"
output_file=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ] && [ "$#" -ge 2 ]; then
    output_file="$2"
    shift 2
  else
    shift
  fi
done

case "$arguments" in
  *"raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/templates/sam-claude"*)
    [ -n "$output_file" ] || exit 22
    cp "$WRAPPER_SOURCE" "$output_file"
    exit 0
    ;;
esac

config="$(cat)"
case "$config" in
  *'header = "Authorization: Bearer test-only-placeholder"'*) ;;
  *) exit 22 ;;
esac
printf '%s\n' "$arguments" >>"$CURL_LOG"

mode="$(cat "$CURL_MODE_FILE")"
[ "$mode" != "network-fail" ] || exit 22

case "$arguments" in
  *"https://sam.soonsoon.ai/v2/claude/v1/models"*)
    case "$mode" in
      duplicate-catalog)
        cat <<'JSON'
{"data":[{"id":"claude-haiku","type":"model","display_name":"Haiku","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-haiku","type":"model","display_name":"Haiku duplicate","created_at":"2026-07-31T00:00:00Z"}],"has_more":false,"first_id":"claude-haiku","last_id":"claude-haiku"}
JSON
        ;;
      alternate)
        cat <<'JSON'
{"data":[{"id":"claude-haiku-alt","type":"model","display_name":"Haiku Alt","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-sonnet-alt","type":"model","display_name":"Sonnet Alt","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-opus-alt","type":"model","display_name":"Opus Alt","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-sam-fw-kimi-k3","type":"model","display_name":"Kimi · SAM bridge","created_at":"2026-07-31T00:00:00Z"}],"has_more":false,"first_id":"claude-haiku-alt","last_id":"claude-sam-fw-kimi-k3"}
JSON
        ;;
      *)
        cat <<'JSON'
{"data":[{"id":"claude-haiku","type":"model","display_name":"Haiku","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-sonnet-5","type":"model","display_name":"Sonnet 5","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-opus-5","type":"model","display_name":"Opus 5","created_at":"2026-07-31T00:00:00Z"},{"id":"claude-sam-fw-kimi-k3","type":"model","display_name":"Kimi · SAM bridge","created_at":"2026-07-31T00:00:00Z"}],"has_more":false,"first_id":"claude-haiku","last_id":"claude-sam-fw-kimi-k3"}
JSON
        ;;
    esac
    ;;
  *"https://sam.soonsoon.ai/v1/models/code-agent-profiles?agent=claude_code&protocol_surface=anthropic_messages"*)
    if [ "$mode" = "mapping-mismatch" ]; then
      sonnet_alias="claude-sonnet-missing"
    elif [ "$mode" = "alternate" ]; then
      sonnet_alias="claude-sonnet-alt"
    else
      sonnet_alias="claude-sonnet-5"
    fi
    if [ "$mode" = "alternate" ]; then
      haiku_alias="claude-haiku-alt"
      opus_alias="claude-opus-alt"
    else
      haiku_alias="claude-haiku"
      opus_alias="claude-opus-5"
    fi
    if [ "$mode" = "short-context" ]; then
      sonnet_context=200000
    else
      sonnet_context=1000000
    fi
    cat <<JSON
{"ok":true,"count":4,"profiles":[{"alias":"sam-claude-code-fast","agent":"claude_code","protocol_surface":"anthropic_messages","claude_role":"haiku","selected_backing_model":{"alias":"$haiku_alias","max_context_tokens":200000}},{"alias":"sam-code-agent","agent":"claude_code","protocol_surface":"anthropic_messages","claude_role":"sonnet","selected_backing_model":{"alias":"$sonnet_alias","max_context_tokens":$sonnet_context}},{"alias":"sam-claude-code-sonnet-1m","agent":"claude_code","protocol_surface":"anthropic_messages","claude_role":"sonnet_1m","selected_backing_model":{"alias":"$sonnet_alias","max_context_tokens":$sonnet_context}},{"alias":"sam-claude-code-max","agent":"claude_code","protocol_surface":"anthropic_messages","claude_role":"opus","selected_backing_model":{"alias":"$opus_alias","max_context_tokens":200000}}]}
JSON
    ;;
  *) exit 22 ;;
esac
EOF

cat >"$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  cat "$CLAUDE_VERSION_FILE"
  exit 0
fi
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "add" ]; then
  printf 'MCP_ARGS=%s\n' "$*" >>"$CLAUDE_LOG"
  python3 - "$CLAUDE_CONFIG_DIR/.claude.json" <<'PY'
import json
import os
import sys

path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
if os.path.exists(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
else:
    data = {}
servers = data.setdefault("mcpServers", {})
servers["sam-tools"] = {
    "type": "http",
    "url": "https://sam.soonsoon.ai/mcp",
    "headers": {"Authorization": "Bearer ${SAM_API_KEY}"},
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
  exit 0
fi

printf 'RUN\n' >>"$CLAUDE_LOG"
printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}"
printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}"
printf 'ANTHROPIC_MODEL=%s\n' "${ANTHROPIC_MODEL:-}"
printf 'HAIKU=%s\n' "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
printf 'SONNET=%s\n' "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
printf 'OPUS=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
printf 'SMALL_FAST=%s\n' "${ANTHROPIC_SMALL_FAST_MODEL:-}"
printf 'DISCOVERY=%s\n' "${CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY:-}"
printf 'AUTH_TOKEN_SET=%s\n' "$([ "${ANTHROPIC_AUTH_TOKEN:-}" = "test-only-placeholder" ] && printf yes || printf no)"
printf 'SAM_KEY_SET=%s\n' "$([ "${SAM_API_KEY:-}" = "test-only-placeholder" ] && printf yes || printf no)"
printf 'OFFICIAL_API_KEY=%s\n' "${ANTHROPIC_API_KEY-unset}"
printf 'OFFICIAL_OAUTH=%s\n' "${CLAUDE_CODE_OAUTH_TOKEN-unset}"
printf 'BEDROCK=%s\n' "${CLAUDE_CODE_USE_BEDROCK-unset}"
printf 'VERTEX=%s\n' "${CLAUDE_CODE_USE_VERTEX-unset}"
printf 'FOUNDRY=%s\n' "${CLAUDE_CODE_USE_FOUNDRY-unset}"
printf 'ARGS='
printf '<%s>' "$@"
printf '\n'
case " $* " in
  *" exit-seven "*) exit 7 ;;
esac
EOF
chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/claude"

export HOME="$TEST_HOME"
export PATH="$FAKE_BIN:/opt/homebrew/bin:/usr/bin:/bin"
mkdir -p \
  "$HOME/.sam" \
  "$HOME/.claude" \
  "$HOME/.claude-sam" \
  "$HOME/.local/bin" \
  "$HOME/Documents/arbitrary-cwd"
printf 'export SAM_API_KEY=%q\n' "test-only-placeholder" >"$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
printf 'official-settings\n' >"$HOME/.claude/official.txt"
printf '{"official":true}\n' >"$HOME/.claude.json"
printf 'official-sam-codex\n' >"$HOME/.local/bin/sam-codex"
printf '{"userSetting":"preserve"}\n' >"$HOME/.claude-sam/settings.json"
cat >"$HOME/.claude-sam/.claude.json" <<'EOF'
{
  "mcpServers": {
    "unrelated-server": {
      "type": "http",
      "url": "https://example.invalid/mcp"
    }
  }
}
EOF
cat >"$HOME/.zshrc" <<'EOF'
export BEFORE=value
sam-claude() {
  printf 'legacy-function\n'
}
EOF

official_claude_before="$(shasum "$HOME/.claude/official.txt")"
official_root_before="$(shasum "$HOME/.claude.json")"
shared_key_before="$(shasum "$HOME/.sam/env")"
sam_codex_before="$(shasum "$HOME/.local/bin/sam-codex")"
settings_before="$(shasum "$HOME/.claude-sam/settings.json")"

(
  cd "$HOME/Documents/arbitrary-cwd"
  bash -x "$SCRIPT_DIR/install-macos.sh"
) >"$TEST_ROOT/install.stdout" 2>"$TEST_ROOT/install.stderr"
if grep -Fq "test-only-placeholder" \
  "$TEST_ROOT/install.stdout" "$TEST_ROOT/install.stderr"; then
  printf 'Installer trace exposed the placeholder key.\n' >&2
  exit 1
fi

test -x "$HOME/.local/bin/sam-claude"
cmp -s "$WRAPPER_SOURCE" "$HOME/.local/bin/sam-claude"
test -s "$HOME/.claude-sam/runtime-state.json"
grep -Fq '"claude-sam-fw-kimi-k3"' \
  "$HOME/.claude-sam/runtime-state.json"
grep -Fq '"sonnet_1m": true' "$HOME/.claude-sam/runtime-state.json"
test "$(shasum "$HOME/.claude-sam/settings.json")" = "$settings_before"
test "$(shasum "$HOME/.sam/env")" = "$shared_key_before"
test "$(shasum "$HOME/.claude/official.txt")" = "$official_claude_before"
test "$(shasum "$HOME/.claude.json")" = "$official_root_before"
test "$(shasum "$HOME/.local/bin/sam-codex")" = "$sam_codex_before"
test "$(grep -Fc '# >>> SAM-Claude managed >>>' "$HOME/.zshrc")" -eq 1
# The environment-variable reference must remain literal.
# shellcheck disable=SC2016
grep -Fq '"Authorization": "Bearer ${SAM_API_KEY}"' \
  "$HOME/.claude-sam/.claude.json"
grep -Fq '"unrelated-server"' "$HOME/.claude-sam/.claude.json"
if grep -R -Fq "test-only-placeholder" \
  "$HOME/.claude-sam" "$HOME/.local/bin/sam-claude" "$HOME/.zshrc"; then
  printf 'SAM key leaked outside the shared env file.\n' >&2
  exit 1
fi

printf 'export AFTER=value\n' >>"$HOME/.zshrc"
printf 'success\n' >"$CURL_MODE_FILE"
bash "$SCRIPT_DIR/install-macos.sh" >/dev/null
test "$(grep -Fc '# >>> SAM-Claude managed >>>' "$HOME/.zshrc")" -eq 1
grep -Fq 'export BEFORE=value' "$HOME/.zshrc"
grep -Fq 'export AFTER=value' "$HOME/.zshrc"

run_output="$(
  ANTHROPIC_API_KEY=official \
  CLAUDE_CODE_OAUTH_TOKEN=official \
  CLAUDE_CODE_USE_BEDROCK=1 \
  CLAUDE_CODE_USE_VERTEX=1 \
  CLAUDE_CODE_USE_FOUNDRY=1 \
    zsh -f -c \
      'source "$HOME/.zshrc"; sam-claude --model sonnet "two words"'
)"
for expected in \
  "CLAUDE_CONFIG_DIR=$HOME/.claude-sam" \
  "ANTHROPIC_BASE_URL=https://sam.soonsoon.ai/v2/claude" \
  "ANTHROPIC_MODEL=claude-sonnet-5" \
  "HAIKU=claude-haiku" \
  "SONNET=claude-sonnet-5" \
  "OPUS=claude-opus-5" \
  "SMALL_FAST=claude-haiku" \
  "DISCOVERY=1" \
  "AUTH_TOKEN_SET=yes" \
  "SAM_KEY_SET=yes" \
  "OFFICIAL_API_KEY=unset" \
  "OFFICIAL_OAUTH=unset" \
  "BEDROCK=unset" \
  "VERTEX=unset" \
  "FOUNDRY=unset" \
  "ARGS=<--model><sonnet><two words>"
do
  printf '%s' "$run_output" | grep -Fq "$expected"
done
if printf '%s' "$run_output" | grep -Fq 'legacy-function'; then
  exit 1
fi

ignored_state="$TEST_ROOT/normal-run-state-override-must-be-ignored.json"
SAM_CLAUDE_STATE_PATH="$ignored_state" \
  "$HOME/.local/bin/sam-claude" --version >/dev/null
test ! -e "$ignored_state"

printf 'alternate\n' >"$CURL_MODE_FILE"
alternate_output="$("$HOME/.local/bin/sam-claude" --model sonnet)"
printf '%s' "$alternate_output" | grep -Fq 'HAIKU=claude-haiku-alt'
printf '%s' "$alternate_output" | grep -Fq 'SONNET=claude-sonnet-alt'
printf '%s' "$alternate_output" | grep -Fq 'OPUS=claude-opus-alt'

printf 'short-context\n' >"$CURL_MODE_FILE"
"$HOME/.local/bin/sam-claude" --version >/dev/null
grep -Fq '"sonnet_1m": false' "$HOME/.claude-sam/runtime-state.json"

state_before_failure="$(shasum "$HOME/.claude-sam/runtime-state.json")"
claude_runs_before_failure="$(grep -Fc RUN "$CLAUDE_LOG")"
printf 'mapping-mismatch\n' >"$CURL_MODE_FILE"
if "$HOME/.local/bin/sam-claude" --model sonnet \
  >"$TEST_ROOT/mismatch.stdout" 2>"$TEST_ROOT/mismatch.stderr"; then
  printf 'Expected mapping/catalog mismatch to fail closed.\n' >&2
  exit 1
fi
grep -Fq 'previous verified cache was preserved' "$TEST_ROOT/mismatch.stderr"
test "$(shasum "$HOME/.claude-sam/runtime-state.json")" = \
  "$state_before_failure"
test "$(grep -Fc RUN "$CLAUDE_LOG")" = "$claude_runs_before_failure"

printf 'duplicate-catalog\n' >"$CURL_MODE_FILE"
if "$HOME/.local/bin/sam-claude" \
  >"$TEST_ROOT/duplicate.stdout" 2>"$TEST_ROOT/duplicate.stderr"; then
  printf 'Expected duplicate catalog to stop before Claude.\n' >&2
  exit 1
fi
grep -Fq 'previous verified cache was preserved' "$TEST_ROOT/duplicate.stderr"
test "$(shasum "$HOME/.claude-sam/runtime-state.json")" = \
  "$state_before_failure"
test "$(grep -Fc RUN "$CLAUDE_LOG")" = "$claude_runs_before_failure"

printf 'network-fail\n' >"$CURL_MODE_FILE"
if "$HOME/.local/bin/sam-claude" \
  >"$TEST_ROOT/network.stdout" 2>"$TEST_ROOT/network.stderr"; then
  printf 'Expected network failure to stop before Claude.\n' >&2
  exit 1
fi
grep -Fq 'previous verified cache was preserved' "$TEST_ROOT/network.stderr"
test "$(shasum "$HOME/.claude-sam/runtime-state.json")" = \
  "$state_before_failure"
test "$(grep -Fc RUN "$CLAUDE_LOG")" = "$claude_runs_before_failure"

printf 'success\n' >"$CURL_MODE_FILE"
printf '2.1.128 (Claude Code)\n' >"$CLAUDE_VERSION_FILE"
curl_before_old_version="$(wc -l <"$CURL_LOG" | tr -d ' ')"
if "$HOME/.local/bin/sam-claude" \
  >"$TEST_ROOT/version.stdout" 2>"$TEST_ROOT/version.stderr"; then
  printf 'Expected Claude Code 2.1.128 to fail.\n' >&2
  exit 1
fi
grep -Fq '2.1.129 or newer' "$TEST_ROOT/version.stderr"
test "$(wc -l <"$CURL_LOG" | tr -d ' ')" = "$curl_before_old_version"
printf '2.1.129 (Claude Code)\n' >"$CLAUDE_VERSION_FILE"
"$HOME/.local/bin/sam-claude" --version >/dev/null
printf '2.1.220 (Claude Code)\n' >"$CLAUDE_VERSION_FILE"

assert_install_fails_unchanged() {
  case_name="$1"
  zshrc_content="$2"
  case_home="$TEST_ROOT/$case_name"
  mkdir -p "$case_home/.local/bin" "$case_home/.claude-sam"
  printf '%s' "$zshrc_content" >"$case_home/.zshrc"
  printf 'existing wrapper\n' >"$case_home/.local/bin/sam-claude"
  printf 'existing session\n' >"$case_home/.claude-sam/session"
  before_zshrc="$(shasum "$case_home/.zshrc")"
  before_wrapper="$(shasum "$case_home/.local/bin/sam-claude")"
  before_session="$(shasum "$case_home/.claude-sam/session")"
  if HOME="$case_home" bash "$SCRIPT_DIR/install-macos.sh" \
    >/dev/null 2>&1; then
    printf 'Expected install failure: %s\n' "$case_name" >&2
    exit 1
  fi
  test "$(shasum "$case_home/.zshrc")" = "$before_zshrc"
  test "$(shasum "$case_home/.local/bin/sam-claude")" = "$before_wrapper"
  test "$(shasum "$case_home/.claude-sam/session")" = "$before_session"
}

assert_install_fails_unchanged \
  start-only \
  $'before\n# >>> SAM-Claude managed >>>\nafter\n'
assert_install_fails_unchanged \
  end-only \
  $'before\n# <<< SAM-Claude managed <<<\nafter\n'
assert_install_fails_unchanged \
  duplicate \
  $'# >>> SAM-Claude managed >>>\na\n# <<< SAM-Claude managed <<<\n# >>> SAM-Claude managed >>>\nb\n# <<< SAM-Claude managed <<<\n'
assert_install_fails_unchanged \
  reversed \
  $'# <<< SAM-Claude managed <<<\na\n# >>> SAM-Claude managed >>>\n'

unowned_home="$TEST_ROOT/unowned-wrapper"
mkdir -p "$unowned_home/.local/bin"
printf 'unrelated wrapper\n' >"$unowned_home/.local/bin/sam-claude"
unowned_before="$(shasum "$unowned_home/.local/bin/sam-claude")"
if HOME="$unowned_home" bash "$SCRIPT_DIR/install-macos.sh" \
  >/dev/null 2>&1; then
  printf 'Expected unmanaged wrapper install to fail.\n' >&2
  exit 1
fi
test "$(shasum "$unowned_home/.local/bin/sam-claude")" = "$unowned_before"

conflict_home="$TEST_ROOT/mcp-conflict"
mkdir -p "$conflict_home/.sam" "$conflict_home/.claude-sam"
printf 'export SAM_API_KEY=%q\n' "test-only-placeholder" \
  >"$conflict_home/.sam/env"
# shellcheck disable=SC2016
printf '{"mcpServers":{"sam-tools":{"type":"http","url":"https://wrong.example/mcp","headers":{"Authorization":"Bearer ${SAM_API_KEY}"}}}}\n' \
  >"$conflict_home/.claude-sam/.claude.json"
conflict_before="$(shasum "$conflict_home/.claude-sam/.claude.json")"
if HOME="$conflict_home" bash "$SCRIPT_DIR/install-macos.sh" \
  >/dev/null 2>&1; then
  printf 'Expected conflicting MCP entry to fail.\n' >&2
  exit 1
fi
test "$(shasum "$conflict_home/.claude-sam/.claude.json")" = \
  "$conflict_before"
test ! -e "$conflict_home/.local/bin/sam-claude"

malformed_home="$TEST_ROOT/mcp-malformed"
mkdir -p "$malformed_home/.sam" "$malformed_home/.claude-sam"
printf 'export SAM_API_KEY=%q\n' "test-only-placeholder" \
  >"$malformed_home/.sam/env"
printf '{"mcpServers":[]}\n' >"$malformed_home/.claude-sam/.claude.json"
malformed_before="$(shasum "$malformed_home/.claude-sam/.claude.json")"
if HOME="$malformed_home" bash "$SCRIPT_DIR/install-macos.sh" \
  >/dev/null 2>&1; then
  printf 'Expected malformed MCP root to fail.\n' >&2
  exit 1
fi
test "$(shasum "$malformed_home/.claude-sam/.claude.json")" = \
  "$malformed_before"
test ! -e "$malformed_home/.local/bin/sam-claude"

bash "$SCRIPT_DIR/uninstall-macos.sh" >/dev/null
test ! -e "$HOME/.local/bin/sam-claude"
test -d "$HOME/.claude-sam"
test -s "$HOME/.sam/env"
test "$(shasum "$HOME/.sam/env")" = "$shared_key_before"
test "$(shasum "$HOME/.claude/official.txt")" = "$official_claude_before"
test "$(shasum "$HOME/.claude.json")" = "$official_root_before"
test "$(shasum "$HOME/.local/bin/sam-codex")" = "$sam_codex_before"
grep -Fq 'export BEFORE=value' "$HOME/.zshrc"
grep -Fq 'export AFTER=value' "$HOME/.zshrc"
if grep -Fq '# >>> SAM-Claude managed >>>' "$HOME/.zshrc"; then
  exit 1
fi

bash "$SCRIPT_DIR/install-macos.sh" >/dev/null
bash "$SCRIPT_DIR/uninstall-macos.sh" --purge-data >/dev/null
test ! -e "$HOME/.claude-sam"
find "$HOME/.Trash" -maxdepth 1 -type d -name 'SAM-Claude-*' |
  grep -q .
test -s "$HOME/.sam/env"

printf 'PASS: isolated install, runtime refresh, failure gates, uninstall\n'
