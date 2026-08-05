# SAM-Codex Windows 설치·검증

[빠른 시작으로 돌아가기](./README.md) · [English](./WINDOWS_SETUP.en.md)

이 문서는 Windows PowerShell에서 공식 `codex`와 분리된 `sam-codex`를
설치하고 확인하는 순서입니다.

| 명령 | 연결 | 설정 홈 |
| --- | --- | --- |
| `codex` | OpenAI / ChatGPT 직접 연결 | `%USERPROFILE%\.codex` |
| `sam-codex` | SAM V2 + SAM MCP | `%USERPROFILE%\.codex-sam` |

공식 `codex`, `%USERPROFILE%\.codex`, OpenAI 로그인은 변경하지 않습니다.
공용 키는 `%USERPROFILE%\.sam\env.ps1`에만 저장하며 키 값을 TOML, 명령줄,
문서에 넣지 않습니다.

## PowerShell 문법

- PowerShell의 `curl`은 `Invoke-WebRequest` 별칭일 수 있습니다. HTTP 호출은
  `Invoke-RestMethod`/`Invoke-WebRequest`를 사용하거나 `curl.exe`를 명시하세요.
- Unix의 `\` 줄 연결 대신 PowerShell의 백틱 `` ` ``을 사용합니다.
- 환경변수는 `$SAM_API_KEY`가 아니라 `$env:SAM_API_KEY`입니다.
- 키 값, 키의 길이·앞부분·파일 내용은 출력하지 않습니다.

## 1. 공식 Codex 준비

관리자 권한 없이 현재 사용자에만 실행 정책을 설정합니다.

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
npm install -g @openai/codex@0.146.0
codex --version
```

SAM-Codex가 현재 검증하는 버전은 `0.145.x`와 `0.146.0`입니다. 다른 버전은
검증 전까지 사용하지 마세요.

## 2. 권장: 설치 파일로 설치

공개 저장소를 내려받아 파일을 먼저 확인합니다. Git이 없으면 GitHub의 ZIP을
내려받아 같은 폴더 구조로 압축을 푼 뒤 `Set-Location`만 바꾸면 됩니다.

```powershell
$PublicRoot = Join-Path $HOME "sam-public"
if (-not (Test-Path (Join-Path $PublicRoot ".git"))) {
  git clone https://github.com/soonsoonLABS/sam-public.git $PublicRoot
}
Set-Location (Join-Path $PublicRoot "02-Code-Agent-Codex")
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

`SAM API key`를 묻는 경우 숨김 입력으로 입력합니다. 이미
`%USERPROFILE%\.sam\env.ps1`가 있으면 기존 키를 재사용합니다.

설치가 끝나면 PowerShell 창을 새로 열어 PATH를 갱신합니다.

## 3. 생성 없는 설치·연결 확인

```powershell
Get-Command sam-codex
sam-codex --version
sam-codex mcp list
```

다음 상태를 확인합니다.

- `sam-codex`가 `%USERPROFILE%\bin\sam-codex.cmd`에서 발견됨
- 모델 refresh/discovery가 성공함
- `sam-tools`와 `https://sam.soonsoon.ai/mcp`가 표시됨
- 공식 `codex`의 설정 홈은 `%USERPROFILE%\.codex`로 그대로임

`sam-codex --version`은 모델 생성 없이 discovery만 수행합니다. 모델 목록은
SAM Agent 페이지에서 현재 계정에 허용된 항목만 반환되며, 모델 ID를 문서에
직접 고정하지 않습니다.

## 4. 실제 대화 확인(사용량 발생)

먼저 테스트 폴더에서 실행합니다. 홈 디렉터리에서 실행하지 마세요.

```powershell
$TestProject = Join-Path $HOME "SAM-Codex-Test"
New-Item -ItemType Directory -Force $TestProject | Out-Null
Set-Location $TestProject

sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral `
  "Reply with exactly: SAM-CODEX-OK"
```

이 단계부터 SAM 사용량과 비용이 기록될 수 있습니다. 응답이 정확히
`SAM-CODEX-OK`인지 확인합니다.

Codex 안에서는 `/model`을 열어 SAM Agent 페이지에 선택된 native 또는 인증된
호환 모델이 표시되는지 확인합니다. 화면 제목 `OpenAI Codex`는 정상이며,
`sam-codex`의 provider와 모델 discovery가 SAM 연결을 의미합니다.

## 5. 수동 설정(설치 파일을 실행하지 않는 경우)

아래는 공개 저장소의 `templates`를 그대로 사용하는 최소 구성입니다.

### 5.1 표준 키와 폴더

```powershell
$SamHome = Join-Path $HOME ".sam"
$CodexSamHome = Join-Path $HOME ".codex-sam"
$BinDir = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force -Path $SamHome, $CodexSamHome, $BinDir | Out-Null

