#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for document in WINDOWS_SETUP.md WINDOWS_SETUP.en.md; do
  test -s "$ROOT/$document"
done

python3 - "$ROOT" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
documents = [
    root / "README.md",
    root / "README.en.md",
    root / "MANUAL_SETUP.md",
    root / "WINDOWS_SETUP.md",
    root / "WINDOWS_SETUP.en.md",
]
combined = "\n".join(path.read_text(encoding="utf-8") for path in documents)

for path in documents:
    text = path.read_text(encoding="utf-8")
    assert text.count("```") % 2 == 0, f"unbalanced fence: {path.name}"
    for target in re.findall(r"\]\((\./[^)#]+)", text):
        assert (root / target[2:]).exists(), f"broken link: {path.name}: {target}"

for item in (
    "WINDOWS_SETUP.md",
    "WINDOWS_SETUP.en.md",
    "install-windows.ps1",
    "uninstall-windows.ps1",
    "Invoke-RestMethod",
    "$env:SAM_API_KEY",
    "/v2/claude/v1/models",
    "https://sam.soonsoon.ai/mcp",
    "sam-claude mcp list",
    "SAM-CLAUDE-OK",
    "claude-sam-*",
    "official `claude`",
):
    assert item in combined, f"missing Windows Claude documentation contract: {item}"

for forbidden in (
    "Bearer sam_",
    "SAM_API_KEY=sk-ant-",
    "test-only-placeholder",
    "/v2/anthropic",
):
    assert forbidden not in combined, f"stale or secret-shaped content: {forbidden}"

windows = (root / "WINDOWS_SETUP.md").read_text(encoding="utf-8")
assert "curl -sS" not in windows, "Unix curl example leaked into PowerShell guide"
assert "Invoke-RestMethod" in windows
assert "`$env:SAM_API_KEY" in windows
print("PASS: Windows Claude docs, links, fences, PowerShell syntax, and secret hygiene")
PY
