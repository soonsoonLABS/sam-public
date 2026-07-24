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
try {
    $clientVersion = ((& codex --version) -split '\s+')[-1]
    $cacheTmp = Join-Path $CodexSamHome (".models_cache.{0}" -f [guid]::NewGuid().ToString("N"))
    Invoke-WebRequest -UseBasicParsing -Method Get -Uri ("https://sam.soonsoon.ai/v2/openai/models?client_version={0}" -f [uri]::EscapeDataString($clientVersion)) -Headers @{
        Authorization = "Bearer $env:SAM_CODEX_API"
        "x-sam-codex-cache" = "1"
    } -OutFile $cacheTmp
    if ((Get-Content -Raw $cacheTmp) -match '"models"') {
        Move-Item -Force $cacheTmp (Join-Path $CodexSamHome "models_cache.json")
    }
    else {
        Remove-Item -Force $cacheTmp
    }
}
catch {
    if ($cacheTmp -and (Test-Path $cacheTmp)) { Remove-Item -Force $cacheTmp }
}

if ($args.Count -gt 0 -and $args[0] -eq "model") {
    $remainingArgs = @($args | Select-Object -Skip 1)
    if ($remainingArgs.Count -gt 0) {
        $selectedModel = $remainingArgs[0]
        $remainingArgs = @($remainingArgs | Select-Object -Skip 1)
    }
    else {
        $models = @(
            @{ Id = "azure.gpt-5.6-terra"; Label = "Azure Foundry · everyday" },
            @{ Id = "azure.gpt-5.6-sol"; Label = "Azure Foundry · difficult work" },
            @{ Id = "azure.gpt-5.6-luna"; Label = "Azure Foundry · fast" },
            @{ Id = "azure.gpt-5.4"; Label = "Azure Foundry · GPT-5.4" },
            @{ Id = "aws.gpt-5.6-terra"; Label = "AWS Bedrock Mantle · everyday" },
            @{ Id = "aws.gpt-5.6-sol"; Label = "AWS Bedrock Mantle · difficult work" },
            @{ Id = "aws.gpt-5.6-luna"; Label = "AWS Bedrock Mantle · fast" },
            @{ Id = "aws.gpt-5.5"; Label = "AWS Bedrock Mantle · GPT-5.5" },
            @{ Id = "aws.gpt-5.4"; Label = "AWS Bedrock Mantle · GPT-5.4" }
        )
        Write-Host "Choose a SAM model"
        for ($index = 0; $index -lt $models.Count; $index++) {
            Write-Host ("{0}. {1} ({2})" -f ($index + 1), $models[$index].Id, $models[$index].Label)
        }
        do { $choice = Read-Host "Enter a number" } until ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $models.Count)
        $selectedModel = $models[[int]$choice - 1].Id
    }
    & codex -m $selectedModel @remainingArgs
    exit $LASTEXITCODE
}

& codex @args
exit $LASTEXITCODE
