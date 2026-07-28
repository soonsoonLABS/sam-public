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

## 방법 3 — 설치 파일 없이 완전 수동 설정

자동 설치기를 사용하지 않고 모든 파일을 직접 만들려면 아래 순서대로
진행합니다. 이미 자동 설치를 완료했다면 이 과정은 다시 할 필요가 없습니다.

### 1. SAM 전용 폴더 만들기

```bash
mkdir -p "$HOME/.sam" "$HOME/.codex-sam" "$HOME/.local/bin"
chmod 700 "$HOME/.sam" "$HOME/.codex-sam"
```

### 2. SAM API Key 저장하기

기존 `~/.sam/env`가 없다면 다음 블록을 실행합니다.

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

키 값은 화면에 표시되지 않습니다. 이 파일은 SAM-Codex와 SAM-Claude가 함께
사용할 수 있으므로 제품별 설정 파일에 키를 다시 적지 않습니다.

### 3. 키와 허용 모델 확인하기

```bash
source "$HOME/.sam/env"
curl -fsSL --max-time 25 \
  -H "Authorization: Bearer $SAM_API_KEY" \
  "https://sam.soonsoon.ai/v2/openai/models" \
  -o "$HOME/.codex-sam/models.json"
chmod 600 "$HOME/.codex-sam/models.json"
```

오류 없이 끝났다면 키 인증과 SAM Codex 모델 권한이 확인된 것입니다. 허용된
모델 중 기본 모델을 정합니다.

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

### 4. SAM Codex 설정 만들기

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

여기서 OpenAI provider가 아니라 SAM V2의 Responses API를 사용하도록
고정합니다. Codex 내장 검색은 끄고 SAM MCP 검색·페이지 읽기를 연결합니다.

### 5. `sam-codex` 실행 파일 만들기

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

Git 프로젝트가 아닌 곳에서는 자동으로 `~/SAM-Codex`를 사용합니다. 따라서
홈 폴더의 공식 `~/.codex/config.toml`이 SAM 설정에 섞이지 않습니다.

### 6. 터미널 명령 등록하기

다음 블록은 기존 마커가 없을 때만 새 명령을 추가합니다. 정상 관리 블록이
이미 있으면 다시 추가하지 않으며, 마커가 손상됐으면 아무것도 바꾸지 않습니다.

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

과거에 직접 만든 `sam-codex()` 함수가 앞에 남아 있어도 마지막 관리 함수가
새 실행 파일을 사용하도록 덮어씁니다.

### 7. 수동 설치 확인하기

```bash
type sam-codex
sam-codex mcp list
```

`sam-tools`가 `enabled`이면 MCP 연결이 정상입니다. 실제 SAM 모델 호출은:

```bash
cd "$HOME"
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

출력에 아래 세 항목이 보여야 합니다.

```text
workdir: /Users/사용자이름/SAM-Codex
model: azure.gpt-5.6-luna
provider: sam
```

모델은 현재 권한에 따라 Terra 또는 Sol일 수도 있습니다.

### 8. 공식 Codex로 돌아가기

SAM-Codex를 종료한 뒤 평소처럼 실행합니다.

```bash
codex
```

`codex`는 기존 `~/.codex`와 OpenAI/ChatGPT 로그인을 사용합니다.
`sam-codex`만 `~/.codex-sam`과 SAM API Key를 사용합니다.

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

### 설치 파일 없이 수동 해제

아래 블록은 마커가 시작·종료 각각 하나이고 순서도 정상일 때만 실행됩니다.
이상이 있으면 아무 파일도 옮기거나 수정하지 않습니다. SAM 전용 파일은
삭제하지 않고 휴지통으로 옮깁니다.

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

공용 `~/.sam/env` 키는 SAM-Claude가 사용할 수 있으므로 보존합니다. 모든 SAM
클라이언트를 해제한 경우에만 별도로 삭제하세요.

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
