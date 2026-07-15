# SAM Code Agent

**Language:** English | [한국어](README.ko.md)

Run Codex through SAM with one dedicated command: `sam-codex`.

This installer keeps SAM isolated from your usual ChatGPT/Codex profile. It
does not replace the normal `codex` command. Use `sam-codex` whenever you want
a SAM-backed coding session, and keep using plain `codex` for your usual setup.

## What you get

- A dedicated `sam-codex` terminal command using `sam-codex-agent`.
- A local SAM key file that is loaded only for SAM sessions.
- Separate SAM configuration, so normal Codex settings cannot take over.
- A direct SAM API test and a separate Codex smoke test for faster diagnosis.
- Optional desktop shortcuts for macOS and Windows.

## Before you begin

Install these shared prerequisites before cloning this repository:

1. Git
2. Node.js LTS (includes npm)
3. Codex CLI

The platform guides provide the exact commands and recovery steps when PATH or
PowerShell policy blocks `codex`.

## Choose your platform

- [macOS: setup, key management, tests, and shortcut](docs/macos.md)
- [Windows: setup, key management, tests, and shortcut](docs/windows.md)
- [macOS 한국어 가이드](docs/ko/macos.md)
- [Windows 한국어 가이드](docs/ko/windows.md)

## Everyday use

```text
sam-codex
```

It opens the Codex terminal UI with the SAM provider, `sam-codex-agent`, and
the locally stored SAM API key. Use `sam-codex exec ...` for non-interactive
commands. Do not use plain `codex` when you intend a SAM session.

## How it stays separate

The installer keeps SAM separate from the normal Codex home:

- `~/.codex-sam/config.toml`: SAM provider and model configuration.
- `~/.sam-code-agent/env` (macOS) or `~/.sam-code-agent/env.ps1` (Windows):
  local SAM API key file.
- `sam-codex`: dedicated wrapper that loads the key and sets
  `CODEX_HOME=~/.codex-sam` for that process only.

The wrapper also passes the SAM provider settings directly to Codex, so a
normal `~/.codex/config.toml` profile cannot silently take over the session.

## API key safety

Create a SAM key whose owner has `agent:codex` or `agent:coding_agents`
permission. The guides use the installer prompt to store it locally; never put
a real key in Git, documentation, screenshots, a shell history command, or a
project `.env` file.

The direct API test in each guide verifies the key, network route, and
`/openai/v1/responses` independently of Codex. The separate CLI smoke test then
verifies the `sam-codex` wrapper and Codex configuration.

## Desktop app note

The dedicated and reliable SAM path is the terminal command `sam-codex`.
`sam-codex app` can launch the ChatGPT desktop app on macOS, but the desktop
app is not a separate per-launch SAM profile. On Windows, use the optional
desktop switcher only after the CLI test succeeds; it temporarily replaces the
normal user-level Codex profile and must be restored when no longer needed.

## Current scope

This directory targets Codex. Claude Code and MCP setup will be published as
separate guides after their installation paths are stable.
