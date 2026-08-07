# SAM-Claude 문제 해결

[빠른 시작으로 돌아가기](./README.md)

## `sam-claude: command not found`

macOS:

```bash
source "$HOME/.zshrc"
type sam-claude
```

정상 출력은 `~/.zshrc`의 함수가 `~/.local/bin/sam-claude`를 실행한다고
표시합니다. 그래도 없으면 빠른 시작의 한 줄 설치를 다시 실행하세요.

Windows에서는 새 PowerShell 창을 연 뒤 확인합니다.

```powershell
Get-Command sam-claude
```

정상 설치는 반복 실행해도 관리 명령을 하나만 유지합니다.

## `Claude Code 2.1.129 or newer is required`

공식 CLI 버전을 확인합니다.

```bash
claude --version
```

Anthropic 공식 방법으로 Claude Code를 업데이트한 뒤 다시 설치하거나
`sam-claude`를 실행하세요. 버전 검사를 우회하면 gateway discovery가
동작하지 않을 수 있습니다.

## 공식 Anthropic 로그인 화면이나 모델이 보입니다

먼저 실제 명령 경로를 확인합니다.

```bash
type sam-claude
type claude
```

- `claude`: 공식 Anthropic 환경
- `sam-claude`: 격리된 SAM 환경

`sam-claude`의 화면 자체는 공식 Claude Code와 같아서 화면 제목만으로 연결을
판단할 수 없습니다. `/model`에서 현재 SAM 웹에 선택된 역할 모델이 보이는지,
`sam-claude mcp list`에서 `sam-tools`가 보이는지 확인하세요.

과거에 직접 만든 `sam-claude` 함수가 남아 있다면 최신 설치를 다시 실행한 뒤
`source "$HOME/.zshrc"`를 실행합니다. 설치 프로그램은 정상 관리 블록만
안전하게 교체합니다.

## `SAM_API_KEY is missing`

키 파일의 존재와 읽기 가능 여부만 확인합니다. 키 값은 출력하지 마세요.

macOS:

```bash
test -r "$HOME/.sam/env" && echo "키 파일 있음" || echo "키 파일 없음"
```

Windows:

```powershell
if (Test-Path "$HOME\.sam\env.ps1") { "키 파일 있음" } else { "키 파일 없음" }
```

키 파일이 없다면 빠른 시작의 설치를 다시 실행해 키를 입력하세요. 키가
폐기됐거나 권한이 바뀌었다면 SAM에서 유효한 Code Agent 키를 확인한 뒤 승인된
키 교체 절차를 사용하세요. 파일 내용을 화면에 출력하거나 채팅에 붙이지 마세요.

## `Runtime discovery failed`

이 오류는 하나로 단정할 수 없습니다. 다음 중 하나일 수 있습니다.

- 네트워크 또는 SAM gateway 응답 실패
- 키 인증 또는 Code Agent grant 실패
- 사용자 모델 접근·선택 변경
- 통합 discovery와 저장된 역할 매핑 불일치
- 손상되거나 예상과 다른 응답

wrapper는 이전 cache가 있어도 Claude Code를 시작하지 않습니다. 먼저 네트워크를
확인하고, SAM 웹 **Agent > Claude Code**에서 Haiku / Sonnet / Opus에 각각
모델이 선택됐는지 확인한 뒤 다시 실행하세요.

`/health` 성공은 API health만 뜻하며, 현재 키의 모델 discovery
성공을 대신하지 않습니다.

## `/model`에 역할 모델이 없거나 예상과 다릅니다

SAM 웹에서 역할 선택을 확인합니다.

1. Haiku, Sonnet, Opus가 각각 하나씩 선택돼 있는지 확인
2. 현재 계정과 API Key가 각 모델에 접근 가능한지 확인
3. `sam-claude`를 완전히 종료하고 다시 실행
4. `/model`을 다시 열기

wrapper는 실행할 때마다 `/v2/claude/v1/models`와 저장된 profile을 다시
대조합니다. 문서에 있던 과거 모델 ID를 설정 파일에 직접 적거나 낮은 버전으로
임의 대체하지 마세요.

