# SAM Global Agent Instructions

Paste the block below into the global instruction file read by each agent, such
as Codex, Kiro, Copilot, or Claude Code. Examples include `AGENTS.md`,
`CLAUDE.md`, Copilot custom instructions, and Kiro steering documents.

```text
## SAM API Rules

When the user asks to use "SAM", "SAM API", "SAM Search", "SAM image", or a
"SAM model", first read the SAM skills document and follow its rules.

Skill document priority:
1. If available, read ~/.sam/skills/sam-skills.md.
2. Otherwise, read 01-sam-skills/sam-skills.md from the sam-public repository.

Key loading rules:
- macOS/Linux: if SAM_API_KEY is missing from the current process, source ~/.sam/env.
- Windows PowerShell: if SAM_API_KEY is missing from the current process, dot-source ~/.sam/env.ps1.
- Do not create or prefer ~/.config/sam/.env, project .env files, or agent-specific key files.
- If the current shell's temporary SAM_API_KEY differs from the standard key file, prefer the value loaded from the standard key file.
- Never print the key. If confirmation is needed, show only the first 12 characters.
- After replacing a key, tell the user that already-running CLI or agent processes must be restarted.

Call rules:
- Base URL is https://sam.soonsoon.ai.
- Prefer native /v1/* endpoints for new SAM integrations.
- OpenAI-compatible clients use https://sam.soonsoon.ai/openai/v1.
- Do not use legacy /api/* endpoints for new work.
- Run model, image, and search calls only within the user's intent because they may create usage.
- On failure, briefly report the HTTP status, SAM capability, and next action.
```

## Install Example

Copy the skill document to the standard local location on macOS/Linux:

```bash
mkdir -p "$HOME/.sam/skills"
cp 01-sam-skills/sam-skills.md "$HOME/.sam/skills/sam-skills.md"
```

Copy the skill document to the standard local location on Windows PowerShell:

```powershell
$SkillHome = Join-Path $HOME ".sam\skills"
New-Item -ItemType Directory -Force -Path $SkillHome | Out-Null
Copy-Item "01-sam-skills\sam-skills.md" (Join-Path $SkillHome "sam-skills.md") -Force
```

## Where To Apply

- Codex: global or project `AGENTS.md`
- Claude Code: global or project `CLAUDE.md`
- GitHub Copilot: Copilot custom instructions or repository instruction file
- Kiro: Kiro steering or rules document

The exact global settings path can vary by agent version and installation
method. The important rule is that every agent refers to only these shared
locations: `~/.sam/env`, `~/.sam/env.ps1`, and
`~/.sam/skills/sam-skills.md`.
