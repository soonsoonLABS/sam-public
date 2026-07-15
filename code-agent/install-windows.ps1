param(
    [string]$SamApiKey = $env:SAM_API_KEY
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host "Codex CLI was not found on PATH."
    Write-Host "Install Node.js LTS and Codex first, then open a new PowerShell window and rerun this installer:"
    Write-Host "  winget install -e --id OpenJS.NodeJS.LTS"
    Write-Host "  npm install -g @openai/codex@latest"
    Write-Host "  codex --version"
    Write-Host "If PowerShell blocks npm.ps1, run:"
    Write-Host "  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
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
    & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
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

$SamCodexConfig = @(
    "-c", "model=`"sam-codex-agent`"",
    "-c", "model_provider=`"sam`"",
    "-c", "model_reasoning_effort=`"medium`"",
    "-c", "model_providers.sam.name=`"SAM`"",
    "-c", "model_providers.sam.base_url=`"https://sam.soonsoon.ai/openai/v1`"",
    "-c", "model_providers.sam.env_key=`"SAM_API_KEY`"",
    "-c", "model_providers.sam.wire_api=`"responses`"",
    "-c", "model_providers.sam.request_max_retries=4",
    "-c", "model_providers.sam.stream_max_retries=5",
    "-c", "model_providers.sam.stream_idle_timeout_ms=300000"
)

& codex @SamCodexConfig @args
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
Write-Host "Interactive terminal command:"
Write-Host "sam-codex"
Write-Host ""
Write-Host "Note: on Windows, use sam-codex for the CLI/TUI. sam-codex app may open the desktop installer."
Write-Host ""
Write-Host "After the CLI test succeeds, enable the Windows desktop app profile with:"
Write-Host "powershell -ExecutionPolicy Bypass -File .\enable-windows-desktop-sam.ps1"
