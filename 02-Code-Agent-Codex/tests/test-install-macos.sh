#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

TEST_HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$TEST_HOME" "$FAKE_BIN"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"Bearer test-only-placeholder"*) ;;
  *) exit 22 ;;
esac
cat <<'JSON'
{"models":[{"slug":"azure.gpt-5.6-luna","display_name":"Luna"}]}
JSON
EOF

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
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
grep -Fq 'base_url = "https://sam.soonsoon.ai/v2/openai"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'url = "https://sam.soonsoon.ai/mcp"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'web_search = "disabled"' "$HOME/.codex-sam/config.toml"
grep -Fq 'project_root_markers = [".git", ".sam-codex-root"]' \
  "$HOME/.codex-sam/config.toml"
if grep -Fq 'test-only-placeholder' "$HOME/.codex-sam/config.toml"; then
  exit 1
fi

wrapper_output="$(cd "$HOME" && "$HOME/.local/bin/sam-codex" --version)"
printf '%s' "$wrapper_output" |
  grep -Fq "CODEX_HOME=$HOME/.codex-sam"
printf '%s' "$wrapper_output" |
  grep -Fq "model_catalog_json=\"$HOME/.codex-sam/models.json\""
printf '%s' "$wrapper_output" |
  grep -Fq 'model_provider="sam"'
printf '%s' "$wrapper_output" |
  grep -Fq 'model="azure.gpt-5.6-luna"'
printf '%s' "$wrapper_output" |
  grep -Fq "PWD=$HOME/SAM-Codex"
test -e "$HOME/SAM-Codex/.sam-codex-root"

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
