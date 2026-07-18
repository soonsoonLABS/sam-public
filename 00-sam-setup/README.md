# 0. SAM 최초 환경 설정

**언어:** 한국어 | [English](README.en.md)

SAM API 키를 사용자 기기의 표준 로컬 폴더 `~/.sam/`에 저장하고, 현재
터미널에서 불러온 뒤, `Hello SAM`으로 실제 호출을 확인하는 시작 방법입니다.

> 키 파일은 Git 저장소 밖의 사용자 기기에만 저장합니다. 키를 문서, 이슈,
> 명령 기록, URL, 캡처에 넣거나 공유하지 마세요.

## 표준 경로

```text
~/.sam/
  env       # macOS/Linux
  env.ps1   # Windows PowerShell
  skills/   # 에이전트가 읽을 SAM 스킬 문서
```

모든 에이전트는 위 경로만 읽게 맞춥니다. `~/.config/sam/.env`처럼 다른 키
파일을 새로 만들지 마세요. 키를 교체한 뒤에는 이미 실행 중인 CLI나
에이전트 프로세스를 다시 시작해야 새 키를 읽습니다.

## macOS

### 1. 키 저장

아래 명령을 입력한 뒤 SAM 키를 붙여넣고 Enter를 누릅니다. 입력 중에는
키가 화면에 보이지 않습니다.

```bash
mkdir -p "$HOME/.sam"
chmod 700 "$HOME/.sam"
read -s "SAM_API_KEY?SAM 키 입력: "
echo
printf "export SAM_API_KEY='%s'\n" "$SAM_API_KEY" > "$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
source "$HOME/.sam/env"
```

### 2. 키 앞부분 확인

전체 키를 출력하지 않고 앞 12자리만 확인합니다.

```bash
source "$HOME/.sam/env"
echo "${SAM_API_KEY:0:12}..."
```

### 3. Hello SAM 테스트

한국어 인사에는 한국어 농담이 한 줄로 반환됩니다.

```bash
curl -s -X POST https://sam.soonsoon.ai/v1/hello \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"안녕 SAM"}' \
  | sed -E 's/.*"joke":"([^"]*)".*/\1/'
```

## Windows PowerShell

### 1. 키 저장

아래를 실행한 뒤 SAM 키를 붙여넣고 Enter를 누릅니다. 입력 중에는 키가
화면에 보이지 않습니다.

```powershell
$SamHome = Join-Path $HOME ".sam"
New-Item -ItemType Directory -Force -Path $SamHome | Out-Null
$secure = Read-Host "SAM 키 입력" -AsSecureString
$key = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
Set-Content -Path (Join-Path $SamHome "env.ps1") -Encoding UTF8 -Value "`$env:SAM_API_KEY = '$key'"
icacls (Join-Path $SamHome "env.ps1") /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
. (Join-Path $SamHome "env.ps1")
```

### 2. 키 앞부분 확인

```powershell
. "$HOME\.sam\env.ps1"
$env:SAM_API_KEY.Substring(0,12) + "..."
```

### 3. Hello SAM 테스트

PowerShell에서는 macOS용 `curl`, `-H`, `-d`, `\` 줄바꿈 문법을 쓰지
마세요. 아래 PowerShell 블록 전체를 그대로 사용합니다.

```powershell
(Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/v1/hello" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body (@{ greeting = "안녕 SAM" } | ConvertTo-Json)).joke
```

## 키 교체

새 키를 넣을 때는 위의 키 저장 단계를 다시 실행해서 `~/.sam/env` 또는
`~/.sam/env.ps1`만 덮어씁니다. 오래된 키는 SAM 웹의 **API Keys**에서
폐기하세요.

## 성공 기준

농담 한 줄이 반환되면 API 키, 네트워크, SAM 인증, 그리고 실제 모델 호출이
정상입니다. `Hello SAM`은 실제 모델을 호출하므로 소량의 SAM 사용량이
기록됩니다.
