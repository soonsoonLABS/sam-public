# Windows에서 SAM Codex 사용하기

**언어:** [English](../windows.md) | 한국어

이 가이드는 전용 `sam-codex` 터미널 명령을 만듭니다. 이 명령으로만 SAM을
사용하므로 기존 `codex` 환경은 바뀌지 않습니다.

## 1. 사전 도구 설치

`sam-public`을 내려받거나 SAM 설치 프로그램을 실행하기 전에 Git,
Node.js LTS(npm 포함), Codex CLI를 설치합니다.

```powershell
winget install -e --id Git.Git
winget install -e --id OpenJS.NodeJS.LTS
```

PowerShell을 완전히 닫고 새 창을 연 뒤 다음을 실행합니다.

```powershell
node --version
npm --version

# npm.ps1 스크립트가 차단되었다는 오류가 있을 때만 실행합니다.
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

npm install -g @openai/codex@latest
git --version
codex --version
```

`winget`이 없다면 Git과 Node.js LTS 공식 설치 프로그램을 사용하고, 설치
후 새 PowerShell 창을 열어 다음 단계로 진행하세요.

### `codex` 명령이 보이지 않을 때

Windows의 npm 전역 명령은 일반적으로 사용자 npm prefix에 설치됩니다.
다음을 실행해 현재 PowerShell과 이후 사용자 PATH에 추가합니다.

```powershell
npm prefix -g
Get-Command codex -ErrorAction SilentlyContinue
$npmBin = npm prefix -g
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$npmBin", "User")
$env:Path += ";$npmBin"
codex --version
```

그래도 보이지 않으면 모든 PowerShell 창을 닫고 새 창을 여세요.

## 2. 설치 저장소 내려받기 또는 업데이트

처음 한 번만 저장소를 내려받습니다. 이후에는 `git clone`을 다시 하지
말고 기존 저장소를 업데이트합니다.

```powershell
$Repo = "$HOME\sam-public"
if (Test-Path "$Repo\.git") {
  git -C $Repo pull --ff-only
}
elseif (Test-Path $Repo) {
  throw "$Repo 경로는 존재하지만 Git 저장소가 아닙니다. 내용을 확인한 뒤에만 이름 변경 또는 삭제하세요."
}
else {
  git clone https://github.com/soonsoonLABS/sam-public.git $Repo
}

Set-Location "$Repo\code-agent"
```

## 3. 전용 SAM 명령 설치

설치 프로그램을 실행하고 숨김 입력창에만 SAM API 키를 붙여 넣습니다.
키 소유자에게 `agent:codex` 또는 `agent:coding_agents` 권한이 있어야
합니다.

```powershell
Remove-Item Env:SAM_API_KEY -ErrorAction SilentlyContinue
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

설치 프로그램은 `%USERPROFILE%\bin\sam-codex.cmd`를 만들고 사용자 PATH에
그 폴더를 추가합니다. 키는 `%USERPROFILE%\.sam-code-agent\env.ps1`에
로컬 저장됩니다. `sam-codex`가 보이지 않으면 새 PowerShell 창을 여세요.

## 4. SAM Codex 실행

SAM 세션에서는 일반 `codex`가 아니라 항상 `sam-codex`를 사용합니다.

```powershell
# SAM을 사용하는 대화형 Codex 터미널 UI
sam-codex

# 비대화형 스모크 테스트
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

스모크 테스트의 정상 응답은 정확히 `SAM-CODEX-OK`입니다. PATH에 아직
명령이 없다면 전체 경로를 사용합니다.

```powershell
& "$HOME\bin\sam-codex.ps1" exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

## 5. SAM API 키 변경

설치 프로그램을 다시 실행합니다. 현재 프로세스에서 `SAM_API_KEY`를 지우는
것은 상속된 기존 키 대신 숨김 입력창을 표시하게 하므로 중요합니다.

```powershell
Set-Location "$HOME\sam-public\code-agent"
Remove-Item Env:SAM_API_KEY -ErrorAction SilentlyContinue
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

이 작업은 일반 Codex 설정이 아니라 `%USERPROFILE%\.sam-code-agent\env.ps1`만
덮어씁니다. 더 이상 사용하지 않는 이전 키는 SAM에서 폐기하세요.

## 6. 키 직접 호출 테스트

Codex를 거치기 전에 SAM 키와 `/openai/v1/responses` 경로를 확인합니다.
키 자체는 출력하지 않으며, 마지막 줄은 `SAM-CODEX-OK`여야 합니다.

```powershell
. "$HOME\.sam-code-agent\env.ps1"
$body = @{
  model = "sam-codex-agent"
  input = "Reply with exactly: SAM-CODEX-OK"
  stream = $false
  reasoning = @{ effort = "medium"; summary = "none" }
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/openai/v1/responses" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body $body

$response.output_text
Remove-Item Env:SAM_API_KEY -ErrorAction SilentlyContinue
```

직접 호출은 성공하지만 `sam-codex exec`가 실패하면 키와 SAM 경로는 정상입니다.
설치 프로그램을 다시 실행한 뒤 일반 `codex`가 아닌 전용 명령을 사용하세요.

## 7. 데스크톱 바로가기 만들기

설치가 끝난 뒤 데스크톱에 `SAM-Codex` 바로가기를 만듭니다. 이 바로가기는
전용 SAM Codex 터미널 UI를 엽니다.

```powershell
$Desktop = [Environment]::GetFolderPath("Desktop")
$Target = "$HOME\bin\sam-codex.cmd"
$Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $Desktop "SAM-Codex.lnk"))
$Shortcut.TargetPath = $Target
$Shortcut.WorkingDirectory = $HOME
$Shortcut.IconLocation = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe,0"
$Shortcut.Save()
```

데스크톱의 `SAM-Codex`를 더블클릭하면 SAM 세션이 시작됩니다.

## 선택: 기존 Windows Codex 데스크톱 앱을 SAM으로 전환

전용·권장 경로는 터미널의 `sam-codex`입니다. CLI 스모크 테스트가 성공한
뒤에만 데스크톱 전환기를 사용하세요. 이 전환기는 ChatGPT 데스크톱 앱이
SAM을 사용하도록 일반 `%USERPROFILE%\.codex\config.toml`을 임시 변경합니다.
별도 SAM-Codex 데스크톱 앱을 설치하는 기능은 아닙니다.

전환 전 복원 경로를 확인하세요. 스크립트는 기존 Codex 설정을 백업한 뒤
바꿉니다. 기존 데스크톱 앱을 바로 이전 프로필로 되돌리려면
`sam-public\code-agent` 폴더에서 다음을 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\restore-windows-desktop-default.ps1
```

```powershell
Set-Location "$HOME\sam-public\code-agent"
powershell -ExecutionPolicy Bypass -File .\enable-windows-desktop-sam.ps1
```

ChatGPT/Codex 데스크톱 앱을 완전히 종료한 뒤 다시 엽니다. 일반 프로필로
되돌리려면 다음을 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\restore-windows-desktop-default.ps1
```

복원 스크립트는 백업한 설정을 되돌립니다. 전환 후 데스크톱 앱이 실행되지
않거나 잘못된 프로필이 보이면 앱을 완전히 종료하고 위 복원 명령을 실행한
뒤 다시 여세요. 새로 만든 SAM 사용자 환경변수는 복원 스크립트가 제거합니다.
기존에 다른 사용자 수준 `SAM_API_KEY`가 있다면 전환기는 그 키를 덮어쓰지
않고 중단합니다.
