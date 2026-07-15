# SAM Codex on macOS

This guide creates a dedicated `sam-codex` terminal command. It uses SAM only
for that command and leaves your normal `codex` profile unchanged.

## 1. Install prerequisites

Install these before cloning `sam-public`: Git, Node.js LTS (which includes
npm), and Codex CLI.

```bash
# Run only if `git --version` fails. Complete the macOS dialog, then open a new terminal.
xcode-select --install

# Requires Homebrew. Otherwise, install the Node.js LTS package from https://nodejs.org.
brew install node
npm install -g @openai/codex@latest

git --version
node --version
npm --version
codex --version
```

If `brew` is not installed, use the Node.js LTS installer from nodejs.org;
npm is included with Node.js. Do not continue until `codex --version` succeeds.

## 2. Clone or update the installer

Clone the repository once. On later runs, update the existing checkout instead
of cloning it again.

```bash
if [ -d "$HOME/sam-public/.git" ]; then
  git -C "$HOME/sam-public" pull --ff-only
elif [ -e "$HOME/sam-public" ]; then
  echo "~/sam-public exists but is not a Git checkout; rename or remove it only after checking its contents."
  exit 1
else
  git clone https://github.com/soonsoonLABS/sam-public.git "$HOME/sam-public"
fi

cd "$HOME/sam-public/code-agent"
```

## 3. Install the dedicated SAM command

Run the installer and paste the SAM API key only into its hidden prompt. The
key owner needs `agent:codex` or `agent:coding_agents` permission.

```bash
unset SAM_API_KEY
bash install-macos.sh
```

The installer creates `~/.local/bin/sam-codex`. If the command is not found,
add that directory to your zsh PATH once, then open a new terminal:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
sam-codex --version
```

## 4. Use SAM Codex

Use `sam-codex`, not plain `codex`, for every SAM session:

```bash
# Interactive Codex terminal UI with SAM
sam-codex

# Non-interactive smoke test
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  'Reply with exactly: SAM-CODEX-OK'
```

The expected smoke-test reply is exactly `SAM-CODEX-OK`. If the command is not
yet on PATH, use the full path:

```bash
~/.local/bin/sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  'Reply with exactly: SAM-CODEX-OK'
```

## 5. Change the SAM API key

Re-run the installer. `unset` is important: it makes the installer show its
hidden prompt instead of reusing a key inherited by the shell.

```bash
cd "$HOME/sam-public/code-agent"
unset SAM_API_KEY
bash install-macos.sh
```

This overwrites only `~/.sam-code-agent/env`, not your normal Codex settings.
Revoke the old key in SAM when it is no longer needed.

## 6. Test the key directly

This checks the SAM key and `/openai/v1/responses` before involving Codex. It
does not print the key. A successful response contains
`"output_text":"SAM-CODEX-OK"`.

```bash
source "$HOME/.sam-code-agent/env"
curl --silent --show-error --fail-with-body --max-time 120 -X POST \
  'https://sam.soonsoon.ai/openai/v1/responses' \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{"model":"sam-codex-agent","input":"Reply with exactly: SAM-CODEX-OK","stream":false}'
unset SAM_API_KEY
```

If this succeeds but `sam-codex exec` fails, the key and SAM route are working;
re-run the installer and use the dedicated command rather than plain `codex`.

## 7. Create a desktop shortcut

After the installer succeeds, create a clickable Terminal launcher on the
desktop:

```bash
cat > "$HOME/Desktop/SAM-Codex.command" <<'EOF'
#!/bin/zsh
exec "$HOME/.local/bin/sam-codex"
EOF
chmod +x "$HOME/Desktop/SAM-Codex.command"
```

Double-click `SAM-Codex.command` to open the SAM Codex terminal UI. macOS may
ask for confirmation the first time because it is a local executable file.

## Desktop app

`sam-codex app` can launch the ChatGPT desktop app on macOS. Prefer
`sam-codex` for a dedicated SAM session: the desktop app does not provide a
separate, reliable per-launch SAM profile.
