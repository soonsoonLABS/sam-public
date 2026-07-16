# Manual SAM Codex setup (Windows)

**Language:** [한국어](MANUAL_SETUP_WINDOWS.md) | English

This is the baseline Windows PowerShell setup without the installer. It keeps
normal Codex in `%USERPROFILE%\.codex` and runs SAM Codex from
`%USERPROFILE%\.codex-sam` with `SAM_CODE_API_KEY`.

## 1. Prepare a dedicated Code Agent key

Create a dedicated key in SAM web under **API Keys**, named something like
`Code Agent - Windows`. The key owner needs `agent:codex` or
`agent:coding_agents` permission.

## 2. Enter the key in the current PowerShell

The key stays hidden and is not saved to disk yet.

```powershell
$secure = Read-Host "Enter SAM Code Agent key" -AsSecureString
$env:SAM_CODE_API_KEY = (New-Object PSCredential "sam", $secure).GetNetworkCredential().Password
```

Check status without printing the full key:

```powershell
"loaded=" + (-not [string]::IsNullOrWhiteSpace($env:SAM_CODE_API_KEY))
"length=" + $env:SAM_CODE_API_KEY.Length
"prefix=" + $env:SAM_CODE_API_KEY.Substring(0, [Math]::Min(4, $env:SAM_CODE_API_KEY.Length))
```

## 3. Test the key

Verify the SAM route before involving Codex. The final output should be
`SAM-CODEX-OK`.

```powershell
$body = @{
  model = "sam-codex-agent"
  input = "Reply with exactly: SAM-CODEX-OK"
  stream = $false
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/openai/v1/responses" `
  -Headers @{ Authorization = "Bearer $env:SAM_CODE_API_KEY" } `
  -ContentType "application/json" `
  -Body $body

$response.output_text
```

## 4. Save only the verified key

```powershell
$SamHome = Join-Path $HOME ".sam-code-agent"
New-Item -ItemType Directory -Force -Path $SamHome | Out-Null
$EnvFile = Join-Path $SamHome "env.ps1"
Set-Content -Path $EnvFile -Encoding UTF8 -Value "`$env:SAM_CODE_API_KEY = '$env:SAM_CODE_API_KEY'"
icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
Remove-Item Env:SAM_CODE_API_KEY -ErrorAction SilentlyContinue
```

## 5. Install Codex CLI

```powershell
winget install -e --id OpenJS.NodeJS.LTS
```

Close PowerShell completely, open a new window, then run:

```powershell
node --version
npm --version
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
npm install -g @openai/codex@latest
codex --version
```

## 6. Create isolated SAM Codex config

```powershell
$CodexSamHome = Join-Path $HOME ".codex-sam"
New-Item -ItemType Directory -Force -Path $CodexSamHome | Out-Null

@'
model = "sam-codex-agent"
model_provider = "sam"
model_reasoning_effort = "medium"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/openai/v1"
env_key = "SAM_CODE_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
'@ | Set-Content -Path (Join-Path $CodexSamHome "config.toml") -Encoding UTF8
```

## 7. Create `sam-codex` without cloning the repository

```powershell
$BinDir = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

@'
$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam-code-agent"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$EnvFile = Join-Path $SamHome "env.ps1"
$WorkDir = Join-Path $env:TEMP "sam-codex-cli"

if (-not (Test-Path $EnvFile)) {
    Write-Host "Missing $EnvFile. Create your SAM Code Agent key file first."
    exit 1
}

. $EnvFile
$env:CODEX_HOME = $CodexSamHome
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Set-Location $WorkDir

$SamCodexConfig = @(
    "-c", "model=`"sam-codex-agent`"",
    "-c", "model_provider=`"sam`"",
    "-c", "model_reasoning_effort=`"medium`"",
    "-c", "model_providers.sam.name=`"SAM`"",
    "-c", "model_providers.sam.base_url=`"https://sam.soonsoon.ai/openai/v1`"",
    "-c", "model_providers.sam.env_key=`"SAM_CODE_API_KEY`"",
    "-c", "model_providers.sam.wire_api=`"responses`"",
    "-c", "model_providers.sam.request_max_retries=4",
    "-c", "model_providers.sam.stream_max_retries=5",
    "-c", "model_providers.sam.stream_idle_timeout_ms=300000"
)

& codex @SamCodexConfig @args
exit $LASTEXITCODE
'@ | Set-Content -Path (Join-Path $BinDir "sam-codex.ps1") -Encoding UTF8

@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\bin\sam-codex.ps1" %*
"@ | Set-Content -Path (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII
```

Add `%USERPROFILE%\bin` to PATH:

```powershell
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}
$env:Path += ";$BinDir"
```

## 8. Verify

```powershell
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

The header should show `model: sam-codex-agent` and `provider: sam`, and the
reply should be `SAM-CODEX-OK`. Open the interactive CLI with:

```powershell
sam-codex
```

