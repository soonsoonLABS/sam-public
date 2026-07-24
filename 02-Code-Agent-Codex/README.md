# SAM Codex CLI

**언어:** 한국어 | [English](README.en.md)

기존 OpenAI Codex는 그대로 두고, 별도 `sam-codex` 명령으로만 SAM V2와 MCP를
사용합니다. **수동 설정이 기본 경로**이고 자동 설치는 아래의 선택 항목입니다.

## 수동 설정 (macOS/Linux)

### 1. SAM 키 저장

Code Agent 권한이 있는 SAM API 키를 입력합니다. 키는 화면·명령 기록에 보이지
않고 `~/.sam/env`에만 저장됩니다.

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
```

### 2. 분리된 Codex 설정 만들기

```bash
mkdir -p "$HOME/.codex-sam"
nano "$HOME/.codex-sam/config.toml"
```

아래 내용만 붙여 넣고 저장합니다.

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

### 3. `sam-codex` 명령 만들기

```bash
mkdir -p "$HOME/.local/bin"
nano "$HOME/.local/bin/sam-codex"
```

아래 내용만 붙여 넣고 저장합니다.

```bash
#!/usr/bin/env bash
set -euo pipefail

. "$HOME/.sam/env"
export CODEX_HOME="$HOME/.codex-sam"
exec codex "$@"
```

```bash
chmod +x "$HOME/.local/bin/sam-codex"
export PATH="$HOME/.local/bin:$PATH"
sam-codex
```

정상이라면 기본 모델은 `azure.gpt-5.6-terra`입니다. Codex 안에서 `/model`을
입력하면 Azure Foundry와 AWS Bedrock Mantle 모델을 선택할 수 있습니다.
새 터미널에서도 쓰려면 `export PATH="$HOME/.local/bin:$PATH"`를 셸 설정에
한 번 추가합니다.

## 첫 확인

Codex 안에서 다음을 요청합니다.

```text
sam_account_usage를 사용해서 이번 달 SAM 사용량과 남은 SSAM을 짧게 보여줘.
```

`sam_account_usage`는 무료·읽기 전용입니다. 검색은 “SAM 웹 검색으로 … 찾아줘”라고
요청합니다. 검색은 사용량으로 기록되며, 페이지 본문이 대화에 들어가면 모델 입력
토큰이 발생할 수 있습니다.

## 모델

| 모델 | 제공 경로 | 용도 |
| --- | --- | --- |
| `azure.gpt-5.6-terra` / `aws.gpt-5.6-terra` | Azure Foundry / AWS Bedrock Mantle | 기본 코딩·분석 |
| `azure.gpt-5.6-sol` / `aws.gpt-5.6-sol` | Azure Foundry / AWS Bedrock Mantle | 고난도 작업 |
| `azure.gpt-5.6-luna` / `aws.gpt-5.6-luna` | Azure Foundry / AWS Bedrock Mantle | 가벼운 작업 |

## 자동 설치 (선택)

수동 설정을 이해한 뒤 반복 설치할 때만 사용합니다.

```bash
git clone https://github.com/soonsoonLABS/sam-public.git
bash sam-public/02-Code-Agent-Codex/install-macos.sh
```

Windows PowerShell 자동 설치는 다음 명령을 사용합니다.

```powershell
git clone https://github.com/soonsoonLABS/sam-public.git
PowerShell -ExecutionPolicy Bypass -File .\sam-public\02-Code-Agent-Codex\install-windows.ps1
```

`sam-codex-agent`가 보이면 구 환경입니다. 해당 Codex 창을 종료하고, 구
`sam-codex` wrapper가 아닌 위 V2 수동 설정으로 다시 시작하세요.
