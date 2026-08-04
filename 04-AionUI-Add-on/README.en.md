# AionUI Add-on — Use SAM Codex and SAM Claude as AionUI coding agents

**Language:** [한국어](README.md) | English

This add-on connects the `sam-codex` and `sam-claude` wrappers you already
installed to the [AionUI](https://github.com/iOfficeAI/AionUi) desktop app as
coding agents. It does not create a new terminal command. It only registers the
installed SAM wrappers so AionUI can launch them.

The official `codex`, `claude`, `~/.codex`, `~/.claude`, and existing logins are
left unchanged. You do not enter the SAM API key again. Both wrappers keep
reading the shared `~/.sam/env` key.

> The supported scope is macOS, zsh, and the AionUI desktop app.

## Prerequisites

Complete both installations first. The key prompt happens once, in that step.

1. [`02-Code-Agent-Codex/`](../02-Code-Agent-Codex/README.en.md): `sam-codex`
2. [`03-Code-Agent-Claude/`](../03-Code-Agent-Claude/README.en.md): `sam-claude`

Launch the AionUI app once as well. This add-on uses the ACP bridge runtime that
AionUI downloads.

## Two layers

| Layer | What it does | Automation |
| --- | --- | --- |
| Layer 1 (terminal) | Creates the `sam-codex-acp` launcher | Installer in this folder |
| Layer 2 (AionUI app) | Registers two agents | Values entered in the app |

Layer 2 is not automated from outside the app. AionUI exposes configuration only
inside its own runtime, and editing the configuration database directly can
corrupt it across app versions.

## 1. One-line install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/04-AionUI-Add-on/install-macos.sh)
```

On success the installer prints the values for layer 2:

```text
SAM AionUI add-on installed successfully.
Launcher: ~/.local/bin/sam-codex-acp
```

If you see `AionUI runtime was not found`, launch AionUI, open one conversation
with the built-in **Codex CLI** agent, then run the installer again. That step
downloads the ACP bridge.

## 2. Register in AionUI

Configure both entries under AionUI **Settings → Agents**. Leave key fields empty.

### SAM Codex — add a custom agent

| Field | Value |
| --- | --- |
| Name | `SAM Codex Agent` |
| Command | `~/.local/bin/sam-codex-acp` |

### SAM Claude — repoint the existing Claude Code agent

| Field | Value |
| --- | --- |
| Command override | `~/.local/bin/sam-claude` |
| `ANTHROPIC_BASE_URL` | `https://sam.soonsoon.ai/v2/claude` |
| `CLAUDE_CONFIG_DIR` | `~/.claude-sam` |
| `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY` | `1` |

Use absolute paths (`/Users/<username>/...`) in fields that do not expand `~`.

This repoint turns the AionUI Claude Code slot into a SAM-only agent. To keep an
official Anthropic login in the same app, leave Claude Code alone and add a
separate custom agent instead. The official terminal `claude` is never affected.

## 3. Verify the connection

Both entries should appear **online** in the Agents list. Open a new conversation
and check the model list.

- **SAM Codex Agent**: V2-native models selected on the Agent page plus
  authorized compatibility models, under their original names.
- **Claude Code**: Claude-family models returned by SAM discovery.

You can confirm the wrappers first with no generation cost:

```bash
sam-codex mcp list
sam-claude mcp list
```

## Real usage scenarios

### Working in a repository with SAM Codex

1. Open the working folder in AionUI and select **SAM Codex Agent** for a new
   conversation.
2. Pick a model. Use a flagship model for long coding sessions and a lighter one
   for quick fixes.
3. Leave Mode on **Agent** to edit files and run commands. Start in
   **Read-only** when you only need review.
4. Use `/review` to inspect changes before committing, and `/compact` when the
   conversation grows long.

To continue the same work in the terminal, run `sam-codex`. Configuration and
history stay separate from the app while using the same SAM account and key.

### Cross-checking one problem with two models

1. Implement the change in a **SAM Codex Agent** conversation.
2. Open a **Claude Code** (SAM Claude) conversation on the same folder and ask
   for a review of the changes.
3. Compare both results and apply the final fix from one side.

Both agents use the same `SAM_API_KEY`, so no extra key is issued or re-entered.

### Returning to the official environment

In the terminal, run `codex` and `claude` as usual. In AionUI, select the
built-in **Codex CLI** agent for official Codex. This add-on does not modify
that entry.

## Optional: model providers for AionUI chat

To use SAM models in ordinary AionUI chat instead of coding agents, add
providers under **Settings → Model Providers**.

| Name | Protocol | Base URL |
| --- | --- | --- |
| `SAM Claude` | Anthropic | `https://sam.soonsoon.ai/v2/anthropic` |
| `SAM Codex` | OpenAI | `https://sam.soonsoon.ai/openai/v1` |

The OpenAI provider uses `https://sam.soonsoon.ai/openai/v1`. The AionUI OpenAI
client requires an OpenAI-shaped model list, so using the V2 Codex surface
(`/v2/codex`) as a provider base URL fails protocol detection. Use the coding
agent path above for the full V2 catalog.

## Removal

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/04-AionUI-Add-on/uninstall-macos.sh)
```

This moves only the launcher created by the add-on to the Trash. It preserves
`sam-codex`, `sam-claude`, `~/.codex-sam`, `~/.claude-sam`, and the shared
`~/.sam/env` key.

Revert the AionUI side in the app: delete the custom **SAM Codex Agent**, then
clear the command override and environment variables on **Claude Code**.

## Security and cost

- This add-on stores no key. Authentication is handled by the wrappers through
  the shared `~/.sam/env`.
- Do not paste key values into AionUI agent settings. They are not required.
- The launcher is created with `700` permissions so only the owner can run it.
- Listing models and `mcp list` do not generate model output. SAM usage and cost
  can start when a conversation returns a real response.
- After rotating the key, restart running AionUI conversations and terminal
  sessions so they read the new key.

## Troubleshooting

| Symptom | Cause | Action |
| --- | --- | --- |
| `AionUI runtime was not found` | ACP bridge missing | Open one built-in Codex CLI conversation, then rerun |
| Agent shows `offline` | Wrong launcher path | Confirm the Command field uses an absolute path |
| `SAM_API_KEY is missing` | No shared key | Store the key with [`00-sam-setup/`](../00-sam-setup/README.en.md) |
| Empty model list | Insufficient key grants | Verify authorized discovery first |
| Provider protocol detection fails | Wrong base URL | Use `/openai/v1` for the OpenAI provider |

For wrapper-level problems, see the matching document.

- Codex: [`02-Code-Agent-Codex/TROUBLESHOOTING.md`](../02-Code-Agent-Codex/TROUBLESHOOTING.md)
- Claude: [`03-Code-Agent-Claude/TROUBLESHOOTING.md`](../03-Code-Agent-Claude/TROUBLESHOOTING.md)
