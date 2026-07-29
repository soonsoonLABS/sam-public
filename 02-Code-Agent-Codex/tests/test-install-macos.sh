#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
trap 'printf "FAIL: test-install-macos.sh line %s\n" "$LINENO" >&2' ERR

TEST_HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$TEST_HOME" "$FAKE_BIN"
export CURL_LOG="$TEST_ROOT/curl.log"
export CURL_MODE_FILE="$TEST_ROOT/curl-mode"
export CODEX_VERSION_MODE_FILE="$TEST_ROOT/codex-version-mode"
printf 'success\n' >"$CURL_MODE_FILE"
printf 'strict\n' >"$CODEX_VERSION_MODE_FILE"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
HIDDEN_MODELS='{"slug":"gpt-5.6-sol","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.6-terra","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.6-luna","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.5","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.4","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.4-mini","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.2","visibility":"hide","supported_in_api":false},{"slug":"codex-auto-review","visibility":"hide","supported_in_api":false}'
emit_catalog() {
  printf '{"fetched_at":"2026-07-29T00:00:00Z","etag":"sam-v2-unified-codex-catalog","client_version":"%s","models":[%s,%s]}\n' \
    "$1" "$HIDDEN_MODELS" "$2"
}
case "$*" in
  *"Bearer test-only-placeholder"*) ;;
  *) exit 22 ;;
esac
case "$*" in
  *"-H x-sam-codex-cache: 1"*) ;;
  *) exit 22 ;;
esac
case "$*" in
  *"--data-urlencode client_version=0.145.0"*"https://sam.soonsoon.ai/v2/codex/models"*)
    requested_version="0.145.0"
    ;;
  *"--data-urlencode client_version=0.146.0"*"https://sam.soonsoon.ai/v2/codex/models"*)
    requested_version="0.146.0"
    ;;
  *) exit 22 ;;
esac
printf '%s\n' "$*" >>"$CURL_LOG"
case "$(cat "$CURL_MODE_FILE")" in
  fail) exit 22 ;;
  invalid)
    printf '%s\n' '{"models":[{"slug":"azure.gpt-5.6-luna"}]}'
    exit 0
    ;;
  wrong-version)
    emit_catalog \
      "0.144.0" \
      '{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true}'
    exit 0
    ;;
  bundled-visible)
    emit_catalog \
      "$requested_version" \
      '{"slug":"gpt-5.6-sol","visibility":"list","supported_in_api":true},{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true}'
    exit 0
    ;;
  duplicate-visible)
    emit_catalog \
      "$requested_version" \
      '{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true},{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true}'
    exit 0
    ;;
  selection-changed)
    emit_catalog \
      "$requested_version" \
      '{"slug":"aws.gpt-5.6-terra","visibility":"list","supported_in_api":true}'
    exit 0
    ;;
  compat-only)
    emit_catalog \
      "$requested_version" \
      '{"slug":"fw-kimi-k3","display_name":"Kimi K3 (Fireworks)","description":"Kimi coding model (not V2 provider-native)","visibility":"list","supported_in_api":true,"comp_hash":"sam-compat-fw-kimi-k3","priority":100},{"slug":"az-deepseek-v4-pro","display_name":"DeepSeek V4 Pro","description":"DeepSeek coding model (not V2 provider-native)","visibility":"list","supported_in_api":true,"comp_hash":"sam-compat-az-deepseek-v4-pro","priority":101}'
    exit 0
    ;;
  missing-hide)
    printf '{"fetched_at":"2026-07-29T00:00:00Z","etag":"sam-v2-unified-codex-catalog","client_version":"%s","models":[{"slug":"gpt-5.6-sol","visibility":"hide","supported_in_api":false},{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true}]}\n' \
      "$requested_version"
    exit 0
    ;;
  malicious-slug)
    emit_catalog \
      "$requested_version" \
      '{"slug":"azure.gpt-5.6-luna\"injected","visibility":"list","supported_in_api":true}'
    exit 0
    ;;
