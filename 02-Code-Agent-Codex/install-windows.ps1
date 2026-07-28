param(
    [string]$SamApiKey = $env:SAM_API_KEY
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SamHome = Join-Path $HOME ".sam"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"
$SkillSource = Join-Path $ScriptDir "..\01-sam-skills\sam\SKILL.md"
$DiscoveryUrl = "https://sam.soonsoon.ai/v2/openai/models"
$EnvFile = Join-Path $SamHome "env.ps1"

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is not on PATH. Install it first, then run: codex --version"
}

New-Item -ItemType Directory -Force -Path `
    $SamHome, `
    $CodexSamHome, `
    $BinDir, `
    (Join-Path $SamHome "skills\sam"), `
    (Join-Path $CodexSamHome "skills\sam") | Out-Null

if ([string]::IsNullOrWhiteSpace($SamApiKey) -and (Test-Path $EnvFile)) {
    . $EnvFile
    $SamApiKey = $env:SAM_API_KEY
}

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    $secure = Read-Host "Shared SAM API key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $SamApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$SamApiKey = $SamApiKey.Trim()
if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    throw "SAM_API_KEY is required."
}

try {
    $Discovery = Invoke-RestMethod -TimeoutSec 20 `
        -Uri $DiscoveryUrl `
        -Headers @{ Authorization = "Bearer $SamApiKey" }
}
catch {
    throw "SAM OpenAI discovery failed. Fix the key, grant, or runtime before installing. $($_.Exception.Message)"
}

$ModelIds = @($Discovery.models | ForEach-Object { $_.slug } | Where-Object { $_ })
if ("azure.gpt-5.6-luna" -notin $ModelIds) {
    throw "The stable default azure.gpt-5.6-luna is not admitted for this key."
}

$SafeKey = $SamApiKey.Replace("'", "''")
Set-Content -Path $EnvFile -Encoding UTF8 -Value "`$env:SAM_API_KEY = '$SafeKey'"
if (Get-Command icacls -ErrorAction SilentlyContinue) {
    & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
}

Copy-Item -Force (Join-Path $ScriptDir "templates\codex-config.toml") (Join-Path $CodexSamHome "config.toml")
Copy-Item -Force $SkillSource (Join-Path $SamHome "skills\sam\SKILL.md")
Copy-Item -Force $SkillSource (Join-Path $CodexSamHome "skills\sam\SKILL.md")
Copy-Item -Force (Join-Path $ScriptDir "templates\sam-codex.ps1") (Join-Path $BinDir "sam-codex.ps1")
Set-Content -Path (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII `
    -Value "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-codex.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrWhiteSpace($UserPath)) {
    [Environment]::SetEnvironmentVariable("Path", $BinDir, "User")
}
elseif (($UserPath -split ';') -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}

Write-Host "SAM-Codex is ready. Open a new PowerShell window, then run: sam-codex"
Write-Host "Official Codex remains available as: codex"
