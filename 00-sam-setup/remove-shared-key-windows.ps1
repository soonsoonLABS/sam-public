$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam"
$BinDir = Join-Path $HOME "bin"
$CodexRunner = Join-Path $BinDir "sam-codex.ps1"
$ClaudeRunner = Join-Path $BinDir "sam-claude.ps1"

if ((Test-Path $CodexRunner) -or (Test-Path $ClaudeRunner)) {
    Write-Host "A SAM wrapper is still installed in $BinDir."
    Write-Host "Remove both wrappers before deleting their shared key."
    exit 1
}

Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $SamHome "env.ps1")
Remove-Item -Force -ErrorAction SilentlyContinue Env:SAM_API_KEY

if ((Test-Path $SamHome) -and -not (Get-ChildItem -Force $SamHome)) {
    Remove-Item -Force $SamHome
}

Write-Host "Removed the installed shared SAM key file."
