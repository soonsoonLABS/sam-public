# SAM Code Agent

`code-agent/` contains public tools, installers, and documentation for using
SAM-backed models with coding agents such as Codex and Claude Code.

## Quick Install

The first public installer configures Codex with a separate SAM profile. It
does not overwrite your normal `~/.codex` account data.

### macOS

```bash
git clone https://github.com/soonsoonLABS/sam-public.git
cd sam-public/code-agent
bash install-macos.sh
```

After installation:

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

To open Codex Desktop with the SAM profile:

```bash
sam-codex app
```

If `sam-codex` is not found, run it once with the full path:

```bash
~/.local/bin/sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

Desktop fallback:

```bash
~/.local/bin/sam-codex app
```

### Windows PowerShell

```powershell
git clone https://github.com/soonsoonLABS/sam-public.git
cd sam-public\code-agent
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

After installation:

```powershell
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

To open Codex Desktop with the SAM profile:

```powershell
sam-codex app
```

If the command is not visible in the current terminal, open a new PowerShell
window or run:

```powershell
& "$HOME\bin\sam-codex.ps1" exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

Desktop fallback:

```powershell
& "$HOME\bin\sam-codex.ps1" app
```

## What It Installs

- `~/.codex-sam/config.toml`: Codex config that points to SAM.
- `~/.sam-code-agent/env`: local SAM API key file for macOS/Linux shells.
- `~/.sam-code-agent/env.ps1`: local SAM API key file for Windows PowerShell.
- `sam-codex`: wrapper command that launches Codex with the SAM config.

The default model is `sam-codex-agent`.

The SAM profile uses a separate `CODEX_HOME`, so existing ChatGPT/Codex account
sessions are not merged into the SAM profile.

## Current Scope

This first installer targets Codex. Claude Code and MCP tool setup will be
added as separate, explicit steps after the Codex path is stable.

This directory publishes:

- cross-platform setup and diagnostics for supported coding agents
- safe configuration examples for SAM API connections
- MCP tool connection guides
- release notes and troubleshooting documentation

It intentionally does not contain SAM server code, production configuration,
or credentials.
