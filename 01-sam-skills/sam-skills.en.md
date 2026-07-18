# SAM Skills

This document is the baseline operating guide for AI agents using the SAM API.
Always authenticate with the `SAM_API_KEY` environment variable. Do not print
the key or save it to files.

## Core Rules

- Base URL: `https://sam.soonsoon.ai`
- Auth: `Authorization: Bearer $SAM_API_KEY`
- Use [`AGENT_INSTRUCTIONS.md`](AGENT_INSTRUCTIONS.md) as the bootstrap text to
  paste into other agents' global instructions.
- Standard key location: `~/.sam/env` on macOS/Linux and `~/.sam/env.ps1` on
  Windows PowerShell.
- Before calling SAM, load the standard file when `SAM_API_KEY` is missing from
  the current process.
- Do not create alternate key locations such as `~/.config/sam/.env`, project
  `.env` files, or agent-specific key files.
- After replacing a key, restart already-running CLI or agent processes so they
  read the new value.
- Prefer native `/v1/*` endpoints for new SAM integrations.
- Use `/openai/v1/*` for OpenAI-compatible clients.
- Do not use legacy `/api/*` endpoints for new work.
- Confirm the user's intent and model before calls that create usage.
- Never put API keys in logs, docs, commits, issues, or URLs.
- Search may return `503` when server-side search configuration is unavailable.
  Do not silently replace SAM Search with another search provider.

## Common Headers

Load the key before macOS/Linux calls:

```bash
source "$HOME/.sam/env"
```

Load the key before Windows PowerShell calls:

```powershell
. "$HOME\.sam\env.ps1"
```

Common macOS/Linux headers:

```bash
AUTH_HEADER="Authorization: Bearer $SAM_API_KEY"
SERVICE_HEADER="X-Service-Name: sam-skills"
```

## Shell Rule

The examples below are written for macOS/Linux `bash`. On Windows PowerShell,
do not paste `\` line continuations, `-H`, or `-d` as-is. Convert the request to
`Invoke-RestMethod` or `curl.exe`. PowerShell's `curl` may be an alias, not real
curl.

## List Models

```bash
curl -s "https://sam.soonsoon.ai/v1/models?scope=mine" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

Agents use model aliases. If the user does not choose a model, select a light,
fast chat model. For image, file, coding, or other special capabilities, inspect
`/v1/models?scope=mine` first.

## Call an LLM

Use `/v1/generate` for native SAM generation.

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/generate" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.4-nano",
    "task": "chat",
    "messages": [
      { "role": "user", "content": "Say hello in Korean." }
    ],
    "options": {
      "stream": false,
      "max_tokens": 256
    }
  }'
```

Important response fields:

- Text: `output.content`
- Usage: `usage`
- Actual provider/model metadata: `meta`

Only set `options.stream=true` when streaming is required. Native SAM streaming
uses SSE events such as `content`, `usage`, `done`, and `error`.

## OpenAI-Compatible Calls

For OpenAI SDKs or OpenAI-compatible tools, set the base URL to
`https://sam.soonsoon.ai/openai/v1`. Do not use `/v1/generate` as an OpenAI base
URL.

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

Codex custom providers and Responses API clients use
`POST /openai/v1/responses`. Coding-agent usage may require `agent:codex`,
`agent:claude_code`, or `agent:coding_agents` access on the account or key.

## Check Usage

Monthly usage:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

Usage by model:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage/models" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

Recent logs:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage/recent?limit=10" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

Daily trend:

```bash
curl -s "https://sam.soonsoon.ai/v1/account/usage/daily?days=14" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER"
```

Usage responses may include tokens, cost, SSAM, remaining limits, and web-search
usage. Do not publish account-level amounts or credit balances in docs or
commits.

## Generate Images

Use `/v1/image/generate`. The path prefix is singular: `image`.

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

The response normally includes `output.images` and `usage`. If image access is
missing, inspect `/v1/models?scope=mine&task=generate_image`.

## Edit Images

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

Do not upload large files, source images, or sensitive photos without explicit
user intent and file scope.

## Search

Search is an explicit API, not an automatic chat fallback. `/v1/search` returns
source results and citations. `/v1/grounding` returns an answer grounded in
current web sources.

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
    "query": "Summarize recent public AI coding-agent API trends."
  }'
```

SAM policy avoids writing search queries into usage metadata, but agents must
still avoid putting secrets or sensitive personal data into search queries.

## Quick Health Check

Use `/v1/hello` only to verify that the key and a real model call work.

```bash
curl -s -X POST "https://sam.soonsoon.ai/v1/hello" \
  -H "$AUTH_HEADER" \
  -H "$SERVICE_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"Hello SAM"}'
```

If `ok=true` and a short `joke` returns, auth, network, and model inference are
working.

## Error Handling

- `401`: Missing or invalid key. Do not print the key; ask the user to reset it.
- `403`: The key or user lacks model or agent access.
- `429`: Monthly usage or key limit reached.
- `503`: A server-configured feature such as search may be unavailable.
- `5xx`: Provider or SAM server issue. Do not retry indefinitely.

## Agent Response Rules

- Briefly state which SAM capability is being called before or after the call.
- Keep model, image, and search calls within the user's intent.
- Summarize only the fields the user needs instead of dumping full raw responses.
- On failure, report HTTP status, capability, and the next action.
- Never print keys, tokens, account-level amounts, or personal data.
