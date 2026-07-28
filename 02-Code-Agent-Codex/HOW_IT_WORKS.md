# SAM-Codex 동작 방식

[빠른 시작으로 돌아가기](./README.md)

## 두 환경은 분리됩니다

```text
codex
  └─ ~/.codex
     └─ OpenAI / ChatGPT

sam-codex
  └─ ~/.codex-sam
     ├─ SAM V2 OpenAI Responses
     ├─ 인증된 SAM 모델 목록
     └─ SAM MCP 검색·페이지 읽기
```

`sam-codex`는 공식 Codex CLI를 다시 구현한 프로그램이 아닙니다. 같은 CLI를
별도의 `CODEX_HOME`, provider, 모델 목록, API Key로 실행하는 격리
명령입니다. 따라서 화면 상단에는 정상적으로 `OpenAI Codex`가 표시됩니다.

## 연결 주소

| 용도 | 주소 |
| --- | --- |
| Codex provider | `https://sam.soonsoon.ai/v2/openai` |
| 모델 discovery | `https://sam.soonsoon.ai/v2/openai/models` |
| SAM MCP | `https://sam.soonsoon.ai/mcp` |

Codex provider는 provider-native Responses 형식을 사용합니다.

## 키

키는 `~/.sam/env`의 `SAM_API_KEY`로 보관합니다. `config.toml`, 프로젝트
`.env`, Git, 명령 기록에는 키 값을 넣지 않습니다.

같은 공용 키 파일을 SAM-Claude에서도 사용할 수 있습니다. 각 클라이언트는
자신에게 필요한 환경변수로 읽어 사용합니다.

## 모델

실행할 때마다 인증된 `/v2/openai/models` 목록을 갱신합니다. 기본값은 현재
키에 허용된 모델 중 Luna, Terra, Sol 순서로 선택합니다.

CLI 실행 옵션에서도 다음 값을 고정합니다.

- provider: `sam`
- model: 인증된 `azure.*` 모델
- catalog: `~/.codex-sam/models.json`
- hosted web search: disabled

이렇게 해야 프로젝트의 공식 Codex 모델 설정이 SAM 세션을 덮어쓰지 못합니다.

## 작업 폴더 격리

Git 프로젝트 안에서 실행하면 해당 프로젝트를 그대로 사용합니다.

홈 폴더나 일반 폴더에서 실행하면 `~/SAM-Codex`와
`.sam-codex-root`를 사용합니다. 이 경계가 공식 `~/.codex/config.toml`을
프로젝트 설정으로 잘못 읽는 것을 막습니다.

## 검색과 페이지 읽기

Codex provider 자체의 hosted web search는 끕니다. 대신 SAM MCP가 제공합니다.

- `sam_web_search`
- `sam_open_page`
- `sam_find_in_page`
- `sam_account_usage`

따라서 검색 정책과 사용량은 SAM 경계를 통해 관리됩니다.

## 비용 경계

- `codex`: OpenAI/ChatGPT의 인증·정책·비용
- `sam-codex`: SAM API Key의 권한·사용량·비용

`sam-codex mcp list`와 모델 discovery는 생성 모델 호출이 아닙니다. 실제
`sam-codex` 대화와 `sam-codex exec`부터 SAM 사용량이 기록될 수 있습니다.
