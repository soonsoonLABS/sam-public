# SAM-Claude Windows 설치·검증

[빠른 시작으로 돌아가기](./README.md) · [English](./WINDOWS_SETUP.en.md)

이 문서는 Windows PowerShell에서 공식 `claude`와 분리된 `sam-claude`를
설치하고 확인하는 순서입니다.

| 명령 | 연결 | 설정·세션 |
| --- | --- | --- |
| `claude` | Anthropic 직접 연결 | `%USERPROFILE%\.claude` |
| `sam-claude` | SAM `/v2/claude` + SAM MCP | `%USERPROFILE%\.claude-sam` |

공식 `claude`, `%USERPROFILE%\.claude`, 공식 로그인과 프로젝트 설정은
변경하지 않습니다. 공용 키는 `%USERPROFILE%\.sam\env.ps1`에서 읽습니다.

## PowerShell 문법

- PowerShell의 `curl`은 `Invoke-WebRequest` 별칭일 수 있습니다. HTTP 호출은
  `Invoke-RestMethod`/`Invoke-WebRequest`를 사용하거나 `curl.exe`를 명시하세요.
- Unix의 `\` 줄 연결 대신 PowerShell의 백틱 `` ` ``을 사용합니다.
- 환경변수는 `$SAM_API_KEY`가 아니라 `$env:SAM_API_KEY`입니다.
- 키 값, 키의 길이·앞부분·파일 내용은 출력하지 않습니다.

## 1. 공식 Claude Code 준비

```powershell
claude --version
```

