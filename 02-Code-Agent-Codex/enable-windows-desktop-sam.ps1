$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam-code-agent"
$EnvFile = Join-Path $SamHome "env.ps1"
$DefaultCodexHome = Join-Path $HOME ".codex"
$DefaultConfig = Join-Path $DefaultCodexHome "config.toml"
$BackupDir = Join-Path $SamHome "backups"
$ManifestFile = Join-Path $SamHome "desktop-switch.json"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Template = Join-Path $ScriptDir "templates\codex-config.toml"

if (-not (Test-Path $EnvFile)) {
    Write-Host "Missing $EnvFile. Run install-windows.ps1 first."
    exit 1
}

if (-not (Test-Path $Template)) {
    Write-Host "Missing $Template. Run this script from sam-public\02-Code-Agent-Codex."
    exit 1
}

. $EnvFile

if ([string]::IsNullOrWhiteSpace($env:SAM_API_KEY)) {
    Write-Host "SAM_API_KEY is empty. Re-run install-windows.ps1 and paste a valid SAM key."
    exit 1
}

$ExistingUserSamApiKey = [Environment]::GetEnvironmentVariable("SAM_API_KEY", "User")
if ($null -ne $ExistingUserSamApiKey -and $ExistingUserSamApiKey -ne $env:SAM_API_KEY) {
    Write-Host "A different SAM_API_KEY user environment variable already exists."
    Write-Host "The desktop switcher will not overwrite it. Use sam-codex for CLI sessions, or replace that key intentionally before retrying."
    exit 1
}

New-Item -ItemType Directory -Force -Path $DefaultCodexHome, $BackupDir | Out-Null

$HadConfig = Test-Path $DefaultConfig
$BackupPath = $null
$HasExistingManifest = $false
$HadUserSamApiKey = $null

if (Test-Path $ManifestFile) {
    try {
        $Existing = Get-Content -Raw -Path $ManifestFile | ConvertFrom-Json
        $HasExistingManifest = $true
        $HadConfig = [bool]$Existing.had_config
        if ($Existing.backup_path) {
            $BackupPath = [string]$Existing.backup_path
        }
        if ($Existing.PSObject.Properties.Name -contains "had_user_sam_api_key") {
            $HadUserSamApiKey = [bool]$Existing.had_user_sam_api_key
        }
    }
    catch {
        $HasExistingManifest = $false
        $BackupPath = $null
    }
}

if (-not $HasExistingManifest -and [string]::IsNullOrWhiteSpace($BackupPath)) {
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if ($HadConfig) {
        $BackupPath = Join-Path $BackupDir "config.toml.$Stamp.bak"
        Copy-Item -Force -Path $DefaultConfig -Destination $BackupPath
    }

    $HadUserSamApiKey = $null -ne [Environment]::GetEnvironmentVariable("SAM_API_KEY", "User")
}

Copy-Item -Force -Path $Template -Destination $DefaultConfig

[Environment]::SetEnvironmentVariable("SAM_API_KEY", $env:SAM_API_KEY, "User")
$env:SAM_API_KEY = $env:SAM_API_KEY

$Manifest = [ordered]@{
    enabled_at = (Get-Date).ToString("o")
    default_config = $DefaultConfig
    had_config = $HadConfig
    backup_path = $BackupPath
}

if ($null -ne $HadUserSamApiKey) {
    $Manifest.had_user_sam_api_key = $HadUserSamApiKey
}

$Manifest | ConvertTo-Json | Set-Content -Path $ManifestFile -Encoding UTF8

Write-Host "Windows desktop Codex profile switched to SAM."
Write-Host "Config: $DefaultConfig"
if ($BackupPath) {
    Write-Host "Backup: $BackupPath"
}
else {
    Write-Host "Backup: none; there was no existing config.toml."
}
Write-Host ""
Write-Host "Close every ChatGPT/Codex desktop window, then reopen the desktop app."
Write-Host "To restore the previous profile, run:"
Write-Host "powershell -ExecutionPolicy Bypass -File .\restore-windows-desktop-default.ps1"
