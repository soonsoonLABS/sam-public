# SAM-Claude Quick Start

Keep the official Anthropic `claude` command and add an isolated
`sam-claude` command.

**Language:** [한국어](./README.md) | English

| Command | Connection | Configuration and sessions |
| --- | --- | --- |
| `claude` | Direct Anthropic | `~/.claude` |
| `sam-claude` | SAM `/v2/claude` + SAM MCP | `~/.claude-sam` |

> For a first installation, complete only **steps 1–3** below.

## Requirements

- SAM **Agent > Claude Code** access and a SAM API Key
- Official Claude Code `2.1.129` or newer
- macOS: `curl` and either Python 3 or Node.js
- Windows: PowerShell

If Claude Code is not installed, follow the
[official Anthropic setup guide](https://code.claude.com/docs/en/setup) first.
Then check the version:

```bash
claude --version
```

## 1. One-line installation

You can run the command from any directory.

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-macos.sh) && source "$HOME/.zshrc"
```

### Windows PowerShell

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-windows.ps1')))
```

When prompted for `SAM API key:`, paste the key and press Enter. The input is
not displayed. An existing shared key file is reused without another prompt:

- macOS: `~/.sam/env`
- Windows: `%USERPROFILE%\.sam\env.ps1`

The installer verifies authenticated discovery and the saved role mappings
without generating model output. If they do not match, installation stops and
the official Claude environment remains unchanged.

## 2. Start

```bash
sam-claude
```

The interface is the normal Claude Code interface. `sam-claude` uses the
official Claude Code client with an isolated configuration home,
authentication, and SAM gateway.

## 3. Verify the connection

Run `/model` inside Claude Code:

```text
/model
```

Confirm the following:

- The **Haiku / Sonnet / Opus** models selected in SAM Web are shown.
- `sonnet[1m]` is available only when the selected Sonnet has a context window
  of at least 1,000,000 tokens.
- Any separately selected certified compatibility model is shown only by the
  exact `claude-sam-*` ID returned by discovery.

Never construct or guess a compatibility model ID. Use only an ID displayed by
`/model`.

Check SAM MCP:

```bash
sam-claude mcp list
```

If `sam-tools` and `https://sam.soonsoon.ai/mcp` appear, SAM search and page
reading tools are connected.

Run one real model request only when intended:

```bash
sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

Installation and discovery are not generation calls. The command above and
normal conversations can create SAM usage and cost.

## Everyday use

```bash
claude       # existing Anthropic environment
sam-claude   # SAM environment
```

Their logins, settings, and sessions are isolated. The installer does not
modify official `~/.claude`, the official login, or project settings.

At every start, `sam-claude` checks both:

1. Unified SAM-Claude inventory: `/v2/claude/v1/models`
2. The account's saved Claude role mappings: Haiku / Sonnet / Opus

Claude Code starts only when the results match exactly. A network or validation
failure preserves the previous cache but never launches with stale models.

## Remove

The default removal deletes the managed `sam-claude` command and shell setup.
It preserves official `claude`, the shared SAM key, `sam-codex`, and existing
sessions and MCP settings in `~/.claude-sam`.

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-macos.sh) && source "$HOME/.zshrc"
```

To also move isolated SAM-Claude sessions and settings to Trash:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-macos.sh) --purge-data && source "$HOME/.zshrc"
```

### Windows PowerShell

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1')))
```

To also move isolated data to a backup directory:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1'))) -PurgeData
```

The shared SAM key is preserved because SAM-Codex can use the same key.

## Other installation paths

- To inspect the files first, download
  [install-macos.sh](./install-macos.sh) or
  [install-windows.ps1](./install-windows.ps1).
- To configure every component yourself, follow
  [Manual setup](./MANUAL_SETUP.md).

## If something fails

See [Troubleshooting](./TROUBLESHOOTING.md) for command, version, key, role
mapping, `sonnet[1m]`, and MCP errors.

See [How it works](./HOW_IT_WORKS.md) for isolation, discovery, role mapping,
cache, and security boundaries.
