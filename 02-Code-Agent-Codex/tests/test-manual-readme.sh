#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$SCRIPT_DIR/MANUAL_SETUP.md"
QUICKSTART="$SCRIPT_DIR/README.md"
WRAPPER_SOURCE="$SCRIPT_DIR/templates/sam-codex"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p \
  "$HOME/.sam" \
  "$HOME/.codex" \
  "$HOME/.codex-sam" \
  "$HOME/.local/bin" \
  "$FAKE_BIN"

export HOME
export PATH="$FAKE_BIN:/usr/bin:/bin"
export CURL_LOG="$TEST_ROOT/curl.log"
export CURL_MODE_FILE="$TEST_ROOT/curl-mode"
export FAKE_CATALOG="$TEST_ROOT/catalog.json"
export WRAPPER_SOURCE

printf 'success\n' >"$CURL_MODE_FILE"
printf 'export SAM_API_KEY=%q\n' "manual-test-key" >"$HOME/.sam/env"
printf '%s\n' '{"fetched_at":"2026-07-29T00:00:00Z","etag":"sam-v2-unified-codex-catalog","client_version":"0.146.0","models":[{"slug":"gpt-5.6-sol","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.6-terra","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.6-luna","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.5","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.4","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.4-mini","visibility":"hide","supported_in_api":false},{"slug":"gpt-5.2","visibility":"hide","supported_in_api":false},{"slug":"codex-auto-review","visibility":"hide","supported_in_api":false},{"slug":"azure.gpt-5.6-luna","visibility":"list","supported_in_api":true},{"slug":"fw-kimi-k3","display_name":"Kimi K3 (Fireworks)","description":"Kimi coding model (not V2 provider-native)","visibility":"list","supported_in_api":true,"comp_hash":"sam-compat-fw-kimi-k3","priority":100}]}' \
  >"$FAKE_CATALOG"
printf '%s\n' 'model = "gpt-5.6-sol"' >"$HOME/.codex/config.toml"
printf '%s\n' 'export BEFORE=value' >"$HOME/.zshrc"

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
  *"raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/templates/sam-codex"*)
    [ -n "$output_file" ] || exit 22
    cp "$WRAPPER_SOURCE" "$output_file"
    exit 0
    ;;
esac

case "$arguments" in
  *"Bearer manual-test-key"*) ;;
  *) exit 22 ;;
esac
case "$arguments" in
  *"-H x-sam-codex-cache: 1"*) ;;
  *) exit 22 ;;
esac
case "$arguments" in
  *"--data-urlencode client_version="*"https://sam.soonsoon.ai/v2/codex/models"*) ;;
  *) exit 22 ;;
esac
printf '%s\n' "$arguments" >>"$CURL_LOG"
[ "$(cat "$CURL_MODE_FILE")" = "success" ] || exit 22
if [ -n "$output_file" ]; then
  cp "$FAKE_CATALOG" "$output_file"
else
  cat "$FAKE_CATALOG"
fi
EOF

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ] && [ -z "${CODEX_HOME:-}" ]; then
  printf 'codex-cli 0.146.0\n'
  exit 0
fi
printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}"
printf 'PWD=%s\n' "$PWD"
printf 'ARGS=%s\n' "$*"
EOF
chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/codex"

extract_fence_after_heading() {
  heading="$1"
  awk -v heading="$heading" '
    $0 == heading { found_heading = 1; next }
    found_heading && $0 == "```bash" { capture = 1; next }
    capture && $0 == "```" { exit }
    capture { print }
  ' "$README"
}

extract_fence_after_heading '## 2. SAM API Key 저장하기' | zsh -f
extract_fence_after_heading '## 4. SAM Codex 설정 만들기' | zsh -f
# shellcheck disable=SC2016
extract_fence_after_heading '## 5. 검증된 `sam-codex` 실행 파일 받기' |
  zsh -f >/dev/null
extract_fence_after_heading '## 6. 터미널 명령 등록하기' |
  zsh -f
extract_fence_after_heading '## 6. 터미널 명령 등록하기' |
  zsh -f

