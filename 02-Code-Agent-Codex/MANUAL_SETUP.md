# SAM-Codex 완전 수동 설정 — macOS

[빠른 시작으로 돌아가기](./README.md)

설치 프로그램을 사용하지 않고 키, 모델 목록, Codex 설정, 실행 파일, 터미널
함수를 직접 만드는 과정입니다. 자동 설치를 완료했다면 다시 진행할 필요가
없습니다.

## 1. SAM 전용 폴더 만들기

```bash
mkdir -p "$HOME/.sam" "$HOME/.codex-sam" "$HOME/.local/bin"
chmod 700 "$HOME/.sam" "$HOME/.codex-sam"
```

## 2. SAM API Key 저장하기

기존 `~/.sam/env`가 없다면:

```bash
if [[ ! -r "$HOME/.sam/env" ]]; then
  read -r -s "SAM API Key: " SAM_KEY
  echo
  if [[ -n "$SAM_KEY" ]]; then
    printf 'export SAM_API_KEY=%q\n' "$SAM_KEY" > "$HOME/.sam/env"
    chmod 600 "$HOME/.sam/env"
  else
    echo "키가 비어 있습니다. 다시 실행하세요."
  fi
  unset SAM_KEY
else
  echo "기존 ~/.sam/env 키를 사용합니다."
fi
```

키 값은 화면에 표시되지 않습니다. `~/.sam/env`는 SAM-Codex와 SAM-Claude가
함께 사용할 수 있으므로 제품 설정 파일에 키를 다시 적지 않습니다.

## 3. 키와 허용 모델 확인하기

```bash
source "$HOME/.sam/env"
curl -fsSL --max-time 25 \
  -H "Authorization: Bearer $SAM_API_KEY" \
  "https://sam.soonsoon.ai/v2/openai/models" \
  -o "$HOME/.codex-sam/models.json"
chmod 600 "$HOME/.codex-sam/models.json"
```

오류 없이 끝났다면 키 인증과 SAM Codex 모델 권한이 확인된 것입니다.

```bash
SAM_MODEL=""
for candidate in \
  azure.gpt-5.6-luna \
  azure.gpt-5.6-terra \
  azure.gpt-5.6-sol
do
  if grep -Eq "\"slug\"[[:space:]]*:[[:space:]]*\"$candidate\"" \
    "$HOME/.codex-sam/models.json"; then
    SAM_MODEL="$candidate"
    break
  fi
done

if [[ -n "$SAM_MODEL" ]]; then
  echo "기본 SAM 모델: $SAM_MODEL"
else
  echo "사용 가능한 SAM Codex 모델이 없습니다. 다음 단계로 진행하지 마세요."
fi
```

## 4. SAM Codex 설정 만들기

```bash
cat > "$HOME/.codex-sam/config.toml" <<EOF
model = "$SAM_MODEL"
model_provider = "sam"
model_catalog_json = "models.json"
web_search = "disabled"
project_root_markers = [".git", ".sam-codex-root"]

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/openai"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
required = true
EOF

chmod 600 "$HOME/.codex-sam/config.toml"
unset SAM_MODEL SAM_API_KEY
```

## 5. `sam-codex` 실행 파일 만들기

아래 블록 전체를 한 번에 붙여 넣습니다.

```bash
cat > "$HOME/.local/bin/sam-codex" <<'EOF'
#!/usr/bin/env bash
# SAM_CODEX_INSTALLER_MANAGED=1
set -euo pipefail

SAM_HOME="$HOME/.sam"
CODEX_SAM_HOME="$HOME/.codex-sam"
ENV_FILE="$SAM_HOME/env"
DISCOVERY_URL="https://sam.soonsoon.ai/v2/openai/models"
DEFAULT_WORKSPACE="$HOME/SAM-Codex"

[[ -r "$ENV_FILE" ]] || {
  echo "Missing $ENV_FILE" >&2
  exit 1
}

source "$ENV_FILE"
export CODEX_HOME="$CODEX_SAM_HOME"
umask 077

catalog_tmp="$(mktemp "$CODEX_HOME/.models.XXXXXX")"
if curl -fsSL --max-time 15 \
  -H "Authorization: Bearer $SAM_API_KEY" \
  "$DISCOVERY_URL" > "$catalog_tmp" &&
  grep -q '"models"' "$catalog_tmp"; then
  mv "$catalog_tmp" "$CODEX_HOME/models.json"
else
  rm -f "$catalog_tmp"
  [[ -s "$CODEX_HOME/models.json" ]] || exit 1
  echo "Warning: 마지막으로 확인된 SAM 모델 목록을 사용합니다." >&2
fi

default_model="$(
  sed -n 's/^model = "\(azure\.gpt-5\.6-[a-z]*\)"$/\1/p' \
    "$CODEX_HOME/config.toml" | head -n 1
)"

case "$default_model" in
  azure.gpt-5.6-luna | azure.gpt-5.6-terra | azure.gpt-5.6-sol) ;;
  *) echo "SAM 기본 모델 설정이 올바르지 않습니다." >&2; exit 1 ;;
esac

if command -v git >/dev/null 2>&1 &&
  git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  :
elif [[ -e "$PWD/.sam-codex-root" ]]; then
  :
else
  mkdir -p "$DEFAULT_WORKSPACE"
  : > "$DEFAULT_WORKSPACE/.sam-codex-root"
  cd "$DEFAULT_WORKSPACE"
  echo "SAM-Codex workspace: $DEFAULT_WORKSPACE" >&2
fi

exec codex \
  -c 'model_provider="sam"' \
  -c "model=\"$default_model\"" \
  -c "model_catalog_json=\"$CODEX_HOME/models.json\"" \
  -c 'web_search="disabled"' \
  "$@"
EOF

chmod 755 "$HOME/.local/bin/sam-codex"
```

