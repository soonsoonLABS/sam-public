# SAM-Codex 완전 수동 설정 — macOS

[빠른 시작으로 돌아가기](./README.md)

자동 설치 프로그램 없이 SAM 전용 폴더, 설정, 실행 명령을 직접 구성합니다.
공식 `codex`, `~/.codex`, OpenAI/ChatGPT 로그인은 변경하지 않습니다.

> macOS와 zsh에서 최신 공식 Codex CLI를 사용할 수 있습니다. SAM discovery가
> 설치된 CLI 버전과 catalog 응답을 대조합니다.

## 1. SAM 전용 폴더 만들기

```bash
mkdir -p "$HOME/.sam" "$HOME/.codex-sam" "$HOME/.local/bin"
chmod 700 "$HOME/.sam" "$HOME/.codex-sam"
```

## 2. SAM API Key 저장하기

기존 `~/.sam/env`가 없다면 아래 블록을 붙여 넣습니다.

```bash
set +x
if [[ ! -r "$HOME/.sam/env" ]]; then
  printf 'SAM API Key: '
  read -r -s SAM_KEY </dev/tty
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

입력 문자는 화면에 표시되지 않습니다. 키 값은 `config.toml`, 프로젝트 파일,
Git, 명령 기록에 적지 않습니다.

## 3. 지원 Codex 버전 확인하기

```bash
codex --version
```

공식 Codex CLI가 없다면 최신 버전을 설치합니다.

```bash
npm install -g @openai/codex
codex --version
```

`sam-codex`는 설치된 semantic version을 SAM discovery에 전달하고 인증된
catalog만 사용합니다. catalog 형식이 맞지 않거나 client version이 응답과
다르면 실행하지 않습니다.

## 4. SAM Codex 설정 만들기

```bash
cat > "$HOME/.codex-sam/config.toml" <<'EOF'
model_provider = "sam"
model_catalog_json = "models.json"
web_search = "disabled"
project_root_markers = [".git", ".sam-codex-root"]

[model_providers.sam]
name = "SAM"
base_url = "https://sam.soonsoon.ai/v2/codex"
env_key = "SAM_API_KEY"
wire_api = "responses"

[mcp_servers.sam-tools]
url = "https://sam.soonsoon.ai/mcp"
bearer_token_env_var = "SAM_API_KEY"
required = true
EOF

chmod 600 "$HOME/.codex-sam/config.toml"
```

모델 ID를 고정해서 적지 않습니다. `sam-codex`가 실행될 때 Agent 페이지에서
선택된 모델을 인증된 discovery로 받아 결정합니다.

## 5. 검증된 `sam-codex` 실행 파일 받기

```bash
SAM_WRAPPER_TMP="$(mktemp "$HOME/.local/bin/.sam-codex.XXXXXX")"
if curl -fsSL \
  "https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/templates/sam-codex" \
  -o "$SAM_WRAPPER_TMP" &&
  grep -Fq "SAM_CODEX_INSTALLER_MANAGED=1" "$SAM_WRAPPER_TMP"; then
  chmod 755 "$SAM_WRAPPER_TMP"
  mv "$SAM_WRAPPER_TMP" "$HOME/.local/bin/sam-codex"
  echo "sam-codex 실행 파일을 설치했습니다."
else
  rm -f "$SAM_WRAPPER_TMP"
  echo "실행 파일을 받지 못했습니다. 다음 단계로 진행하지 마세요."
fi
unset SAM_WRAPPER_TMP
```

이 파일이 모델 cache 형식, Codex 버전, 숨김 모델, 안전한 모델 ID를 검사합니다.
갱신 실패 시 이전 cache 파일은 보존하지만 제거된 모델일 수 있어 Codex를
실행하지 않습니다.

## 6. 터미널 명령 등록하기

아래 블록은 SAM 관리 마커가 없거나 정확히 한 쌍일 때만 변경합니다. 마커가
손상됐거나 중복되면 `.zshrc`를 그대로 둡니다.

```bash
touch "$HOME/.zshrc"
SAM_START="# >>> SAM-Codex managed >>>"
SAM_END="# <<< SAM-Codex managed <<<"
SAM_START_COUNT="$(grep -Fxc "$SAM_START" "$HOME/.zshrc" || true)"
SAM_END_COUNT="$(grep -Fxc "$SAM_END" "$HOME/.zshrc" || true)"

SAM_BLOCK_OK=0
if [[ "$SAM_START_COUNT" -eq 0 && "$SAM_END_COUNT" -eq 0 ]]; then
  SAM_BLOCK_OK=1