이전 SAM Anthropic gateway 연결에서 만들어진 격리 모델 cache가 남아 있으면
최신 wrapper는 첫 실행 때 그 파일만 `~/.claude-sam/cache-backups/`로 옮깁니다.
현재 `/v2/claude` cache, 세션, MCP, 공식 `~/.claude`는 변경하지 않습니다.
cache가 손상됐거나 링크라면 임의 삭제하지 않고 실행을 중단합니다.

## `sonnet[1m]`을 사용할 수 없습니다

정상일 수 있습니다. `sonnet[1m]`은 별도 모델 매핑이 아니라 현재 선택된
Sonnet의 context가 1,000,000 토큰 이상일 때만 켜지는 모드입니다.

SAM 웹에서 Sonnet 역할에 선택한 모델의 context를 확인하세요. 예전
`Sonnet 1M` 저장값이나 이름만으로 활성화되지 않습니다.

## `claude-sam-*` 호환 모델이 보이지 않습니다

호환 모델은 다음 조건을 모두 통과한 경우에만 표시됩니다.

- Claude Code 호환성이 exact-certified 상태
- 현재 사용자와 API Key의 접근 권한
- SAM 웹에서 사용자가 별도로 선택
- 통합 discovery 응답에 포함

현재 인증·선택 모델이 없다면 아무것도 표시되지 않는 것이 정상입니다.
`claude-sam-*` ID를 직접 만들거나 registry alias 앞에 접두사를 붙이지 마세요.

## `sam-tools`가 보이지 않습니다

```bash
sam-claude mcp list
```

정상 목록에는 다음 주소의 `sam-tools`가 있습니다.

```text
https://sam.soonsoon.ai/mcp
```

없다면 설치를 다시 실행하세요. 격리 설정에 같은 이름의 MCP가 다른 주소나
다른 인증으로 이미 있으면 installer는 덮어쓰지 않고 중단합니다. 해당 항목이
본인이 만든 것인지 확인한 뒤 정리하거나 별도 이름으로 보존하세요.

MCP 설정의 Authorization 값은 실제 키가 아니라 아래 문자열이어야 합니다.

```text
Bearer ${SAM_API_KEY}
```

## 검색이나 페이지 읽기가 실패합니다

먼저 `sam-claude mcp list`에서 연결을 확인합니다. 일부 사이트는 로그인,
robots 정책, 응답 형식, 네트워크 정책 때문에 열리지 않을 수 있습니다. 공개된
일반 HTTPS 페이지로 다시 확인하세요.

SAM MCP 문제와 Claude 모델 gateway 문제는 다른 경계입니다. MCP 목록 성공이
모델 생성 성공을, 모델 discovery 성공이 MCP 도구 실행 성공을 대신하지 않습니다.

## `Malformed or duplicate SAM-Claude block`

`.zshrc`의 관리 마커가 누락, 역순 또는 중복된 상태입니다. 안전을 위해
installer와 uninstaller가 아무것도 바꾸지 않은 것입니다.

```text
# >>> SAM-Claude managed >>>
...
# <<< SAM-Claude managed <<<
```

파일을 백업한 뒤 SAM-Claude 마커 쌍만 하나로 정리하세요. 다른 셸 설정은
삭제하지 마세요. 확신이 없으면 [완전 수동 설정](./MANUAL_SETUP.md)의 관리
블록 설명을 확인하세요.

## `Unmanaged ... already exists`

설치 대상 경로에 installer가 만들지 않은 같은 이름의 파일이 있습니다. 안전을
위해 덮어쓰지 않은 것입니다.

- macOS/Linux: `~/.local/bin/sam-claude`
- Windows: `%USERPROFILE%\bin\sam-claude.ps1`, `sam-claude.cmd`

직접 만든 파일인지 확인해 별도 이름으로 백업한 뒤 설치를 다시 실행하세요.
공식 `claude` 파일은 이동하거나 삭제하지 마세요.

## 완전히 다시 설치하고 싶습니다

기본 삭제는 세션과 MCP를 보존합니다. 격리 데이터까지 복구 가능한 위치로
옮기려면 다음을 사용하세요.

macOS:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-macos.sh) --purge-data && source "$HOME/.zshrc"
```

Windows:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/uninstall-windows.ps1'))) -PurgeData
```

그 뒤 빠른 시작의 설치를 다시 실행합니다. 공식 `~/.claude`와 공용
`~/.sam/env` 또는 `env.ps1`은 그대로 보존됩니다.
