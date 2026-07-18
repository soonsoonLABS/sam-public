# SAM Public

**Language:** [한국어](README.md) | English

Public tools, installers, and documentation for connecting supported clients to
SoonSoon AI Management (SAM).

## Start Here

Start with [`00-sam-setup/`](00-sam-setup/README.en.md) to enter your SAM API
key, confirm only the key prefix, and run a tiny `Hello SAM` test call.

The standard local location for SAM usage keys is `~/.sam/`. Point other agents
to that folder's `env` or `env.ps1` file to avoid split keys across processes.

## Documents

- [`00-sam-setup/`](00-sam-setup/README.en.md): the shortest first SAM setup
  guide for macOS and Windows
- [`01-sam-skills/`](01-sam-skills/README.en.md): essential SAM API skill
  documents for AI agents to read from global configuration
- [`02-Code-Agent-Codex/`](02-Code-Agent-Codex/README.en.md): coding-agent connection tools and
  guides for Codex and Claude Code

## Security

This repository contains no SAM server code, production configuration, or
credentials. Never add API keys to Git-tracked files, shared docs, issue text,
command history, or URLs.

Local key files belong outside Git, under `~/.sam/` only. After replacing a key,
restart any already-running CLI or agent process.
