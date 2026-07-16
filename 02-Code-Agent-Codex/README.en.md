# SAM Code Agent

**Language:** [한국어](README.md) | English

Run Codex through SAM with one dedicated command: `sam-codex`.

## Start with manual setup

Before using installer automation, verify the key, connection, isolated CLI,
and default-app switch/restore one step at a time through the manual guide.

- [Manual setup for macOS](MANUAL_SETUP.en.md)
- [macOS 수동 설정](MANUAL_SETUP.md)
- [Manual setup for Windows](MANUAL_SETUP_WINDOWS.en.md)
- [Windows 수동 설정](MANUAL_SETUP_WINDOWS.md)

## Installer automation

1. In SAM web, open **API Keys** and create a dedicated key named something
   like `Code Agent - my device`. Do not reuse a general service key.
2. Run the installer for your platform once and paste only that dedicated key
   into its hidden prompt. You do not need to create `.env` or `config.toml` by
   hand.
3. Use `sam-codex` from then on.

```text
sam-codex
```

The installer stores the key only under `~/.sam-code-agent/` on that device and
keeps Codex settings under `~/.codex-sam/`. To rotate a key, rerun the installer
and enter the new dedicated Code Agent key.

Code Agent uses only `SAM_CODE_API_KEY`. If you previously configured
`SAM_API_KEY`, rerun manual setup steps 2-5 or the installer once to update the
local key file.

## Two Codex modes

| Mode | Command | Config home | Use |
| --- | --- | --- | --- |
| Default Codex | `codex` or `codex app` | `~/.codex` | Your normal ChatGPT/Codex account and OpenAI configuration |
| SAM Codex CLI | `sam-codex` | `~/.codex-sam` | A terminal session using a SAM API key and `sam-codex-agent` |
| macOS SAM-Codex Desktop | `sam-codex-desktop` | `~/.codex-sam` plus separate Electron data | A separate SAM desktop window beside normal Codex |

The modes do not share a configuration file. `sam-codex` does not replace
plain `codex`; use it only when you want a SAM-backed session. On macOS,
`sam-codex-desktop` uses a separate Electron `user-data-dir` so it can run
beside the normal Codex/ChatGPT Desktop app. It detects either a standalone
`Codex.app` or a `ChatGPT.app` installation.

## What you get

- A dedicated `sam-codex` terminal command using `sam-codex-agent`.
- A local SAM key file that is loaded only for SAM sessions.
- Separate SAM configuration, so normal Codex settings cannot take over.
- A direct SAM API test and a separate Codex smoke test for faster diagnosis.
- Optional macOS side-by-side Desktop launcher and Windows profile switcher.

## Before you begin

Install these shared prerequisites before cloning this repository:

1. Git
2. Node.js LTS (includes npm)
3. Codex CLI

The platform guides provide the exact commands and recovery steps when PATH or
PowerShell policy blocks `codex`.

## Choose your platform

- [macOS: setup, key management, tests, and shortcut](docs/macos.en.md)
- [Windows: setup, key management, tests, and shortcut](docs/windows.en.md)
- [macOS 한국어 가이드](docs/macos.md)
- [Windows 한국어 가이드](docs/windows.md)

If you need to set up without cloning the installer repository, use the macOS
[manual setup](MANUAL_SETUP.en.md) or Windows
[manual setup](MANUAL_SETUP_WINDOWS.en.md).

## Everyday use

```text
codex                # Default Codex: ~/.codex
sam-codex            # SAM Codex CLI: ~/.codex-sam
sam-codex-desktop    # macOS only: separate Desktop window
```

`sam-codex` opens the Codex terminal UI with the SAM provider,
`sam-codex-agent`, and the locally stored SAM API key. Use `sam-codex exec
...` for non-interactive commands. Do not use plain `codex` when you intend a
SAM session.

## How it stays separate

The installer keeps SAM separate from the normal Codex home:

- `~/.codex-sam/config.toml`: SAM provider and model configuration.
- `~/.sam-code-agent/env` (macOS) or `~/.sam-code-agent/env.ps1` (Windows):
  local SAM API key file.
- `sam-codex`: dedicated wrapper that loads the key and sets
  `CODEX_HOME=~/.codex-sam` for that process only.
- `sam-codex-desktop` on macOS: Desktop launcher using `CODEX_HOME=~/.codex-sam`
  plus `~/Library/Application Support/SAM Codex Desktop` as a separate Electron
  data directory.

The wrapper also passes the SAM provider settings directly to Codex, so a
normal `~/.codex/config.toml` profile cannot silently take over the session.

## API key safety

Create a dedicated Code Agent SAM key whose owner has `agent:codex` or
`agent:coding_agents` permission. The guides use the installer prompt to store
it locally; never put a real key in Git, documentation, screenshots, a shell
history command, or a project `.env` file.

The direct API test in each guide verifies the key, network route, and
`/openai/v1/responses` independently of Codex. The separate CLI smoke test then
verifies the `sam-codex` wrapper and Codex configuration.

## Desktop app options

On macOS, use `sam-codex-desktop` to open a separate SAM-Codex Desktop window
while the normal Codex/ChatGPT Desktop remains available. This launcher uses a
separate Electron `user-data-dir` and depends on Codex Desktop launch arguments;
if it fails, diagnose with the CLI smoke test first.

The standard ChatGPT/Codex desktop app can also be **temporarily switched** to
the SAM provider through its `~/.codex` configuration. This is a provider swap,
not simultaneous account and SAM modes. Run the platform switcher only after
the `sam-codex` smoke test succeeds.

- macOS: [switch and restore the default desktop app](docs/macos.en.md#optional-temporarily-switch-the-default-macos-codex-desktop-mode-to-sam)
- Windows: [switch and restore the default desktop app](docs/windows.en.md#optional-temporarily-switch-the-default-windows-codex-desktop-mode-to-sam)

After switching, fully quit the app before reopening it. On macOS, the GUI
session key disappears after logout or reboot, so rerun the switch command
before opening the app. `sam-codex app` does not create a separate SAM-Codex app
or reliably switch the existing desktop provider; use `sam-codex-desktop` for a
separate macOS window.

## Current scope

This directory targets Codex. Claude Code and MCP setup will be published as
separate guides after their installation paths are stable.
