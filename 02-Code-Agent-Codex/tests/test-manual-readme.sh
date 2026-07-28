#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$SCRIPT_DIR/MANUAL_SETUP.md"
QUICKSTART="$SCRIPT_DIR/README.md"
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

printf 'export SAM_API_KEY=%q\n' "manual-test-key" >"$HOME/.sam/env"
printf '%s\n' '{"models":[{"slug":"azure.gpt-5.6-luna"}]}' \
  >"$HOME/.codex-sam/models.json"
printf '%s\n' 'model = "gpt-5.6-sol"' >"$HOME/.codex/config.toml"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"Bearer manual-test-key"*) ;;
  *) exit 22 ;;
esac
printf '%s\n' '{"models":[{"slug":"azure.gpt-5.6-luna"}]}'
EOF

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}"
printf 'PWD=%s\n' "$PWD"
printf 'ARGS=%s\n' "$*"
EOF
chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/codex"

extract_heredoc() {
  marker="$1"
  awk -v marker="$marker" '
    index($0, marker) { capture = 1; next }
    capture && $0 == "EOF" { exit }
    capture { print }
  ' "$README"
}

# shellcheck disable=SC2016
extract_heredoc 'cat > "$HOME/.codex-sam/config.toml" <<EOF' |
  sed 's/$SAM_MODEL/azure.gpt-5.6-luna/g' \
    >"$HOME/.codex-sam/config.toml"

# shellcheck disable=SC2016
extract_heredoc 'cat > "$HOME/.local/bin/sam-codex" <<'\''EOF'\''' \
  >"$HOME/.local/bin/sam-codex"
chmod +x "$HOME/.local/bin/sam-codex"

# shellcheck disable=SC2016
extract_heredoc 'cat >> "$HOME/.zshrc" <<'\''EOF'\''' >"$HOME/.zshrc"

export HOME
export PATH="$FAKE_BIN:/usr/bin:/bin"

manual_output="$(
  zsh -f -c 'source "$HOME/.zshrc"; cd "$HOME"; sam-codex --version'
)"
printf '%s' "$manual_output" |
  grep -Fq "CODEX_HOME=$HOME/.codex-sam"
printf '%s' "$manual_output" |
  grep -Fq "PWD=$HOME/SAM-Codex"
printf '%s' "$manual_output" |
  grep -Fq 'model_provider="sam"'
printf '%s' "$manual_output" |
  grep -Fq 'model="azure.gpt-5.6-luna"'
if printf '%s' "$manual_output" | grep -Fq 'gpt-5.6-sol'; then
  exit 1
fi

official_output="$(zsh -f -c 'cd "$HOME"; codex --version')"
printf '%s' "$official_output" | grep -Fq 'CODEX_HOME='
if printf '%s' "$official_output" | grep -Fq '.codex-sam'; then
  exit 1
fi

grep -Fq 'url = "https://sam.soonsoon.ai/mcp"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'bearer_token_env_var = "SAM_API_KEY"' \
  "$HOME/.codex-sam/config.toml"
grep -Fq 'grep -Fxc "# >>> SAM-Codex managed >>>"' "$README"
grep -Fq 'grep -Fxc "# <<< SAM-Codex managed <<<"' "$README"
grep -Fq '[완전 수동 설정](./MANUAL_SETUP.md)' "$QUICKSTART"
grep -Fq '[문제 해결](./TROUBLESHOOTING.md)' "$QUICKSTART"
grep -Fq '[동작 방식](./HOW_IT_WORKS.md)' "$QUICKSTART"

printf 'PASS: README manual config, wrapper, function, isolation, MCP, official return\n'
