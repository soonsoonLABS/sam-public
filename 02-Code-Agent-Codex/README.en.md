# SAM Codex CLI

**Language:** [한국어](README.md) | English

This package runs Codex with SAM models and MCP tools in a separate environment.
It does not change your normal `codex`, ChatGPT, or Codex account configuration.

## What it installs

- V2 OpenAI Responses at `https://sam.soonsoon.ai/v2/openai`
- Azure Foundry and AWS Bedrock Mantle model selection
- SAM MCP tools for web search, public-page reading, in-page find, and monthly usage
- A dedicated `sam-codex` command

Codex provider-hosted search is deliberately disabled. SAM MCP performs search
and records its SAM usage.

## Install

Prepare a SAM API key with Code Agent access and install Codex CLI first.

```bash
codex --version
git clone https://github.com/soonsoonLABS/sam-public.git
cd sam-public/02-Code-Agent-Codex
bash install-macos.sh
```

On Windows PowerShell:

```powershell
git clone https://github.com/soonsoonLABS/sam-public.git
Set-Location sam-public\02-Code-Agent-Codex
PowerShell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

The installer securely creates `~/.sam/` for the API key and shared skills, and
`~/.codex-sam/` for the isolated Codex configuration. Never put the key in Git,
URLs, screenshots, or command-line arguments.

## Run and verify

```bash
sam-codex
```

Then ask Codex:

```text
Use sam_account_usage to briefly show this month's SAM usage and remaining SSAM.
```

This read-only tool is free. Model prompts are recorded as normal model-token usage.

## Choose a model

Run `/model` inside Codex. The default is `azure.gpt-5.6-terra`.

| Model | Provider | Best for |
| --- | --- | --- |
| `azure.gpt-5.6-sol`, `aws.gpt-5.6-sol` | Azure Foundry / AWS Bedrock Mantle | difficult coding and long agent work |
| `azure.gpt-5.6-terra`, `aws.gpt-5.6-terra` | Azure Foundry / AWS Bedrock Mantle | everyday coding and analysis |
| `azure.gpt-5.6-luna`, `aws.gpt-5.6-luna` | Azure Foundry / AWS Bedrock Mantle | lighter work |
| `azure.gpt-5.4`, `aws.gpt-5.5`, `aws.gpt-5.4` | Azure Foundry / AWS Bedrock Mantle | general work |

## SAM MCP tools

| Tool | Purpose | SAM usage |
| --- | --- | --- |
| `sam_web_search` | web search | recorded as search usage |
| `sam_open_page` | open a public page | no search charge for the tool itself |
| `sam_find_in_page` | find text in an opened page | no search charge for the tool itself |
| `sam_account_usage` | monthly usage and remaining SSAM | free and read-only |

Ask explicitly for “SAM web search” when you need current web research. Page
content may still create normal input tokens when it is included in the model context.

See [troubleshooting](docs/troubleshooting.md) for common setup errors.

## Scope

This package supports Codex CLI. It does not switch the provider of an existing
Codex Desktop app because that can conflict with the user's account and settings.
