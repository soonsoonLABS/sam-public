#!/usr/bin/env python3
"""Static contract checks used when PowerShell is unavailable in CI/dev."""

from __future__ import annotations

import hashlib
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
INSTALL = (ROOT / "install-windows.ps1").read_text(encoding="utf-8")
UNINSTALL = (ROOT / "uninstall-windows.ps1").read_text(encoding="utf-8")
WRAPPER_PATH = ROOT / "templates" / "sam-claude.ps1"
WRAPPER = WRAPPER_PATH.read_text(encoding="utf-8")


def require(text: str, source: str) -> None:
    assert text in source, f"missing contract: {text}"


hash_match = re.search(r'\$WrapperSha256 = "([0-9a-f]{64})"', INSTALL)
assert hash_match, "installer SHA-256 pin is missing"
actual_hash = hashlib.sha256(WRAPPER_PATH.read_bytes()).hexdigest()
assert hash_match.group(1) == actual_hash, "PowerShell wrapper hash pin drifted"

for required in (
    "SAM_CLAUDE_INSTALLER_MANAGED=1",
    "2.1.129",
    "https://sam.soonsoon.ai/v2/claude/v1/models",
    "protocol_surface=anthropic_messages",
    "Exactly Haiku, Sonnet, and Opus mappings are required.",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY",
    'ANTHROPIC_BASE_URL = "https://sam.soonsoon.ai/v2/claude"',
    "Runtime discovery failed. The previous verified cache was preserved",
    "Move-StaleGatewayModelCache",
    'Join-Path $ClaudeSamHome "cache/gateway-models.json"',
    '"https://sam.soonsoon.ai/v2/claude"',
    "cache-backups",
    "The isolated gateway model cache is malformed. It was not changed.",
    "SAM_CLAUDE_PREFLIGHT_ONLY",
    '$env:SAM_CLAUDE_PREFLIGHT_ONLY -eq "1" -and',
):
    require(required, WRAPPER)

for required in (
    "Set-PSDebug -Off",
    ".sam",
    "env.ps1",
    ".claude-sam",
    "Assert-NotReparsePoint",
    "SAM_CLAUDE_INSTALLER_MANAGED=1",
    "Get-FileHash -Algorithm SHA256",
    "SAM_CLAUDE_PREFLIGHT_ONLY",
    "https://sam.soonsoon.ai/mcp",
    "Bearer ${SAM_API_KEY}",
    "claude mcp add --transport http --scope user",
    "icacls.exe",
    "runtime-state.json",
    "$transactionStarted",
    "$runnerBackup",
    "$stateBackup",
):
    require(required, INSTALL)

for forbidden in (
    "settings.json",
    "claude-sonnet-5",
    "claude-opus-5",
    "claude-haiku",
    "/v2/anthropic",
):
    assert forbidden not in INSTALL, f"installer hardcodes forbidden value: {forbidden}"

for required in (
    "[switch]$PurgeData",
    "Assert-ManagedFile",
    "Assert-NotReparsePoint",
    "SAM-Claude-Backups",
    "shared ~/.sam/env.ps1 key were not changed",
):
    require(required, UNINSTALL)

assert "Remove-Item" not in UNINSTALL.split("Assert-ManagedFile", 1)[0]
assert 'Join-Path $HOME ".claude"' not in UNINSTALL
assert ".sam/env.ps1" not in UNINSTALL.replace(
    "shared ~/.sam/env.ps1 key were not changed", ""
)

print("PASS: Windows static isolation, integrity, discovery, and removal contracts")
