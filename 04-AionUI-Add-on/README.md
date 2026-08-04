# AionUI Add-on — SAM Codex · SAM Claude를 AionUI 코딩 에이전트로 사용

**언어:** 한국어 | [English](README.en.md)

이미 설치한 `sam-codex`와 `sam-claude`를 [AionUI](https://github.com/iOfficeAI/AionUi)
데스크톱 앱의 코딩 에이전트로 연결하는 add-on입니다. 터미널 명령을 새로 만들지 않고,
설치된 SAM 전용 wrapper를 AionUI가 실행하도록 등록만 추가합니다.

공식 `codex`, `claude`, `~/.codex`, `~/.claude`, 기존 로그인은 변경하지 않습니다.
SAM API 키도 다시 입력하지 않습니다. 두 wrapper가 공용 `~/.sam/env` 키를 그대로 읽습니다.

> 현재 지원 범위는 macOS, zsh, AionUI 데스크톱 앱입니다.

## 전제

먼저 아래 두 설치를 마쳐야 합니다. 키 입력은 이 단계에서 한 번만 발생합니다.

1. [`02-Code-Agent-Codex/`](../02-Code-Agent-Codex/): `sam-codex`
2. [`03-Code-Agent-Claude/`](../03-Code-Agent-Claude/): `sam-claude`

AionUI 앱도 한 번 실행해 두세요. 이 add-on은 AionUI가 내려받은 ACP 브리지 런타임을 사용합니다.

## 두 층으로 나뉩니다

| 층 | 무엇을 하는가 | 자동화 |
| --- | --- | --- |
| 1층 (터미널) | `sam-codex-acp` 런처 생성 | 이 폴더의 설치 스크립트 |
| 2층 (AionUI 앱) | 에이전트 두 개 등록 | 앱에서 값 입력 |

2층은 앱 밖에서 자동화하지 않습니다. AionUI는 설정을 앱 런타임 안에서만 열어 주며,
설정 데이터베이스를 직접 수정하면 앱 버전에 따라 손상될 수 있습니다.

## 1. 한 줄 설치

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/04-AionUI-Add-on/install-macos.sh)
```

성공하면 다음 메시지와 함께 2층에 입력할 값이 출력됩니다.

```text
SAM AionUI add-on installed successfully.
Launcher: ~/.local/bin/sam-codex-acp
```

`AionUI runtime was not found`가 나오면 AionUI를 실행하고 내장 **Codex CLI**
에이전트로 대화를 한 번 연 뒤 다시 실행하세요. 그때 ACP 브리지가 내려받아집니다.

## 2. AionUI에 등록

AionUI **Settings → Agents**에서 아래 두 항목을 설정합니다. 키 입력란은 비워 둡니다.

### SAM Codex — 커스텀 에이전트 추가

| 항목 | 값 |
| --- | --- |
| Name | `SAM Codex Agent` |
| Command | `~/.local/bin/sam-codex-acp` |

### SAM Claude — 기존 Claude Code 에이전트 재지정

| 항목 | 값 |
| --- | --- |
| Command override | `~/.local/bin/sam-claude` |
| `ANTHROPIC_BASE_URL` | `https://sam.soonsoon.ai/v2/claude` |
| `CLAUDE_CONFIG_DIR` | `~/.claude-sam` |
| `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY` | `1` |

`~`를 받지 않는 입력란에는 절대 경로(`/Users/<사용자명>/...`)를 넣으세요.

이 재지정은 AionUI의 Claude Code 슬롯을 SAM 전용으로 바꿉니다. 같은 앱에서 공식 Anthropic
로그인도 함께 쓰려면 Claude Code를 그대로 두고 별도 커스텀 에이전트로 추가하세요.
터미널의 공식 `claude`는 어느 경우에도 영향받지 않습니다.

## 3. 정상 연결 확인

Agents 목록에서 두 항목이 **online**이면 정상입니다. 새 대화를 열고 모델 목록을 확인하세요.

- **SAM Codex Agent**: Agent 페이지에서 선택한 V2-native 모델과 인증된 호환 모델이 원래
  이름으로 표시됩니다.
- **Claude Code**: SAM discovery가 반환한 Claude 계열 모델이 표시됩니다.

터미널에서 생성 비용 없이 먼저 확인할 수 있습니다.

```bash
sam-codex mcp list
sam-claude mcp list
```

## 실제 사용 시나리오

### 리포지토리에서 SAM Codex로 작업

