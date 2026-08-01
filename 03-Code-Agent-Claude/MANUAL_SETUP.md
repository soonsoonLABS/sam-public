# SAM-Claude 완전 수동 설정 — macOS

[빠른 시작으로 돌아가기](./README.md)

자동 설치 프로그램 없이 공용 키, 격리 홈, 검증 wrapper, SAM MCP, 터미널
명령을 직접 구성합니다. 공식 `claude`, `~/.claude`, Anthropic 로그인은
변경하지 않습니다.

> 아래 블록은 같은 터미널에서 위에서 아래 순서로 실행하세요. Windows에서
> 설치 파일을 먼저 검토한 뒤 실행하는 방법은 [Windows](#windows에서-파일을-먼저-확인해-설치) 절을
> 참고하세요.

## 1. 준비 확인

```bash
claude --version
command -v curl
command -v python3 || command -v node
```

Claude Code는 `2.1.129` 이상이어야 합니다. 낮은 버전이면
[Anthropic 공식 설치 안내](https://code.claude.com/docs/en/setup)에 따라
업데이트하세요.

## 2. 전용 폴더 만들기

```bash
umask 077
SAM_PATHS_OK=1
for SAM_PATH in \
  "$HOME/.sam" \
  "$HOME/.claude-sam" \
  "$HOME/.local" \
  "$HOME/.local/bin" \
  "$HOME/.zshrc"
do
  if [[ -L "$SAM_PATH" ]]; then
    echo "심볼릭 링크 경로를 수동 설정으로 변경하지 않습니다: $SAM_PATH"
    SAM_PATHS_OK=0
  fi
done
if [[ "$SAM_PATHS_OK" -eq 1 ]]; then
  mkdir -p "$HOME/.sam" "$HOME/.claude-sam" "$HOME/.local/bin"
  chmod 700 "$HOME/.sam" "$HOME/.claude-sam"
else
  echo "다음 단계로 진행하지 마세요."
  false
fi
unset SAM_PATH SAM_PATHS_OK
```

공식 Claude 설정 홈인 `~/.claude`는 만들거나 수정하지 않습니다.

## 3. 공용 SAM API Key 저장

기존 `~/.sam/env`가 있으면 그대로 사용합니다. 없을 때만 아래 블록이 키를
화면에 표시하지 않고 입력받습니다.

```bash
set +x
if [[ -e "$HOME/.sam/env" ]] &&
  { [[ -L "$HOME/.sam/env" ]] ||
    [[ ! -f "$HOME/.sam/env" ]] ||
    [[ ! -r "$HOME/.sam/env" ]]; }; then
  echo "기존 ~/.sam/env가 읽을 수 있는 일반 파일이 아닙니다."
  echo "덮어쓰지 않았습니다. 다음 단계로 진행하지 마세요."
  false
elif [[ ! -e "$HOME/.sam/env" ]]; then
  printf 'SAM API key: '
  IFS= read -r -s SAM_KEY </dev/tty
  printf '\n'
  if [[ -n "$SAM_KEY" ]]; then
    printf 'export SAM_API_KEY=%q\n' "$SAM_KEY" >"$HOME/.sam/env"
    chmod 600 "$HOME/.sam/env"
  else
    echo "키가 비어 있습니다. 다음 단계로 진행하지 마세요."
  fi
  unset SAM_KEY
else
  echo "기존 ~/.sam/env 키를 사용합니다."
fi
```

키 값은 `settings.json`, 프로젝트 `.env`, Git, 명령 인자에 적지 않습니다.

## 4. 검증된 wrapper 받기

공개 installer에 고정된 SHA-256과 wrapper 파일을 대조합니다. 다운로드나
검증이 실패하면 다음 단계로 진행하지 마세요.

```bash
SAM_MANUAL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sam-claude-manual.XXXXXX")"
SAM_INSTALLER_URL="https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-macos.sh"
SAM_WRAPPER_URL="https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/templates/sam-claude"

curl -fsSL "$SAM_INSTALLER_URL" -o "$SAM_MANUAL_TMP/install-macos.sh"
curl -fsSL "$SAM_WRAPPER_URL" -o "$SAM_MANUAL_TMP/sam-claude"

SAM_EXPECTED_SHA="$(
  sed -n 's/^WRAPPER_SHA256="\([0-9a-f][0-9a-f]*\)"$/\1/p' \
    "$SAM_MANUAL_TMP/install-macos.sh"
)"
if command -v shasum >/dev/null 2>&1; then
  SAM_ACTUAL_SHA="$(shasum -a 256 "$SAM_MANUAL_TMP/sam-claude" | awk '{print $1}')"
else
  SAM_ACTUAL_SHA="$(sha256sum "$SAM_MANUAL_TMP/sam-claude" | awk '{print $1}')"
fi

if [[ ${#SAM_EXPECTED_SHA} -eq 64 ]] &&
  [[ "$SAM_ACTUAL_SHA" == "$SAM_EXPECTED_SHA" ]] &&
  [[ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' \
    "$SAM_MANUAL_TMP/sam-claude" || true)" -eq 1 ]]; then
  chmod 755 "$SAM_MANUAL_TMP/sam-claude"
  echo "wrapper 검증 성공"
else
  echo "wrapper 검증 실패. 다음 단계로 진행하지 마세요."
  false
fi
```

wrapper 안에 고정 모델 목록을 적지 않습니다. 실행 때마다 현재 계정의
discovery와 역할 매핑을 대조합니다.

## 5. 생성 없이 discovery와 역할 매핑 검증

```bash
SAM_CLAUDE_STATE_PATH="$SAM_MANUAL_TMP/runtime-state.json" \
SAM_CLAUDE_PREFLIGHT_ONLY=1 \
  "$SAM_MANUAL_TMP/sam-claude"
```

정상 출력 예:

```text
SAM-Claude preflight OK: Claude Code <현재 버전>, Sonnet 1M yes 또는 no
```

이 단계는 다음 조건을 검사합니다.

- `/v2/claude/v1/models` 인증 성공
- Haiku / Sonnet / Opus의 저장된 backing alias가 모두 discovery에 존재
- 선택된 세 alias가 서로 다름
- 선택된 Sonnet의 context로 `sonnet[1m]` 가능 여부 계산
- 호환 모델은 discovery가 실제 반환한 `claude-sam-*` ID만 허용

오류가 나면 기존 모델명으로 추측해 계속하지 말고
[문제 해결](./TROUBLESHOOTING.md)을 확인하세요.

## 6. 격리된 SAM MCP 추가

먼저 현재 격리 설정에 같은 이름의 MCP가 있는지 확인합니다. 아래 예시는
Python 3을 사용합니다. Node.js만 있다면 자동 installer를 사용하는 편이
안전합니다.

```bash
MCP_STATUS="$(
  python3 - "$HOME/.claude-sam/.claude.json" <<'PY'
import json
import os
import sys

path = sys.argv[1]
if not os.path.exists(path):
    print("absent")
    raise SystemExit
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    print("conflict")
    raise SystemExit
if not isinstance(data, dict):
    print("conflict")
    raise SystemExit
servers = data.get("mcpServers", {})
if "mcpServers" in data and not isinstance(servers, dict):
    print("conflict")
    raise SystemExit
server = servers.get("sam-tools")
if server is None:
    print("absent")
elif (
    isinstance(server, dict)
    and server.get("type") == "http"
    and server.get("url") == "https://sam.soonsoon.ai/mcp"
    and isinstance(server.get("headers"), dict)
    and server["headers"].get("Authorization") == "Bearer ${SAM_API_KEY}"
):
    print("valid")
else:
    print("conflict")
PY
)"

case "$MCP_STATUS" in
  valid)
    echo "기존 sam-tools 설정을 그대로 사용합니다."
    ;;
  absent)
    set +x
    # 환경변수 참조가 실제 키로 확장되지 않도록 작은따옴표를 유지합니다.
    CLAUDE_CONFIG_DIR="$HOME/.claude-sam" \
      claude mcp add --transport http --scope user \
        sam-tools "https://sam.soonsoon.ai/mcp" \
        --header 'Authorization: Bearer ${SAM_API_KEY}'
    ;;
  *)
    echo "기존 sam-tools가 다른 설정입니다. 덮어쓰지 말고 먼저 확인하세요."
    false
    ;;
esac
unset MCP_STATUS
```

공식 Claude의 MCP 설정이 아니라 `~/.claude-sam/.claude.json`만 사용합니다.
Authorization에는 실제 키가 아닌 `${SAM_API_KEY}` 참조가 저장돼야 합니다.

## 7. wrapper와 검증 상태 설치

기존에 직접 만든 같은 이름의 파일이 있으면 덮어쓰지 않습니다.

```bash
SAM_WRAPPER_TARGET="$HOME/.local/bin/sam-claude"
if [[ -L "$SAM_WRAPPER_TARGET" ]]; then
  echo "대상 wrapper가 심볼릭 링크입니다. 다음 단계로 진행하지 마세요."
  false
elif [[ -e "$SAM_WRAPPER_TARGET" ]] &&
  [[ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' \
    "$SAM_WRAPPER_TARGET" || true)" -ne 1 ]]; then
  echo "직접 만든 sam-claude 파일이 있습니다. 먼저 별도 이름으로 백업하세요."
  false
else
  SAM_WRAPPER_INSTALL_TMP="$(mktemp "$HOME/.local/bin/.sam-claude.XXXXXX")"
  cp "$SAM_MANUAL_TMP/sam-claude" "$SAM_WRAPPER_INSTALL_TMP"
  chmod 755 "$SAM_WRAPPER_INSTALL_TMP"
  mv "$SAM_WRAPPER_INSTALL_TMP" "$SAM_WRAPPER_TARGET"

  SAM_STATE_INSTALL_TMP="$(mktemp "$HOME/.claude-sam/.runtime-state.XXXXXX")"
  cp "$SAM_MANUAL_TMP/runtime-state.json" "$SAM_STATE_INSTALL_TMP"
  chmod 600 "$SAM_STATE_INSTALL_TMP"
  mv "$SAM_STATE_INSTALL_TMP" "$HOME/.claude-sam/runtime-state.json"
fi
```

## 8. 터미널 명령 등록

아래 블록은 관리 마커가 없거나 정확히 한 쌍일 때만 `.zshrc`를 바꿉니다.
누락, 역순, 중복 마커가 있으면 다른 셸 설정을 보존하고 중단합니다.

```bash
SAM_START="# >>> SAM-Claude managed >>>"
SAM_END="# <<< SAM-Claude managed <<<"
SAM_BLOCK_OK=0
SAM_WRAPPER_TARGET="$HOME/.local/bin/sam-claude"
SAM_WRAPPER_READY=0

if command -v shasum >/dev/null 2>&1; then
  SAM_INSTALLED_SHA="$(shasum -a 256 "$SAM_WRAPPER_TARGET" 2>/dev/null |
    awk '{print $1}')"
else
  SAM_INSTALLED_SHA="$(sha256sum "$SAM_WRAPPER_TARGET" 2>/dev/null |
    awk '{print $1}')"
fi

if [[ -f "$SAM_WRAPPER_TARGET" ]] &&
  [[ ! -L "$SAM_WRAPPER_TARGET" ]] &&
  [[ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' \
    "$SAM_WRAPPER_TARGET" || true)" -eq 1 ]] &&
  [[ ${#SAM_EXPECTED_SHA} -eq 64 ]] &&
  [[ "$SAM_INSTALLED_SHA" == "$SAM_EXPECTED_SHA" ]]; then
  SAM_WRAPPER_READY=1
else
  echo "검증된 SAM-Claude wrapper가 없어 ~/.zshrc를 변경하지 않습니다."
fi

if [[ "$SAM_WRAPPER_READY" -ne 1 ]]; then
  echo "검증된 SAM-Claude wrapper가 없으므로 ~/.zshrc를 변경하지 않습니다."
  false
elif [[ -L "$HOME/.zshrc" ]]; then
  echo "~/.zshrc가 심볼릭 링크라서 변경하지 않습니다."
  false
else
  touch "$HOME/.zshrc"
  SAM_START_COUNT="$(grep -Fxc "$SAM_START" "$HOME/.zshrc" || true)"
  SAM_END_COUNT="$(grep -Fxc "$SAM_END" "$HOME/.zshrc" || true)"
  if [[ "$SAM_START_COUNT" -eq 0 && "$SAM_END_COUNT" -eq 0 ]]; then
    SAM_BLOCK_OK=1
  elif [[ "$SAM_START_COUNT" -eq 1 && "$SAM_END_COUNT" -eq 1 ]] &&
    awk -v start="$SAM_START" -v end="$SAM_END" '
      $0 == start {
        if (seen_start || seen_end) exit 1
        seen_start = 1
        next
      }
      $0 == end {
        if (!seen_start || seen_end) exit 1
        seen_end = 1
      }
      END { if (!seen_start || !seen_end) exit 1 }
    ' "$HOME/.zshrc"; then
    SAM_BLOCK_OK=1
  fi
fi

if [[ "$SAM_BLOCK_OK" -eq 1 ]]; then
  SAM_ZSHRC_TMP="$(mktemp "$HOME/.zshrc.sam-claude.XXXXXX")"
  awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$HOME/.zshrc" >"$SAM_ZSHRC_TMP"
  if [[ -s "$SAM_ZSHRC_TMP" ]] &&
    [[ "$(tail -c 1 "$SAM_ZSHRC_TMP" | wc -l | tr -d ' ')" -eq 0 ]]; then
    printf '\n' >>"$SAM_ZSHRC_TMP"
  fi
  cat >>"$SAM_ZSHRC_TMP" <<'EOF'
# >>> SAM-Claude managed >>>
export PATH="$HOME/.local/bin:$PATH"
sam-claude() {
  command "$HOME/.local/bin/sam-claude" "$@"
}
# <<< SAM-Claude managed <<<
EOF
  mv "$SAM_ZSHRC_TMP" "$HOME/.zshrc"
  source "$HOME/.zshrc"
else
  echo "SAM-Claude 마커가 손상됐습니다. ~/.zshrc는 변경하지 않았습니다."
  false
fi

unset SAM_START SAM_END SAM_START_COUNT SAM_END_COUNT SAM_BLOCK_OK
unset SAM_WRAPPER_READY SAM_INSTALLED_SHA
unset SAM_ZSHRC_TMP SAM_WRAPPER_TARGET SAM_WRAPPER_INSTALL_TMP
unset SAM_STATE_INSTALL_TMP SAM_EXPECTED_SHA SAM_ACTUAL_SHA
unset SAM_INSTALLER_URL SAM_WRAPPER_URL
rm -rf "$SAM_MANUAL_TMP"
unset SAM_MANUAL_TMP
```

## 9. 확인과 사용

```bash
type sam-claude
sam-claude --version
sam-claude mcp list
```

`sam-claude --version`도 먼저 runtime discovery와 역할 매핑을 검증한 뒤 공식
Claude Code 버전을 표시합니다.

대화형 실행:

```bash
sam-claude
```

Claude Code 안에서 `/model`을 열어 현재 반환된 모델을 선택합니다. 실제 생성
테스트는 SAM 사용량과 비용이 기록될 수 있습니다.

```bash
sam-claude -p --model sonnet "Reply with exactly: SAM-CLAUDE-OK"
```

공식 Anthropic 환경으로 돌아갈 때는 SAM-Claude를 종료하고 평소처럼 실행합니다.

```bash
claude
```

## 수동 해제

아래 블록은 정상 관리 블록과 installer가 소유한 wrapper만 제거합니다.
공식 `claude`, `~/.claude`, 공용 `~/.sam/env`, `sam-codex`,
`~/.claude-sam` 세션과 MCP는 보존합니다.

```bash
SAM_START="# >>> SAM-Claude managed >>>"
SAM_END="# <<< SAM-Claude managed <<<"
SAM_WRAPPER="$HOME/.local/bin/sam-claude"
SAM_START_COUNT="$(grep -Fxc "$SAM_START" "$HOME/.zshrc" || true)"
SAM_END_COUNT="$(grep -Fxc "$SAM_END" "$HOME/.zshrc" || true)"

if [[ -L "$HOME/.zshrc" ]] ||
  [[ "$SAM_START_COUNT" -ne 1 || "$SAM_END_COUNT" -ne 1 ]] ||
  ! awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start {
      if (seen_start || seen_end) exit 1
      seen_start = 1
      next
    }
    $0 == end {
      if (!seen_start || seen_end) exit 1
      seen_end = 1
    }
    END { if (!seen_start || !seen_end) exit 1 }
  ' "$HOME/.zshrc"; then
  echo "관리 마커가 정상이 아닙니다. 아무것도 제거하지 않았습니다."
  false
elif [[ -L "$SAM_WRAPPER" ]] ||
  { [[ -e "$SAM_WRAPPER" ]] &&
    [[ "$(grep -Fxc '# SAM_CLAUDE_INSTALLER_MANAGED=1' \
      "$SAM_WRAPPER" || true)" -ne 1 ]]; }; then
  echo "관리되지 않은 wrapper입니다. 아무것도 제거하지 않았습니다."
  false
else
  SAM_ZSHRC_TMP="$(mktemp "$HOME/.zshrc.sam-claude.XXXXXX")"
  awk -v start="$SAM_START" -v end="$SAM_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$HOME/.zshrc" >"$SAM_ZSHRC_TMP"
  mv "$SAM_ZSHRC_TMP" "$HOME/.zshrc"

  if [[ -e "$SAM_WRAPPER" ]]; then
    mkdir -p "$HOME/.Trash"
    mv "$SAM_WRAPPER" \
      "$HOME/.Trash/sam-claude-$(date +%Y%m%d-%H%M%S)"
  fi
  source "$HOME/.zshrc"
  echo "SAM-Claude 명령을 해제했습니다. 세션과 공용 키는 보존했습니다."
fi

unset SAM_START SAM_END SAM_WRAPPER SAM_START_COUNT SAM_END_COUNT SAM_ZSHRC_TMP
```

격리 세션과 MCP도 제거하려면 삭제 전에 내용을 확인한 뒤 복구 가능한 위치로
옮깁니다.

```bash
if [[ -d "$HOME/.claude-sam" && ! -L "$HOME/.claude-sam" ]]; then
  mkdir -p "$HOME/.Trash"
  mv "$HOME/.claude-sam" \
    "$HOME/.Trash/SAM-Claude-$(date +%Y%m%d-%H%M%S)"
fi
```

## Windows에서 파일을 먼저 확인해 설치

PowerShell 자동 실행 대신 설치 파일을 내려받고 내용을 확인한 뒤 실행할 수
있습니다. 이 방법도 공식 Claude 설정과 공용 키를 분리하는 동일한 installer를
사용합니다.

```powershell
$installer = Join-Path $env:TEMP "install-sam-claude.ps1"
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/03-Code-Agent-Claude/install-windows.ps1" `
  -OutFile $installer
Get-Content $installer
```

내용을 확인한 뒤:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
Remove-Item -Force $installer
```

Windows installer가 직접 구성하는 경로는 다음과 같습니다.

```text
%USERPROFILE%\.sam\env.ps1
%USERPROFILE%\.claude-sam
%USERPROFILE%\bin\sam-claude.ps1
%USERPROFILE%\bin\sam-claude.cmd
```

기본 Windows 해제는 명령만 제거하고 세션과 공용 키를 보존합니다. 격리
데이터까지 백업 폴더로 옮기려면 `-PurgeData`를 명시합니다.
