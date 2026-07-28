# SAM-Codex 설치

공식 OpenAI `codex`는 그대로 두고, SAM 전용 `sam-codex`를 추가합니다.

| 명령 | 연결 | 설정 |
| --- | --- | --- |
| `codex` | OpenAI / ChatGPT | `~/.codex` |
| `sam-codex` | SAM V2 + SAM MCP | `~/.codex-sam` |

## 준비

공식 Codex CLI와 **Code Agent 권한이 있는 SAM API Key**가 필요합니다.

```bash
npm install -g @openai/codex@latest
codex --version
```

## 방법 1 — 한 줄 자동 설치

터미널에 아래 한 줄을 그대로 붙여 넣습니다.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/install-macos.sh) && source "$HOME/.zshrc"
```

키를 묻는 화면이 나오면 SAM API Key를 붙여 넣고 Enter를 누릅니다. 입력한
문자는 화면에 표시되지 않습니다.

설치기는 다음 작업만 수행합니다.

- 키를 권한 `600`의 `~/.sam/env`에 저장
- SAM 전용 `~/.codex-sam` 생성
- 인증된 SAM V2 모델 목록 저장
- `sam-codex` 명령과 SAM MCP 검색·페이지 읽기 연결
- `~/.zshrc`에 표시된 SAM-Codex 관리 블록만 추가

## 방법 2 — 파일을 내려받아 설치

자동 설치 파일을 먼저 확인하고 실행하려면:

```bash
curl -fsSLo "$HOME/Downloads/install-sam-codex.sh" \
  https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/install-macos.sh
bash "$HOME/Downloads/install-sam-codex.sh"
source "$HOME/.zshrc"
```

## 실행

Codex는 프로젝트 폴더에서 사용하는 것이 가장 안전합니다.

```bash
mkdir -p "$HOME/Developer/sam-codex-test"
cd "$HOME/Developer/sam-codex-test"
git init
sam-codex
```

홈 폴더나 Git 프로젝트가 아닌 곳에서 `sam-codex`를 실행하면 공식
`~/.codex` 설정이 섞이지 않도록 자동으로 `~/SAM-Codex` 전용 작업 폴더에서
시작합니다. 기존 프로젝트를 작업하려면 해당 Git 프로젝트 폴더로 이동한 뒤
실행하세요.

화면 아래 모델이 `azure.gpt-5.6-luna`, `azure.gpt-5.6-terra` 또는
`azure.gpt-5.6-sol`이면 SAM 환경입니다. 같은 화면을 사용하지만 연결 대상이
다릅니다.

### 바로 확인

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

이 호출부터 SAM 사용량이 기록될 수 있습니다.

### SAM 검색 확인

`sam-codex` 대화창에서 다음처럼 요청합니다.

```text
SAM 검색 도구로 오늘의 OpenAI 공식 뉴스를 하나 찾고, 페이지 읽기 도구로 내용을 확인한 뒤 출처와 함께 요약해줘.
```

설치된 도구 확인:

```bash
sam-codex mcp list
```

`sam-tools`가 `enabled`로 표시되어야 합니다. Codex 내장 웹 검색은 꺼져 있고,
SAM이 사용량과 정책을 관리하는 `sam_web_search`, `sam_open_page`,
`sam_find_in_page`, `sam_account_usage`를 사용합니다.

## 평소 사용

```bash
codex       # 기존 OpenAI / ChatGPT
sam-codex   # SAM
```

두 명령의 로그인·설정·대화 기록은 서로 분리됩니다.

## 삭제

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/uninstall-macos.sh) && source "$HOME/.zshrc"
```

삭제기는 `sam-codex` 명령과 관리 블록을 제거하고 `~/.codex-sam`을 휴지통으로
옮깁니다. 공식 `codex`, `~/.codex`, 공용 `~/.sam/env` 키는 보존합니다.
설치 전부터 사용자가 직접 만든 동명의 함수나 별칭은 삭제하지 않습니다.

## 오류 확인

```bash
codex --version
sam-codex --version
sam-codex mcp list
```

- `command not found`: `source "$HOME/.zshrc"` 실행
- `model discovery failed`: SAM 키 또는 Code Agent 권한 확인
- `MODEL_NOT_NATIVE_ON_SURFACE`: `/model`에서 현재 표시되는 `azure.*` 모델 선택

## 적용 기준

- SAM OpenAI base: `https://sam.soonsoon.ai/v2/openai`
- Codex wire API: `responses`
- SAM MCP: `https://sam.soonsoon.ai/mcp`
- 키 환경변수: `SAM_API_KEY`
- Codex 공식 설정 근거:
  [configuration](https://learn.chatgpt.com/docs/config-file/config-basic),
  [environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables),
  [custom providers](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers),
  [MCP](https://learn.chatgpt.com/docs/extend/mcp)
