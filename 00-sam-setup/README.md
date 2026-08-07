# 0. SAM 환경과 공용 API 키 테스트

**언어:** 한국어 | [English](README.en.md)

`sam-codex`와 `sam-claude`가 함께 쓸 하나의 `SAM_API_KEY`를 표준 로컬
폴더 `~/.sam/`에 저장합니다. 설치 전에 아래 순서로 환경, 키, 두 Coding
Agent 권한을 분리해 확인합니다.

## 표준 경로

```text
~/.sam/
  env       # macOS/Linux
  env.ps1   # Windows PowerShell
  skills/   # 에이전트가 읽을 SAM 스킬 문서
```

다른 키 파일을 에이전트별로 만들지 마세요. 키를 교체한 뒤에는 이미 실행
중인 CLI나 에이전트를 다시 시작해야 새 키를 읽습니다.

## 1. SAM 사용 환경 테스트

키 없이 서비스 연결과 API health만 확인합니다. 이 호출은 모델을 생성하지
않습니다. 공개 도메인의 `/readyz`는 현재 Web 응답으로 라우팅될 수 있으므로
초기 연결 확인에는 API health 경로인 `/health`를 사용합니다.

```bash
curl -fsS --max-time 10 https://sam.soonsoon.ai/health
```

```powershell
(Invoke-WebRequest -TimeoutSec 10 -Uri "https://sam.soonsoon.ai/health").StatusCode
```

JSON health 응답 또는 HTTP `200`이면 네트워크·DNS·TLS·SAM API 진입점이
응답한 것입니다. 이 결과만으로 API 키나 모델 provider까지 정상이라고
판단하면 안 됩니다. `/readyz`에서 SAM 웹 페이지 HTML이 나오면 로컬 설정
문제가 아니라 운영 라우팅 상태이므로, 아래 인증 discovery를 별도로
확인하세요.

## 2. 공용 SAM API 키 저장

키를 명령문에 직접 쓰지 말고 숨김 입력으로 받습니다.

### macOS / Linux

```bash
mkdir -p "$HOME/.sam"
chmod 700 "$HOME/.sam"
printf "SAM API 키 입력: "
stty -echo
IFS= read -r SAM_API_KEY
stty echo
printf "\n"
printf 'export SAM_API_KEY=%q\n' "$SAM_API_KEY" > "$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
unset SAM_API_KEY
source "$HOME/.sam/env"
```

### Windows PowerShell

```powershell
$SamHome = Join-Path $HOME ".sam"
New-Item -ItemType Directory -Force -Path $SamHome | Out-Null
$secure = Read-Host "SAM API 키 입력" -AsSecureString
$key = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
$safeKey = $key.Replace("'", "''")
Set-Content -Path (Join-Path $SamHome "env.ps1") -Encoding UTF8 `
  -Value "`$env:SAM_API_KEY = '$safeKey'"
icacls (Join-Path $SamHome "env.ps1") /inheritance:r `
  /grant:r "$($env:USERNAME):F" | Out-Null
. (Join-Path $SamHome "env.ps1")
$key = $null
$safeKey = $null
```

키 전체나 앞부분을 출력하지 마세요. installer를 실행하면 기존 표준 키를
재사용하며, 현재 터미널의 `SAM_API_KEY`에 새 키가 있으면 표준 파일을
갱신합니다.

## 3. 키와 Coding Agent 권한 테스트

같은 키로 OpenAI/Codex와 Anthropic/Claude Code discovery를 각각 확인합니다.
두 요청 모두 모델을 생성하지 않으므로 모델 사용량이 없습니다.

### macOS / Linux

```bash
source "$HOME/.sam/env"

curl -sS --max-time 15 -o /dev/null \
  -w "SAM OpenAI discovery: HTTP %{http_code}\n" \
  https://sam.soonsoon.ai/v2/openai/models \
  -H "Authorization: Bearer $SAM_API_KEY"

curl -sS --max-time 15 -o /dev/null \
  -w "SAM Anthropic discovery: HTTP %{http_code}\n" \
  https://sam.soonsoon.ai/v2/anthropic/v1/models \
  -H "Authorization: Bearer $SAM_API_KEY"
```

### Windows PowerShell

```powershell
. "$HOME\.sam\env.ps1"
$headers = @{ Authorization = "Bearer $env:SAM_API_KEY" }

(Invoke-WebRequest -TimeoutSec 15 `
  -Uri "https://sam.soonsoon.ai/v2/openai/models" `
  -Headers $headers).StatusCode

(Invoke-WebRequest -TimeoutSec 15 `
  -Uri "https://sam.soonsoon.ai/v2/anthropic/v1/models" `
  -Headers $headers).StatusCode
```

## 결과 해석

| 결과 | 의미 | 조치 |
| --- | --- | --- |
| 두 discovery 모두 `200` | 키와 두 Coding Agent 권한 정상 | 설치 진행 |
| `401 AUTH_INVALID` | 키가 잘못됐거나 폐기됨 | SAM에서 활성 키를 확인하고 다시 저장 |
| `403` | 키는 인식됐지만 해당 Agent 권한 없음 | 계정/키의 Coding Agent 권한 확인 |
| `404` | 오래된 URL 또는 잘못된 base URL | 반드시 이 문서의 V2 URL 사용 |
| timeout / HTTP `000` | 네트워크 또는 SAM runtime 문제 | readiness와 discovery 결과를 분리해 보고 |

`/health`의 `200`은 API health만 뜻합니다. 인증된 discovery의 `200`이
나오기 전에는 CLI 설정 문제로 단정하거나 유료 생성 테스트를 실행하지
마세요.

## 선택: 실제 생성까지 확인

`Hello SAM`은 실제 모델을 호출하므로 소량의 SAM 사용량이 기록될 수
있습니다. 비용 없는 discovery가 성공한 뒤에만 실행합니다.

### macOS / Linux

```bash
curl -sS -X POST https://sam.soonsoon.ai/v1/hello \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"안녕 SAM"}'
```

### Windows PowerShell

PowerShell의 `curl`은 `Invoke-WebRequest` 별칭일 수 있고, Unix용 `\` 줄
연결도 동작하지 않습니다. PowerShell 명령을 그대로 사용하세요.

```powershell
. "$HOME\.sam\env.ps1"

$headers = @{
  Authorization = "Bearer $env:SAM_API_KEY"
  "Content-Type" = "application/json"
}
$body = @{ greeting = "안녕 SAM" } | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/v1/hello" `
  -Headers $headers `
  -Body $body
```

실제 curl을 사용하려면 `curl` 대신 `curl.exe`를 쓰고 PowerShell 환경변수는
`$env:SAM_API_KEY`로 참조합니다.

## 공용 키 최종 삭제

먼저 `sam-codex`와 `sam-claude`를 각각 해제합니다. 그 후에만 공용 키 삭제
스크립트를 실행합니다.

```bash
./remove-shared-key-macos.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\remove-shared-key-windows.ps1
```

이미 열린 macOS/Linux 터미널에서는 마지막으로 `unset SAM_API_KEY`를
실행합니다.
