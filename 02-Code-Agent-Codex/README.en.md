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
npm install -g @openai/codex@0.146.0
codex --version
codex login
codex
```

The current SAM model-catalog contract supports Codex `0.145.x` and `0.146.0`.
Later unverified versions are rejected until their bundled-model hide contract
is verified.

Run `codex logout` only when you intend to remove official authentication. It
is not required when removing SAM-Codex.

## B. Add `sam-codex` without changing official Codex

First use [`../00-sam-setup/`](../00-sam-setup/README.en.md) to confirm that the
shared `SAM_API_KEY` receives HTTP `200` from `/v2/codex/models`.

For a complete Windows installation, manual setup, and test sequence, see
[Windows setup](./WINDOWS_SETUP.en.md).

### macOS

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

| Item | macOS | Windows |
| --- | --- | --- |
| Shared key | `~/.sam/env` | `%USERPROFILE%\.sam\env.ps1` |
| SAM Codex home | `~/.codex-sam` | `%USERPROFILE%\.codex-sam` |
| Wrapper | `~/.local/bin/sam-codex` | `%USERPROFILE%\bin\sam-codex.*` |

The installer keeps an existing configured model while it remains admitted.
For a fresh setup it prefers `azure.gpt-5.6-luna` when selected, then falls back
to the first Web-selected model returned by authenticated discovery.
Installation stops when the unified selected catalog is empty or cannot be
verified.

```toml
model = "<a selected native or certified compatibility alias>"
model_provider = "sam"
web_search = "disabled"

[model_providers.sam]
base_url = "https://sam.soonsoon.ai/v2/codex"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
required = true
```

Provider-hosted Codex search is disabled. Search, page reading, and usage tools
are provided through SAM-observed MCP instead.

## Launch and select a model

Run SAM-Codex from a Git project. When launched from the home directory or
another non-Git directory, the wrapper moves to the isolated `~/SAM-Codex`
workspace so ordinary `~/.codex` settings cannot override SAM isolation.

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

At every launch, the wrapper requests a client-versioned catalog. `/model`
contains Web-selected native models plus selected, certified compatibility
models under their original aliases. Compatibility rows are not V2-native;
SAM classifies their aliases before execution. The catalog is cached only under
the SAM-specific home and contains no key. A failed refresh preserves the prior
file but stops the launch so a model removed on the Agent page cannot be reused.

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

Windows PowerShell uses the PowerShell continuation character:

```powershell
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral `
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

Both uninstallers leave official `codex`, `~/.codex`, the shared SAM key, and
`sam-claude` unchanged. On macOS, `~/.codex-sam` (including its sessions) is
moved to Trash for recovery. On Windows, the provider configuration and wrapper
are removed while other files under `.codex-sam` are preserved.

After removing both SAM wrappers, use the shared-key removal step in
[`../00-sam-setup/`](../00-sam-setup/README.en.md) if the key is no longer
needed.

## Diagnostic order

1. `codex --version`: official CLI installation
2. `/health`: network and SAM API health
3. `/v2/codex/models`: key, grant, and admitted native/compatibility model
4. `sam-codex --version` in a Git project: isolated wrapper
5. Minimal generation: V2 Responses and usage

`MODEL_NOT_NATIVE_ON_SURFACE`, `MODEL_NOT_SELECTED`, or
`MODEL_NOT_CODEX_CERTIFIED` means the alias is not admitted on the unified
SAM-Codex surface. Use `/model` or a selected alias from current discovery.

## Official references

- [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Codex environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables)
- [Codex custom model providers](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers)