esac
emit_catalog \
  "$requested_version" \
  '{"slug":"azure.gpt-5.6-sol","visibility":"list","supported_in_api":true},{"slug":"azure.gpt-5.6-terra","visibility":"list","supported_in_api":true},{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true},{"slug":"fw-kimi-k3","display_name":"Kimi K3 (Fireworks)","description":"Kimi coding model (not V2 provider-native)","visibility":"list","supported_in_api":true,"comp_hash":"sam-compat-fw-kimi-k3","priority":100},{"slug":"az-deepseek-v4-pro","display_name":"DeepSeek V4 Pro","description":"DeepSeek coding model (not V2 provider-native)","visibility":"list","supported_in_api":true,"comp_hash":"sam-compat-az-deepseek-v4-pro","priority":101}'
EOF

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ] && [ -z "${CODEX_HOME:-}" ]; then
  case "$(cat "$CODEX_VERSION_MODE_FILE")" in
    extra-line) printf 'warning: update available\ncodex-cli 0.145.0\n' ;;
    legacy) printf 'codex-cli 0.145.0\n' ;;
    future) printf 'codex-cli 0.147.0\n' ;;
    *) printf 'codex-cli 0.146.0\n' ;;
  esac
  exit 0
fi
printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}"
printf 'PWD=%s\n' "$PWD"
printf 'ARGS=%s\n' "$*"
EOF

chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/codex"

export HOME="$TEST_HOME"
export PATH="$FAKE_BIN:/usr/bin:/bin"
export SAM_API_KEY="test-only-placeholder"

cat >"$HOME/.zshrc" <<'EOF'
export BEFORE=value
sam-codex() {
  printf 'legacy-function\n'
}
EOF
before_install="$(cat "$HOME/.zshrc")"

bash "$SCRIPT_DIR/install-macos.sh" >/dev/null
printf 'export AFTER=value\n' >>"$HOME/.zshrc"
expected_unrelated="$(printf '%s\n%s' "$before_install" 'export AFTER=value')"
key_file_before_repeat="$(shasum "$HOME/.sam/env")"
export SAM_API_KEY="stale-process-placeholder"
bash "$SCRIPT_DIR/install-macos.sh" >/dev/null
test "$(shasum "$HOME/.sam/env")" = "$key_file_before_repeat"
unset SAM_API_KEY

test -x "$HOME/.local/bin/sam-codex"
test -s "$HOME/.codex-sam/models.json"
test -s "$HOME/.codex-sam/config.toml"
test -s "$HOME/.sam/env"
awk '
  /^cat >"\$WRAPPER" <<'\''EOF'\''$/ { capture = 1; next }
  capture && $0 == "EOF" { exit }
  capture { print }
' "$SCRIPT_DIR/install-macos.sh" >"$TEST_ROOT/embedded-wrapper"
cmp -s "$SCRIPT_DIR/templates/sam-codex" "$TEST_ROOT/embedded-wrapper"
cmp -s "$SCRIPT_DIR/templates/sam-codex" "$HOME/.local/bin/sam-codex"
test "$(grep -Fc 'set +x' "$HOME/.local/bin/sam-codex")" -ge 2
grep -Fq '"slug":"azure.gpt-5.6-luna"' "$HOME/.codex-sam/models.json"
grep -Fq '"slug":"azure.gpt-5.6-sol"' "$HOME/.codex-sam/models.json"
grep -Fq '"slug":"azure.gpt-5.6-terra"' "$HOME/.codex-sam/models.json"
grep -Fq '"slug":"fw-kimi-k3"' "$HOME/.codex-sam/models.json"
grep -Fq '"display_name":"Kimi K3 (Fireworks)"' \
  "$HOME/.codex-sam/models.json"
if grep -Fq '"slug":"aws.gpt-5.6-sol"' "$HOME/.codex-sam/models.json"; then
  exit 1
fi
grep -Fq \
  '"slug":"gpt-5.6-sol","visibility":"hide","supported_in_api":false' \
  "$HOME/.codex-sam/models.json"