$EnvFile = Join-Path $SamHome "env.ps1"
if (-not (Test-Path $EnvFile)) {
  $secure = Read-Host "SAM API key" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    $safeKey = $key.Replace("'", "''")
    Set-Content -Path $EnvFile -Encoding UTF8 `
      -Value "`$env:SAM_API_KEY = '$safeKey'"
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    Remove-Variable key, safeKey -ErrorAction SilentlyContinue
  }
  icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
}
. $EnvFile
if ([string]::IsNullOrWhiteSpace($env:SAM_API_KEY)) {
  throw "SAM_API_KEY가 로드되지 않았습니다."
}
```

### 5.2 인증된 discovery 확인

```powershell
$headers = @{ Authorization = "Bearer $env:SAM_API_KEY" }
$catalog = Invoke-RestMethod -TimeoutSec 20 `
  -Uri "https://sam.soonsoon.ai/v2/codex/models" -Headers $headers
$models = @($catalog.models | Where-Object {
  $_.visibility -eq "list" -and $_.supported_in_api -eq $true
})
if ($models.Count -lt 1) { throw "사용 가능한 SAM-Codex 모델이 없습니다." }
$models | Select-Object slug, display_name
$SelectedModel = [string]$models[0].slug
if ($SelectedModel -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
  throw "discovery 모델 ID 형식이 안전하지 않습니다."
}
```

이 요청은 모델 생성이 아니며 사용량이 발생하지 않습니다. 반환된 모델만
선택할 수 있습니다.

### 5.3 설정·wrapper·명령 등록

```powershell
@"
model = "$SelectedModel"
model_provider = "sam"
model_catalog_json = "models_cache.json"
web_search = "disabled"
project_root_markers = [".git", ".sam-codex-root"]

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/codex"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
required = true
"@ | Set-Content (Join-Path $CodexSamHome "config.toml") -Encoding UTF8

$PublicRoot = Join-Path $HOME "sam-public"
$CodeRoot = Join-Path $PublicRoot "02-Code-Agent-Codex"
Copy-Item (Join-Path $CodeRoot "templates\sam-codex.ps1") `
  (Join-Path $BinDir "sam-codex.ps1") -Force
Set-Content (Join-Path $BinDir "sam-codex.cmd") -Encoding ASCII `
  -Value "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-codex.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($UserPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}
```

새 PowerShell 창을 연 뒤 3~4단계 검증을 다시 실행합니다. 공식 복귀는
`codex`를 실행하면 됩니다.

## 삭제

```powershell
Set-Location (Join-Path $HOME "sam-public\02-Code-Agent-Codex")
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

공식 `codex`, `%USERPROFILE%\.codex`, 공용 키, `sam-claude`는 보존됩니다.
공용 키까지 삭제할 때는 두 SAM wrapper를 모두 해제한 뒤
`00-sam-setup\remove-shared-key-windows.ps1`을 별도로 실행합니다.

## 문제 분리

| 증상 | 먼저 확인할 것 |
| --- | --- |
| `curl`의 `-sS` 오류 | `curl` 대신 PowerShell cmdlet 또는 `curl.exe` 사용 |
| `sam-codex`를 찾지 못함 | 새 PowerShell 창, 사용자 PATH, `%USERPROFILE%\bin` |
| `401` | `env.ps1` dot-source 여부와 Agent grant |
| `404 Unknown model` | discovery에 없는 ID를 직접 입력하지 않았는지 |
| `sam-tools` 없음 | `config.toml`의 MCP URL와 `SAM_API_KEY` 환경변수 이름 |
| discovery timeout | 네트워크/SAM runtime 문제와 CLI 문제를 분리 |

현재 Windows installer 자체의 반복 설치 문제는 공개 Issue #23에서 추적합니다.
그 문제가 나타나면 추가 삭제나 키 재입력 대신 이 문서의 수동 경로를 사용하고
이슈 상태를 먼저 확인하세요.