test -x "$HOME/.local/bin/sam-codex"
cmp -s "$WRAPPER_SOURCE" "$HOME/.local/bin/sam-codex"
test "$(grep -Fc '# >>> SAM-Codex managed >>>' "$HOME/.zshrc")" -eq 1
grep -Fq 'export BEFORE=value' "$HOME/.zshrc"
grep -Fq 'base_url = "https://sam.soonsoon.ai/v2/codex"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'url = "https://sam.soonsoon.ai/mcp"' \
  "$HOME/.codex-sam/config.toml"
if grep -Fq 'manual-test-key' "$HOME/.codex-sam/config.toml"; then
  exit 1
fi

manual_output="$(
  zsh -f -c 'source "$HOME/.zshrc"; cd "$HOME"; sam-codex --version'
)"
for expected in \
  "CODEX_HOME=$HOME/.codex-sam" \
  "PWD=$HOME/SAM-Codex" \
  'model_provider="sam"' \
  'model="azure.gpt-5.6-luna"'
do
  if ! printf '%s' "$manual_output" | grep -Fq "$expected"; then
    printf 'Missing expected sanitized wrapper output: %s\n' "$expected" >&2
    printf '%s\n' "$manual_output" >&2
    exit 1
  fi
done
if printf '%s' "$manual_output" | grep -Fq 'model="gpt-5.6-sol"'; then
  exit 1
fi

if zsh -f -c \
  'source "$HOME/.zshrc"; cd "$HOME"; sam-codex -c '\''model_provider="openai"'\'' --version' \
  >"$TEST_ROOT/override.stdout" 2>"$TEST_ROOT/override.stderr"; then
  printf 'Expected manual wrapper routing override to be rejected.\n' >&2
  exit 1
fi
test ! -s "$TEST_ROOT/override.stdout"
grep -Fq 'blocks model/provider/config override options' \
  "$TEST_ROOT/override.stderr"

catalog_before_failure="$(shasum "$HOME/.codex-sam/models.json")"
printf 'fail\n' >"$CURL_MODE_FILE"
if zsh -f -c 'source "$HOME/.zshrc"; cd "$HOME"; sam-codex --version' \
  >"$TEST_ROOT/stale.stdout" 2>"$TEST_ROOT/stale.stderr"; then
  printf 'Expected manual wrapper to stop when refresh fails.\n' >&2
  exit 1
fi
test ! -s "$TEST_ROOT/stale.stdout"
grep -Fq 'cache was preserved' "$TEST_ROOT/stale.stderr"
test "$(shasum "$HOME/.codex-sam/models.json")" = \
  "$catalog_before_failure"

official_output="$(zsh -f -c 'cd "$HOME"; codex official-check')"
printf '%s' "$official_output" | grep -Fq 'CODEX_HOME='
if printf '%s' "$official_output" | grep -Fq '.codex-sam'; then
  exit 1
fi

grep -Fq 'npm install -g @openai/codex' "$README"
grep -Fq '버전은 고정하지 않습니다' "$QUICKSTART"
grep -Fq 'Agent 페이지에서' "$README"
grep -Fq '선택한 V2-native 모델과 인증된' "$README"
grep -Fq 'templates/sam-codex' "$README"
grep -Fq '[완전 수동 설정](./MANUAL_SETUP.md)' "$QUICKSTART"
grep -Fq '[문제 해결](./TROUBLESHOOTING.md)' "$QUICKSTART"
grep -Fq '[동작 방식](./HOW_IT_WORKS.md)' "$QUICKSTART"

extract_fence_after_heading '## 수동 해제' | zsh -f >/dev/null
test ! -e "$HOME/.local/bin/sam-codex"
test ! -e "$HOME/.codex-sam"
test -s "$HOME/.sam/env"
grep -Fq 'export BEFORE=value' "$HOME/.zshrc"
if grep -Fq '# >>> SAM-Codex managed >>>' "$HOME/.zshrc"; then
  exit 1
fi

printf 'PASS: concise manual setup, wrapper sync, isolation, removal\n'
