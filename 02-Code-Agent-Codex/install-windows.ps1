param(
    [string]$SamCodexApi = $env:SAM_CODEX_API
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SamHome = Join-Path $HOME ".sam"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"
$SkillSource = Join-Path $ScriptDir "..\01-sam-skills\sam\SKILL.md"

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI was not found on PATH. Install Codex first, then run: codex --version"
}

if ([string]::IsNullOrWhiteSpace($SamCodexApi)) {
    $secure = Read-Host "SAM Code Agent API key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $SamCodexApi = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$SamCodexApi = $SamCodexApi.Trim()
if ([string]::IsNullOrWhiteSpace($SamCodexApi)) { throw "A SAM Code Agent API key is required." }

New-Item -ItemType Directory -Force -Path $SamHome, $CodexSamHome, $BinDir, (Join-Path $SamHome "skills\sam"), (Join-Path $CodexSamHome "skills\sam") | Out-Null
$safeKey = $SamCodexApi.Replace("'", "''")
$EnvFile = Join-Path $SamHome "env.ps1"
Set-Content -Path $EnvFile -Encoding UTF8 -Value "`$env:SAM_CODEX_API = '$safeKey'`r`n`$env:SAM_API_KEY = `$env:SAM_CODEX_API"
if (Get-Command icacls -ErrorAction SilentlyContinue) { & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null }

Copy-Item -Force (Join-Path $ScriptDir "templates\codex-config.toml") (Join-Path $CodexSamHome "config.toml")
Copy-Item -Force $SkillSource (Join-Path $SamHome "skills\sam\SKILL.md")
Copy-Item -Force $SkillSource (Join-Path $CodexSamHome "skills\sam\SKILL.md")
Copy-Item -Force (Join-Path $ScriptDir "templates\sam-codex.ps1") (Join-Path $BinDir "sam-codex.ps1")
Set-Content -Path (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII -Value "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-codex.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinDir*") { [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User") }

Write-Host "SAM Codex CLI is ready. Open a new PowerShell window, then run: sam-codex"
