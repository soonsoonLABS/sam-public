Set-PSDebug -Off
$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$EnvFile = Join-Path $SamHome "env.ps1"
$ConfigFile = Join-Path $CodexSamHome "config.toml"
$CatalogPath = Join-Path $CodexSamHome "models_cache.json"
$CatalogPathForToml = $CatalogPath.Replace('\', '/')
$DiscoveryUrl = "https://sam.soonsoon.ai/v2/codex/models"
$DefaultWorkspace = Join-Path $HOME "SAM-Codex"

function Get-CodexClientVersion {
    $versionOutput = @(& codex --version 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read the Codex CLI version."
    }

    $versionPattern = [regex]'^codex-cli ([0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?)$'
    if ($versionOutput.Count -ne 1) {
        throw "Expected exactly one codex-cli version line."
    }
    $versionMatch = $versionPattern.Match(([string]$versionOutput[0]).Trim())
    if (-not $versionMatch.Success) {
        throw "Could not parse the codex-cli version line."
    }
    $clientVersion = $versionMatch.Groups[1].Value
    return $clientVersion
}

function Get-ConfiguredModelPreference {
    param([Parameter(Mandatory = $true)][string]$Path)

    foreach ($line in Get-Content -Path $Path) {
        if ($line -match '^\s*model\s*=\s*"([^"]+)"\s*$') {
            return $Matches[1]
        }
    }
    return ""
}

function Get-VerifiedSamCatalogModel {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$PreferredModel = "",
        [Parameter(Mandatory = $true)][string]$ExpectedClientVersion
    )

    try {
        $catalog = Get-Content -Raw -Path $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }

    if ($null -eq $catalog -or
        [string]$catalog.etag -cne "sam-v2-unified-codex-catalog" -or
        -not ($catalog.PSObject.Properties.Name -contains "models")) {
        return $null
    }
    if ([string]$catalog.client_version -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$' -or
        [string]$catalog.client_version -cne $ExpectedClientVersion) {
        return $null
    }

    $fetchedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse(
        [string]$catalog.fetched_at,
        [ref]$fetchedAt
    )) {
        return $null
    }

    $visibleSlugs = @()
    $seenVisibleSlugs = @{}
    $requiredHiddenSlugs = @(
        "gpt-5.6-sol",
        "gpt-5.6-terra",
        "gpt-5.6-luna",
        "gpt-5.5",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.2",
        "codex-auto-review"
    )
    $seenHiddenSlugs = @{}
    foreach ($model in @($catalog.models)) {
        $slug = [string]$model.slug
        if ($requiredHiddenSlugs -ccontains $slug) {
            if ([string]$model.visibility -cne "hide" -or
                $model.supported_in_api -ne $false -or
                $seenHiddenSlugs.ContainsKey($slug)) {
                return $null
            }
            $seenHiddenSlugs[$slug] = $true
        }
        if ([string]$model.visibility -cne "list") {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($slug) -or
            $slug -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
            $model.supported_in_api -ne $true -or
            $seenVisibleSlugs.ContainsKey($slug)) {
            return $null
        }
        $seenVisibleSlugs[$slug] = $true
        $visibleSlugs += $slug
    }

    if ($seenHiddenSlugs.Count -ne $requiredHiddenSlugs.Count -or
        $visibleSlugs.Count -lt 1) {
        return $null
    }
    if (-not [string]::IsNullOrWhiteSpace($PreferredModel) -and
        $visibleSlugs -ccontains $PreferredModel) {
        return $PreferredModel
    }
    return $visibleSlugs[0]
}

if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile. Run install-windows.ps1 first."
}

. $EnvFile
Set-PSDebug -Off
if ([string]::IsNullOrWhiteSpace($env:SAM_API_KEY)) {
    throw "SAM_API_KEY is not set in $EnvFile."
}

$env:CODEX_HOME = $CodexSamHome
$PreferredModel = Get-ConfiguredModelPreference -Path $ConfigFile
if ([string]::IsNullOrWhiteSpace($PreferredModel)) {
    $PreferredModel = "azure.gpt-5.6-luna"
}
$ClientVersion = Get-CodexClientVersion

foreach ($argument in $args) {
    $argumentText = [string]$argument
    if ($argumentText -cin @(
            "-c",
            "--config",
            "-m",
            "--model",
            "-p",
            "--profile",
            "--oss",
            "--local-provider",
            "--search"
        ) -or
        $argumentText -cmatch '^-[cmp].+' -or
        $argumentText -cmatch '^--(config|model|profile|local-provider)=') {
        throw "SAM-Codex blocks model/provider/config override options. Use /model inside SAM-Codex."
    }
}

$CatalogTmp = Join-Path $CodexSamHome (".models_cache.{0}.json" -f [guid]::NewGuid().ToString("N"))
try {
    Invoke-WebRequest -UseBasicParsing -Method Get -TimeoutSec 15 `
        -Uri ("{0}?client_version={1}" -f $DiscoveryUrl, [uri]::EscapeDataString($ClientVersion)) `
        -Headers @{
            Authorization = "Bearer $env:SAM_API_KEY"
            "x-sam-codex-cache" = "1"
        } `
        -OutFile $CatalogTmp
    $SelectedModel = Get-VerifiedSamCatalogModel `
        -Path $CatalogTmp `
        -PreferredModel $PreferredModel `
        -ExpectedClientVersion $ClientVersion
    if ([string]::IsNullOrWhiteSpace($SelectedModel)) {
        throw "The SAM Codex catalog response was not a verified cache envelope."
    }

    if (Test-Path $CatalogPath) {
        [System.IO.File]::Replace($CatalogTmp, $CatalogPath, $null)
    }
    else {
        [System.IO.File]::Move($CatalogTmp, $CatalogPath)
    }
    $CatalogTmp = $null
}
catch {
    if ($CatalogTmp -and (Test-Path $CatalogTmp)) {
        Remove-Item -Force $CatalogTmp
    }
    throw "SAM model discovery failed or returned an invalid catalog. The previous cache was not changed, but SAM Codex did not start."
}

$InGitProject = $false
if (Get-Command git -ErrorAction SilentlyContinue) {
    $null = & git -C $PWD.Path rev-parse --show-toplevel 2>$null
    $InGitProject = $LASTEXITCODE -eq 0
}
$HasSamRoot = Test-Path (Join-Path $PWD.Path ".sam-codex-root")
if (-not $InGitProject -and -not $HasSamRoot) {
    New-Item -ItemType Directory -Force -Path $DefaultWorkspace | Out-Null
    Set-Content -Path (Join-Path $DefaultWorkspace ".sam-codex-root") `
        -Encoding ASCII `
        -NoNewline `
        -Value ""
    Set-Location $DefaultWorkspace
    Write-Host "SAM-Codex workspace: $DefaultWorkspace"
}

& codex `
    -c 'model_provider="sam"' `
    -c "model=`"$SelectedModel`"" `
    -c "model_catalog_json=`"$CatalogPathForToml`"" `
    -c 'web_search="disabled"' `
    @args
exit $LASTEXITCODE
