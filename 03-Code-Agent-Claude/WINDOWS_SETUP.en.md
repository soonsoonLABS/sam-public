# SAM-Claude Windows setup and verification

[Back to quick start](./README.en.md) · [한국어](./WINDOWS_SETUP.md)

This guide installs `sam-claude` beside the official `claude` in Windows
PowerShell.

| Command | Connection | Configuration/session home |
| --- | --- | --- |
| `claude` | Direct Anthropic | `%USERPROFILE%\.claude` |
| `sam-claude` | SAM `/v2/claude` + SAM MCP | `%USERPROFILE%\.claude-sam` |

The official `claude`, `%USERPROFILE%\.claude`, login, and project settings
remain untouched. The shared key is read from `%USERPROFILE%\.sam\env.ps1`.

## PowerShell syntax

- PowerShell may alias `curl` to `Invoke-WebRequest`; use
  `Invoke-RestMethod`/`Invoke-WebRequest`, or call `curl.exe` explicitly.
- Use the PowerShell backtick `` ` `` instead of Unix `\` line continuation.
- Read the environment variable as `$env:SAM_API_KEY`, not `$SAM_API_KEY`.
- Never print the key, its length/prefix, or the key file.

## 1. Prepare official Claude Code

```powershell
claude --version
```

Claude Code `2.1.129` or later is required. Update through the
[official Anthropic setup guide](https://code.claude.com/docs/en/setup) when
needed, then open a new PowerShell window.

## 2. Recommended: run the Windows installer

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-windows.ps1')))
```

Enter the hidden `SAM API key` prompt. An existing
`%USERPROFILE%\.sam\env.ps1` is reused. The installer performs authenticated
`/v2/claude/v1/models` discovery and Haiku/Sonnet/Opus role validation without a
generation call. Open a new PowerShell window after installation.

## 3. No-generation verification

```powershell
Get-Command sam-claude
sam-claude --version
sam-claude mcp list
```

Confirm that the wrapper is under `%USERPROFILE%\bin`, discovery and role
mapping agree, and `sam-tools` points to `https://sam.soonsoon.ai/mcp`. Open
`/model` inside Claude Code and use only models returned by discovery, including
exact `claude-sam-*` compatibility IDs.

## 4. Real conversation check (usage may be recorded)

```powershell
$TestProject = Join-Path $HOME "SAM-Claude-Test"
New-Item -ItemType Directory -Force $TestProject | Out-Null
Set-Location $TestProject

sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

Confirm the exact response `SAM-CLAUDE-OK`. Use `sam-claude` for SAM and
`claude` to return to the official Anthropic environment.

## 5. Manual setup without the installer

### 5.1 Standard key and isolated folders

```powershell
$PublicRoot = Join-Path $HOME "sam-public"
$ClaudeRoot = Join-Path $PublicRoot "03-Code-Agent-Claude"
$SamHome = Join-Path $HOME ".sam"
$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$BinDir = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force -Path $SamHome, $ClaudeSamHome, $BinDir | Out-Null

$EnvFile = Join-Path $SamHome "env.ps1"
if (-not (Test-Path $EnvFile)) {
  $secure = Read-Host "SAM API key" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    $safeKey = $key.Replace("'", "''")
    Set-Content -Path $EnvFile -Encoding UTF8 `
      -Value "`$env:SAM_API_KEY = '$safeKey'"
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    Remove-Variable key, safeKey -ErrorAction SilentlyContinue
  }
  icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
}
. $EnvFile
if ([string]::IsNullOrWhiteSpace($env:SAM_API_KEY)) {
  throw "SAM_API_KEY was not loaded."
}
```

### 5.2 Wrapper preflight without generation

```powershell
$WrapperSource = Join-Path $ClaudeRoot "templates\sam-claude.ps1"
$StateTemp = Join-Path ([IO.Path]::GetTempPath()) (
  "sam-claude-state-{0}.json" -f [guid]::NewGuid().ToString("N")
)
$oldStatePath = $env:SAM_CLAUDE_STATE_PATH
$oldPreflight = $env:SAM_CLAUDE_PREFLIGHT_ONLY
try {
  $env:SAM_CLAUDE_STATE_PATH = $StateTemp
  $env:SAM_CLAUDE_PREFLIGHT_ONLY = "1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File $WrapperSource
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $StateTemp)) {
    throw "SAM-Claude discovery or role mapping validation failed."
  }
}
finally {
  $env:SAM_CLAUDE_STATE_PATH = $oldStatePath
  $env:SAM_CLAUDE_PREFLIGHT_ONLY = $oldPreflight
}
```

This compares `/v2/claude/v1/models` with the saved role mappings and does not
generate model output. Do not bypass a failure by entering an old model ID.

### 5.3 SAM MCP and command registration

```powershell
$env:CLAUDE_CONFIG_DIR = $ClaudeSamHome
claude mcp add --transport http --scope user `
  sam-tools "https://sam.soonsoon.ai/mcp" `
  --header 'Authorization: Bearer ${SAM_API_KEY}'

Copy-Item $WrapperSource (Join-Path $BinDir "sam-claude.ps1") -Force
Set-Content (Join-Path $BinDir "sam-claude.cmd") -Encoding ASCII `
  -Value "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-claude.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($UserPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}
Remove-Item $StateTemp -Force -ErrorAction SilentlyContinue
```

Open a new PowerShell window and repeat sections 3–4. Do not modify the
official `claude` MCP or `%USERPROFILE%\.claude`.

## Remove SAM-Claude

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1')))
```

To move isolated sessions and settings to the recovery directory:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1'))) -PurgeData
```

The official `claude`, `%USERPROFILE%\.claude`, shared key, and `sam-codex` are
preserved. Remove the shared key only after both SAM wrappers are removed.

## Troubleshooting order

| Symptom | Check first |
| --- | --- |
| `curl` rejects `-sS` | Use PowerShell cmdlets or `curl.exe` |
| `sam-claude` not found | New PowerShell window and `%USERPROFILE%\bin` in user PATH |
| `401` | Dot-source `env.ps1` and check `agent:claude_code` grant |
| Mapping error | Compare SAM Web role mappings with authenticated discovery |
| MCP missing | `CLAUDE_CONFIG_DIR` and the `SAM_API_KEY` variable reference |
| Discovery timeout | Separate network/SAM runtime from Claude CLI configuration |
