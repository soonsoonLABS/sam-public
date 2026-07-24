# SAM Codex CLI — macOS

이 문서는 **macOS에서만** SAM 모델을 Codex CLI에 연결하는 방법입니다. 일반 OpenAI
Codex 계정과 `~/.codex` 설정은 그대로 두고, SAM은 별도 `sam-codex` 명령으로만
실행합니다. 일반 `codex` 명령은 SAM 모델을 사용하지 않습니다.

## 이 구성으로 되는 것

- Azure Foundry와 AWS Bedrock Mantle의 SAM V2 Responses 모델 사용
- Codex 내부 `/model`에서 **SAM 모델만** 선택
- SAM MCP의 사용량 조회와 웹 검색 사용
- 모델 목록 캐시가 삭제되거나 깨져도 다음 실행에서 자동 복구

SAM은 V2 native endpoint만 사용합니다. 일반 OpenAI Codex 설정, 로그인, 사용량에는
영향을 주지 않습니다.

## 준비물

- macOS Terminal
- 설치되어 있고 PATH에서 실행되는 Codex CLI
- Code Agent 권한이 있는 SAM API 키

먼저 확인합니다.

```bash
codex --version
```

## 수동 설치

수동 설치가 기본 경로입니다. 아래에서 **터미널에서 실행** 블록은 Terminal에 붙여
넣습니다. **파일 내용** 블록은 `nano` 편집기에 붙여 넣는 내용입니다.

`nano` 저장: `Control + O` → `Enter` → `Control + X`

### 1. SAM API 키 저장

아래 명령은 키 입력을 화면에 표시하지 않습니다. 키는 `~/.sam/env`에만 저장됩니다.

```bash
mkdir -p "$HOME/.sam"
chmod 700 "$HOME/.sam"
printf "SAM Code Agent API key: "
stty -echo
IFS= read -r SAM_CODEX_API
stty echo
printf "\n"
printf 'export SAM_CODEX_API=%q\n' "$SAM_CODEX_API" > "$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
unset SAM_CODEX_API
```

### 2. 분리된 SAM Codex 설정 만들기

터미널에서 실행:

```bash
mkdir -p "$HOME/.codex-sam"
nano "$HOME/.codex-sam/config.toml"
```

`nano`에 아래 **파일 내용**을 붙여 넣고 저장합니다.

```toml
model = "azure.gpt-5.6-terra"
model_provider = "sam"
service_tier = "default"
web_search = "disabled"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/openai"
env_key = "SAM_CODEX_API"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_CODEX_API"
```

`web_search = "disabled"`은 Codex 자체 검색을 끕니다. SAM 웹 검색은 아래 MCP 도구로
별도 제공됩니다.

### 3. `sam-codex` 명령 만들기

터미널에서 실행:

```bash
mkdir -p "$HOME/.local/bin"
nano "$HOME/.local/bin/sam-codex"
```

`nano`에 아래 **파일 내용**을 붙여 넣고 저장합니다.

```bash
#!/usr/bin/env bash
set -euo pipefail

. "$HOME/.sam/env"
export CODEX_HOME="$HOME/.codex-sam"

refresh_model_catalog() {
  local client_version cache_tmp
  client_version="$(codex --version | awk '{print $2}')"
  [[ -n "$client_version" ]] || return 0
  mkdir -p "$CODEX_HOME"
  umask 077
  cache_tmp="$(mktemp "$CODEX_HOME/.models_cache.XXXXXX")" || return 0
  if curl --fail --silent --show-error --max-time 10 --get \
    -H "Authorization: Bearer $SAM_CODEX_API" \
    -H 'x-sam-codex-cache: 1' \
    --data-urlencode "client_version=$client_version" \
    'https://sam.soonsoon.ai/v2/openai/models' > "$cache_tmp" \
    && grep -q '"models"' "$cache_tmp"; then
    mv "$cache_tmp" "$CODEX_HOME/models_cache.json"
  else
    rm -f "$cache_tmp"
  fi
}

refresh_model_catalog
exec codex "$@"
```

### 4. 최초 1회만 실행

```bash
chmod +x "$HOME/.local/bin/sam-codex"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
source "$HOME/.zshrc"
```

### 5. 실행과 모델 선택

이후에는 아래 한 줄만 실행합니다.

```bash
sam-codex
```

Codex가 열리면 `/model`을 입력합니다. 모델 목록에는 SAM에서 허용한 아래 9개만
표시됩니다.

