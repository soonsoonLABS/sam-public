# SAM Codex 수동 설정 (Windows)

**언어:** 한국어 | [English](MANUAL_SETUP_WINDOWS.en.md)

설치 프로그램 없이 Windows PowerShell에서 SAM Codex를 직접 설정하는 기준
절차입니다. 일반 Codex 설정은 `%USERPROFILE%\.codex`에 두고, SAM Codex는
`%USERPROFILE%\.codex-sam`과 `SAM_CODE_API_KEY`만 사용합니다.

## 1. Code Agent 전용 키 준비

SAM 웹의 **API Keys**에서 `Code Agent - Windows`처럼 구분되는 전용 키를
하나 준비합니다. 키 소유자에게 `agent:codex` 또는 `agent:coding_agents`
권한이 있어야 합니다.

## 2. 현재 PowerShell에 키 입력

키는 화면에 보이지 않으며 아직 파일에도 저장하지 않습니다.

```powershell
$secure = Read-Host "SAM Code Agent 키 입력" -AsSecureString
$env:SAM_CODE_API_KEY = (New-Object PSCredential "sam", $secure).GetNetworkCredential().Password
```

전체 키를 출력하지 않고 상태만 확인합니다.

```powershell
"loaded=" + (-not [string]::IsNullOrWhiteSpace($env:SAM_CODE_API_KEY))
"length=" + $env:SAM_CODE_API_KEY.Length
"prefix=" + $env:SAM_CODE_API_KEY.Substring(0, [Math]::Min(4, $env:SAM_CODE_API_KEY.Length))
```

## 3. 키 유효성 확인

Codex보다 먼저 SAM API 연결을 확인합니다. 정상 응답의 마지막 값은
`SAM-CODEX-OK`입니다.

```powershell
$body = @{
  model = "sam-codex-agent"
  input = "Reply with exactly: SAM-CODEX-OK"
  stream = $false
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/openai/v1/responses" `
  -Headers @{ Authorization = "Bearer $env:SAM_CODE_API_KEY" } `
  -ContentType "application/json" `
  -Body $body

$response.output_text
```

## 4. 성공한 키 저장

테스트가 성공한 키만 Code Agent 전용 로컬 파일에 저장합니다.

```powershell
$SamHome = Join-Path $HOME ".sam-code-agent"
New-Item -ItemType Directory -Force -Path $SamHome | Out-Null
$EnvFile = Join-Path $SamHome "env.ps1"
Set-Content -Path $EnvFile -Encoding UTF8 -Value "`$env:SAM_CODE_API_KEY = '$env:SAM_CODE_API_KEY'"
icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
Remove-Item Env:SAM_CODE_API_KEY -ErrorAction SilentlyContinue
```

## 5. Codex CLI 설치

Node.js LTS와 Codex CLI가 필요합니다.

```powershell
winget install -e --id OpenJS.NodeJS.LTS
```

PowerShell을 완전히 닫고 새 창을 연 뒤 실행합니다.

```powershell
node --version
npm --version
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
npm install -g @openai/codex@latest
codex --version
```

## 6. 분리된 SAM Codex 설정 만들기

```powershell
$CodexSamHome = Join-Path $HOME ".codex-sam"
New-Item -ItemType Directory -Force -Path $CodexSamHome | Out-Null

@'
model = "sam-codex-agent"
model_provider = "sam"
model_reasoning_effort = "medium"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/openai/v1"
env_key = "SAM_CODE_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
'@ | Set-Content -Path (Join-Path $CodexSamHome "config.toml") -Encoding UTF8
```

## 7. 저장소 없이 `sam-codex` 명령 만들기

Git 저장소 없이도 wrapper만 직접 만들 수 있습니다.

```powershell
$BinDir = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

@'
$ErrorActionPreference = "Stop"

$SamHome = Join-Path $HOME ".sam-code-agent"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$EnvFile = Join-Path $SamHome "env.ps1"
$WorkDir = Join-Path $env:TEMP "sam-codex-cli"

if (-not (Test-Path $EnvFile)) {
    Write-Host "Missing $EnvFile. Create your SAM Code Agent key file first."
    exit 1
}

. $EnvFile
$env:CODEX_HOME = $CodexSamHome
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Set-Location $WorkDir

$SamCodexConfig = @(
    "-c", "model=`"sam-codex-agent`"",
    "-c", "model_provider=`"sam`"",
    "-c", "model_reasoning_effort=`"medium`"",
    "-c", "model_providers.sam.name=`"SAM`"",
    "-c", "model_providers.sam.base_url=`"https://sam.soonsoon.ai/openai/v1`"",
    "-c", "model_providers.sam.env_key=`"SAM_CODE_API_KEY`"",
    "-c", "model_providers.sam.wire_api=`"responses`"",
    "-c", "model_providers.sam.request_max_retries=4",
    "-c", "model_providers.sam.stream_max_retries=5",
    "-c", "model_providers.sam.stream_idle_timeout_ms=300000"
)

& codex @SamCodexConfig @args
exit $LASTEXITCODE
'@ | Set-Content -Path (Join-Path $BinDir "sam-codex.ps1") -Encoding UTF8

@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\bin\sam-codex.ps1" %*
"@ | Set-Content -Path (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII
```

PATH에 `%USERPROFILE%\bin`을 추가합니다.

```powershell
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}
$env:Path += ";$BinDir"
```

## 8. 실행 확인

```powershell
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

정상이라면 헤더에 `model: sam-codex-agent`, `provider: sam`이 표시되고
응답은 `SAM-CODEX-OK`입니다. 대화형 CLI는 다음 명령으로 엽니다.

```powershell
sam-codex
```