1. AionUI에서 작업 폴더를 열고 새 대화의 에이전트를 **SAM Codex Agent**로 선택합니다.
2. 모델을 고릅니다. 긴 코딩 작업은 flagship 계열, 빠른 수정은 경량 계열을 씁니다.
3. Mode를 **Agent**로 두면 파일 편집과 명령 실행까지 진행합니다. 검토만 필요하면
   **Read-only**로 시작합니다.
4. `/review`로 커밋 전 변경을 점검하고, 대화가 길어지면 `/compact`로 정리합니다.

같은 작업을 터미널에서 계속하려면 `sam-codex`를 실행합니다. 설정과 대화 기록은 앱과
분리되지만 같은 SAM 계정과 키를 사용합니다.

### 같은 문제를 두 모델로 교차 검토

1. **SAM Codex Agent** 대화에서 구현을 진행합니다.
2. **Claude Code**(SAM Claude) 대화를 새로 열어 같은 폴더를 지정하고 변경 사항 검토를
   요청합니다.
3. 두 결과를 비교해 최종 수정을 한쪽에서 반영합니다.

두 에이전트는 같은 `SAM_API_KEY`를 쓰므로 키를 추가로 발급하거나 재입력하지 않습니다.

### 공식 환경으로 돌아가기

터미널에서는 `codex`, `claude`를 평소처럼 실행합니다. AionUI에서 공식 Codex를 쓰려면
내장 **Codex CLI** 에이전트를 선택합니다. 이 add-on은 해당 항목을 변경하지 않습니다.

## 선택: AionUI 일반 채팅용 모델 공급자

코딩 에이전트가 아니라 AionUI 기본 채팅에서도 SAM 모델을 쓰려면
**Settings → Model Providers**에 공급자를 추가합니다.

| 이름 | Protocol | Base URL |
| --- | --- | --- |
| `SAM Claude` | Anthropic | `https://sam.soonsoon.ai/v2/anthropic` |
| `SAM Codex` | OpenAI | `https://sam.soonsoon.ai/openai/v1` |

OpenAI 공급자는 `https://sam.soonsoon.ai/openai/v1`을 사용합니다. AionUI의 OpenAI
클라이언트는 OpenAI 규격 모델 목록을 요구하므로 V2 Codex 표면(`/v2/codex`)을 공급자
Base URL로 넣으면 프로토콜 감지에 실패합니다. V2 전체 카탈로그는 위 코딩 에이전트
경로에서 사용하세요.

## 삭제

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/04-AionUI-Add-on/uninstall-macos.sh)
```

이 스크립트는 add-on이 만든 런처만 휴지통으로 옮깁니다. `sam-codex`, `sam-claude`,
`~/.codex-sam`, `~/.claude-sam`, 공용 `~/.sam/env` 키는 보존합니다.

AionUI 쪽은 앱에서 되돌립니다. 커스텀 **SAM Codex Agent**를 삭제하고, **Claude Code**의
command override와 환경 변수를 비웁니다.

## 보안과 비용

- 이 add-on은 키를 새로 저장하지 않습니다. 인증은 wrapper가 공용 `~/.sam/env`에서 처리합니다.
- AionUI 에이전트 설정에 키 값을 직접 넣지 마세요. 넣지 않아도 동작합니다.
- 런처 파일은 소유자만 실행할 수 있도록 `700` 권한으로 만듭니다.
- 모델 목록 표시와 `mcp list`는 모델을 생성하지 않습니다. 대화에서 실제 응답을 받는
  시점부터 SAM 사용량과 비용이 기록될 수 있습니다.
- 키를 교체하면 실행 중인 AionUI 대화와 터미널 세션을 다시 시작해야 새 키를 읽습니다.

## 문제가 생겼다면

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| `AionUI runtime was not found` | ACP 브리지 미설치 | AionUI에서 내장 Codex CLI 대화를 한 번 열고 재실행 |
| 에이전트가 `offline` | 런처 경로 오류 | Command에 절대 경로를 입력했는지 확인 |
| `SAM_API_KEY is missing` | 공용 키 없음 | [`00-sam-setup/`](../00-sam-setup/)에서 키를 저장 |
| 모델 목록이 비어 있음 | 키 권한 부족 | 인증된 discovery 결과를 먼저 확인 |
| 공급자 프로토콜 감지 실패 | 잘못된 Base URL | OpenAI 공급자에 `/openai/v1` 사용 |

wrapper 자체 문제는 각 폴더의 문서를 확인하세요.

- Codex: [`02-Code-Agent-Codex/TROUBLESHOOTING.md`](../02-Code-Agent-Codex/TROUBLESHOOTING.md)
- Claude: [`03-Code-Agent-Claude/TROUBLESHOOTING.md`](../03-Code-Agent-Claude/TROUBLESHOOTING.md)
