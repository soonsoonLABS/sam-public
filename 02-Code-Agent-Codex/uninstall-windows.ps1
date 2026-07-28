$ErrorActionPreference = "Stop"

$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"

Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir "sam-codex.ps1")
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir "sam-codex.cmd")
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CodexSamHome "config.toml")

if ((Test-Path $CodexSamHome) -and -not (Get-ChildItem -Force $CodexSamHome)) {
    Remove-Item -Force $CodexSamHome
    Write-Host "Removed the empty SAM-Codex home."
}
elseif (Test-Path $CodexSamHome) {
    Write-Host "Preserved existing SAM-Codex session data in $CodexSamHome."
}

Write-Host "Removed sam-codex. Official codex and the shared SAM key were not changed."
