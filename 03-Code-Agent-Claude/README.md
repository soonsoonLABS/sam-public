# 3. Claude Code와 SAM-Claude 설정

**언어:** 한국어 | [English](README.en.md)

공식 `claude`와 SAM 전용 `sam-claude`를 동시에 유지하는 구성입니다.
`sam-claude`는 별도 `CLAUDE_CONFIG_DIR`과 실행 프로세스 전용 gateway
환경변수를 사용하므로 기존 Anthropic 로그인, 설정, 세션을 바꾸지 않습니다.

## 두 사용 방식

| 구분 | 명령 | 설정 홈 | API·비용 |
| --- | --- | --- | --- |
| 공식 Claude Code | `claude` | `~/.claude` | Anthropic 직접 사용, SAM 외부 |
| SAM-Claude | `sam-claude` | `~/.claude-sam` | SAM V2 Anthropic, SAM 사용량·비용 적용 |

두 명령을 같은 프로젝트 폴더에서 번갈아 실행할 수 있습니다.

## A. 공식 Claude Code만 사용

[Anthropic 공식 설치 안내](https://code.claude.com/docs/en/setup)를 따라 설치한
뒤 실행합니다.

```bash
claude --version
claude
```

공식 Anthropic 인증을 해제하려는 경우에만 공식 Claude Code 세션에서
`/logout`을 실행합니다. SAM-Claude를 제거하기 위해 공식 로그아웃을 할
필요는 없습니다.

## B. 공식 Claude Code를 유지하면서 `sam-claude` 추가

먼저 [`../00-sam-setup/`](../00-sam-setup/)에서 같은 `SAM_API_KEY`로
`/v2/anthropic/v1/models`가 HTTP `200`인지 확인합니다.

SAM-Claude는 Claude Code의 네 가지 선택 역할을 SAM 역할 alias에
연결합니다.

| Claude Code 선택 | SAM에 보내는 역할 alias | stable discovery backing ID |
| --- | --- | --- |
| Haiku | `claude-haiku` | `anthropic.claude-haiku-4-5` |
| Sonnet | `claude-sonnet-5` | `anthropic.claude-sonnet-5` |
| Sonnet 1M | `claude-sonnet-5` + `[1m]` 선택 | 위 Sonnet 중 1M 자격 후보 |
| Opus | `claude-opus-5` | `anthropic.claude-opus-5` |

설치 프로그램은 이 stable backing ID 세 개가 현재 인증된 discovery에 모두
있는지 확인합니다. 클라이언트는 역할 alias를 보내고 SAM은 계정에 저장된
역할별 후보로 연결합니다. backing ID가 없다면 낮은 버전으로 임의 변경하지
않고 설치를 중단하므로 SAM 웹의 Claude Code 역할 매핑을 먼저 확인하세요.

### macOS / Linux

```bash
chmod +x install-macos.sh uninstall-macos.sh
./install-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

이미 `~/.sam/env` 또는 `%USERPROFILE%\.sam\env.ps1`에 공용 키가
있으면 `sam-codex`와 같은 키를 그대로 재사용합니다.

## 설치 결과와 인증 경계

```text
~/.sam/env                    # macOS/Linux 공용 SAM 키
~/.claude-sam/                # SAM 전용 Claude 설정·세션 홈
~/.local/bin/sam-claude       # SAM 전용 명령
```

Windows에서는 각각 `%USERPROFILE%\.sam\env.ps1`,
`%USERPROFILE%\.claude-sam`, `%USERPROFILE%\bin\sam-claude.*`를 사용합니다.

wrapper가 `sam-claude` 프로세스에만 다음 값을 넣습니다.

```text
ANTHROPIC_BASE_URL=https://sam.soonsoon.ai/v2/anthropic
ANTHROPIC_AUTH_TOKEN=<공용 SAM_API_KEY를 런타임에 전달>
ANTHROPIC_MODEL=claude-sonnet-5
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5
ANTHROPIC_SMALL_FAST_MODEL=claude-haiku
```

키 값은 `settings.json`에 쓰지 않습니다. `ANTHROPIC_API_KEY`와
`CLAUDE_CODE_OAUTH_TOKEN`은 SAM 프로세스에서 제거해 공식 Anthropic 인증이
섞이지 않게 합니다.

## 사용과 모델 선택

```text
claude        # 공식 Anthropic 환경
sam-claude    # SAM 환경, 기본 Sonnet
```

SAM-Claude 안에서 `/model`을 열거나 실행할 때 모델을 지정합니다.

```bash
sam-claude --model haiku
sam-claude --model sonnet
sam-claude --model 'sonnet[1m]'
sam-claude --model opus
```

`sonnet[1m]`은 SAM의 Sonnet 1M 역할에 연결된 후보가 실제로 1M context
자격을 가진 경우에만 성공합니다.

설치는 discovery만 호출하므로 모델 사용량이 없습니다. 실제 호출을
확인하려면 아래 최소 테스트를 한 번 실행합니다. 이 호출부터 SAM 사용량이
기록될 수 있습니다.

```bash
sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

## `sam-claude`만 해제

### macOS / Linux

```bash
./uninstall-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

해제 프로그램은 `sam-claude` wrapper만 제거합니다. 공식 `claude`,
`~/.claude`, 공용 SAM 키, `sam-codex`는 건드리지 않습니다. 기존 SAM-Claude
세션은 `~/.claude-sam`에 보존합니다.

두 SAM wrapper를 모두 해제한 뒤 공용 키까지 삭제하려면
[`../00-sam-setup/`](../00-sam-setup/)의 공용 키 삭제 단계를 실행합니다.

## 문제 진단 순서

1. `claude --version`: 공식 CLI 설치 여부
2. `/readyz`: 네트워크·SAM readiness
3. `/v2/anthropic/v1/models`: 키·권한·세 stable backing ID
4. `sam-claude --model sonnet`: 격리 실행과 모델 선택
5. 최소 print 호출: provider-native Messages와 사용량

`401 AUTH_INVALID`이면 키 문제입니다. discovery가 `200`이지만 역할 model이
없으면 키 초기화로 단정하지 말고 SAM 역할 매핑과 catalog admission을
확인하세요.

## 공식 근거

- [Claude Code environment variables](https://code.claude.com/docs/en/env-vars)
- [Claude Code model configuration](https://code.claude.com/docs/en/model-config)
- [Claude Code gateway configuration](https://code.claude.com/docs/en/llm-gateway)
