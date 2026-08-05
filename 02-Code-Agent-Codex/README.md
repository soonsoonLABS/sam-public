# SAM-Codex 빠른 시작 — macOS / Windows

공식 OpenAI `codex`는 그대로 두고, SAM 전용 `sam-codex`를 추가합니다.

| 실행 명령 | 연결 | 설정 |
| --- | --- | --- |
| `codex` | OpenAI / ChatGPT | `~/.codex` |
| `sam-codex` | SAM V2 + SAM MCP | `~/.codex-sam` |

> 처음 설치한다면 아래 **1~3단계만** 진행하세요.

## 준비

- macOS 기본 터미널/iTerm 또는 Windows PowerShell
- [SAM API Keys](https://sam.soonsoon.ai/api-keys)에서 발급한 Code Agent 권한 키
- 공식 Codex CLI

Codex가 없다면:

```bash
npm install -g @openai/codex@0.146.0
codex --version
```

Windows PowerShell에서는 먼저 실행 정책을 설정하고 같은 명령을 실행합니다.

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
npm install -g @openai/codex@0.146.0
codex --version
```

현재 SAM 전용 모델 카탈로그는 Codex `0.145.x`와 `0.146.0`을 허용합니다.
검증되지 않은 이후 버전은 내장 모델이 다시 노출되지 않도록 실행을 중단합니다.

## 1. 한 줄 설치

아래 한 줄을 터미널에 그대로 붙여 넣습니다.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/install-macos.sh) && source "$HOME/.zshrc"
```

### Windows PowerShell

Windows 설치·수동 설정·검증은 [Windows 설치 가이드](./WINDOWS_SETUP.md)를
따르세요. 설치 파일이 있는 폴더에서 다음을 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

`SAM API key:`가 나오면 발급받은 키를 붙여 넣고 Enter를 누릅니다. 입력한
문자는 화면에 표시되지 않습니다.

성공하면 다음 메시지가 나옵니다.

```text
SAM-Codex installed successfully.
SAM Codex: sam-codex
```

## 2. 실행

```bash
sam-codex
```

Windows PowerShell에서는 새 창을 연 뒤 같은 `sam-codex` 명령을 실행합니다.

Git 프로젝트가 아닌 곳에서 실행하면 안전한 `~/SAM-Codex` 작업 폴더로
자동 이동합니다.

## 3. 정상 연결 확인

화면 상단의 **`OpenAI Codex` 표시는 정상**입니다. 같은 Codex CLI를 사용하되
연결 대상만 SAM으로 바뀝니다.

다음 두 항목을 확인하세요.

```text
model: Agent 페이지에서 선택한 모델의 원래 alias
directory: ~/SAM-Codex
```

정확한 모델은 Agent 페이지에서 선택한 목록과 계정 권한에 따라 달라집니다.
**provider가 `sam`이면 SAM 연결입니다.** Codex 안에서 `/model`을 열면 현재
Agent 페이지에서 선택한 V2-native 모델과 인증된 호환 모델이 원래 이름으로
함께 표시됩니다.

SAM 도구 확인:

```bash
sam-codex mcp list
```

`sam-tools ... enabled`가 표시되면 검색·페이지 읽기 도구도 연결된 것입니다.

실제 모델 호출 확인:

```bash
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  "Reply with exactly: SAM-CODEX-OK"
```

Windows PowerShell:

```powershell
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral `
  "Reply with exactly: SAM-CODEX-OK"
```

이 호출부터 SAM 사용량이 기록될 수 있습니다.

## 평소 사용

```bash
codex       # 기존 OpenAI / ChatGPT 환경
sam-codex   # SAM 환경
```

두 명령의 설정, 로그인, 대화 기록은 서로 분리됩니다.

## 삭제

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/soonsoonLABS/sam-public/main/02-Code-Agent-Codex/uninstall-macos.sh) && source "$HOME/.zshrc"
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
```

SAM-Codex 파일은 휴지통으로 이동합니다. 공식 `codex`, `~/.codex`, 공용
`~/.sam/env` 키는 보존합니다.

## 다른 설치 방법

- 설치 파일을 먼저 확인하려면
  [install-macos.sh](./install-macos.sh)를 내려받아 실행하세요.
- 설치 프로그램 없이 직접 구성하려면
  [완전 수동 설정](./MANUAL_SETUP.md)을 따라 하세요.
- Windows에서 설치 파일 없이 구성하려면
  [Windows 설치 가이드](./WINDOWS_SETUP.md)의 수동 설정 절을 따르세요.

## 문제가 생겼다면

`command not found`, 공식 모델 표시, 키 인증, MCP 연결 문제는
[문제 해결](./TROUBLESHOOTING.md)에서 증상별로 확인하세요.

SAM V2, Responses, MCP, 설정 분리 원리는
[동작 방식](./HOW_IT_WORKS.md)에 정리되어 있습니다.
