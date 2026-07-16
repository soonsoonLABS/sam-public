# SAM Codex 수동 설정 (macOS)

**언어:** 한국어 | [English](MANUAL_SETUP.en.md)

설치 프로그램 없이 SAM Codex를 직접 설정하는 기준 절차입니다. API 키를 명령
기록이나 문서에 적지 않고, 일반 Codex와 SAM CLI를 분리합니다.

## 1. 기존 SAM 키 또는 Code Agent 전용 키 선택

기존 SAM 키도 사용할 수 있지만, 기기별로 `Code Agent - Mac` 같은 전용 키를
새로 만드는 것을 권장합니다. SAM 웹의 **API Keys**에서 사용할 키를 준비합니다.
기존 키를 쓰더라도 Code Agent에서는 아래 `SAM_CODE_API_KEY` 변수에 따로
입력합니다.

## 2. 현재 터미널에 키 입력

아래 명령을 입력한 뒤 키를 붙여 넣고 Enter를 누릅니다. 키는 화면에 보이지
않으며 아직 파일에도 저장하지 않습니다.

```bash
read -s "SAM_CODE_API_KEY?SAM Code Agent 키 입력: "
echo
export SAM_CODE_API_KEY
```

## 3. 키 앞부분 확인

전체 키를 출력하지 않고 앞 12자리만 확인합니다.

```bash
echo "${SAM_CODE_API_KEY:0:12}..."
```

## 4. 키 유효성 확인

Codex보다 먼저 SAM API 연결을 확인합니다. 성공하면 응답에 `SAM-CODEX-OK`가
포함됩니다.

```bash
curl --silent --show-error --fail-with-body --max-time 120 -X POST \
  'https://sam.soonsoon.ai/openai/v1/responses' \
  -H "Authorization: Bearer $SAM_CODE_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{"model":"sam-codex-agent","input":"Reply with exactly: SAM-CODEX-OK","stream":false}'
```

## 5. 성공한 키만 Code Agent 경로에 저장

테스트가 성공한 경우에만 키를 Code Agent 전용 로컬 파일에 저장합니다.

```bash
mkdir -p "$HOME/.sam-code-agent"
printf 'export SAM_CODE_API_KEY=%q\n' "$SAM_CODE_API_KEY" > "$HOME/.sam-code-agent/env"
chmod 600 "$HOME/.sam-code-agent/env"
unset SAM_CODE_API_KEY
```

## 6. Codex CLI 설치

Node.js LTS가 없다면 먼저 설치한 뒤 실행합니다.

```bash
npm install -g @openai/codex@latest
codex --version
```

## 7. 분리된 SAM Codex CLI 환경 만들기

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

SAM CLI는 일반 `codex`가 아니라 아래처럼 중립 작업 폴더에서 실행합니다.
홈 디렉터리에서 실행하면 기존 `~/.codex/config.toml`이 프로젝트 설정처럼
감지되어 provider 설정이 무시될 수 있습니다.

```bash
mkdir -p /private/tmp/sam-codex-cli
cd /private/tmp/sam-codex-cli
source "$HOME/.sam-code-agent/env"

CODEX_HOME="$HOME/.codex-sam" codex
```

스모크 테스트는 다음 명령으로 확인합니다.

```bash
mkdir -p /private/tmp/sam-codex-cli
cd /private/tmp/sam-codex-cli
source "$HOME/.sam-code-agent/env"

CODEX_HOME="$HOME/.codex-sam" codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

정상이라면 헤더에 `model: sam-codex-agent`, `provider: sam`이 표시됩니다.
일반 OpenAI/ChatGPT Codex CLI는 그대로 `codex`로 실행합니다.

## 8. 기존 Codex와 SAM-Codex Desktop을 별도 창으로 열기

기존 Codex Desktop을 유지한 채 SAM-Codex를 별도 창으로 띄우려면
`CODEX_HOME`뿐 아니라 Electron `user-data-dir`도 분리해야 합니다. 이 방식이
우리가 확인한 macOS 동시 실행 방식입니다.

먼저 런처를 만듭니다.

```bash
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/sam-codex-desktop" <<'EOF'
#!/bin/zsh
set -euo pipefail

ENV_FILE="$HOME/.sam-code-agent/env"
CODEX_HOME_DIR="$HOME/.codex-sam"
USER_DATA_DIR="$HOME/Library/Application Support/SAM Codex Desktop"
WORKSPACE="${1:-/private/tmp/sam-codex-desktop}"

fail() {
  /usr/bin/osascript -e "display alert \"SAM Codex\" message \"$1\" as critical" >/dev/null 2>&1 || true
  echo "$1" >&2
  exit 1
}

[[ -r "$ENV_FILE" ]] || fail "Key file not found: $ENV_FILE"

set -a
source "$ENV_FILE"
set +a

[[ -n "${SAM_CODE_API_KEY:-}" ]] || fail "SAM_CODE_API_KEY is not set."

if [[ -d /Applications/Codex.app ]]; then
  APP_NAME="Codex"
elif [[ -d /Applications/ChatGPT.app ]]; then
  APP_NAME="ChatGPT"
else
  fail "Neither /Applications/Codex.app nor /Applications/ChatGPT.app was found."
fi

mkdir -p "$USER_DATA_DIR" "$CODEX_HOME_DIR" "$WORKSPACE"
umask 077
printf 'SAM_CODE_API_KEY=%s\n' "$SAM_CODE_API_KEY" > "$CODEX_HOME_DIR/.env"
chmod 600 "$CODEX_HOME_DIR/.env"

launchctl setenv SAM_CODE_API_KEY "$SAM_CODE_API_KEY"
launchctl setenv CODEX_HOME "$CODEX_HOME_DIR"
open -n -a "$APP_NAME" --args --user-data-dir="$USER_DATA_DIR" "$WORKSPACE"
EOF
chmod +x "$HOME/.local/bin/sam-codex-desktop"
```

실행은 다음 명령으로 합니다.

```bash
~/.local/bin/sam-codex-desktop
```

바탕화면 바로가기가 필요하면 다음을 추가합니다.

```bash
cat > "$HOME/Desktop/SAM-Codex.command" <<'EOF'
#!/bin/zsh
exec "$HOME/.local/bin/sam-codex-desktop" "$@"
EOF
chmod +x "$HOME/Desktop/SAM-Codex.command"
```

이 방식은 Codex Desktop 내부 실행 인자에 의존하는 launcher입니다. 문제가
생기면 먼저 7번의 CLI 스모크 테스트가 정상인지 확인하세요. 가장 안정적인
기준 경로는 `sam-codex` CLI입니다.

## 선택: 기본 Codex CLI 또는 데스크톱 앱을 SAM으로 일시 전환

아래 방식은 별도 창이 아니라 기본 `~/.codex/config.toml`을 SAM 설정으로
바꿨다가 복원하는 방식입니다. 일반 Codex 계정 모드와 동시에 쓰는 용도가
아니므로, 동시에 쓰려면 8번의 `sam-codex-desktop`을 사용하세요.

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
데스크톱 앱은 창만 닫지 말고 `Cmd-Q`로 완전히 종료한 뒤 다시 여세요.

원래 OpenAI/ChatGPT Codex 설정으로 복원하려면:

```bash
if [ -f "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak" ]; then
  cp "$HOME/.sam-code-agent/backups/default-codex-config.toml.bak" "$HOME/.codex/config.toml"
else
  rm -f "$HOME/.codex/config.toml"
fi
launchctl unsetenv SAM_CODE_API_KEY
```

다시 `Cmd-Q`로 완전히 종료하고 앱을 여세요.