test "$(grep -Fc -- '-H x-sam-codex-cache: 1' "$CURL_LOG")" -ge 2
test "$(
  grep -Fc -- \
    '--data-urlencode client_version=0.146.0' \
    "$CURL_LOG"
)" -ge 2
test "$(grep -Fc '# >>> SAM-Codex managed >>>' "$HOME/.zshrc")" -eq 1
# shellcheck disable=SC2016
test "$(grep -Fc 'command "$HOME/.local/bin/sam-codex" "$@"' "$HOME/.zshrc")" -eq 1
actual_unrelated="$(
  awk '
    $0 == "# >>> SAM-Codex managed >>>" { managed = 1; next }
    $0 == "# <<< SAM-Codex managed <<<" { managed = 0; next }
    !managed { print }
  ' "$HOME/.zshrc"
)"
test "$actual_unrelated" = "$expected_unrelated"
grep -Fq 'base_url = "https://sam.soonsoon.ai/v2/codex"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'url = "https://sam.soonsoon.ai/mcp"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'web_search = "disabled"' "$HOME/.codex-sam/config.toml"
grep -Fq 'project_root_markers = [".git", ".sam-codex-root"]' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'model = "azure.gpt-5.6-luna"' \
  "$HOME/.codex-sam/config.toml"
if grep -Fq 'test-only-placeholder' "$HOME/.codex-sam/config.toml"; then
  exit 1
fi

catalog_before_failure="$(shasum "$HOME/.codex-sam/models.json")"
config_before_failure="$(shasum "$HOME/.codex-sam/config.toml")"
wrapper_before_failure="$(shasum "$HOME/.local/bin/sam-codex")"
zshrc_before_failure="$(shasum "$HOME/.zshrc")"
printf 'fail\n' >"$CURL_MODE_FILE"
if bash "$SCRIPT_DIR/install-macos.sh" \
  >"$TEST_ROOT/install-fail.stdout" 2>"$TEST_ROOT/install-fail.stderr"; then
  printf 'Expected install refresh failure to stop installation.\n' >&2
  exit 1
fi
grep -Fq 'cache was preserved' "$TEST_ROOT/install-fail.stderr"
test "$(shasum "$HOME/.codex-sam/models.json")" = "$catalog_before_failure"
test "$(shasum "$HOME/.codex-sam/config.toml")" = "$config_before_failure"
test "$(shasum "$HOME/.local/bin/sam-codex")" = "$wrapper_before_failure"
test "$(shasum "$HOME/.zshrc")" = "$zshrc_before_failure"

printf 'success\n' >"$CURL_MODE_FILE"
wrapper_output="$(cd "$HOME" && "$HOME/.local/bin/sam-codex" --version)"
printf '%s' "$wrapper_output" |
  grep -Fq "CODEX_HOME=$HOME/.codex-sam"
printf '%s' "$wrapper_output" |
  grep -Fq "model_catalog_json=\"$HOME/.codex-sam/models.json\""
printf '%s' "$wrapper_output" |
  grep -Fq 'model_provider="sam"'
if ! printf '%s' "$wrapper_output" |
  grep -Fq 'model="azure.gpt-5.6-luna"'; then
  printf 'Unexpected sanitized default-model output:\n%s\n' \
    "$wrapper_output" >&2
  exit 1
fi
printf '%s' "$wrapper_output" |
  grep -Fq "PWD=$HOME/SAM-Codex"
test -e "$HOME/SAM-Codex/.sam-codex-root"

sed 's/model = "azure.gpt-5.6-luna"/model = "azure.gpt-5.6-terra"/' \
  "$HOME/.codex-sam/config.toml" >"$HOME/.codex-sam/config.toml.tmp"
mv "$HOME/.codex-sam/config.toml.tmp" "$HOME/.codex-sam/config.toml"
preferred_output="$(cd "$HOME" && "$HOME/.local/bin/sam-codex" --version)"
printf '%s' "$preferred_output" |
  grep -Fq 'model="azure.gpt-5.6-terra"'

printf 'selection-changed\n' >"$CURL_MODE_FILE"
changed_selection_output="$(
  cd "$HOME" && "$HOME/.local/bin/sam-codex" --version
)"
printf '%s' "$changed_selection_output" |
  grep -Fq 'model="aws.gpt-5.6-terra"'
if printf '%s' "$changed_selection_output" |
  grep -Fq 'model="azure.gpt-5.6-luna"'; then
  exit 1
fi
printf 'success\n' >"$CURL_MODE_FILE"
"$HOME/.local/bin/sam-codex" --version >/dev/null
catalog_before_failure="$(shasum "$HOME/.codex-sam/models.json")"