| 제공 경로 | 모델 |
| --- | --- |
| Azure Foundry | `azure.gpt-5.6-sol`, `azure.gpt-5.6-terra`, `azure.gpt-5.6-luna`, `azure.gpt-5.4` |
| AWS Bedrock Mantle | `aws.gpt-5.6-sol`, `aws.gpt-5.6-terra`, `aws.gpt-5.6-luna`, `aws.gpt-5.5`, `aws.gpt-5.4` |

기본값은 `azure.gpt-5.6-terra`입니다. `sol`은 고난도 작업, `terra`는 일반 코딩·분석,
`luna`는 빠른 작업에 적합합니다.

## 모델 목록은 어디서 오나

`sam-codex`는 시작할 때마다 인증된 V2 endpoint에서 모델 카탈로그를 받아옵니다.

```text
https://sam.soonsoon.ai/v2/openai/models
```

목록은 로컬 `~/.codex-sam/models_cache.json`에만 저장됩니다. 이 파일에는 API 키나
OpenAI 계정 정보가 들어가지 않습니다. Codex의 내장 모델은 SAM 전용 캐시에서 숨김
처리되므로 `/model`에서 실수로 비-SAM 모델을 선택할 수 없습니다.

## MCP 도구

Codex 안에서 자연어로 요청하면 됩니다.

```text
sam_account_usage를 사용해서 이번 달 SAM 사용량과 남은 SSAM을 짧게 보여줘.
```

- `sam_account_usage`: 무료·읽기 전용 사용량 조회
- `sam_web_search`: “SAM 웹 검색으로 … 찾아줘”라고 요청. 검색 사용량이 기록됩니다.
- `sam_open_page`, `sam_find_in_page`: 검색 결과나 공개 URL의 페이지 내용을 읽고 찾는 도구입니다.

페이지 본문이 대화에 들어오면 모델 입력 토큰이 발생할 수 있습니다.

## 복구

### 화면에 `Ignored unsupported project-local config keys`가 보일 때

이 경고는 일반 `codex`가 실행됐거나 SAM 설정이 잘못 `~/.codex/config.toml`에 들어간
상태입니다. 이 화면에서 모델을 고르지 말고 종료합니다. Terminal에서 아래를 실행해
SAM 전용 wrapper를 직접 엽니다.

```bash
unset CODEX_HOME CODEX_SAM_HOME
"$HOME/.local/bin/sam-codex"
```

정상이라면 시작 화면의 모델이 `azure.gpt-5.6-terra`이고, `/model`에는 Azure/AWS
SAM 모델만 표시됩니다. 여전히 같은 경고가 나오면 `~/.codex-sam/config.toml`이 없거나
잘못된 것이므로 위의 “2. 분리된 SAM Codex 설정 만들기”부터 다시 진행합니다.

일반 `~/.codex/config.toml`은 OpenAI Codex 설정이므로 전체 파일을 삭제하거나 덮어쓰지
마세요. 그 파일에 SAM 관련 설정이 이미 섞였다면 백업 후 SAM 블록만 분리해야 합니다.

### `/model` 목록이 이상하거나 기본 Codex 모델이 보일 때

Codex를 종료한 뒤 다시 실행합니다.

```bash
sam-codex
```

그래도 해결되지 않으면 SAM 전용 캐시만 지우고 다시 실행합니다. 일반 OpenAI Codex
설정은 건드리지 않습니다.

```bash
rm -f "$HOME/.codex-sam/models_cache.json"
sam-codex
```

### `sam-codex: command not found`

현재 Terminal에서 아래를 실행한 뒤 다시 시도합니다.

```bash
export PATH="$HOME/.local/bin:$PATH"
sam-codex
```

새 Terminal에서도 유지하려면 위의 “최초 1회만 실행” 단계를 완료합니다.

### `sam-codex-agent`가 보일 때

그것은 폐기 예정인 구 환경입니다. 해당 Codex 창을 닫고 이 문서의 `sam-codex`로
다시 실행합니다.

## 자동 설치 (선택)

수동 설치를 이해했고 반복 설치할 때만 사용합니다.

```bash
git clone https://github.com/soonsoonLABS/sam-public.git
bash sam-public/02-Code-Agent-Codex/install-macos.sh
```

자동 설치도 같은 분리 경로(`~/.sam`, `~/.codex-sam`, `~/.local/bin/sam-codex`)와
동일한 모델 캐시 갱신을 사용합니다.

## 보안 경계

- API 키를 문서, Git, 채팅, 스크린샷에 남기지 않습니다.
- `~/.sam/env`는 사용자만 읽을 수 있도록 권한 `600`으로 저장합니다.
- `~/.codex`는 일반 OpenAI Codex용입니다. SAM 설정이나 키를 여기에 넣지 않습니다.
- 모델 호출은 `/v2/openai`만 사용하며 V1/compat fallback을 사용하지 않습니다.
