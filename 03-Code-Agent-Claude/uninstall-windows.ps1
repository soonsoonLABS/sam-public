$ErrorActionPreference = "Stop"

$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$BinDir = Join-Path $HOME "bin"

Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir "sam-claude.ps1")
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir "sam-claude.cmd")

Write-Host "Removed sam-claude."
Write-Host "Official claude, the shared SAM key, and sessions in $ClaudeSamHome were not changed."
