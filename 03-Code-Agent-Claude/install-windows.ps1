Set-PSDebug -Off
$ErrorActionPreference = "Stop"
$SamApiKey = $env:SAM_API_KEY

$SamHome = Join-Path $HOME ".sam"
$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$BinDir = Join-Path $HOME "bin"
$EnvFile = Join-Path $SamHome "env.ps1"
$McpConfig = Join-Path $ClaudeSamHome ".claude.json"
$Runner = Join-Path $BinDir "sam-claude.ps1"
$CmdRunner = Join-Path $BinDir "sam-claude.cmd"
$StateFile = Join-Path $ClaudeSamHome "runtime-state.json"
$WrapperUrl = "https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/templates/sam-claude.ps1"
$WrapperSha256 = "7f0e36f875d459f8728055938291fcc8fd134897d87538d87dddd644bfe8abbd"
$McpUrl = "https://sam.soonsoon.ai/mcp"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Assert-NotReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -Force -LiteralPath $Path
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Path is a link or reparse point. Nothing was changed."
        }
    }
}

function Test-ManagedFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Marker
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $true
    }
    return @(
        Get-Content -LiteralPath $Path | Where-Object { $_ -ceq $Marker }
    ).Count -eq 1
}

function Get-McpStatus {
    if (-not (Test-Path -LiteralPath $McpConfig)) {
        return "absent"
    }
    try {
        $data = Get-Content -Raw -LiteralPath $McpConfig | ConvertFrom-Json
    }
    catch {
        return "conflict"
    }
    if ($data -isnot [pscustomobject]) {
        return "conflict"
    }
    $hasServers = $data.PSObject.Properties.Name -ccontains "mcpServers"
    if (-not $hasServers) {
        return "absent"
    }
    $servers = $data.mcpServers
    if ($servers -isnot [pscustomobject]) {
        return "conflict"
    }
    $server = $servers.'sam-tools'
    if ($null -eq $server) {
        return "absent"
    }
    if (
        [string]$server.type -ceq "http" -and
        [string]$server.url -ceq $McpUrl -and
        [string]$server.headers.Authorization -ceq 'Bearer ${SAM_API_KEY}'
    ) {
        return "valid"
    }
    return "conflict"
}

foreach ($path in @(
    $SamHome,
    $ClaudeSamHome,
    $BinDir,
    $EnvFile,
    $McpConfig,
    $Runner,
    $CmdRunner,
    $StateFile
)) {
    Assert-NotReparsePoint -Path $path
}
if (-not (Test-ManagedFile -Path $Runner -Marker "# SAM_CLAUDE_INSTALLER_MANAGED=1")) {
    throw "Unmanaged $Runner already exists. Nothing was changed."
}
if (-not (Test-ManagedFile -Path $CmdRunner -Marker "REM SAM_CLAUDE_INSTALLER_MANAGED=1")) {
    throw "Unmanaged $CmdRunner already exists. Nothing was changed."
}
$mcpStatus = Get-McpStatus
if ($mcpStatus -eq "conflict") {
    throw "The isolated sam-tools MCP entry is malformed or points elsewhere. Nothing was changed."
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Official Claude Code is missing. Install it from https://code.claude.com/docs/en/setup."
}
if (-not (Get-Command icacls.exe -ErrorAction SilentlyContinue)) {
    throw "icacls.exe is required to protect a newly created key file."
}

$keyFromExistingFile = $false
if (Test-Path -LiteralPath $EnvFile) {
    . $EnvFile
    Set-PSDebug -Off
    $SamApiKey = $env:SAM_API_KEY
    $keyFromExistingFile = $true
}
elseif ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    $secure = Read-Host "SAM API key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $SamApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}
$SamApiKey = [string]$SamApiKey
if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    throw "SAM_API_KEY is required."
}
$SamApiKey = $SamApiKey.Trim()

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sam-claude-install-{0}" -f [guid]::NewGuid().ToString("N")
)
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$wrapperTemp = Join-Path $tempRoot "sam-claude.ps1"
$stateTemp = Join-Path $tempRoot "runtime-state.json"
$mcpBackup = Join-Path $tempRoot "mcp-config.backup"
$runnerBackup = Join-Path $tempRoot "runner.backup"
$cmdBackup = Join-Path $tempRoot "cmd.backup"
$stateBackup = Join-Path $tempRoot "state.backup"
$mcpExisted = $false
$runnerExisted = $false
$cmdExisted = $false
$stateExisted = $false
$transactionStarted = $false
$pathChanged = $false
$originalUserPath = [Environment]::GetEnvironmentVariable("Path", "User")

