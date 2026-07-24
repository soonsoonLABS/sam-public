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

refresh_model_catalog() {
  local client_version cache_tmp
  client_version="$(codex --version | awk '{print $2}')"
  [[ -n "$client_version" ]] || return 0
  mkdir -p "$CODEX_HOME"
  umask 077
  cache_tmp="$(mktemp "$CODEX_HOME/.models_cache.XXXXXX")" || return 0
  if curl --fail --silent --show-error --max-time 10 --get \
    -H "Authorization: Bearer $SAM_CODEX_API" \
    -H 'x-sam-codex-cache: 1' \
    --data-urlencode "client_version=$client_version" \
    'https://sam.soonsoon.ai/v2/openai/models' > "$cache_tmp" \
    && grep -q '"models"' "$cache_tmp"; then
    mv "$cache_tmp" "$CODEX_HOME/models_cache.json"
  else
    rm -f "$cache_tmp"
  fi
}

refresh_model_catalog

models=(
  "azure.gpt-5.6-terra|Azure Foundry · everyday"
  "azure.gpt-5.6-sol|Azure Foundry · difficult work"
  "azure.gpt-5.6-luna|Azure Foundry · fast"
  "azure.gpt-5.4|Azure Foundry · GPT-5.4"
  "aws.gpt-5.6-terra|AWS Bedrock Mantle · everyday"
  "aws.gpt-5.6-sol|AWS Bedrock Mantle · difficult work"
  "aws.gpt-5.6-luna|AWS Bedrock Mantle · fast"
  "aws.gpt-5.5|AWS Bedrock Mantle · GPT-5.5"
  "aws.gpt-5.4|AWS Bedrock Mantle · GPT-5.4"
)

if [[ "${1:-}" == "model" ]]; then
  shift
  if [[ $# -gt 0 ]]; then
    selected_model="$1"
    shift
  else
    echo "Choose a SAM model"
    PS3="Enter a number: "
    select entry in "${models[@]}"; do
      if [[ -n "${entry:-}" ]]; then
        selected_model="${entry%%|*}"
        break
      fi
      echo "Enter a number from the list."
    done
  fi
  exec codex -m "$selected_model" "$@"
fi

exec codex "$@"
```

### 4. Run once

After closing the editor, run this once in Terminal. It makes the wrapper
executable and adds the local bin directory to the default macOS zsh PATH.

```bash
chmod +x "$HOME/.local/bin/sam-codex"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
source "$HOME/.zshrc"
```

### 5. Run every time

After that, open a new Terminal and run only:

```bash
sam-codex
```

The default model is `azure.gpt-5.6-terra`. `sam-codex` refreshes its isolated
SAM model catalog at startup. Type `/model` inside Codex to see the Azure
Foundry and AWS Bedrock Mantle aliases.

To refresh the list, close Codex and run it again:

```bash
sam-codex
```

Use this optional terminal selector only when you already want to launch a
specific model directly:

```bash
sam-codex model aws.gpt-5.6-sol
```

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
