# SAM Code Agent

`code-agent/` contains public installers and guides for using SAM-backed
models with Codex. The installer creates a dedicated `sam-codex` command; it
does not replace the normal `codex` command or require changing your everyday
ChatGPT/Codex profile.

## Start here

1. Install the shared prerequisites: Git, Node.js LTS (includes npm), and the
   Codex CLI.
2. Follow exactly one operating-system guide:
   - [macOS setup, key management, testing, and shortcut](docs/macos.md)
   - [Windows setup, key management, testing, and shortcut](docs/windows.md)
3. Run the guided `sam-codex exec` smoke test.

The intended daily command is:

```text
sam-codex
```

It opens the Codex terminal UI with the SAM provider, `sam-codex-agent`, and
the locally stored SAM API key. Use `sam-codex exec ...` for non-interactive
commands. Do not use plain `codex` when you intend a SAM session.

## What the installer changes

The installer keeps SAM separate from the normal Codex home:

- `~/.codex-sam/config.toml`: SAM provider and model configuration.
- `~/.sam-code-agent/env` (macOS) or `~/.sam-code-agent/env.ps1` (Windows):
  local SAM API key file.
- `sam-codex`: dedicated wrapper that loads the key and sets
  `CODEX_HOME=~/.codex-sam` for that process only.

The wrapper also passes the SAM provider settings directly to Codex, so a
normal `~/.codex/config.toml` profile cannot silently take over the session.

## Key safety

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
