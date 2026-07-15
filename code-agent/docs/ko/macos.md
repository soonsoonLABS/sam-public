# macOS에서 SAM Codex 사용하기

**언어:** [English](../macos.md) | 한국어

이 가이드는 전용 `sam-codex` 터미널 명령을 만듭니다. 이 명령으로만 SAM을
사용하므로 기존 `codex` 환경은 바뀌지 않습니다.

## 1. 사전 도구 설치

`sam-public`을 내려받기 전에 Git, Node.js LTS(npm 포함), Codex CLI를
설치합니다.

```bash
# `git --version`이 실패할 때만 실행합니다. macOS 대화상자를 완료한 뒤 새 터미널을 엽니다.
xcode-select --install

# Homebrew 사용 시. Homebrew가 없으면 https://nodejs.org 에서 Node.js LTS 설치 프로그램을 사용합니다.
brew install node
npm install -g @openai/codex@latest

git --version
node --version
npm --version
codex --version
```

Homebrew가 없으면 nodejs.org의 Node.js LTS 설치 프로그램을 사용하세요.
npm은 Node.js에 포함됩니다. `codex --version`이 성공하기 전에는 다음
단계로 진행하지 마세요.

## 2. 설치 저장소 내려받기 또는 업데이트

처음 한 번만 저장소를 내려받습니다. 이후에는 `git clone`을 다시 하지
말고 기존 저장소를 업데이트합니다.

```bash
if [ -d "$HOME/sam-public/.git" ]; then
  git -C "$HOME/sam-public" pull --ff-only
elif [ -e "$HOME/sam-public" ]; then
  echo "~/sam-public은 존재하지만 Git 저장소가 아닙니다. 내용을 확인한 뒤에만 이름 변경 또는 삭제하세요."
  exit 1
else
  git clone https://github.com/soonsoonLABS/sam-public.git "$HOME/sam-public"
fi

cd "$HOME/sam-public/code-agent"
```

## 3. 전용 SAM 명령 설치

설치 프로그램을 실행하고 숨김 입력창에만 SAM API 키를 붙여 넣습니다.
키 소유자에게 `agent:codex` 또는 `agent:coding_agents` 권한이 있어야
합니다.

```bash
unset SAM_API_KEY
bash install-macos.sh
```

설치 프로그램은 `~/.local/bin/sam-codex`를 만듭니다. 명령이 보이지
않으면 다음을 한 번 실행하고 새 터미널을 여세요.

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
sam-codex --version
```

## 4. SAM Codex 실행

SAM 세션에서는 일반 `codex`가 아니라 항상 `sam-codex`를 사용합니다.

```bash
# SAM을 사용하는 대화형 Codex 터미널 UI
sam-codex

# 비대화형 스모크 테스트
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  'Reply with exactly: SAM-CODEX-OK'
```

스모크 테스트의 정상 응답은 정확히 `SAM-CODEX-OK`입니다. PATH에 아직
명령이 없다면 전체 경로를 사용합니다.

```bash
~/.local/bin/sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  'Reply with exactly: SAM-CODEX-OK'
```

## 5. SAM API 키 변경

설치 프로그램을 다시 실행합니다. `unset`은 현재 셸에 상속된 기존 키를
재사용하지 않고 숨김 입력창을 표시하게 하므로 중요합니다.

```bash
cd "$HOME/sam-public/code-agent"
unset SAM_API_KEY
bash install-macos.sh
```

이 작업은 일반 Codex 설정이 아니라 `~/.sam-code-agent/env`만 덮어씁니다.
더 이상 사용하지 않는 이전 키는 SAM에서 폐기하세요.

## 6. 키 직접 호출 테스트

Codex를 거치기 전에 SAM 키와 `/openai/v1/responses` 경로를 확인합니다.
키 자체는 출력하지 않으며, 성공한 응답에는
`"output_text":"SAM-CODEX-OK"`가 포함됩니다.

```bash
source "$HOME/.sam-code-agent/env"
curl --silent --show-error --fail-with-body --max-time 120 -X POST \
  'https://sam.soonsoon.ai/openai/v1/responses' \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{"model":"sam-codex-agent","input":"Reply with exactly: SAM-CODEX-OK","stream":false}'
unset SAM_API_KEY
```

직접 호출은 성공하지만 `sam-codex exec`가 실패하면 키와 SAM 경로는 정상입니다.
설치 프로그램을 다시 실행한 뒤 일반 `codex`가 아닌 전용 명령을 사용하세요.

## 7. 데스크톱 바로가기 만들기

설치가 끝난 뒤 데스크톱에서 실행할 수 있는 터미널 launcher를 만듭니다.

```bash
cat > "$HOME/Desktop/SAM-Codex.command" <<'EOF'
#!/bin/zsh
exec "$HOME/.local/bin/sam-codex"
EOF
chmod +x "$HOME/Desktop/SAM-Codex.command"
```

`SAM-Codex.command`를 더블클릭하면 SAM Codex 터미널 UI가 열립니다. 처음에는
macOS가 로컬 실행 파일 확인을 요청할 수 있습니다.

## 데스크톱 앱 참고

`sam-codex app`은 macOS에서 ChatGPT 데스크톱 앱을 열 수 있습니다. 다만
전용 SAM 세션에는 `sam-codex` 터미널 명령을 권장합니다. 데스크톱 앱은
실행마다 분리된 SAM 프로필을 신뢰성 있게 보장하지 않습니다.
