# SAM_CLAUDE_INSTALLER_MANAGED=1
Set-PSDebug -Off
$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam"
$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$EnvFile = Join-Path $SamHome "env.ps1"
$StatePath = if (
    $env:SAM_CLAUDE_PREFLIGHT_ONLY -eq "1" -and
    $env:SAM_CLAUDE_STATE_PATH
) {
    $env:SAM_CLAUDE_STATE_PATH
}
else {
    Join-Path $ClaudeSamHome "runtime-state.json"
}
$DiscoveryUrl = "https://sam.soonsoon.ai/v2/claude/v1/models"
$ProfilesUrl = "https://sam.soonsoon.ai/v1/models/code-agent-profiles?agent=claude_code&protocol_surface=anthropic_messages"
$GatewayBaseUrl = "https://sam.soonsoon.ai/v2/claude"
$GatewayCache = Join-Path $ClaudeSamHome "cache/gateway-models.json"
$GatewayCacheBackupDirectory = Join-Path $ClaudeSamHome "cache-backups"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Get-ClaudeClientVersion {
    $output = @(& claude --version 2>$null)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) {
        return $null
    }
    $match = [regex]::Match(
        [string]$output[0],
        '^([0-9]+)\.([0-9]+)\.([0-9]+) \(Claude Code\)$'
    )
    if (-not $match.Success) {
        return $null
    }
    $version = [version]::new(
        [int]$match.Groups[1].Value,
        [int]$match.Groups[2].Value,
        [int]$match.Groups[3].Value
    )
    if ($version -lt [version]"2.1.129") {
        return $null
    }
    return $version.ToString()
}

function Assert-SafeModelId {
    param([Parameter(Mandatory = $true)][string]$ModelId)
    if ($ModelId -cnotmatch '^(?:claude|anthropic)[A-Za-z0-9._-]*$') {
        throw "SAM-Claude discovery returned an unsafe model ID."
    }
}

