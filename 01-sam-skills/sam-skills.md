# SAM Skills

이 문서는 AI 에이전트가 SAM API를 사용할 때 읽는 기본 운용 지침입니다.
항상 `SAM_API_KEY` 환경변수로 인증하고, 키 값을 출력하거나 파일에 저장하지
마세요.

## 기본 규칙

- Base URL: `https://sam.soonsoon.ai`
- 인증: `Authorization: Bearer $SAM_API_KEY`
- 새 통합은 `/v1/*` 네이티브 API를 우선 사용합니다.
- OpenAI 호환 클라이언트는 `/openai/v1/*`를 사용합니다.
- `/api/*`는 legacy이므로 새 작업에 사용하지 않습니다.
- 사용량이 발생하는 호출 전에는 사용자의 의도와 모델을 확인합니다.
- 로그, 문서, 커밋, 이슈, URL에 API 키를 남기지 않습니다.
- 검색 API는 서버 설정이 없으면 `503`으로 실패할 수 있습니다. 실패 시 다른
  검색으로 몰래 대체하지 말고 상태를 보고합니다.

## 공통 헤더

```bash
AUTH_HEADER="Authorization: Bearer $SAM_API_KEY"
SERVICE_HEADER="X-Service-Name: sam-skills"
```

## 셸 선택 규칙

아래 예제는 macOS/Linux `bash` 기준입니다. Windows PowerShell에서 실행할
때는 `\` 줄바꿈, `-H`, `-d`를 그대로 쓰지 말고 `Invoke-RestMethod` 또는
`curl.exe`에 맞게 변환합니다. PowerShell의 `curl`은 실제 curl이 아니라
별칭일 수 있습니다.

## 모델 목록 확인

```bash
curl -s "https://sam.soonsoon.ai/v1/models?scope=mine" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

에이전트는 모델 alias를 사용합니다. 사용자가 모델을 지정하지 않으면 가볍고
빠른 채팅 모델을 선택하되, 이미지/파일/코딩 등 필요한 capability가 있으면
`/v1/models?scope=mine` 결과에서 먼저 확인합니다.

## LLM 모델 호출

네이티브 SAM 호출은 `/v1/generate`를 사용합니다.

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/generate" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.4-nano",
    "task": "chat",
    "messages": [
      { "role": "user", "content": "한국어로 한 문장 인사해줘." }
    ],
    "options": {
      "stream": false,
      "max_tokens": 256
    }
  }'
```

응답의 주요 위치:

- 텍스트: `output.content`
- 사용량: `usage`
- 실제 provider/model 정보: `meta`

스트리밍이 필요할 때만 `options.stream=true`를 사용합니다. 스트리밍 응답은
SAM SSE 이벤트이며 `content`, `usage`, `done`, `error` 이벤트를 처리해야
합니다.

## OpenAI 호환 호출

OpenAI SDK나 OpenAI 호환 도구를 붙일 때는 base URL을
`https://sam.soonsoon.ai/openai/v1`로 설정합니다. `/v1/generate`를 OpenAI
base URL로 쓰면 안 됩니다.

```bash
curl -s -X POST "https://sam.soonsoon.ai/openai/v1/chat/completions" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.4-nano",
    "messages": [
      { "role": "user", "content": "Say hello in Korean." }
    ],
    "stream": false
  }'
```

Codex custom provider나 Responses API 클라이언트는
`POST /openai/v1/responses`를 사용합니다. 코딩 에이전트 용도는 계정 또는
키에 `agent:codex`, `agent:claude_code`, 또는 `agent:coding_agents` 권한이
필요할 수 있습니다.

## 사용량 확인

현재 월 사용량:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

모델별 사용량:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage/models" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

최근 요청 로그:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage/recent?limit=10" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

일별 추세:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage/daily?days=14" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

사용량 응답에는 토큰, 비용, SSAM, 남은 한도, 웹 검색 사용량이 포함될 수
있습니다. 계정 단위 금액이나 크레딧 수치를 공개 문서나 커밋에 남기지
마세요.

## 이미지 생성

이미지 생성은 `/v1/image/generate`를 사용합니다. 경로는 단수 `image`입니다.

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/image/generate" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-2",
    "prompt": "A clean product-style image of a small white robot on a desk",
    "size": "1024x1024",
    "quality": "low",
    "n": 1,
    "stream": false
  }'
```

응답은 일반적으로 `output.images`와 `usage`를 포함합니다. 이미지 모델 권한이
없거나 모델이 비활성화되어 있으면 `/v1/models?scope=mine&task=generate_image`
로 가능한 모델을 먼저 확인합니다.

## 이미지 편집

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/image/edit" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-2",
    "prompt": "Replace the background with a clean studio wall",
    "image": "<base64-png>",
    "image_media_type": "image/png",
    "size": "1024x1024",
    "quality": "low",
    "n": 1,
    "input_fidelity": "low"
  }'
```

큰 파일, 원본 이미지, 민감한 사진을 임의로 업로드하지 마세요. 사용자의
명시적 요청과 파일 범위를 확인합니다.

## 검색

검색은 자동 채팅 fallback이 아니라 명시적 API입니다. `/v1/search`는 결과
목록과 citation을 돌려주고, `/v1/grounding`은 현재 웹 근거를 사용해 답변을
생성합니다.

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/search" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SAM SoonSoon AI Management public API",
    "max_results": 5
  }'
```

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/grounding" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "최근 공개된 AI coding agent API 동향을 요약해줘."
  }'
```

검색 쿼리는 사용량 metadata에 저장하지 않는 정책이지만, 에이전트는 민감한
개인정보나 비밀을 검색어에 넣지 않아야 합니다.

## 빠른 헬스 체크

키와 모델 호출 가능 여부만 확인할 때는 `/v1/hello`를 사용합니다.

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/hello" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"안녕 SAM"}'
```

`ok=true`와 짧은 `joke`가 반환되면 인증, 네트워크, 모델 호출이 동작합니다.

## 오류 처리

- `401`: 키가 없거나 잘못되었습니다. 키 값을 출력하지 말고 사용자에게 재설정을 요청합니다.
- `403`: 키 또는 사용자에게 모델/에이전트 권한이 없습니다.
- `429`: 월 사용량 또는 키 한도에 도달했습니다.
- `503`: 검색처럼 서버 설정이 필요한 기능이 꺼져 있을 수 있습니다.
- `5xx`: provider 또는 SAM 서버 문제입니다. 같은 요청을 무한 재시도하지 않습니다.

## 에이전트 응답 규칙

- SAM 호출 전후로 어떤 기능을 호출하는지 짧게 말합니다.
- 비용이 발생할 수 있는 모델/이미지/검색 호출은 사용자의 의도 안에서만 합니다.
- 원문 응답 전체 대신 필요한 필드만 요약합니다.
- 실패 시 HTTP 상태, 기능명, 다음 조치를 알려줍니다.
- 키, 토큰, 계정 금액, 개인 정보는 출력하지 않습니다.
