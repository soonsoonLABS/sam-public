param(
    [switch]$PurgeData
)

Set-PSDebug -Off
$ErrorActionPreference = "Stop"

$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$BinDir = Join-Path $HOME "bin"
$Runner = Join-Path $BinDir "sam-claude.ps1"
$CmdRunner = Join-Path $BinDir "sam-claude.cmd"

function Assert-NotReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -Force -LiteralPath $Path
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Path is a link or reparse point. Nothing was changed."
        }
    }
}

function Assert-ManagedFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Marker
    )
    if (
        (Test-Path -LiteralPath $Path) -and
        @(
            Get-Content -LiteralPath $Path | Where-Object { $_ -ceq $Marker }
        ).Count -ne 1
    ) {
        throw "Unmanaged $Path was preserved. Nothing was changed."
    }
}

foreach ($path in @($ClaudeSamHome, $Runner, $CmdRunner)) {
    Assert-NotReparsePoint -Path $path
}
Assert-ManagedFile -Path $Runner -Marker "# SAM_CLAUDE_INSTALLER_MANAGED=1"
Assert-ManagedFile -Path $CmdRunner -Marker "REM SAM_CLAUDE_INSTALLER_MANAGED=1"

Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $Runner
Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $CmdRunner

if ($PurgeData -and (Test-Path -LiteralPath $ClaudeSamHome)) {
    $backupRoot = Join-Path $HOME "SAM-Claude-Backups"
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $backupTarget = Join-Path $backupRoot (
        "SAM-Claude-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
    )
    Move-Item -LiteralPath $ClaudeSamHome -Destination $backupTarget
    Write-Host "SAM-Claude data moved to: $backupTarget"
}

Write-Host ""
Write-Host "SAM-Claude command removed."
Write-Host "Official claude, ~/.claude, and the shared ~/.sam/env.ps1 key were not changed."
if (-not $PurgeData -and (Test-Path -LiteralPath $ClaudeSamHome)) {
    Write-Host "SAM-Claude sessions and isolated MCP settings were preserved in $ClaudeSamHome."
}
