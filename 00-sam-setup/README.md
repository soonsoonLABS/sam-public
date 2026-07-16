# 0. SAM 최초 환경 설정

SAM API 키를 현재 터미널에 안전하게 넣고, `Hello SAM`으로 실제 호출을
확인하는 가장 짧은 시작 방법입니다.

> 키는 현재 터미널 창을 닫으면 사라집니다. 키를 Git, `.env`, URL, 캡처,
> 명령 기록에 저장하거나 공유하지 마세요.

## macOS

### 1. 키 입력

아래 명령을 입력한 뒤 SAM 키를 붙여넣고 Enter를 누릅니다. 입력 중에는
키가 화면에 보이지 않습니다.

```bash
read -s "SAM_API_KEY?SAM 키 입력: "
echo
export SAM_API_KEY
```

### 2. 키 앞부분 확인

전체 키를 출력하지 않고 앞 12자리만 확인합니다.

```bash
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

### 1. 키 입력

아래를 실행한 뒤 SAM 키를 붙여넣고 Enter를 누릅니다. 입력 중에는 키가
화면에 보이지 않습니다.

```powershell
$secure = Read-Host "SAM 키 입력" -AsSecureString
$env:SAM_API_KEY = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
```

### 2. 키 앞부분 확인

```powershell
$env:SAM_API_KEY.Substring(0,12) + "..."
```

### 3. Hello SAM 테스트

영어 인사에는 영어 농담이 한 줄로 반환됩니다.

```powershell
$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/v1/hello" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body '{"greeting":"Hello SAM"}'

$response.joke
```

## 성공 기준

농담 한 줄이 반환되면 API 키, 네트워크, SAM 인증, 그리고 실제 모델 호출이
정상입니다. `Hello SAM`은 실제 모델을 호출하므로 소량의 SAM 사용량이
기록됩니다.

---

# 0. First SAM Setup

This is the shortest way to safely load a SAM API key into your current terminal
and confirm that a real `Hello SAM` call works.

> The key disappears when you close the current terminal window. Do not save or
> share API keys in Git, `.env` files, URLs, screenshots, or command history.

## macOS

### 1. Enter your key

Run the command below, paste your SAM key, then press Enter. The key will not be
shown while you type or paste it.

```bash
read -s "SAM_API_KEY?Enter SAM key: "
echo
export SAM_API_KEY
```

### 2. Check the key prefix

Print only the first 12 characters, not the full key.

```bash
echo "${SAM_API_KEY:0:12}..."
```

### 3. Test Hello SAM

An English greeting returns a short one-line English joke.

```bash
curl -s -X POST https://sam.soonsoon.ai/v1/hello \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"Hello SAM"}' \
  | sed -E 's/.*"joke":"([^"]*)".*/\1/'
```

## Windows PowerShell

### 1. Enter your key

Run the commands below, paste your SAM key, then press Enter. The key will not be
shown while you type or paste it.

```powershell
$secure = Read-Host "Enter SAM key" -AsSecureString
$env:SAM_API_KEY = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
```

### 2. Check the key prefix

```powershell
$env:SAM_API_KEY.Substring(0,12) + "..."
```

### 3. Test Hello SAM

```powershell
$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/v1/hello" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body '{"greeting":"Hello SAM"}'

$response.joke
```

## Success Criteria

If you get one short joke back, your API key, network connection, SAM
authentication, and real model call are working. `Hello SAM` calls a real model,
so a small amount of SAM usage is recorded.
