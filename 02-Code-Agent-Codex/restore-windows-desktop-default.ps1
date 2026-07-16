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

if ($Manifest.PSObject.Properties.Name -contains "had_user_sam_api_key") {
    if (-not [bool]$Manifest.had_user_sam_api_key) {
        [Environment]::SetEnvironmentVariable("SAM_CODE_API_KEY", $null, "User")
        Remove-Item Env:SAM_CODE_API_KEY -ErrorAction SilentlyContinue
        Write-Host "Removed the SAM_CODE_API_KEY user environment variable created for the desktop switch."
    }
    else {
        Write-Host "An existing SAM_CODE_API_KEY user environment variable was present before the switch, so it was left unchanged."
    }
}
else {
    Write-Host "Legacy desktop-switch manifest detected; SAM_CODE_API_KEY user environment variable was left unchanged."
}

Write-Host ""
Write-Host "Close every ChatGPT/Codex desktop window, then reopen the desktop app."
