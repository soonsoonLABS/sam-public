param(
    [string]$SamApiKey = $env:SAM_API_KEY
)

$ErrorActionPreference = "Stop"
$DiscoveryUrl = "https://sam.soonsoon.ai/v2/anthropic/v1/models"
$SamHome = Join-Path $HOME ".sam"
$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$BinDir = Join-Path $HOME "bin"
$EnvFile = Join-Path $SamHome "env.ps1"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Claude Code is not on PATH. Follow https://code.claude.com/docs/en/setup first."
}

New-Item -ItemType Directory -Force -Path $SamHome, $ClaudeSamHome, $BinDir | Out-Null

if ([string]::IsNullOrWhiteSpace($SamApiKey) -and (Test-Path $EnvFile)) {
    . $EnvFile
    $SamApiKey = $env:SAM_API_KEY
}

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    $secure = Read-Host "Enter the shared SAM API key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $SamApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    throw "SAM_API_KEY is required."
}

try {
    $response = Invoke-RestMethod -TimeoutSec 20 `
        -Uri $DiscoveryUrl `
        -Headers @{ Authorization = "Bearer $SamApiKey" }
}
catch {
    throw "SAM Anthropic discovery failed. Fix the key/grant/runtime before installing. $($_.Exception.Message)"
}

$ModelIds = @($response.data | ForEach-Object { $_.id } | Where-Object { $_ })
$RequiredModels = @(
    "anthropic.claude-haiku-4-5",
    "anthropic.claude-sonnet-5",
    "anthropic.claude-opus-5"
)
$MissingModels = @($RequiredModels | Where-Object { $_ -notin $ModelIds })

if ($MissingModels.Count -gt 0) {
    throw "Required backing model(s) absent from authenticated discovery: $($MissingModels -join ', '). Check the SAM Claude role mapping."
}

$EscapedKey = $SamApiKey.Replace("'", "''")
Set-Content -Path $EnvFile -Encoding UTF8 -Value "`$env:SAM_API_KEY = '$EscapedKey'"
if (Get-Command icacls -ErrorAction SilentlyContinue) {
    & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
}

@'
{
  "model": "claude-sonnet-5"
}
'@ | Set-Content -Path (Join-Path $ClaudeSamHome "settings.json") -Encoding UTF8

$Runner = Join-Path $BinDir "sam-claude.ps1"
@'
$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam"
$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$EnvFile = Join-Path $SamHome "env.ps1"

if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile. Run the SAM installer first."
}

. $EnvFile

Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_OAUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_USE_BEDROCK -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_USE_VERTEX -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_USE_FOUNDRY -ErrorAction SilentlyContinue

$env:CLAUDE_CONFIG_DIR = $ClaudeSamHome
$env:ANTHROPIC_BASE_URL = "https://sam.soonsoon.ai/v2/anthropic"
$env:ANTHROPIC_AUTH_TOKEN = $env:SAM_API_KEY
$env:ANTHROPIC_MODEL = "claude-sonnet-5"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-5"
$env:ANTHROPIC_SMALL_FAST_MODEL = "claude-haiku"

New-Item -ItemType Directory -Force -Path $env:CLAUDE_CONFIG_DIR | Out-Null
& claude @args
exit $LASTEXITCODE
'@ | Set-Content -Path $Runner -Encoding UTF8

$CmdRunner = Join-Path $BinDir "sam-claude.cmd"
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\bin\sam-claude.ps1" %*
"@ | Set-Content -Path $CmdRunner -Encoding ASCII

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrWhiteSpace($UserPath)) {
    [Environment]::SetEnvironmentVariable("Path", $BinDir, "User")
}
elseif (($UserPath -split ';') -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}

Write-Host ""
Write-Host "SAM-Claude installed."
Write-Host "Config home: $ClaudeSamHome"
Write-Host "Command: $CmdRunner"
Write-Host "Open a new PowerShell window if sam-claude is not found."
Write-Host ""
Write-Host "Official Claude Code remains: claude"
Write-Host "SAM-Claude command:          sam-claude"