printf 'compat-only\n' >"$CURL_MODE_FILE"
compat_only_output="$(
  cd "$HOME" && "$HOME/.local/bin/sam-codex" --version
)"
printf '%s' "$compat_only_output" |
  grep -Fq 'model="fw-kimi-k3"'
grep -Fq '"slug":"az-deepseek-v4-pro"' \
  "$HOME/.codex-sam/models.json"

printf 'success\n' >"$CURL_MODE_FILE"
"$HOME/.local/bin/sam-codex" --version >/dev/null
catalog_before_failure="$(shasum "$HOME/.codex-sam/models.json")"

printf 'fail\n' >"$CURL_MODE_FILE"
if (
  cd "$HOME" &&
    "$HOME/.local/bin/sam-codex" --version
) >"$TEST_ROOT/stale.stdout" 2>"$TEST_ROOT/stale.stderr"; then
  printf 'Expected SAM-Codex to stop when refresh fails.\n' >&2
  exit 1
fi
test ! -s "$TEST_ROOT/stale.stdout"
grep -Fq 'cache was preserved' "$TEST_ROOT/stale.stderr"
test "$(shasum "$HOME/.codex-sam/models.json")" = "$catalog_before_failure"

assert_refresh_rejected() {
  mode="$1"
  printf '%s\n' "$mode" >"$CURL_MODE_FILE"
  if (
    cd "$HOME" && "$HOME/.local/bin/sam-codex" --version
  ) >"$TEST_ROOT/$mode.stdout" 2>"$TEST_ROOT/$mode.stderr"; then
    printf 'Expected refresh rejection for mode: %s\n' "$mode" >&2
    exit 1
  fi
  test ! -s "$TEST_ROOT/$mode.stdout"
  grep -Fq 'cache was preserved' "$TEST_ROOT/$mode.stderr"
  test "$(shasum "$HOME/.codex-sam/models.json")" = "$catalog_before_failure"
}

assert_refresh_rejected invalid
assert_refresh_rejected wrong-version
assert_refresh_rejected bundled-visible
assert_refresh_rejected duplicate-visible
assert_refresh_rejected missing-hide
assert_refresh_rejected malicious-slug

printf 'success\n' >"$CURL_MODE_FILE"
if (
  cd "$HOME" &&
    "$HOME/.local/bin/sam-codex" -c 'model_provider="openai"' --version
) >"$TEST_ROOT/override.stdout" 2>"$TEST_ROOT/override.stderr"; then
  printf 'Expected routing override to be rejected.\n' >&2
  exit 1
fi
test ! -s "$TEST_ROOT/override.stdout"
grep -Fq 'blocks model/provider/config override options' \
  "$TEST_ROOT/override.stderr"

printf 'success\n' >"$CURL_MODE_FILE"
printf 'legacy\n' >"$CODEX_VERSION_MODE_FILE"
"$HOME/.local/bin/sam-codex" --version >/dev/null
grep -Fq -- \
  '--data-urlencode client_version=0.145.0' \
  "$CURL_LOG"
printf 'strict\n' >"$CODEX_VERSION_MODE_FILE"
"$HOME/.local/bin/sam-codex" --version >/dev/null

curl_count_before_bad_version="$(wc -l <"$CURL_LOG" | tr -d ' ')"
printf 'extra-line\n' >"$CODEX_VERSION_MODE_FILE"
if (
  cd "$HOME" && "$HOME/.local/bin/sam-codex" --version
) >"$TEST_ROOT/version.stdout" 2>"$TEST_ROOT/version.stderr"; then
  printf 'Expected strict Codex version parsing to reject extra output.\n' >&2
  exit 1
fi
grep -Fq 'requires one exact Codex 0.145.x or 0.146.0 version line' \
  "$TEST_ROOT/version.stderr"
test "$(wc -l <"$CURL_LOG" | tr -d ' ')" = \
  "$curl_count_before_bad_version"
test "$(shasum "$HOME/.codex-sam/models.json")" = "$catalog_before_failure"
printf 'strict\n' >"$CODEX_VERSION_MODE_FILE"

curl_count_before_future_version="$(wc -l <"$CURL_LOG" | tr -d ' ')"
printf 'future\n' >"$CODEX_VERSION_MODE_FILE"
if (
  cd "$HOME" && "$HOME/.local/bin/sam-codex" --version
) >"$TEST_ROOT/future-version.stdout" 2>"$TEST_ROOT/future-version.stderr"; then
  printf 'Expected future Codex minor version to fail closed.\n' >&2
  exit 1