try {
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 `
        -Uri $WrapperUrl `
        -OutFile $wrapperTemp
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $wrapperTemp).Hash.ToLowerInvariant()
    if ($actualHash -cne $WrapperSha256) {
        throw "Downloaded SAM-Claude wrapper checksum mismatch."
    }
    if (-not (Test-ManagedFile -Path $wrapperTemp -Marker "# SAM_CLAUDE_INSTALLER_MANAGED=1")) {
        throw "Downloaded wrapper ownership marker is missing."
    }

    $shellExe = (Get-Process -Id $PID).Path
    $savedKey = $env:SAM_API_KEY
    $savedState = $env:SAM_CLAUDE_STATE_PATH
    $savedPreflight = $env:SAM_CLAUDE_PREFLIGHT_ONLY
    try {
        $env:SAM_API_KEY = $SamApiKey
        $env:SAM_CLAUDE_STATE_PATH = $stateTemp
        $env:SAM_CLAUDE_PREFLIGHT_ONLY = "1"
        & $shellExe -NoProfile -ExecutionPolicy Bypass -File $wrapperTemp | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $stateTemp)) {
            throw "Authenticated SAM-Claude discovery or role mapping validation failed."
        }
    }
    finally {
        $env:SAM_API_KEY = $savedKey
        $env:SAM_CLAUDE_STATE_PATH = $savedState
        $env:SAM_CLAUDE_PREFLIGHT_ONLY = $savedPreflight
    }

    New-Item -ItemType Directory -Force -Path $SamHome, $ClaudeSamHome, $BinDir |
        Out-Null
    if (Test-Path -LiteralPath $McpConfig) {
        Copy-Item -LiteralPath $McpConfig -Destination $mcpBackup
        $mcpExisted = $true
    }
    if (Test-Path -LiteralPath $Runner) {
        Copy-Item -LiteralPath $Runner -Destination $runnerBackup
        $runnerExisted = $true
    }
    if (Test-Path -LiteralPath $CmdRunner) {
        Copy-Item -LiteralPath $CmdRunner -Destination $cmdBackup
        $cmdExisted = $true
    }
    if (Test-Path -LiteralPath $StateFile) {
        Copy-Item -LiteralPath $StateFile -Destination $stateBackup
        $stateExisted = $true
    }
    $transactionStarted = $true
    if ($mcpStatus -eq "absent") {
        $savedConfigDir = $env:CLAUDE_CONFIG_DIR
        $savedKey = $env:SAM_API_KEY
        try {
            $env:CLAUDE_CONFIG_DIR = $ClaudeSamHome
            $env:SAM_API_KEY = $SamApiKey
            & claude mcp add --transport http --scope user `
                sam-tools $McpUrl `
                --header 'Authorization: Bearer ${SAM_API_KEY}' | Out-Null
            if ($LASTEXITCODE -ne 0 -or (Get-McpStatus) -ne "valid") {
                throw "Claude did not create the expected isolated MCP entry."
            }
        }
        catch {
            if (Test-Path -LiteralPath $mcpBackup) {
                Copy-Item -Force -LiteralPath $mcpBackup -Destination $McpConfig
            }
            else {
                Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $McpConfig
            }
            throw "Could not add the isolated sam-tools MCP entry."
        }
        finally {
            $env:CLAUDE_CONFIG_DIR = $savedConfigDir
            $env:SAM_API_KEY = $savedKey
        }
    }

    if (-not $keyFromExistingFile) {
        $escapedKey = $SamApiKey.Replace("'", "''")
        $envTemp = Join-Path $SamHome (
            ".env.{0}.ps1" -f [guid]::NewGuid().ToString("N")
        )
        [IO.File]::WriteAllText(
            $envTemp,
            ("`$env:SAM_API_KEY = '{0}'`r`n" -f $escapedKey),
            $Utf8NoBom
        )
        & icacls.exe $envTemp /inheritance:r /grant:r "$($env:USERNAME):(F)" |
            Out-Null
        if ($LASTEXITCODE -ne 0) {
            Remove-Item -Force -LiteralPath $envTemp
            throw "Could not restrict the SAM key file permissions."
        }
        Move-Item -Force -LiteralPath $envTemp -Destination $EnvFile
    }

    $runnerTemp = Join-Path $BinDir (
        ".sam-claude.{0}.ps1" -f [guid]::NewGuid().ToString("N")
    )
    Copy-Item -LiteralPath $wrapperTemp -Destination $runnerTemp
    Move-Item -Force -LiteralPath $runnerTemp -Destination $Runner

    $cmdText = @'
@echo off
REM SAM_CLAUDE_INSTALLER_MANAGED=1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\bin\sam-claude.ps1" %*
'@
    $cmdTemp = Join-Path $BinDir (
        ".sam-claude.{0}.cmd" -f [guid]::NewGuid().ToString("N")
    )
    [IO.File]::WriteAllText($cmdTemp, ($cmdText.TrimStart() + "`r`n"), [Text.Encoding]::ASCII)
    Move-Item -Force -LiteralPath $cmdTemp -Destination $CmdRunner

    $stateInstallTemp = Join-Path $ClaudeSamHome (
        ".runtime-state.{0}.json" -f [guid]::NewGuid().ToString("N")
    )
    Copy-Item -LiteralPath $stateTemp -Destination $stateInstallTemp
    Move-Item -Force -LiteralPath $stateInstallTemp -Destination $StateFile

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrWhiteSpace($userPath)) {
        [Environment]::SetEnvironmentVariable("Path", $BinDir, "User")
        $pathChanged = $true
    }
    elseif (($userPath -split ";") -cnotcontains $BinDir) {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$BinDir", "User")
        $pathChanged = $true
    }
    $transactionStarted = $false
}
catch {
    $failure = $_
    if ($transactionStarted) {
        if ($mcpExisted) {
            Copy-Item -Force -LiteralPath $mcpBackup -Destination $McpConfig
        }
        else {
            Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $McpConfig
        }
        if ($runnerExisted) {
            Copy-Item -Force -LiteralPath $runnerBackup -Destination $Runner
        }
        else {
            Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $Runner
        }
        if ($cmdExisted) {
            Copy-Item -Force -LiteralPath $cmdBackup -Destination $CmdRunner
        }
        else {
            Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $CmdRunner
        }
        if ($stateExisted) {
            Copy-Item -Force -LiteralPath $stateBackup -Destination $StateFile
        }
        else {
            Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $StateFile
        }
        if (-not $keyFromExistingFile) {
            Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $EnvFile
        }
        if ($pathChanged) {
            [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
        }
    }
    throw $failure
}
finally {
    $SamApiKey = $null
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $tempRoot
}

Write-Host ""
Write-Host "SAM-Claude installed successfully."
Write-Host "  Official Claude Code: claude"
Write-Host "  SAM Claude:           sam-claude"
Write-Host "Open a new PowerShell window, then run: sam-claude"
