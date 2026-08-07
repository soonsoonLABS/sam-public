# SAM-Codex Windows setup and verification

[Back to quick start](./README.en.md) · [한국어](./WINDOWS_SETUP.md)

This guide installs `sam-codex` beside the official `codex` in Windows
PowerShell.

| Command | Connection | Configuration home |
| --- | --- | --- |
| `codex` | Direct OpenAI / ChatGPT | `%USERPROFILE%\.codex` |
| `sam-codex` | SAM V2 + SAM MCP | `%USERPROFILE%\.codex-sam` |

The official `codex`, `%USERPROFILE%\.codex`, and OpenAI login remain untouched.
The shared key is kept only in `%USERPROFILE%\.sam\env.ps1`.

## PowerShell syntax

- PowerShell may alias `curl` to `Invoke-WebRequest`; use
  `Invoke-RestMethod`/`Invoke-WebRequest`, or call `curl.exe` explicitly.
- Use the PowerShell backtick `` ` `` instead of Unix `\` line continuation.
- Read the key as `$env:SAM_API_KEY`, not `$SAM_API_KEY`.
- Never print the key, its length/prefix, or the key file.

## 1. Prepare the official Codex CLI

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
npm install -g @openai/codex
codex --version
```

Use the latest official Codex CLI. `sam-codex` reads its semantic version and
sends it to SAM discovery as metadata, then uses only the authenticated SAM
catalog. A malformed catalog or client-version mismatch still fails closed.

## 2. Recommended: run the Windows installer

Download the public repository first so the installer has its templates and
skill files beside it. If Git is unavailable, download the repository ZIP and
use the extracted directory instead.

```powershell
$PublicRoot = Join-Path $HOME "sam-public"
if (-not (Test-Path (Join-Path $PublicRoot ".git"))) {
  git clone https://github.com/soonsoonLABS/sam-public.git $PublicRoot
}
Set-Location (Join-Path $PublicRoot "02-Code-Agent-Codex")
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Enter the `SAM API key` at the hidden prompt. An existing
`%USERPROFILE%\.sam\env.ps1` is reused. Open a new PowerShell window after
installation so the user PATH is refreshed.

## 3. No-generation verification

```powershell
Get-Command sam-codex
sam-codex --version
sam-codex mcp list
```

Check that the wrapper is under `%USERPROFILE%\bin`, discovery succeeds, and
`sam-tools` points to `https://sam.soonsoon.ai/mcp`. The model list comes from
authenticated SAM discovery and is not hardcoded in this guide.

## 4. Real conversation check (usage may be recorded)

Run from a test directory, not from your home directory:

```powershell
$TestProject = Join-Path $HOME "SAM-Codex-Test"
New-Item -ItemType Directory -Force $TestProject | Out-Null
Set-Location $TestProject

sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral `
  "Reply with exactly: SAM-CODEX-OK"
```

Confirm the exact response `SAM-CODEX-OK`. Open `/model` inside Codex to see the
native and certified compatibility models selected in SAM Web. The `OpenAI
Codex` title is expected; use the SAM provider/discovery result to distinguish
the SAM environment.

## 5. Manual setup without the installer

### 5.1 Standard key and folders

```powershell
$SamHome = Join-Path $HOME ".sam"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force -Path $SamHome, $CodexSamHome, $BinDir | Out-Null

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

### 5.2 Authenticated discovery

```powershell
$headers = @{ Authorization = "Bearer $env:SAM_API_KEY" }
$catalog = Invoke-RestMethod -TimeoutSec 20 `
  -Uri "https://sam.soonsoon.ai/v2/codex/models" -Headers $headers
$models = @($catalog.models | Where-Object {
  $_.visibility -eq "list" -and $_.supported_in_api -eq $true
})
if ($models.Count -lt 1) { throw "No SAM-Codex model is available." }
$models | Select-Object slug, display_name
$SelectedModel = [string]$models[0].slug
if ($SelectedModel -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
  throw "The discovered model ID is not safe."
}
```

This is a no-generation discovery call. Use only a returned model ID.

### 5.3 Config, wrapper, and command registration

```powershell
@"
model = "$SelectedModel"
model_provider = "sam"
model_catalog_json = "models_cache.json"
web_search = "disabled"
project_root_markers = [".git", ".sam-codex-root"]

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/codex"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
required = true
"@ | Set-Content (Join-Path $CodexSamHome "config.toml") -Encoding UTF8

$PublicRoot = Join-Path $HOME "sam-public"
$CodeRoot = Join-Path $PublicRoot "02-Code-Agent-Codex"
Copy-Item (Join-Path $CodeRoot "templates\sam-codex.ps1") `
  (Join-Path $BinDir "sam-codex.ps1") -Force
Set-Content (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII `
  -Value "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-codex.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($UserPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}
```

Open a new PowerShell window and repeat sections 3–4. Run `codex` for the
official environment.

## Remove SAM-Codex

```powershell
Set-Location (Join-Path $HOME "sam-public\02-Code-Agent-Codex")
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

The official `codex`, `%USERPROFILE%\.codex`, shared key, and `sam-claude` are
preserved. Remove the shared key only after both SAM wrappers are removed.

## Troubleshooting order

| Symptom | Check first |
| --- | --- |
| `curl` rejects `-sS` | Use PowerShell cmdlets or `curl.exe` |
| `sam-codex` not found | New PowerShell window and `%USERPROFILE%\bin` in user PATH |
| `401` | Dot-source `env.ps1` and check Agent grant |
| `404 Unknown model` | Do not enter an ID absent from discovery |
| MCP missing | URL and `SAM_API_KEY` environment-variable name in config |
| Discovery timeout | Separate network/SAM runtime from CLI configuration |

The current Windows installer repeat-install regression is tracked in public
Issue #23. If it appears, do not delete official folders or re-enter the key;
use this manual path and check the issue status first.
