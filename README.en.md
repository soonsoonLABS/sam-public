# SAM Public

**Language:** [한국어](README.md) | English

Public guides and installers for using SAM (SoonSoon AI Management) from local
coding-agent CLIs. The core rule is simple: **leave the official CLIs unchanged
and add separate SAM-only commands**.

## Recommended order

1. Use [`00-sam-setup/`](00-sam-setup/README.en.md) to test SAM connectivity
   and the shared API key with no-generation discovery requests.
2. Use [`02-Code-Agent-Codex/`](02-Code-Agent-Codex/README.en.md) to add
   `sam-codex` alongside the existing `codex` command.
3. Use [`03-Code-Agent-Claude/`](03-Code-Agent-Claude/README.en.md) to add
   `sam-claude` alongside the existing `claude` command.
4. Optionally use [`04-AionUI-Add-on/`](04-AionUI-Add-on/README.en.md) to
   register both wrappers as coding agents in the AionUI app.
5. Remove either wrapper independently. Delete the shared key file only after
   both wrappers are no longer needed.

## Command and configuration isolation

| Command | Destination | Local configuration | Authentication |
| --- | --- | --- | --- |
| `codex` | OpenAI / ChatGPT | `~/.codex` | Existing OpenAI login or key |
| `sam-codex` | SAM V2 OpenAI | `~/.codex-sam` | Shared `SAM_API_KEY` |
| `claude` | Anthropic | `~/.claude` | Existing Anthropic login or key |
| `sam-claude` | SAM V2 Anthropic | `~/.claude-sam` | The same `SAM_API_KEY` |

The standard local key location is `~/.sam/`. Both wrappers read the same key
from that folder. Removing one wrapper does not delete the key, so the other
wrapper keeps working.

## Documentation

- [`00-sam-setup/`](00-sam-setup/README.en.md): environment, network,
  shared-key, and grant checks
- [`01-sam-skills/`](01-sam-skills/README.en.md): operating guidance for AI
  agents using the SAM API
- [`02-Code-Agent-Codex/`](02-Code-Agent-Codex/README.en.md): official Codex
  versus `sam-codex`, including installation, verification, and removal
- [`03-Code-Agent-Claude/`](03-Code-Agent-Claude/README.en.md): official Claude
  Code versus `sam-claude`, including installation, verification, and removal
- [`04-AionUI-Add-on/`](04-AionUI-Add-on/README.en.md): register both installed
  wrappers as coding agents in the AionUI desktop app (optional)

## Security and cost

- Never paste key values into Git-tracked files, documentation, issues, URLs,
  screenshots, or command history.
- `/health` and model discovery do not generate model output and do not create
  model usage.
- Real generation tests such as `sam-codex exec ...` and `sam-claude -p ...`
  may create SAM usage and cost.
- Traffic from the official `codex` and `claude` commands does not pass through
  SAM and is not included in SAM usage.
