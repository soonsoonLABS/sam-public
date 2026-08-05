# SAM-Claude 빠른 시작

공식 Anthropic `claude`는 그대로 두고, SAM 전용 `sam-claude`를 추가합니다.

**언어:** 한국어 | [English](./README.en.md)

| 실행 명령 | 연결 | 설정·세션 |
| --- | --- | --- |
| `claude` | Anthropic 직접 연결 | `~/.claude` |
| `sam-claude` | SAM `/v2/claude` + SAM MCP | `~/.claude-sam` |

> 처음 설치한다면 아래 **1~3단계만** 진행하세요.

## 준비

- SAM의 **Agent > Claude Code** 사용 권한과 SAM API Key
- 공식 Claude Code `2.1.129` 이상
- macOS: `curl`과 Python 3 또는 Node.js
- Windows: PowerShell

Claude Code가 없다면
[Anthropic 공식 설치 안내](https://code.claude.com/docs/en/setup)를 먼저
따르세요. 설치 후 버전을 확인합니다.

```bash
claude --version
```

## 1. 한 줄 설치

어느 폴더에서 실행해도 됩니다.

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-macos.sh) && source "$HOME/.zshrc"
```

### Windows PowerShell

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-windows.ps1')))
```

설치 파일을 쓰지 않는 수동 설정과 Windows 전용 검증 순서는
[Windows 설치 가이드](./WINDOWS_SETUP.md)를 따르세요.

`SAM API key:`가 나오면 키를 붙여 넣고 Enter를 누릅니다. 입력한 문자는
화면에 표시되지 않습니다. 이미 공용 키 파일이 있으면 기존 키를 그대로
재사용하며 다시 묻지 않습니다.

- macOS: `~/.sam/env`
- Windows: `%USERPROFILE%\.sam\env.ps1`

설치 프로그램은 모델 생성 없이 인증된 discovery와 역할 매핑을 검증합니다.
둘이 일치하지 않으면 설치를 중단하고 기존 공식 Claude 환경은 변경하지 않습니다.

## 2. 실행

```bash
sam-claude
```

Windows PowerShell에서도 새 창을 연 뒤 `sam-claude`를 실행합니다.

화면은 공식 Claude Code와 같습니다. `sam-claude`도 공식 Claude Code를
사용하되 설정 홈, 인증, 연결 주소만 SAM 전용으로 격리하기 때문입니다.

## 3. 정상 연결 확인

Claude Code 안에서 `/model`을 실행합니다.

```text
/model
```

다음 항목을 확인하세요.

- SAM 웹에서 선택한 **Haiku / Sonnet / Opus** 모델이 표시됨
- 선택한 Sonnet의 context가 1,000,000 이상일 때만 `sonnet[1m]` 사용 가능
- 별도로 선택한 인증 호환 모델이 있다면 discovery가 반환한
  `claude-sam-*` ID로 표시됨

호환 모델 ID는 직접 만들거나 추측하지 마세요. `/model`에 실제로 반환된 ID만
사용합니다.

SAM MCP 확인:

```bash
sam-claude mcp list
```

`sam-tools`와 `https://sam.soonsoon.ai/mcp`가 표시되면 SAM 검색·페이지 읽기
도구가 연결된 것입니다.

실제 모델 호출 확인:

```bash
sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

Windows PowerShell:

```powershell
sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

설치와 discovery는 생성 호출이 아닙니다. 위 테스트와 실제 대화부터 SAM
사용량과 비용이 기록될 수 있습니다.

## 평소 사용

```bash
claude       # 기존 Anthropic 환경
sam-claude   # SAM 환경
```

두 명령의 로그인, 설정, 세션은 서로 분리됩니다. 설치 프로그램은 공식
`~/.claude`, 공식 로그인, 프로젝트 설정을 수정하지 않습니다.

`sam-claude`는 시작할 때마다 다음 두 정보를 다시 확인합니다.

1. 통합 SAM-Claude 모델 목록: `/v2/claude/v1/models`
2. 계정에 저장된 Claude 역할 매핑: Haiku / Sonnet / Opus

두 결과가 정확히 일치해야 Claude Code를 실행합니다. 네트워크나 검증이
실패하면 이전 cache는 보존하지만 오래된 모델로 실행하지는 않습니다.

## 삭제

기본 삭제는 `sam-claude` 명령과 관리된 셸 설정만 제거합니다. 공식
`claude`, 공용 SAM 키, `sam-codex`, 기존 `~/.claude-sam` 세션과 MCP 설정은
보존합니다.

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-macos.sh) && source "$HOME/.zshrc"
```

SAM-Claude 세션과 격리 설정도 휴지통으로 옮기려면:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-macos.sh) --purge-data && source "$HOME/.zshrc"
```

### Windows PowerShell

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1')))
```

Windows 격리 데이터도 백업 폴더로 옮기려면:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1'))) -PurgeData
```

공용 SAM 키는 SAM-Codex도 사용할 수 있으므로 이 삭제 과정에서는 제거하지
않습니다.

## 다른 설치 방법

- 설치 파일을 먼저 확인하려면
  [install-macos.sh](./install-macos.sh) 또는
  [install-windows.ps1](./install-windows.ps1)을 내려받아 실행하세요.
- 설치 프로그램 없이 직접 구성하려면
  [완전 수동 설정](./MANUAL_SETUP.md)을 따라 하세요.
- Windows에서 설치·수동 설정·검증을 한 번에 보려면
  [Windows 설치 가이드](./WINDOWS_SETUP.md)를 따라 하세요.

## 문제가 생겼다면

`command not found`, 버전, 키, 모델 매핑, `sonnet[1m]`, MCP 문제는
[문제 해결](./TROUBLESHOOTING.md)에서 증상별로 확인하세요.

격리, discovery, 역할 매핑, cache 보안 원리는
[동작 방식](./HOW_IT_WORKS.md)에 정리되어 있습니다.
