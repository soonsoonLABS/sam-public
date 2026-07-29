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
| Codex provider | `https://sam.soonsoon.ai/v2/codex` |
| 모델 discovery | `https://sam.soonsoon.ai/v2/codex/models` |
| SAM MCP | `https://sam.soonsoon.ai/mcp` |

Codex provider는 provider-native Responses 형식을 사용합니다.

## 키

키는 `~/.sam/env`의 `SAM_API_KEY`로 보관합니다. `config.toml`, 프로젝트
`.env`, Git, 명령 기록에는 키 값을 넣지 않습니다.

같은 공용 키 파일을 SAM-Claude에서도 사용할 수 있습니다. 각 클라이언트는
자신에게 필요한 환경변수로 읽어 사용합니다.

## 모델

설치할 때와 실행할 때마다 `codex --version`에서 현재 client version을 읽고,
전용 cache 요청으로 인증된 `/v2/codex/models` 목록을 갱신합니다. 코드 에이전트
페이지에서 선택된 V2-native `azure.*`/`aws.*` 모델과 인증된 호환 모델의 원래
alias를 함께 표시하며, Codex의 내장 모델은 숨깁니다. 호환 모델은 V2-native가
아니며 SAM이 요청 alias를 분류해 인증된 compatibility executor로 전달합니다.
기존 기본 모델이 여전히 선택 목록에 있으면 유지합니다.
새 설치는 `azure.gpt-5.6-luna`가 선택돼 있으면 안정 기본값으로 사용하고,
그렇지 않으면 확인된 목록의 첫 번째 모델을 사용합니다.

현재 검증 범위는 Codex `0.145.x`입니다. 이후 minor 버전은 새로운 내장 모델이
추가됐을 가능성이 있으므로, SAM의 숨김 계약을 확인하기 전에는 실행하지 않습니다.

갱신 결과가 전용 cache 형식이 아니거나 선택 모델이 비어 있으면 새 파일로
교체하지 않습니다. 이전에 검증된 cache 파일은 보존하지만, 페이지에서 제거된
모델일 가능성이 있으므로 그 실행은 중단합니다. 다음 정상 갱신이 성공해야 다시
SAM-Codex를 실행할 수 있습니다.

CLI 실행 옵션에서도 다음 값을 고정합니다.

- provider: `sam`
- model: Agent 페이지에서 선택한 native 또는 인증된 호환 모델의 원래 alias
- catalog: macOS `~/.codex-sam/models.json`, Windows
  `%USERPROFILE%\.codex-sam\models_cache.json`
- hosted web search: disabled

이렇게 해야 프로젝트의 공식 Codex 모델 설정이 SAM 세션을 덮어쓰지 못합니다.

## 롤백 경계

통합 gateway 릴리스에 문제가 생기면 공개 wrapper와 config를 이전
`/v2/openai` base 및 `sam-v2-native-codex-catalog` etag 조합으로 함께 되돌립니다.
URL이나 etag 한쪽만 섞어 바꾸지 않으며, 실행 중 실패를 감지해 자동으로 다른
surface에 fallback하지 않습니다.

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
