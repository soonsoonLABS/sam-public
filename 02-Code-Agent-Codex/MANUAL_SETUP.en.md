# Manual SAM Codex setup (macOS)

**Language:** [한국어](MANUAL_SETUP.md) | English

This is the baseline manual setup without an installer. It keeps the API key
out of shell history and separates normal Codex from SAM Codex CLI state.

## 1. Choose an existing SAM key or dedicated Code Agent key

An existing SAM key works, but a per-device key such as `Code Agent - Mac` is
recommended. Prepare the key in SAM web under **API Keys**. Even when reusing
an existing key, enter it separately as `SAM_CODE_API_KEY` for Code Agent.

## 2. Enter the key in the current terminal

Run this command, paste the key, then press Enter. It stays hidden and is not
saved to disk yet.

```bash
read -s "SAM_CODE_API_KEY?Enter SAM Code Agent key: "
echo
export SAM_CODE_API_KEY
```

## 3. Check the key prefix

Print only the first 12 characters, never the full key.

```bash
echo "${SAM_CODE_API_KEY:0:12}..."
```

## 4. Test the key

Verify the SAM route before involving Codex. A successful response includes
`SAM-CODEX-OK`.

```bash
curl --silent --show-error --fail-with-body --max-time 120 -X POST \
  'https://sam.soonsoon.ai/openai/v1/responses' \
  -H "Authorization: Bearer $SAM_CODE_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{"model":"sam-codex-agent","input":"Reply with exactly: SAM-CODEX-OK","stream":false}'
```

## 5. Save only the verified key in the Code Agent path

Store the key in the Code Agent-only local file only after the test succeeds.

```bash
mkdir -p "$HOME/.sam-code-agent"
printf 'export SAM_CODE_API_KEY=%q\n' "$SAM_CODE_API_KEY" > "$HOME/.sam-code-agent/env"
chmod 600 "$HOME/.sam-code-agent/env"
unset SAM_CODE_API_KEY
```

## 6. Install Codex CLI

Install Node.js LTS first if needed, then run:

```bash
npm install -g @openai/codex@latest
codex --version
```

## 7. Create an isolated SAM Codex CLI environment

Keep SAM configuration in `~/.codex-sam`, not the normal `~/.codex` home.

```bash
mkdir -p "$HOME/.codex-sam"
cat > "$HOME/.codex-sam/config.toml" <<'EOF'
model = "sam-codex-agent"
model_provider = "sam"
model_reasoning_effort = "medium"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/openai/v1"
env_key = "SAM_CODE_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
EOF
chmod 600 "$HOME/.codex-sam/config.toml"
```

Launch SAM Codex from a neutral workspace, not from `$HOME`. Running from
`$HOME` can make the normal `~/.codex/config.toml` look like project-local
configuration and cause provider settings to be ignored.

```bash
mkdir -p /private/tmp/sam-codex-cli
cd /private/tmp/sam-codex-cli
source "$HOME/.sam-code-agent/env"

CODEX_HOME="$HOME/.codex-sam" codex
```

Smoke-test the route with:

```bash
mkdir -p /private/tmp/sam-codex-cli
cd /private/tmp/sam-codex-cli
source "$HOME/.sam-code-agent/env"

CODEX_HOME="$HOME/.codex-sam" codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

The header should show `model: sam-codex-agent` and `provider: sam`. Use plain
`codex` for the normal OpenAI/ChatGPT Codex CLI.

## 8. Run default Codex and SAM-Codex Desktop side by side

To keep the default Codex Desktop open and launch SAM-Codex in a separate
window, isolate both `CODEX_HOME` and Electron `user-data-dir`. This is the
macOS side-by-side method we verified.

Create the launcher:

```bash
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/sam-codex-desktop" <<'EOF'
#!/bin/zsh
set -euo pipefail

ENV_FILE="$HOME/.sam-code-agent/env"
CODEX_HOME_DIR="$HOME/.codex-sam"
USER_DATA_DIR="$HOME/Library/Application Support/SAM Codex Desktop"
WORKSPACE="${1:-/private/tmp/sam-codex-desktop}"

fail() {
  /usr/bin/osascript -e "display alert \"SAM Codex\" message \"$1\" as critical" >/dev/null 2>&1 || true
  echo "$1" >&2
  exit 1
}

[[ -r "$ENV_FILE" ]] || fail "Key file not found: $ENV_FILE"

set -a
source "$ENV_FILE"
set +a

[[ -n "${SAM_CODE_API_KEY:-}" ]] || fail "SAM_CODE_API_KEY is not set."
[[ -d /Applications/Codex.app ]] || fail "/Applications/Codex.app was not found."

mkdir -p "$USER_DATA_DIR" "$CODEX_HOME_DIR" "$WORKSPACE"
umask 077
printf 'SAM_CODE_API_KEY=%s\n' "$SAM_CODE_API_KEY" > "$CODEX_HOME_DIR/.env"
chmod 600 "$CODEX_HOME_DIR/.env"

launchctl setenv SAM_CODE_API_KEY "$SAM_CODE_API_KEY"
launchctl setenv CODEX_HOME "$CODEX_HOME_DIR"
open -n -a Codex --args --user-data-dir="$USER_DATA_DIR" "$WORKSPACE"
EOF
chmod +x "$HOME/.local/bin/sam-codex-desktop"
```

Run it:

```bash
~/.local/bin/sam-codex-desktop
```

Optional desktop shortcut:

```bash
cat > "$HOME/Desktop/SAM-Codex.command" <<'EOF'
#!/bin/zsh
exec "$HOME/.local/bin/sam-codex-desktop" "$@"
EOF
chmod +x "$HOME/Desktop/SAM-Codex.command"
```

This launcher depends on Codex Desktop launch arguments. If it fails, diagnose
the CLI smoke test in step 7 first. The most stable baseline remains the
`sam-codex` CLI.

## Optional: temporarily switch the default Codex CLI or desktop app to SAM

This is not the side-by-side path. It replaces the default `~/.codex/config.toml`
with the SAM config and later restores it. Use step 8 above for simultaneous
default Codex + SAM-Codex Desktop use.

The default profile uses `~/.codex/config.toml`. Back it up, replace it with
the SAM configuration, and set the GUI-session key:

```bash
mkdir -p "$HOME/.sam-code-agent/backups"
if [ -f "$HOME/.codex/config.toml" ]; then
  cp -p "$HOME/.codex/config.toml" "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak"
else
  : > "$HOME/.sam-code-agent/backups/default-codex-config-was-absent"
fi
mkdir -p "$HOME/.codex"
cp "$HOME/.codex-sam/config.toml" "$HOME/.codex/config.toml"

source "$HOME/.sam-code-agent/env"
launchctl setenv SAM_CODE_API_KEY "$SAM_CODE_API_KEY"
unset SAM_CODE_API_KEY
```

Fully quit the desktop app with `Cmd-Q` before reopening it.

Restore the normal OpenAI/ChatGPT configuration with:

```bash
if [ -f "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak" ]; then
  cp "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak" "$HOME/.codex/config.toml"
else
  rm -f "$HOME/.codex/config.toml"
fi
launchctl unsetenv SAM_CODE_API_KEY
```

Fully quit and reopen the app after restoring.
