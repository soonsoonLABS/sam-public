# 1. Essential SAM Skill Documents

**Language:** [한국어](README.md) | English

This folder provides shared skill documents that AI agents such as Codex, Kiro,
Copilot, and Claude Code can read from global configuration to learn how to use
the SAM API.

## Files

- [`sam-skills.md`](sam-skills.md): Korean default skill document
- [`sam-skills.en.md`](sam-skills.en.md): English skill document
- [`AGENT_INSTRUCTIONS.md`](AGENT_INSTRUCTIONS.md): Korean bootstrap text to
  paste into other agents' global instructions
- [`AGENT_INSTRUCTIONS.en.md`](AGENT_INSTRUCTIONS.en.md): English bootstrap text

## Usage

Put this folder in the user's agent-specific global configuration area, then
instruct the agent to read `sam-skills.md` when it needs SAM API access.

Recommended local copy location:

```bash
mkdir -p "$HOME/.sam/skills"
cp sam-skills.md "$HOME/.sam/skills/sam-skills.md"
```

Example instruction:

```text
When using the SAM API, read sam-skills.md first and authenticate with the
SAM_API_KEY environment variable. Do not print the key or save it to arbitrary
files.
Load SAM keys only from ~/.sam/env or ~/.sam/env.ps1.
```

Paste the common bootstrap text from [`AGENT_INSTRUCTIONS.md`](AGENT_INSTRUCTIONS.md)
into each agent's global instruction file.

## Prerequisite

First complete [`00-sam-setup/`](../00-sam-setup/README.en.md) so `SAM_API_KEY`
is saved under the standard `~/.sam/` folder and the `Hello SAM` test succeeds.
