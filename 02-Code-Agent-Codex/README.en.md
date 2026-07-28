# 2. Configure Codex and SAM-Codex

**Language:** [한국어](README.md) | English

This setup keeps the official `codex` command and adds an isolated `sam-codex`
command. `sam-codex` uses a separate `CODEX_HOME` and the SAM V2 provider, so it
does not change the existing OpenAI login, configuration, or sessions.

## Two modes

| Mode | Command | Configuration home | API and billing |
| --- | --- | --- | --- |
| Official Codex | `codex` | `~/.codex` | Direct OpenAI/ChatGPT; outside SAM |
| SAM-Codex | `sam-codex` | `~/.codex-sam` | SAM V2 OpenAI; SAM usage and cost |

## A. Use only official Codex

```bash
npm install -g @openai/codex@latest
codex --version
codex login
codex
```

Run `codex logout` only when you intend to remove official authentication. It
is not required when removing SAM-Codex.

## B. Add `sam-codex` without changing official Codex

First use [`../00-sam-setup/`](../00-sam-setup/README.en.md) to confirm that the
shared `SAM_API_KEY` receives HTTP `200` from `/v2/openai/models`.

### macOS / Linux

```bash
chmod +x install-macos.sh uninstall-macos.sh
./install-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

The installer reuses the shared key in `~/.sam/env` or
`%USERPROFILE%\.sam\env.ps1`. If it is missing, the installer accepts hidden
input and stores it in the same standard file.

## Installed files

| Item | macOS / Linux | Windows |
| --- | --- | --- |
| Shared key | `~/.sam/env` | `%USERPROFILE%\.sam\env.ps1` |
| SAM Codex home | `~/.codex-sam` | `%USERPROFILE%\.codex-sam` |
| Wrapper | `~/.local/bin/sam-codex` | `%USERPROFILE%\bin\sam-codex.*` |

The default model is `azure.gpt-5.6-luna`. Installation stops when current
authenticated discovery does not admit that model.

```toml
model = "azure.gpt-5.6-luna"
model_provider = "sam"
web_search = "disabled"

[model_providers.sam]
base_url = "https://sam.soonsoon.ai/v2/openai"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
```

Provider-hosted Codex search is disabled. Search, page reading, and usage tools
are provided through SAM-observed MCP instead.

## Launch and select a model

Run SAM-Codex from a Git project. The wrapper blocks a non-project launch under
the home directory so ordinary `~/.codex` settings cannot be interpreted as a
project layer and override SAM isolation.

```bash
cd "$HOME/Developer/my-project"
sam-codex
```

For an empty test project:

```bash
mkdir -p "$HOME/Developer/sam-codex-test"
cd "$HOME/Developer/sam-codex-test"
git init
sam-codex
```

`/model` contains only SAM Responses models admitted for the current account
and key by authenticated V2 discovery. The catalog is cached only under the
SAM-specific home and contains no key.

No-generation wrapper and discovery check:

```bash
sam-codex --version
```

Run one minimal provider-native Responses call only when you intend to create
SAM usage:

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

Daily use:

```text
codex        # official OpenAI/ChatGPT environment
sam-codex    # SAM environment
```

## Remove only `sam-codex`

```bash
./uninstall-macos.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

The uninstaller removes only the wrapper and SAM Codex provider
configuration. It leaves official `codex`, `~/.codex`, the shared SAM key,
`sam-claude`, and existing SAM-Codex session data unchanged.

After removing both SAM wrappers, use the shared-key removal step in
[`../00-sam-setup/`](../00-sam-setup/README.en.md) if the key is no longer
needed.

## Diagnostic order

1. `codex --version`: official CLI installation
2. `/readyz`: network and SAM readiness
3. `/v2/openai/models`: key, grant, and admitted model
4. `sam-codex --version` in a Git project: isolated wrapper
5. Minimal generation: V2 Responses and usage

`MODEL_NOT_NATIVE_ON_SURFACE` means the selected alias is not admitted on the
V2 OpenAI surface. Use `/model` or a provider-explicit alias from current
discovery.

## Official references

- [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Codex environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables)
- [Codex custom model providers](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers)