function Get-VerifiedRuntimeState {
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $headers = @{ Authorization = "Bearer $Token" }
    $catalog = Invoke-RestMethod -TimeoutSec 20 `
        -Uri $DiscoveryUrl `
        -Headers $headers
    $profilesPayload = Invoke-RestMethod -TimeoutSec 20 `
        -Uri $ProfilesUrl `
        -Headers $headers

    if ($catalog.has_more -ne $false) {
        throw "Invalid SAM-Claude catalog envelope."
    }
    $items = @($catalog.data)
    if ($items.Count -lt 1) {
        throw "SAM-Claude catalog is empty."
    }
    $catalogIds = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $items) {
        $modelId = [string]$item.id
        Assert-SafeModelId -ModelId $modelId
        if (
            [string]$item.type -cne "model" -or
            [string]::IsNullOrWhiteSpace([string]$item.display_name) -or
            [string]::IsNullOrWhiteSpace([string]$item.created_at)
        ) {
            throw "Invalid SAM-Claude catalog item."
        }
        if ($catalogIds.Contains($modelId)) {
            throw "Duplicate SAM-Claude catalog model."
        }
        $catalogIds.Add($modelId)
    }
    if (
        [string]$catalog.first_id -cne $catalogIds[0] -or
        [string]$catalog.last_id -cne $catalogIds[$catalogIds.Count - 1]
    ) {
        throw "SAM-Claude catalog bounds do not match."
    }

    if ($profilesPayload.ok -ne $true) {
        throw "Invalid Claude profile envelope."
    }
    $requiredRoles = @("haiku", "sonnet", "opus")
    $roleModels = @{}
    foreach ($profile in @($profilesPayload.profiles)) {
        if (
            [string]$profile.agent -cne "claude_code" -or
            [string]$profile.protocol_surface -cne "anthropic_messages"
        ) {
            throw "Unexpected Claude profile surface."
        }
        $role = [string]$profile.claude_role
        if ($role -ceq "sonnet_1m") {
            continue
        }
        if ($requiredRoles -cnotcontains $role -or $roleModels.ContainsKey($role)) {
            throw "Unexpected or duplicate Claude role."
        }
        $selected = $profile.selected_backing_model
        if ($null -eq $selected) {
            throw "Claude role has no selected backing model."
        }
        $alias = [string]$selected.alias
        Assert-SafeModelId -ModelId $alias
        $context = 0L
        if (
            -not [long]::TryParse(
                [string]$selected.max_context_tokens,
                [ref]$context
            ) -or
            $context -le 0 -or
            -not $catalogIds.Contains($alias)
        ) {
            throw "Claude role backing model is not in unified discovery."
        }
        $roleModels[$role] = [ordered]@{
            alias = $alias
            max_context_tokens = $context
        }
    }
    if (
        $roleModels.Count -ne 3 -or
        @($requiredRoles | Where-Object { -not $roleModels.ContainsKey($_) }).Count -gt 0
    ) {
        throw "Exactly Haiku, Sonnet, and Opus mappings are required."
    }
    $aliases = @($requiredRoles | ForEach-Object { $roleModels[$_].alias })
    if (@($aliases | Select-Object -Unique).Count -ne 3) {
        throw "Claude role mappings must be distinct."
    }
    if (@(
        $catalogIds | Where-Object {
            $aliases -cnotcontains $_ -and -not $_.StartsWith("claude-sam-")
        }
    ).Count -gt 0) {
        throw "Uncertified compatibility model ID."
    }

    $sonnet1m = [long]$roleModels["sonnet"].max_context_tokens -ge 1000000
    $state = [ordered]@{
        schema_version = 1
        verified_at = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        catalog = $items
        roles = $roleModels
        sonnet_1m = $sonnet1m
    }
    [System.IO.File]::WriteAllText(
        $OutputPath,
        (($state | ConvertTo-Json -Depth 20) + "`n"),
        $Utf8NoBom
    )
    return [pscustomobject]@{
        Haiku = [string]$roleModels["haiku"].alias
        Sonnet = [string]$roleModels["sonnet"].alias
        Opus = [string]$roleModels["opus"].alias
        Sonnet1M = $sonnet1m
    }
}