elif [[ "$SAM_START_COUNT" -eq 1 && "$SAM_END_COUNT" -eq 1 ]] &&
  awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start {
      if (seen_start || seen_end) exit 1
      seen_start = 1
    }
    $0 == end {
      if (!seen_start || seen_end) exit 1
      seen_end = 1
    }
    END { if (!seen_start || !seen_end) exit 1 }
  ' "$HOME/.zshrc"; then
  SAM_BLOCK_OK=1
fi

if [[ "$SAM_BLOCK_OK" -eq 1 ]]; then
  SAM_ZSHRC_TMP="$(mktemp "$HOME/.zshrc.sam-codex.XXXXXX")"
  awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$HOME/.zshrc" > "$SAM_ZSHRC_TMP"
  cat >> "$SAM_ZSHRC_TMP" <<'EOF'
# >>> SAM-Codex managed >>>
export PATH="$HOME/.local/bin:$PATH"
sam-codex() {
  command "$HOME/.local/bin/sam-codex" "$@"
}
# <<< SAM-Codex managed <<<
EOF
  mv "$SAM_ZSHRC_TMP" "$HOME/.zshrc"
  source "$HOME/.zshrc"
else
  echo "SAM-Codex 마커가 손상됐습니다. ~/.zshrc는 변경하지 않았습니다."
fi

unset SAM_START SAM_END SAM_START_COUNT SAM_END_COUNT SAM_BLOCK_OK SAM_ZSHRC_TMP
```

## 7. 연결 확인하기

먼저 생성 비용이 없는 설정·discovery를 확인합니다.

```bash
type sam-codex
sam-codex --version
sam-codex mcp list
```

- 화면 제목 `OpenAI Codex`: 정상
- 모델: Agent 페이지에서 선택한 native 또는 인증된 호환 모델의 원래 alias
- `sam-tools ... enabled`: SAM MCP 연결

Codex 안에서 `/model`을 열면 Agent 페이지에서 선택한 V2-native 모델과 인증된
호환 모델이 원래 이름으로 함께 표시되어야 합니다.

실제 모델 호출은 사용량이 기록될 수 있습니다.

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

## 8. 공식 Codex 사용하기

SAM-Codex를 종료한 뒤 평소처럼 실행합니다.

```bash
codex
```

`codex`는 계속 기존 `~/.codex`와 OpenAI/ChatGPT 로그인을 사용합니다.

## 수동 해제

아래 블록은 정상 SAM 관리 블록과 관리된 wrapper만 제거합니다.
`~/.codex-sam`은 휴지통으로 이동하고, 공식 Codex와 공용 `~/.sam/env` 키는
보존합니다.

```bash
SAM_START="# >>> SAM-Codex managed >>>"
SAM_END="# <<< SAM-Codex managed <<<"
SAM_START_COUNT="$(grep -Fxc "$SAM_START" "$HOME/.zshrc" || true)"
SAM_END_COUNT="$(grep -Fxc "$SAM_END" "$HOME/.zshrc" || true)"

if [[ "$SAM_START_COUNT" -eq 1 && "$SAM_END_COUNT" -eq 1 ]] &&
  awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start {
      if (seen_start || seen_end) exit 1
      seen_start = 1
    }
    $0 == end {
      if (!seen_start || seen_end) exit 1
      seen_end = 1
    }
    END { if (!seen_start || !seen_end) exit 1 }
  ' "$HOME/.zshrc"; then
  SAM_ZSHRC_TMP="$(mktemp "$HOME/.zshrc.sam-codex.XXXXXX")"
  awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$HOME/.zshrc" > "$SAM_ZSHRC_TMP"
  mv "$SAM_ZSHRC_TMP" "$HOME/.zshrc"

  if [[ -f "$HOME/.local/bin/sam-codex" ]] &&
    grep -Fq "SAM_CODEX_INSTALLER_MANAGED=1" \
      "$HOME/.local/bin/sam-codex"; then
    rm -f "$HOME/.local/bin/sam-codex"
  fi

  if [[ -d "$HOME/.codex-sam" ]]; then
    SAM_TRASH="$HOME/.Trash/SAM-Codex-manual-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$HOME/.Trash"
    mv "$HOME/.codex-sam" "$SAM_TRASH"
    echo "SAM-Codex 설정을 휴지통으로 이동했습니다: $SAM_TRASH"
  fi

  source "$HOME/.zshrc"
else
  echo "SAM-Codex 마커가 없거나 손상됐습니다. 아무것도 삭제하지 않았습니다."
fi

unset SAM_START SAM_END SAM_START_COUNT SAM_END_COUNT SAM_ZSHRC_TMP SAM_TRASH
```