Claude Code `2.1.129` 이상이 필요합니다. 낮은 버전이면
[Anthropic 공식 설치 안내](https://code.claude.com/docs/en/setup)에 따라
업데이트한 뒤 새 PowerShell 창에서 다시 확인합니다.

## 2. 권장: Windows 설치 파일로 설치

어느 폴더에서 실행해도 됩니다.

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-windows.ps1')))
```

`SAM API key`를 묻는 경우 숨김 입력으로 입력합니다. 이미
`%USERPROFILE%\.sam\env.ps1`가 있으면 기존 키를 재사용합니다. 설치 과정은
생성 호출 없이 `/v2/claude/v1/models` discovery와 Haiku/Sonnet/Opus 역할
매핑을 검증합니다.

설치 후 PowerShell 창을 새로 열어 PATH를 갱신합니다.

## 3. 생성 없는 연결 확인

```powershell
Get-Command sam-claude
sam-claude --version
sam-claude mcp list
```

다음 상태를 확인합니다.

- `sam-claude`가 `%USERPROFILE%\bin\sam-claude.cmd`에서 발견됨
- `/v2/claude/v1/models` discovery와 저장된 역할 매핑이 일치함
- `sam-tools`와 `https://sam.soonsoon.ai/mcp`가 표시됨
- 공식 `claude`의 설정 홈은 `%USERPROFILE%\.claude`로 그대로임

Claude Code 안에서 `/model`을 실행해 SAM 웹에서 선택한 Haiku/Sonnet/Opus와
실제로 discovery된 `claude-sam-*` 호환 모델만 표시되는지 확인합니다. 모델 ID를
직접 만들거나 추측하지 마세요.

## 4. 실제 대화 확인(사용량 발생)

```powershell
$TestProject = Join-Path $HOME "SAM-Claude-Test"
New-Item -ItemType Directory -Force $TestProject | Out-Null
Set-Location $TestProject

sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

이 단계부터 SAM 사용량과 비용이 기록될 수 있습니다. 응답이 정확히
`SAM-CLAUDE-OK`인지 확인합니다. 이후 대화형 실행은 `sam-claude`이고, 공식
Anthropic 환경으로 돌아갈 때는 `claude`입니다.

## 5. 수동 설정(설치 파일을 실행하지 않는 경우)

아래는 공개 저장소의 `templates/sam-claude.ps1`를 검증 wrapper로 사용하는
최소 구성입니다. 저장소 ZIP을 풀었거나 `git clone`한 경로를 사용하세요.

### 5.1 표준 키와 격리 폴더

```powershell
$PublicRoot = Join-Path $HOME "sam-public"
$ClaudeRoot = Join-Path $PublicRoot "03-Code-Agent-Claude"
$SamHome = Join-Path $HOME ".sam"
$ClaudeSamHome = Join-Path $HOME ".claude-sam"
$BinDir = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force -Path $SamHome, $ClaudeSamHome, $BinDir | Out-Null

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

### 5.2 wrapper의 생성 없는 preflight

```powershell
$WrapperSource = Join-Path $ClaudeRoot "templates\sam-claude.ps1"
$StateTemp = Join-Path ([IO.Path]::GetTempPath()) (
  "sam-claude-state-{0}.json" -f [guid]::NewGuid().ToString("N")
)
$oldStatePath = $env:SAM_CLAUDE_STATE_PATH
$oldPreflight = $env:SAM_CLAUDE_PREFLIGHT_ONLY
try {
  $env:SAM_CLAUDE_STATE_PATH = $StateTemp
  $env:SAM_CLAUDE_PREFLIGHT_ONLY = "1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File $WrapperSource
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $StateTemp)) {
    throw "SAM-Claude discovery 또는 역할 매핑 검증에 실패했습니다."
  }
}
finally {
  $env:SAM_CLAUDE_STATE_PATH = $oldStatePath
  $env:SAM_CLAUDE_PREFLIGHT_ONLY = $oldPreflight
}
```

이 검증은 `/v2/claude/v1/models`와 저장된 역할 매핑을 대조하며 모델을
생성하지 않습니다. 실패하면 오래된 모델 ID를 직접 넣어 계속하지 마세요.

### 5.3 SAM MCP와 명령 등록

```powershell
$env:CLAUDE_CONFIG_DIR = $ClaudeSamHome
claude mcp add --transport http --scope user `
  sam-tools "https://sam.soonsoon.ai/mcp" `
  --header 'Authorization: Bearer ${SAM_API_KEY}'

Copy-Item $WrapperSource (Join-Path $BinDir "sam-claude.ps1") -Force
Set-Content (Join-Path $BinDir "sam-claude.cmd") -Encoding ASCII `
  -Value "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\bin\sam-claude.ps1`" %*"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($UserPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
}
Remove-Item $StateTemp -Force -ErrorAction SilentlyContinue
```

새 PowerShell 창을 열고 3~4단계 검증을 다시 실행합니다. `claude`의 MCP나
`%USERPROFILE%\.claude`는 수정하지 않습니다.

## 삭제

기본 삭제는 명령과 관리 파일만 제거합니다.

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1')))
```

격리된 SAM-Claude 세션과 설정까지 백업 폴더로 옮기려면:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1'))) -PurgeData
```

공식 `claude`, `%USERPROFILE%\.claude`, 공용 키, `sam-codex`는 보존됩니다.
공용 키까지 삭제할 때는 두 SAM wrapper를 모두 해제한 뒤
`00-sam-setup\remove-shared-key-windows.ps1`을 별도로 실행합니다.

## 문제 분리

| 증상 | 먼저 확인할 것 |
| --- | --- |
| `curl`의 `-sS` 오류 | `curl` 대신 PowerShell cmdlet 또는 `curl.exe` 사용 |
| `sam-claude`를 찾지 못함 | 새 PowerShell 창, 사용자 PATH, `%USERPROFILE%\bin` |
| `401` | `env.ps1` dot-source 여부와 `agent:claude_code` 권한 |
| 모델 매핑 오류 | SAM 웹 역할 매핑과 authenticated discovery의 일치 여부 |
| MCP 없음 | `CLAUDE_CONFIG_DIR`와 `SAM_API_KEY` 환경변수 참조 확인 |
| discovery timeout | 네트워크/SAM runtime 문제와 Claude CLI 문제를 분리 |
