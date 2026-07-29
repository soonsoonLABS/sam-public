# SAM-Codex 문제 해결 — macOS

[빠른 시작으로 돌아가기](./README.md)

## 화면에 `OpenAI Codex`가 표시됩니다

정상입니다. `sam-codex`도 공식 Codex CLI 화면을 사용합니다.

아래쪽 모델을 확인하세요.

- `provider: sam`: SAM
- `gpt-5.6-*`처럼 `azure.`/`aws.`가 없는 모델: 공식 설정이 섞였을 가능성

정상 SAM 실행은 전용 작업 폴더와 SAM 모델을 표시합니다.

```text
directory: ~/SAM-Codex
model: Agent 페이지에서 선택한 모델의 원래 alias
```

## `sam-codex: command not found`

```bash
source "$HOME/.zshrc"
type sam-codex
```

그래도 없으면 빠른 시작의 한 줄 설치를 다시 실행하세요. 정상 설치는 반복
실행해도 관리 블록을 하나만 유지합니다.

## 공식 모델 `gpt-5.6-sol`이 표시됩니다

현재 터미널에 과거 함수가 남았을 수 있습니다.

```bash
source "$HOME/.zshrc"
type sam-codex
```

`sam-codex is a shell function from .../.zshrc`가 표시된 뒤 다시 실행하세요.
최신 관리 함수는 항상 `~/.local/bin/sam-codex`로 연결됩니다.

## `model discovery failed` 또는 HTTP 401

저장된 키가 있고 읽기 권한이 있는지 확인합니다. 키 값은 출력하지 마세요.

```bash
test -r "$HOME/.sam/env" && echo "키 파일 있음" || echo "키 파일 없음"
```

키가 잘못됐다면 기존 파일을 직접 출력하지 말고 휴지통으로 옮긴 뒤 설치를
다시 실행해 새 키를 입력하세요.

## `sam-tools`가 보이지 않습니다

```bash
sam-codex mcp list
```

정상 출력에는 다음 행이 있습니다.

```text
sam-tools  https://sam.soonsoon.ai/mcp  ...  enabled
```

없다면 설치를 다시 실행하세요. `~/.codex-sam/config.toml`에 키 값 자체를
적으면 안 됩니다.

## 모델 선택 오류

`MODEL_NOT_NATIVE_ON_SURFACE`, `MODEL_NOT_SELECTED`,
`MODEL_NOT_CODEX_CERTIFIED`는 현재 SAM-Codex catalog에서 실행할 수 없는 alias를
선택했다는 뜻입니다.
`/model`에서 현재 표시되는 native 또는 인증된 호환 모델을 선택하세요.

## `requires one exact Codex 0.145.x version line`

현재 공개 설정은 Codex `0.145.x`의 내장 모델 목록만 검증했습니다. 임의로 검사를
우회하지 말고, 빠른 시작의 지원 버전을 설치하거나 SAM 문서가 새 버전을 지원할
때까지 기다리세요.

## OpenAI 페이지 읽기가 실패합니다

SAM MCP 페이지 읽기는 공개 HTTPS 문서만 지원하며 사이트의 응답 형식이나
보안 정책에 따라 일부 페이지가 차단될 수 있습니다. 다른 일반 HTML 페이지로
도구 연결을 확인하세요.

## 완전히 다시 설치하고 싶습니다

먼저 [빠른 시작의 삭제 명령](./README.md#삭제)을 실행하세요. SAM-Codex
설정은 즉시 삭제하지 않고 휴지통으로 이동하며, 공식 Codex와 공용 키는
보존합니다.
