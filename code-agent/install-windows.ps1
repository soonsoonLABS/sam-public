param(
    [string]$SamApiKey = $env:SAM_API_KEY
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host "Codex CLI was not found on PATH."
    Write-Host "Install Codex first, then rerun this installer."
    exit 1
}

$SamHome = Join-Path $HOME ".sam-code-agent"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

New-Item -ItemType Directory -Force -Path $SamHome, $CodexSamHome, $BinDir | Out-Null

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    $secure = Read-Host "Enter your SAM API key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $SamApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    Write-Host "SAM API key is required."
    exit 1
}

$SamApiKey = $SamApiKey.Trim()

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    Write-Host "SAM API key is required."
    exit 1
}

$EnvFile = Join-Path $SamHome "env.ps1"
Set-Content -Path $EnvFile -Encoding UTF8 -Value "`$env:SAM_API_KEY = '$SamApiKey'"
if (Get-Command icacls -ErrorAction SilentlyContinue) {
    & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):R" | Out-Null
}

$Template = Join-Path $ScriptDir "templates\codex-config.toml"
Copy-Item -Force -Path $Template -Destination (Join-Path $CodexSamHome "config.toml")

$Runner = Join-Path $BinDir "sam-codex.ps1"
@'
$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam-code-agent"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$EnvFile = Join-Path $SamHome "env.ps1"

if (-not (Test-Path $EnvFile)) {
    Write-Host "Missing $EnvFile. Run the SAM code-agent installer first."
    exit 1
}

. $EnvFile
$env:CODEX_HOME = $CodexSamHome

& codex @args
exit $LASTEXITCODE
'@ | Set-Content -Path $Runner -Encoding UTF8

$CmdRunner = Join-Path $BinDir "sam-codex.cmd"
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\bin\sam-codex.ps1" %*
"@ | Set-Content -Path $CmdRunner -Encoding ASCII

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrWhiteSpace($UserPath)) {
    [Environment]::SetEnvironmentVariable("Path", $BinDir, "User")
}
elseif ($UserPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}

Write-Host "SAM Codex setup complete."
Write-Host "Config: $(Join-Path $CodexSamHome 'config.toml')"
Write-Host "Runner: $Runner"
Write-Host "Command shim: $CmdRunner"
Write-Host ""
Write-Host "Open a new PowerShell window if sam-codex is not found in this terminal."
Write-Host "Test command:"
Write-Host "sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral `"Reply with exactly: SAM-CODEX-OK`""
Write-Host ""
Write-Host "Desktop command:"
Write-Host "sam-codex app"
