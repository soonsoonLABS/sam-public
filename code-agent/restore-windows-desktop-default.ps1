$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam-code-agent"
$ManifestFile = Join-Path $SamHome "desktop-switch.json"
$DefaultCodexHome = Join-Path $HOME ".codex"
$DefaultConfig = Join-Path $DefaultCodexHome "config.toml"

if (-not (Test-Path $ManifestFile)) {
    Write-Host "No desktop switch manifest found. Nothing to restore."
    exit 0
}

$Manifest = Get-Content -Raw -Path $ManifestFile | ConvertFrom-Json
$HadConfig = [bool]$Manifest.had_config
$BackupPath = [string]$Manifest.backup_path

if ($HadConfig) {
    if ([string]::IsNullOrWhiteSpace($BackupPath) -or -not (Test-Path $BackupPath)) {
        Write-Host "Backup config was expected but not found: $BackupPath"
        exit 1
    }

    New-Item -ItemType Directory -Force -Path $DefaultCodexHome | Out-Null
    Copy-Item -Force -Path $BackupPath -Destination $DefaultConfig
    Write-Host "Restored previous Codex desktop config:"
    Write-Host $DefaultConfig
}
else {
    if (Test-Path $DefaultConfig) {
        Remove-Item -Force -Path $DefaultConfig
    }
    Write-Host "Removed SAM desktop config. No previous config.toml existed."
}

Remove-Item -Force -Path $ManifestFile

Write-Host ""
Write-Host "Close every ChatGPT/Codex desktop window, then reopen the desktop app."
