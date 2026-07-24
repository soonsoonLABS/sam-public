# SAM Codex CLI

**Language:** [한국어](README.md) | English

Keep normal OpenAI Codex unchanged. Use SAM V2 and MCP only through a separate
`sam-codex` command. **Manual setup is the default path**; the installer is optional.

## Manual setup (macOS/Linux)

Copy a **Run in Terminal** block into Terminal. A **File contents** block is
text to paste into `nano`, not a Terminal command. Save in `nano` with
`Control + O`, `Enter`, then `Control + X`.

### 1. Save the SAM key

Enter a SAM API key with Code Agent access. It is stored only in `~/.sam/env`.

```bash
mkdir -p "$HOME/.sam"
chmod 700 "$HOME/.sam"
printf "SAM Code Agent API key: "
stty -echo
IFS= read -r SAM_CODEX_API
stty echo
printf "\n"
printf 'export SAM_CODEX_API=%q\n' "$SAM_CODEX_API" > "$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
```

### 2. Create isolated Codex settings

Run in Terminal:

```bash
mkdir -p "$HOME/.codex-sam"
nano "$HOME/.codex-sam/config.toml"
```

When `nano` opens, paste these **File contents** and save:

```toml
model = "azure.gpt-5.6-terra"
model_provider = "sam"
service_tier = "default"
web_search = "disabled"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/openai"
env_key = "SAM_CODEX_API"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_CODEX_API"
```

### 3. Create `sam-codex`

Run in Terminal:

```bash
mkdir -p "$HOME/.local/bin"
nano "$HOME/.local/bin/sam-codex"
```

When `nano` opens, paste these **File contents**. Save and exit `nano`; do not
run this block in Terminal.

```bash
#!/usr/bin/env bash
set -euo pipefail

. "$HOME/.sam/env"
export CODEX_HOME="$HOME/.codex-sam"
exec codex "$@"
```

### 4. Run

After closing the editor, run this in Terminal. The final `sam-codex` line
actually starts Codex.

```bash
chmod +x "$HOME/.local/bin/sam-codex"
export PATH="$HOME/.local/bin:$PATH"
sam-codex
```

The default model is `azure.gpt-5.6-terra`. Use `/model` inside Codex to select
Azure Foundry or AWS Bedrock Mantle models.
To use it in a new terminal, add `export PATH="$HOME/.local/bin:$PATH"` to your
shell configuration once.

## Verify

Ask Codex:

```text
Use sam_account_usage to briefly show this month's SAM usage and remaining SSAM.
```

The tool is free and read-only. Ask for “SAM web search” when you need current
research; search is recorded as SAM usage.

## Optional installer

Use this only after you understand the manual setup.

```bash
git clone https://github.com/soonsoonLABS/sam-public.git
bash sam-public/02-Code-Agent-Codex/install-macos.sh
```

If `sam-codex-agent` appears, you are in a legacy environment. Close that Codex
window and use the V2 manual setup above.