function Move-StaleGatewayModelCache {
    $cacheDirectory = Split-Path -Parent $GatewayCache
    foreach ($path in @(
        $ClaudeSamHome,
        $cacheDirectory,
        $GatewayCache,
        $GatewayCacheBackupDirectory
    )) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -Force -LiteralPath $path
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "The isolated gateway model cache path is a link or reparse point."
            }
        }
    }
    if (
        (Test-Path -LiteralPath $cacheDirectory) -and
        -not (Get-Item -Force -LiteralPath $cacheDirectory).PSIsContainer
    ) {
        throw "The isolated gateway model cache parent is not a directory."
    }
    if (-not (Test-Path -LiteralPath $GatewayCache)) {
        return
    }
    if ((Get-Item -Force -LiteralPath $GatewayCache).PSIsContainer) {
        throw "The isolated gateway model cache is not a regular file."
    }
    if (
        (Test-Path -LiteralPath $GatewayCacheBackupDirectory) -and
        -not (Get-Item -Force -LiteralPath $GatewayCacheBackupDirectory).PSIsContainer
    ) {
        throw "The isolated gateway model cache backup path is not a directory."
    }

    try {
        $payload = Get-Content -Raw -LiteralPath $GatewayCache |
            ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "The isolated gateway model cache is malformed. It was not changed."
    }
    $baseUrlProperty = $payload.PSObject.Properties["baseUrl"]
    if (
        $null -eq $baseUrlProperty -or
        [string]::IsNullOrWhiteSpace([string]$baseUrlProperty.Value)
    ) {
        throw "The isolated gateway model cache is malformed. It was not changed."
    }
    if ([string]$baseUrlProperty.Value -ceq $GatewayBaseUrl) {
        return
    }

    New-Item -ItemType Directory -Force -Path $GatewayCacheBackupDirectory |
        Out-Null
    $backupName = "gateway-models.{0}.{1}.json" -f `
        [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ"),
        [guid]::NewGuid().ToString("N")
    $backupPath = Join-Path $GatewayCacheBackupDirectory $backupName
    if (Test-Path -LiteralPath $backupPath) {
        throw "The isolated gateway model cache backup target already exists."
    }
    Move-Item -LiteralPath $GatewayCache -Destination $backupPath
    Write-Warning (
        "SAM-Claude moved an outdated isolated model cache to {0}" -f
        $backupPath
    )
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Official Claude Code is not on PATH."
}
$clientVersion = Get-ClaudeClientVersion
if ([string]::IsNullOrWhiteSpace($clientVersion)) {
    throw "Claude Code 2.1.129 or newer is required."
}

if (Test-Path $EnvFile) {
    . $EnvFile
    Set-PSDebug -Off
}
if ([string]::IsNullOrWhiteSpace($env:SAM_API_KEY)) {
    throw "SAM_API_KEY is missing from $EnvFile."
}

$stateDirectory = Split-Path -Parent $StatePath
foreach ($path in @($ClaudeSamHome, $stateDirectory, $StatePath)) {
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -Force -LiteralPath $path
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Runtime state path is a link or reparse point."
        }
    }
}
if (
    (Test-Path -LiteralPath $stateDirectory) -and
    -not (Get-Item -Force -LiteralPath $stateDirectory).PSIsContainer
) {
    throw "Runtime state parent is not a directory."
}
if (
    (Test-Path -LiteralPath $StatePath) -and
    (Get-Item -Force -LiteralPath $StatePath).PSIsContainer
) {
    throw "Runtime state target is not a file."
}
New-Item -ItemType Directory -Force -Path $stateDirectory | Out-Null
$stateTmp = Join-Path $stateDirectory (
    ".runtime-state.{0}.json" -f [guid]::NewGuid().ToString("N")
)
try {
    $mapping = Get-VerifiedRuntimeState `
        -Token $env:SAM_API_KEY `
        -OutputPath $stateTmp
    if (Test-Path $StatePath) {
        [System.IO.File]::Replace($stateTmp, $StatePath, $null)
    }
    else {
        [System.IO.File]::Move($stateTmp, $StatePath)
    }
}
catch {
    if (Test-Path $stateTmp) {
        Remove-Item -Force $stateTmp
    }
    if (Test-Path $StatePath) {
        throw "Runtime discovery failed. The previous verified cache was preserved, but Claude was not started."
    }
    throw "Runtime discovery failed and no verified cache exists."
}

if ($env:SAM_CLAUDE_PREFLIGHT_ONLY -eq "1") {
    Write-Host (
        "SAM-Claude preflight OK: Claude Code {0}, Sonnet 1M {1}" -f
        $clientVersion,
        $mapping.Sonnet1M
    )
    exit 0
}

Move-StaleGatewayModelCache

Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_OAUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_USE_BEDROCK -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_USE_VERTEX -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_USE_FOUNDRY -ErrorAction SilentlyContinue

$env:CLAUDE_CONFIG_DIR = $ClaudeSamHome
$env:ANTHROPIC_BASE_URL = "https://sam.soonsoon.ai/v2/claude"
$env:ANTHROPIC_AUTH_TOKEN = $env:SAM_API_KEY
$env:ANTHROPIC_MODEL = $mapping.Sonnet
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $mapping.Haiku
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $mapping.Sonnet
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $mapping.Opus
$env:ANTHROPIC_SMALL_FAST_MODEL = $mapping.Haiku
$env:CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"

New-Item -ItemType Directory -Force -Path $env:CLAUDE_CONFIG_DIR | Out-Null
& claude @args
exit $LASTEXITCODE