## 6. 터미널 명령 등록하기

기존 마커가 없을 때만 명령을 추가합니다. 정상 블록이 이미 있으면 재사용하고,
마커가 손상됐다면 아무것도 바꾸지 않습니다.

```bash
touch "$HOME/.zshrc"
SAM_START_COUNT="$(grep -Fxc "# >>> SAM-Codex managed >>>" "$HOME/.zshrc" || true)"
SAM_END_COUNT="$(grep -Fxc "# <<< SAM-Codex managed <<<" "$HOME/.zshrc" || true)"

if [[ "$SAM_START_COUNT" -eq 0 && "$SAM_END_COUNT" -eq 0 ]]; then
  cat >> "$HOME/.zshrc" <<'EOF'
# >>> SAM-Codex managed >>>
export PATH="$HOME/.local/bin:$PATH"
sam-codex() {
  command "$HOME/.local/bin/sam-codex" "$@"
}
# <<< SAM-Codex managed <<<
EOF
  source "$HOME/.zshrc"
elif [[ "$SAM_START_COUNT" -eq 1 && "$SAM_END_COUNT" -eq 1 ]] &&
  awk '
    $0 == "# >>> SAM-Codex managed >>>" {
      if (seen_start || seen_end) exit 1
      seen_start = 1
    }
    $0 == "# <<< SAM-Codex managed <<<" {
      if (!seen_start || seen_end) exit 1
      seen_end = 1
    }
    END { if (!seen_start || !seen_end) exit 1 }
  ' "$HOME/.zshrc"; then
  echo "기존 SAM-Codex 관리 블록을 사용합니다."
  source "$HOME/.zshrc"
else
  echo "SAM-Codex 마커가 손상됐습니다. ~/.zshrc를 확인하세요."
fi

unset SAM_START_COUNT SAM_END_COUNT
```

## 7. 연결 확인하기

```bash
type sam-codex
sam-codex mcp list
```

`sam-tools`가 `enabled`이면 MCP 연결이 정상입니다.

```bash
cd "$HOME"
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

정상 출력:

```text
workdir: /Users/사용자이름/SAM-Codex
model: azure.gpt-5.6-luna
provider: sam
```

모델은 현재 권한에 따라 Terra 또는 Sol일 수도 있습니다.

## 8. 공식 Codex로 돌아가기

SAM-Codex를 종료한 뒤:

```bash
codex
```

`codex`는 기존 `~/.codex`와 OpenAI/ChatGPT 로그인을 사용합니다.

## 수동 해제

아래 블록은 관리 마커가 시작·종료 각각 하나이고 순서도 정상일 때만
실행됩니다. 이상이 있으면 아무 파일도 변경하지 않습니다.

```bash
SAM_START_COUNT="$(grep -Fxc "# >>> SAM-Codex managed >>>" "$HOME/.zshrc" || true)"
SAM_END_COUNT="$(grep -Fxc "# <<< SAM-Codex managed <<<" "$HOME/.zshrc" || true)"

if [[ "$SAM_START_COUNT" -eq 1 && "$SAM_END_COUNT" -eq 1 ]] &&
  awk '
    $0 == "# >>> SAM-Codex managed >>>" {
      if (seen_start || seen_end) exit 1
      seen_start = 1
    }
    $0 == "# <<< SAM-Codex managed <<<" {
      if (!seen_start || seen_end) exit 1
      seen_end = 1
    }
    END { if (!seen_start || !seen_end) exit 1 }
  ' "$HOME/.zshrc"; then
  SAM_TRASH="$HOME/.Trash/SAM-Codex-manual-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$SAM_TRASH"

  awk '
    $0 == "# >>> SAM-Codex managed >>>" { managed = 1; next }
    $0 == "# <<< SAM-Codex managed <<<" { managed = 0; next }
    !managed { print }
  ' "$HOME/.zshrc" > "$HOME/.zshrc.sam-codex.tmp"
  mv "$HOME/.zshrc.sam-codex.tmp" "$HOME/.zshrc"

  [[ ! -e "$HOME/.local/bin/sam-codex" ]] ||
    mv "$HOME/.local/bin/sam-codex" "$SAM_TRASH/"
  [[ ! -d "$HOME/.codex-sam" ]] ||
    mv "$HOME/.codex-sam" "$SAM_TRASH/"
  [[ ! -d "$HOME/SAM-Codex" ]] ||
    mv "$HOME/SAM-Codex" "$SAM_TRASH/"

  unfunction sam-codex 2>/dev/null || true
  source "$HOME/.zshrc"
  echo "SAM-Codex 수동 해제 완료: $SAM_TRASH"
else
  echo "SAM-Codex 마커가 올바르지 않아 수동 해제를 중단했습니다."
fi

unset SAM_START_COUNT SAM_END_COUNT
```

공용 `~/.sam/env` 키는 SAM-Claude가 사용할 수 있으므로 보존합니다.
