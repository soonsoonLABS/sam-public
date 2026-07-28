# 3. Configure Claude Code and SAM-Claude

**Language:** [한국어](README.md) | English

This setup keeps the official `claude` command and adds an isolated
`sam-claude` command. `sam-claude` uses a separate `CLAUDE_CONFIG_DIR` and
process-only gateway variables, so it does not change the existing Anthropic
login, configuration, or sessions.

## Two modes

| Mode | Command | Configuration home | API and billing |
| --- | --- | --- | --- |
| Official Claude Code | `claude` | `~/.claude` | Direct Anthropic; outside SAM |
| SAM-Claude | `sam-claude` | `~/.claude-sam` | SAM V2 Anthropic; SAM usage and cost |

You can run either command from the same project directory.

## A. Use only official Claude Code

Follow the [official Anthropic setup guide](https://code.claude.com/docs/en/setup),
then run:

```bash
claude --version
claude
```

Use `/logout` inside an official Claude Code session only when you intend to
remove the official Anthropic authentication. It is not required when removing
SAM-Claude.

## B. Add `sam-claude` without changing official Claude Code

First use [`../00-sam-setup/`](../00-sam-setup/README.en.md) to confirm that the same
`SAM_API_KEY` receives HTTP `200` from `/v2/anthropic/v1/models`.

SAM-Claude maps the four Claude Code choices to SAM role aliases:

| Claude Code choice | SAM role alias | Stable discovery backing ID |
| --- | --- | --- |
| Haiku | `claude-haiku` | `anthropic.claude-haiku-4-5` |
| Sonnet | `claude-sonnet-5` | `anthropic.claude-sonnet-5` |
| Sonnet 1M | `claude-sonnet-5` with `[1m]` selection | The eligible 1M Sonnet candidate |
| Opus | `claude-opus-5` | `anthropic.claude-opus-5` |

The installer requires all three stable backing IDs to appear in current
authenticated discovery. The client sends the role alias and SAM resolves it
to the account's saved candidate. The installer stops instead of silently
downgrading versions. Check the Claude Code role mappings in SAM when a backing
ID is missing.

### macOS / Linux

```bash
chmod +x install-macos.sh uninstall-macos.sh
./install-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

An existing key in `~/.sam/env` or
`%USERPROFILE%\.sam\env.ps1` is reused, so both wrappers use the same
SAM key.

## Installed files and authentication boundary

```text
~/.sam/env                    # shared SAM key on macOS/Linux
~/.claude-sam/                # isolated SAM Claude configuration and sessions
~/.local/bin/sam-claude       # SAM-only command
```

Windows uses `%USERPROFILE%\.sam\env.ps1`,
`%USERPROFILE%\.claude-sam`, and `%USERPROFILE%\bin\sam-claude.*`.

The wrapper sets these values only in the `sam-claude` process:

```text
ANTHROPIC_BASE_URL=https://sam.soonsoon.ai/v2/anthropic
ANTHROPIC_AUTH_TOKEN=<shared SAM_API_KEY passed at runtime>
ANTHROPIC_MODEL=claude-sonnet-5
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5
ANTHROPIC_SMALL_FAST_MODEL=claude-haiku
```

The key is never written to `settings.json`. The wrapper removes
`ANTHROPIC_API_KEY` and `CLAUDE_CODE_OAUTH_TOKEN` from the SAM process so
official Anthropic authentication cannot override the SAM token.

## Use and select a model

```text
claude        # official Anthropic environment
sam-claude    # SAM environment, Sonnet by default
```

Open `/model` in SAM-Claude or choose at launch:

```bash
sam-claude --model haiku
sam-claude --model sonnet
sam-claude --model 'sonnet[1m]'
sam-claude --model opus
```

`sonnet[1m]` succeeds only when the candidate mapped to the SAM Sonnet 1M role
is actually eligible for a 1M context window.

Installation uses discovery only and creates no model usage. Run one minimal
generation only when you intend to create SAM usage:

```bash
sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

## Remove only `sam-claude`

### macOS / Linux

```bash
./uninstall-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

The uninstaller removes only the wrapper. It leaves official `claude`,
`~/.claude`, the shared SAM key, `sam-codex`, and existing SAM-Claude sessions
unchanged.

After removing both SAM wrappers, use the shared-key removal step in
[`../00-sam-setup/`](../00-sam-setup/README.en.md) if the key is no longer needed.

## Diagnostic order

1. `claude --version`: official CLI installation
2. `/readyz`: network and SAM readiness
3. `/v2/anthropic/v1/models`: key, grant, and the three stable backing IDs
4. `sam-claude --model sonnet`: isolated launch and model selection
5. Minimal print call: provider-native Messages and usage

`401 AUTH_INVALID` is a key failure. If discovery returns `200` but a role model
is absent, do not assume key reset; inspect the SAM role mapping and catalog
admission.

## Official references

- [Claude Code environment variables](https://code.claude.com/docs/en/env-vars)
- [Claude Code model configuration](https://code.claude.com/docs/en/model-config)
- [Claude Code gateway configuration](https://code.claude.com/docs/en/llm-gateway)
