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

Use `sam-codex`, not `codex`, for SAM sessions on Windows. The wrapper loads
`SAM_API_KEY` from `~\.sam-code-agent\env.ps1` into the current PowerShell
process before launching Codex with `CODEX_HOME=~\.codex-sam`. It also passes
the SAM provider settings as command-line overrides so the normal
`~\.codex\config.toml` profile cannot silently take over.

To open the interactive terminal UI with the SAM profile:

```powershell
sam-codex
```

If the command is not visible in the current terminal, open a new PowerShell
window or run:

```powershell
& "$HOME\bin\sam-codex.ps1" exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

Interactive terminal fallback:

```powershell
& "$HOME\bin\sam-codex.ps1"
```

## What It Installs

- `~/.codex-sam/config.toml`: Codex config that points to SAM.
- `~/.sam-code-agent/env`: local SAM API key file for macOS/Linux shells.
- `~/.sam-code-agent/env.ps1`: local SAM API key file for Windows PowerShell.
- `sam-codex`: wrapper command that launches Codex with the SAM config.

The default model is `sam-codex-agent`.

The SAM profile uses a separate `CODEX_HOME`, so existing ChatGPT/Codex account
sessions are not merged into the SAM profile.

On Windows, the separate SAM profile is currently intended for Codex CLI and
the interactive terminal UI. `sam-codex app` may start the ChatGPT desktop app
installer if the Codex CLI cannot detect the installed desktop app, and the
Windows desktop app normally uses `%USERPROFILE%\.codex` rather than the
wrapper's temporary `CODEX_HOME`.

### Windows Desktop Switcher

After `sam-codex exec` works, you can temporarily switch the Windows desktop
app's default Codex profile to SAM:

```powershell
cd sam-public\code-agent
powershell -ExecutionPolicy Bypass -File .\enable-windows-desktop-sam.ps1
```

Then fully quit and reopen the ChatGPT/Codex desktop app. The model selector
should use `sam-codex-agent`.

To restore the previous desktop profile:

```powershell
cd sam-public\code-agent
powershell -ExecutionPolicy Bypass -File .\restore-windows-desktop-default.ps1
```

The switcher backs up `%USERPROFILE%\.codex\config.toml` before writing the SAM
profile. It also stores `SAM_API_KEY` as a Windows user environment variable so
the desktop app can read it when launched outside the terminal.

## Troubleshooting

### `Missing environment variable`

If you run `codex exec` directly, Codex reads `env_key = "SAM_API_KEY"` from the
config and looks for a real process environment variable named `SAM_API_KEY`.
It does not automatically load `~/.codex/.env`.

Use the wrapper instead:

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

On Windows:

```powershell
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

### `sam-codex` is not found

Open a new terminal after installation. If it is still not found, run the
wrapper by full path:

```bash
~/.local/bin/sam-codex app
```

On Windows:

```powershell
& "$HOME\bin\sam-codex.ps1"
```

### Windows `sam-codex app` downloads the installer

Use `sam-codex` or `sam-codex exec` for the separate CLI profile. To use the
Windows desktop app with SAM, run the desktop switcher above. The `sam-codex
app` launch path is controlled by Codex and may fall back to the installer even
when the app is already present.

```powershell
sam-codex
```

### Windows still shows `gpt-5.5 minimal`

Reinstall the wrapper so it can pass the SAM provider settings directly to
Codex:

```powershell
cd sam-public\code-agent
git pull
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
sam-codex
```

The top of the Codex screen should show `sam-codex-agent`.

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
