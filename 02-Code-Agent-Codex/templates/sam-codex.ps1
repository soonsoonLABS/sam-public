$ErrorActionPreference = "Stop"

$SamHome = if ($env:SAM_HOME) { $env:SAM_HOME } else { Join-Path $HOME ".sam" }
$CodexSamHome = if ($env:CODEX_SAM_HOME) { $env:CODEX_SAM_HOME } else { Join-Path $HOME ".codex-sam" }
$EnvFile = Join-Path $SamHome "env.ps1"

if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile. Run install-windows.ps1 first."
}

. $EnvFile
if ([string]::IsNullOrWhiteSpace($env:SAM_CODEX_API)) {
    throw "SAM_CODEX_API is not set in $EnvFile."
}

$env:CODEX_HOME = $CodexSamHome
& codex @args
exit $LASTEXITCODE
