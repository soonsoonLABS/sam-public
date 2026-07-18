# 1. Essential SAM Skill Documents

**Language:** [한국어](README.md) | English

This folder provides shared skill documents that AI agents such as Codex, Kiro,
Copilot, and Claude Code can read from global configuration to learn how to use
the SAM API.

## Files

- [`sam-skills.md`](sam-skills.md): Korean default skill document
- [`sam-skills.en.md`](sam-skills.en.md): English skill document

## Usage

Put this folder in the user's agent-specific global configuration area, then
instruct the agent to read `sam-skills.md` when it needs SAM API access.

Example instruction:

```text
When using the SAM API, read sam-skills.md first and authenticate with the
SAM_API_KEY environment variable. Do not print the key or save it to files.
Load SAM keys only from ~/.sam/env or ~/.sam/env.ps1.
```

## Prerequisite

First complete [`00-sam-setup/`](../00-sam-setup/README.en.md) so `SAM_API_KEY`
is saved under the standard `~/.sam/` folder and the `Hello SAM` test succeeds.
