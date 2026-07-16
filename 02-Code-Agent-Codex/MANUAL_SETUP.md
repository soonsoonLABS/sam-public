# SAM Codex 수동 설정 (macOS)

**언어:** 한국어 | [English](MANUAL_SETUP.en.md)

설치 프로그램 없이 SAM Codex를 직접 설정하는 기준 절차입니다. API 키를 명령
기록이나 문서에 적지 않고, 일반 Codex와 SAM CLI를 분리합니다.

## 1. 기존 SAM 키 또는 Code Agent 전용 키 준비

기존 SAM 키도 사용할 수 있지만, 기기별로 `Code Agent - Mac` 같은 전용 키를
새로 만드는 것을 권장합니다. SAM 웹의 **API Keys**에서 키를 만든 뒤, 아래
명령의 숨김 입력창에만 붙여 넣습니다.

```bash
mkdir -p "$HOME/.sam-code-agent"
printf 'SAM Code Agent 키 붙여넣기: '
stty -echo
IFS= read -r SAM_CODE_API_KEY
stty echo
printf '\n'
printf 'export SAM_CODE_API_KEY=%q\n' "$SAM_CODE_API_KEY" > "$HOME/.sam-code-agent/env"
chmod 600 "$HOME/.sam-code-agent/env"
unset SAM_CODE_API_KEY
```

## 2. 키 유효성 확인

Codex보다 먼저 SAM API 연결을 확인합니다. 성공하면 응답에 `SAM-CODEX-OK`가
포함됩니다.

```bash
source "$HOME/.sam-code-agent/env"
curl --silent --show-error --fail-with-body --max-time 120 -X POST \
  'https://sam.soonsoon.ai/openai/v1/responses' \
  -H "Authorization: Bearer $SAM_CODE_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{"model":"sam-codex-agent","input":"Reply with exactly: SAM-CODEX-OK","stream":false}'
unset SAM_CODE_API_KEY
```

## 3. Codex CLI 설치

Node.js LTS가 없다면 먼저 설치한 뒤 실행합니다.

```bash
npm install -g @openai/codex@latest
codex --version
```

## 4. 분리된 SAM Codex CLI 환경 만들기

SAM 설정을 일반 `~/.codex`가 아닌 `~/.codex-sam`에 만듭니다.

```bash
mkdir -p "$HOME/.codex-sam"
cat > "$HOME/.codex-sam/config.toml" <<'EOF'
model = "sam-codex-agent"
model_provider = "sam"
model_reasoning_effort = "medium"

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/openai/v1"
env_key = "SAM_CODE_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
EOF
chmod 600 "$HOME/.codex-sam/config.toml"
```

SAM CLI는 매번 다음 명령으로 실행합니다. 키와 `CODEX_HOME`은 이 명령의
서브셸에서만 적용되므로 일반 `codex` 설정을 바꾸지 않습니다.

```bash
(
  source "$HOME/.sam-code-agent/env"
  CODEX_HOME="$HOME/.codex-sam" codex
)
```

이것이 수동 설정의 SAM 전용 CLI입니다. 일반 OpenAI/ChatGPT Codex CLI는
그대로 `codex`로 실행합니다.

## 5. 기존 Codex CLI 또는 데스크톱 앱을 SAM으로 전환·복원

기본 Codex는 `~/.codex/config.toml`을 사용합니다. SAM으로 바꾸기 전에 원본을
백업하고, GUI 앱이 읽을 현재 로그인 세션 키를 설정합니다.

```bash
mkdir -p "$HOME/.sam-code-agent/backups"
if [ -f "$HOME/.codex/config.toml" ]; then
  cp -p "$HOME/.codex/config.toml" "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak"
else
  : > "$HOME/.sam-code-agent/backups/default-codex-config-was-absent"
fi
mkdir -p "$HOME/.codex"
cp "$HOME/.codex-sam/config.toml" "$HOME/.codex/config.toml"

source "$HOME/.sam-code-agent/env"
launchctl setenv SAM_CODE_API_KEY "$SAM_CODE_API_KEY"
unset SAM_CODE_API_KEY
```

이후 일반 `codex`와 ChatGPT/Codex 데스크톱 앱은 SAM provider 설정을 사용합니다.
데스크톱 앱은 창만 닫지 말고 `Cmd-Q`로 완전히 종료한 뒤 다시 여세요. 이 GUI
세션 키는 로그아웃·재부팅 후 사라지므로, 그때는 위 전환 명령을 다시 실행해야
합니다.

원래 OpenAI/ChatGPT Codex 설정으로 복원하려면:

```bash
if [ -f "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak" ]; then
  cp "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak" "$HOME/.codex/config.toml"
else
  rm -f "$HOME/.codex/config.toml"
fi
launchctl unsetenv SAM_CODE_API_KEY
```

다시 `Cmd-Q`로 완전히 종료하고 앱을 여세요. 이 과정은 ChatGPT 로그인 정보나
대화 기록을 삭제하지 않습니다. 다만 SAM API 모드와 ChatGPT 계정 기반 대화
목록은 서로 다른 인증·세션이므로 하나의 대화 목록으로 합쳐지지 않습니다.

## 데스크톱 분리에 대한 현재 기준

`CODEX_HOME`으로 분리된 환경은 Codex CLI에 사용합니다. 기존 ChatGPT/Codex
데스크톱 앱을 별도 복제해 독립 프로필로 실행하는 방식은 공식적으로 안정된
설정 경로가 아니므로, 이 수동 가이드에서는 지원 경로로 안내하지 않습니다.
데스크톱은 위의 백업·전환·복원 방식으로 사용합니다.
