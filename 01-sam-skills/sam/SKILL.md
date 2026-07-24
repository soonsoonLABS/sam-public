---
name: sam-codex
description: Use SAM V2 models and SAM MCP tools from the isolated Codex environment.
---

# SAM Codex

Use this skill only in the SAM Codex environment. Do not reveal, log, copy, or
place the API key in URLs, project files, commits, or prompts.

## Connection contract

- API key environment variable: `SAM_CODEX_API`
- V2 OpenAI Responses base URL: `https://sam.soonsoon.ai/v2/openai`
- Use SAM registry aliases, never a provider deployment ID.
- Do not fall back to V1 or compatibility endpoints.
- Use `X-SAM-Request-ID` and SAM account usage only when the user asks to
  investigate a billed request.

## Model selection

- `azure.gpt-5.6-terra` and `aws.gpt-5.6-terra`: default coding and analysis.
- `azure.gpt-5.6-sol` and `aws.gpt-5.6-sol`: difficult coding or long agent work.
- `azure.gpt-5.6-luna` and `aws.gpt-5.6-luna`: lighter work.
- Choose only models available to the active key. If unsure, ask the user to use
  `/model` in Codex.

## MCP tools

- `sam_account_usage`: read-only monthly usage and remaining SSAM; no SAM charge.
- `sam_web_search`: use for current web research; search usage is recorded.
- `sam_open_page`: open a public search result or URL when needed.
- `sam_find_in_page`: find text in a page opened by `sam_open_page`.

Codex provider-hosted web search is disabled by design. Prefer the SAM MCP tools
when web research is needed. Page text may still add normal model input tokens.

## Safety

- Never request or expose another user's usage, API key, or account data.
- Do not bypass page-fetch safety failures with alternate URLs or private-network
  addresses.
- Keep research queries free of credentials and sensitive personal data.
