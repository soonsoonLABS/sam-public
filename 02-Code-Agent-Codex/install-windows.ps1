param(
    [string]$SamApiKey = $env:SAM_API_KEY
)

Set-PSDebug -Off
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SamHome = Join-Path $HOME ".sam"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"
$SkillSource = Join-Path $ScriptDir "..\01-sam-skills\sam\SKILL.md"
$DiscoveryUrl = "https://sam.soonsoon.ai/v2/codex/models"
$EnvFile = Join-Path $SamHome "env.ps1"
$ConfigTemplate = Join-Path $ScriptDir "templates\codex-config.toml"
$ConfigPath = Join-Path $CodexSamHome "config.toml"
$CatalogPath = Join-Path $CodexSamHome "models_cache.json"

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
    if ($clientVersion -cnotmatch '^0\.145\.') {
        throw "SAM-Codex currently supports Codex 0.145.x."
    }
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
    if ([string]$catalog.client_version -cne $ExpectedClientVersion) {
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

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is not on PATH. Install it first, then run: codex --version"
}

$ClientVersion = Get-CodexClientVersion
$PreferencePath = if (Test-Path $ConfigPath) {
    $ConfigPath
}
else {
    $ConfigTemplate
}
$PreferredModel = Get-ConfiguredModelPreference -Path $PreferencePath

New-Item -ItemType Directory -Force -Path `
    $SamHome, `
    $CodexSamHome, `
    $BinDir, `
    (Join-Path $SamHome "skills\sam"), `
    (Join-Path $CodexSamHome "skills\sam") | Out-Null

if ([string]::IsNullOrWhiteSpace($SamApiKey) -and (Test-Path $EnvFile)) {
    . $EnvFile
    Set-PSDebug -Off
    $SamApiKey = $env:SAM_API_KEY
}

if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    $secure = Read-Host "Shared SAM API key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $SamApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$SamApiKey = $SamApiKey.Trim()
if ([string]::IsNullOrWhiteSpace($SamApiKey)) {
    throw "SAM_API_KEY is required."
}

$CatalogTmp = Join-Path $CodexSamHome (".models_cache.{0}.json" -f [guid]::NewGuid().ToString("N"))
try {
    Invoke-WebRequest -UseBasicParsing -Method Get -TimeoutSec 20 `
        -Uri ("{0}?client_version={1}" -f $DiscoveryUrl, [uri]::EscapeDataString($ClientVersion)) `
        -Headers @{
            Authorization = "Bearer $SamApiKey"
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
    throw "SAM OpenAI discovery failed or returned an invalid catalog. The previous verified cache, if any, was not changed."
}
finally {
    if ($CatalogTmp -and (Test-Path $CatalogTmp)) {
        Remove-Item -Force $CatalogTmp
    }
}

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$SafeKey = $SamApiKey.Replace("'", "''")
$EnvTmp = Join-Path $SamHome (".env.{0}.ps1" -f [guid]::NewGuid().ToString("N"))
try {
    [System.IO.File]::WriteAllText($EnvTmp, "", $Utf8NoBom)
    if (-not (Get-Command icacls -ErrorAction SilentlyContinue)) {
        throw "icacls is required to protect the SAM key file."
    }
    & icacls $EnvTmp /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not protect the temporary SAM key file."
    }
    if (Test-Path $EnvFile) {
        & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not restrict permissions on the existing SAM key file."
        }
    }

    [System.IO.File]::WriteAllText(
        $EnvTmp,
        "`$env:SAM_API_KEY = '$SafeKey'`r`n",
        $Utf8NoBom
    )
    if (Test-Path $EnvFile) {
        [System.IO.File]::Replace($EnvTmp, $EnvFile, $null)
    }
    else {
        [System.IO.File]::Move($EnvTmp, $EnvFile)
    }
    $EnvTmp = $null
}
finally {
    if ($EnvTmp -and (Test-Path $EnvTmp)) {
        Remove-Item -Force $EnvTmp
    }
}

$ConfigContent = Get-Content -Raw -Path $ConfigTemplate
$ConfigModelPattern = [regex]'(?m)^model\s*=\s*"[^"]+"\s*$'
if ($ConfigModelPattern.Matches($ConfigContent).Count -ne 1) {
    throw "The SAM Codex config template must contain exactly one model setting."
}
$ConfigContent = $ConfigModelPattern.Replace(
    $ConfigContent,
    "model = `"$SelectedModel`"",
    1
)
[System.IO.File]::WriteAllText(
    $ConfigPath,
    $ConfigContent,
    $Utf8NoBom
)
Copy-Item -Force $SkillSource (Join-Path $SamHome "skills\sam\SKILL.md")
Copy-Item -Force $SkillSource (Join-Path $CodexSamHome "skills\sam\SKILL.md")
Copy-Item -Force (Join-Path $ScriptDir "templates\sam-codex.ps1") (Join-Path $BinDir "sam-codex.ps1")
Set-Content -Path (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII `
    -Value "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-codex.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrWhiteSpace($UserPath)) {
    [Environment]::SetEnvironmentVariable("Path", $BinDir, "User")
}
elseif (($UserPath -split ';') -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}

Write-Host "SAM-Codex is ready. Open a new PowerShell window, then run: sam-codex"
Write-Host "Official Codex remains available as: codex"
