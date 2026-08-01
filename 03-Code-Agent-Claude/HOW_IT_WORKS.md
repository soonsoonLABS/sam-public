# SAM-Claude 동작 방식

[빠른 시작으로 돌아가기](./README.md)

## 공식 환경과 SAM 환경은 분리됩니다

```text
claude
  └─ ~/.claude
     └─ Anthropic 직접 인증·사용량·비용

sam-claude
  └─ ~/.claude-sam
     ├─ SAM /v2/claude
     ├─ 인증된 역할·호환 모델 discovery
     └─ SAM MCP 검색·페이지 읽기
```

`sam-claude`는 Claude Code를 다시 만든 프로그램이 아닙니다. 공식 Claude Code
CLI를 별도 `CLAUDE_CONFIG_DIR`, SAM 인증, SAM gateway로 실행하는 격리
wrapper입니다. 공식 `claude`, `~/.claude`, Anthropic 로그인은 바꾸지 않습니다.

## 연결 주소

| 용도 | 주소 |
| --- | --- |
| Claude Code gateway | `https://sam.soonsoon.ai/v2/claude` |
| 모델 discovery | `https://sam.soonsoon.ai/v2/claude/v1/models` |
| 역할 매핑 확인 | `https://sam.soonsoon.ai/v1/models/code-agent-profiles` |
| SAM MCP | `https://sam.soonsoon.ai/mcp` |

Claude Code가 gateway base 뒤에 Anthropic wire 경로인 `/v1/messages`,
`/v1/messages/count_tokens`, `/v1/models`를 붙입니다. 따라서
`/v2/claude/v1/...`의 두 버전 표기는 중복 API가 아닙니다.

## 키와 인증 경계

공용 키는 macOS의 `~/.sam/env` 또는 Windows의
`%USERPROFILE%\.sam\env.ps1`에 `SAM_API_KEY`로 저장합니다. SAM-Codex도 같은
키 파일을 사용할 수 있습니다.

wrapper는 키 값을 설정 JSON, 프로젝트, URL, Git에 복사하지 않습니다.
`sam-claude` 프로세스 안에서만 SAM 키를 `ANTHROPIC_AUTH_TOKEN`으로 전달하고,
공식 Anthropic 인증 및 다른 provider 선택 변수는 제거합니다.

SAM MCP 설정도 키 값이 아니라 아래의 **문자 그대로인 환경변수 참조**를
보관합니다.

```text
Authorization: Bearer ${SAM_API_KEY}
```

따옴표를 제거하거나 실제 키로 바꾸면 안 됩니다.

## 실행 전 이중 검증

설치할 때와 실행할 때마다 wrapper는 생성 요청 없이 두 API를 확인합니다.

1. `/v2/claude/v1/models`: 현재 키로 사용할 수 있는 통합 모델 목록
2. V1 Claude profile API: 계정에 저장된 Haiku / Sonnet / Opus backing 매핑

다음 조건을 모두 만족해야 Claude Code가 시작됩니다.

- 정확히 Haiku, Sonnet, Opus 세 역할이 각각 하나의 backing 모델을 가짐
- 세 backing ID가 서로 다르고 통합 discovery에도 실제로 존재함
- 모델 ID와 응답 형식이 검증 규칙을 통과함
- 키, 사용자 모델 접근, Code Agent grant, 선택 상태가 유효함

역할명을 보고 낮은 버전이나 비슷한 모델을 추측하지 않습니다. 검증 실패나
네트워크 실패 시 이전 cache 파일은 보존하지만 오래된 상태로 Claude Code를
실행하지 않습니다. 성공한 새 상태만 원자적으로 교체합니다.

## Haiku / Sonnet / Opus와 Sonnet 1M

Claude Code의 런타임 모델 슬롯은 Haiku, Sonnet, Opus 세 개입니다.
SAM 웹 **Agent > Claude Code**에서 각 역할에 상세 모델을 선택합니다.
wrapper는 저장된 선택의 정확한 backing alias를 실행 환경에 넣습니다.

`Sonnet 1M`은 별도의 네 번째 backing 모델을 추측하는 기능이 아닙니다. 현재
선택된 Sonnet의 context가 1,000,000 토큰 이상일 때만 같은 Sonnet을
`sonnet[1m]` 모드로 사용할 수 있습니다.

SAM 웹의 선택을 바꿔도 로컬 설정 파일을 직접 덮어쓰지 않습니다. 다음
`sam-claude` 실행에서 다시 discovery와 profile을 대조해 새 선택을 적용합니다.

## 인증된 호환 모델

SAM은 provider-native Anthropic 모델 외에도 Claude Code 호환성이 실제로
인증되고 사용자가 선택한 모델을 통합 discovery에 추가할 수 있습니다.

- 호환 모델은 native 역할 매핑을 대신하지 않습니다.
- discovery가 반환한 정확한 `claude-sam-*` ID로만 선택합니다.
- registry alias나 provider model ID로 client ID를 직접 만들지 않습니다.
- 인증·선택된 호환 모델이 없으면 `/model`에는 역할 모델만 표시됩니다.
- 실패한 native 요청을 호환 경로로, 또는 그 반대로 자동 재시도하지 않습니다.

## Gateway discovery

Claude Code `2.1.129` 이상에서 wrapper는 다음 기능을 켭니다.

```text
CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
```

이 기능으로 `/model`은 문서에 적힌 고정 목록이 아니라 현재 계정의 통합
discovery 결과를 사용합니다. 실제 허용 목록은 언제든 권한과 선택에 따라 달라질
수 있으므로 문서의 예전 모델명으로 판단하지 않습니다.

## SAM MCP

설치 프로그램은 격리된 `~/.claude-sam`에 `sam-tools` HTTP MCP를 추가합니다.
기존의 다른 격리 MCP 항목은 보존합니다. 같은 이름이 다른 주소나 인증 방식으로
이미 존재하면 덮어쓰지 않고 설치를 중단합니다.

MCP는 다음과 같은 SAM 관리 도구를 제공합니다.

- 웹 검색
- 공개 페이지 열기와 본문 확인
- SAM 계정 사용량 확인

정확한 도구 이름과 현재 제공 범위는 `sam-claude mcp list`와 실행 중 MCP
목록이 정본입니다.

## 설치·삭제 소유권

설치 프로그램은 자신이 만든 wrapper와 명시적 관리 마커 사이의 `.zshrc`
블록만 갱신합니다. 마커가 누락, 역순, 중복이면 다른 셸 설정을 손상시키지 않도록
아무것도 바꾸지 않고 중단합니다.

기본 삭제는 관리된 명령만 제거하고 `~/.claude-sam` 데이터와 공용 키를
보존합니다. `--purge-data` 또는 Windows의 `-PurgeData`를 명시한 경우에만
격리 데이터를 복구 가능한 위치로 이동합니다.

## 비용 경계

- `claude`: Anthropic의 인증·정책·사용량·비용
- `sam-claude`: SAM API Key의 권한·사용량·비용

설치, 버전 검사, 모델 discovery, MCP 목록 확인은 모델 생성 호출이 아닙니다.
실제 대화와 `sam-claude -p ...`부터 SAM 사용량과 비용이 기록될 수 있습니다.
