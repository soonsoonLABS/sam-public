# 2. Codex와 SAM-Codex 설정

**언어:** 한국어 | [English](README.en.md)

공식 `codex`와 SAM 전용 `sam-codex`를 동시에 유지하는 구성입니다.
`sam-codex`는 별도 `CODEX_HOME`과 SAM V2 provider를 사용하므로 기존 OpenAI
로그인, 설정, 세션을 바꾸지 않습니다.

## 두 사용 방식

| 구분 | 명령 | 설정 홈 | API·비용 |
| --- | --- | --- | --- |
| 공식 Codex | `codex` | `~/.codex` | OpenAI/ChatGPT 직접 사용, SAM 외부 |
| SAM-Codex | `sam-codex` | `~/.codex-sam` | SAM V2 OpenAI, SAM 사용량·비용 적용 |

## A. 공식 Codex만 사용

```bash
npm install -g @openai/codex@latest
codex --version
codex login
codex
```

공식 인증을 해제하려는 경우에만 `codex logout`을 사용합니다. SAM-Codex를
제거하기 위해 공식 Codex에서 로그아웃할 필요는 없습니다.

## B. 공식 Codex를 유지하면서 `sam-codex` 추가

먼저 [`../00-sam-setup/`](../00-sam-setup/)에서 공용 `SAM_API_KEY`로
`/v2/openai/models`가 HTTP `200`인지 확인합니다.

### macOS / Linux

```bash
chmod +x install-macos.sh uninstall-macos.sh
./install-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

installer는 기존 `~/.sam/env` 또는 `%USERPROFILE%\.sam\env.ps1`의 공용 키를
재사용합니다. 키가 없으면 숨김 입력으로 받아 같은 표준 파일에 저장합니다.

## 설치 결과

| 항목 | macOS / Linux | Windows |
| --- | --- | --- |
| 공용 키 | `~/.sam/env` | `%USERPROFILE%\.sam\env.ps1` |
| SAM Codex 홈 | `~/.codex-sam` | `%USERPROFILE%\.codex-sam` |
| 전용 명령 | `~/.local/bin/sam-codex` | `%USERPROFILE%\bin\sam-codex.*` |

기본 모델은 `azure.gpt-5.6-luna`입니다. installer는 현재 인증된 discovery에
이 모델이 없으면 설치를 중단합니다.

```toml
model = "azure.gpt-5.6-luna"
model_provider = "sam"
web_search = "disabled"

[model_providers.sam]
base_url = "https://sam.soonsoon.ai/v2/openai"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
```

Codex 자체 provider 검색은 끄고, SAM이 관측하는 MCP 검색·페이지 읽기·사용량
도구를 사용합니다.

## 실행과 모델 선택

SAM-Codex는 Git 프로젝트 폴더 안에서 실행합니다. 일반 `~/.codex` 설정이
프로젝트 설정처럼 섞이지 않도록 wrapper가 홈 폴더의 비프로젝트 실행을
차단합니다.

```bash
cd "$HOME/Developer/my-project"
sam-codex
```

처음 확인할 빈 프로젝트가 필요하면:

```bash
mkdir -p "$HOME/Developer/sam-codex-test"
cd "$HOME/Developer/sam-codex-test"
git init
sam-codex
```

`/model`에는 시작할 때 인증된 V2 discovery에서 받은, 현재 계정과 키에
허용된 SAM Responses 모델만 표시됩니다. 목록은 SAM 전용 홈에만 cache되며
키 값은 들어가지 않습니다.

비용 없는 wrapper·discovery 확인:

```bash
sam-codex --version
```

실제 provider-native Responses까지 확인하려면 아래 최소 호출을 한 번
실행합니다. 이 호출부터 SAM 사용량이 기록될 수 있습니다.

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

일상 사용:

```text
codex        # 공식 OpenAI/ChatGPT 환경
sam-codex    # SAM 환경
```

## `sam-codex`만 해제

```bash
./uninstall-macos.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

해제 프로그램은 wrapper와 SAM Codex provider 설정만 제거합니다. 공식
`codex`, `~/.codex`, 공용 SAM 키, `sam-claude`는 건드리지 않습니다.
기존 SAM-Codex 세션 파일은 `~/.codex-sam`에 보존합니다.

두 SAM wrapper를 모두 해제한 뒤 공용 키까지 삭제하려면
[`../00-sam-setup/`](../00-sam-setup/)의 공용 키 삭제 단계를 실행합니다.

## 문제 진단 순서

1. `codex --version`: 공식 CLI 설치 여부
2. `/readyz`: 네트워크·SAM readiness
3. `/v2/openai/models`: 키·권한·허용 모델
4. Git 프로젝트에서 `sam-codex --version`: 격리 wrapper
5. 최소 generation: V2 Responses와 사용량

`MODEL_NOT_NATIVE_ON_SURFACE`가 나오면 선택한 alias가 해당 V2 OpenAI
surface에 허용되지 않은 것입니다. `/model` 또는 현재 discovery의
provider-explicit alias를 사용하세요.

## 공식 근거

- [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Codex environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables)
- [Codex custom model providers](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers)