fi
grep -Fq 'requires one exact Codex 0.145.x or 0.146.0 version line' \
  "$TEST_ROOT/future-version.stderr"
test "$(wc -l <"$CURL_LOG" | tr -d ' ')" = \
  "$curl_count_before_future_version"
test "$(shasum "$HOME/.codex-sam/models.json")" = "$catalog_before_failure"
printf 'strict\n' >"$CODEX_VERSION_MODE_FILE"

printf 'success\n' >"$CURL_MODE_FILE"
managed_function_output="$(zsh -f -c 'source "$HOME/.zshrc"; sam-codex --version')"
printf '%s' "$managed_function_output" |
  grep -Fq "CODEX_HOME=$HOME/.codex-sam"
if printf '%s' "$managed_function_output" | grep -Fq 'legacy-function'; then
  exit 1
fi

mkdir -p "$HOME/Documents/non-git"
non_git_output="$(
  cd "$HOME/Documents/non-git" &&
    "$HOME/.local/bin/sam-codex" --version
)"
printf '%s' "$non_git_output" |
  grep -Fq "PWD=$HOME/SAM-Codex"

bash "$SCRIPT_DIR/uninstall-macos.sh" >/dev/null
test ! -e "$HOME/.local/bin/sam-codex"
test ! -e "$HOME/.codex-sam"
test -s "$HOME/.sam/env"
if grep -Fq '# >>> SAM-Codex managed >>>' "$HOME/.zshrc"; then
  exit 1
fi
test "$(cat "$HOME/.zshrc")" = "$expected_unrelated"

bash "$SCRIPT_DIR/install-macos.sh" >/dev/null
test -x "$HOME/.local/bin/sam-codex"
test -s "$HOME/.codex-sam/config.toml"

assert_malformed_fails_closed() {
  case_name="$1"
  malformed_content="$2"

  case_home="$TEST_ROOT/malformed-$case_name"
  mkdir -p "$case_home/.local/bin" "$case_home/.codex-sam"
  printf '%s' "$malformed_content" >"$case_home/.zshrc"
  printf 'existing wrapper\n' >"$case_home/.local/bin/sam-codex"
  printf 'existing config\n' >"$case_home/.codex-sam/config.toml"

  before_zshrc="$(shasum "$case_home/.zshrc")"
  before_wrapper="$(shasum "$case_home/.local/bin/sam-codex")"
  before_config="$(shasum "$case_home/.codex-sam/config.toml")"

  if HOME="$case_home" bash "$SCRIPT_DIR/install-macos.sh" >/dev/null 2>&1; then
    printf 'Expected install failure for malformed case: %s\n' "$case_name" >&2
    exit 1
  fi
  test "$(shasum "$case_home/.zshrc")" = "$before_zshrc"
  test "$(shasum "$case_home/.local/bin/sam-codex")" = "$before_wrapper"
  test "$(shasum "$case_home/.codex-sam/config.toml")" = "$before_config"

  if HOME="$case_home" bash "$SCRIPT_DIR/uninstall-macos.sh" >/dev/null 2>&1; then
    printf 'Expected uninstall failure for malformed case: %s\n' "$case_name" >&2
    exit 1
  fi
  test "$(shasum "$case_home/.zshrc")" = "$before_zshrc"
  test "$(shasum "$case_home/.local/bin/sam-codex")" = "$before_wrapper"
  test "$(shasum "$case_home/.codex-sam/config.toml")" = "$before_config"
}

assert_malformed_fails_closed \
  start-only \
  $'before\n# >>> SAM-Codex managed >>>\nafter\n'
assert_malformed_fails_closed \
  end-only \
  $'before\n# <<< SAM-Codex managed <<<\nafter\n'
assert_malformed_fails_closed \
  duplicate \
  $'# >>> SAM-Codex managed >>>\nfirst\n# <<< SAM-Codex managed <<<\n# >>> SAM-Codex managed >>>\nsecond\n# <<< SAM-Codex managed <<<\n'

printf 'PASS: install, repeat install, command isolation, uninstall, reinstall\n'
