#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

for document in \
  README.md \
  README.en.md \
  MANUAL_SETUP.md \
  HOW_IT_WORKS.md \
  TROUBLESHOOTING.md
do
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
    root / "HOW_IT_WORKS.md",
    root / "TROUBLESHOOTING.md",
]
combined = "\n".join(path.read_text(encoding="utf-8") for path in documents)

for path in documents:
    text = path.read_text(encoding="utf-8")
    assert text.count("```") % 2 == 0, f"unbalanced fence: {path.name}"
    for target in re.findall(r"\]\((\./[^)#]+)", text):
        assert (root / target[2:]).exists(), f"broken link: {path.name}: {target}"

required = (
    "Claude Code `2.1.129`",
    "https://sam.soonsoon.ai/v2/claude",
    "/v2/claude/v1/models",
    "Haiku / Sonnet / Opus",
    "claude-sam-*",
    "https://sam.soonsoon.ai/mcp",
    "Bearer ${SAM_API_KEY}",
    "SAM_CLAUDE_INSTALLER_MANAGED=1",
    "uninstall-macos.sh",
    "uninstall-windows.ps1",
)
for item in required:
    assert item in combined, f"missing public contract: {item}"

for forbidden in (
    "/v2/anthropic",
    "anthropic.claude-haiku",
    "anthropic.claude-sonnet",
    "anthropic.claude-opus",
):
    assert forbidden not in combined, f"stale or volatile contract: {forbidden}"

assert "sk-ant-" not in combined
assert "Bearer sam_" not in combined
print("PASS: documentation links, fences, public contracts, and secret hygiene")
PY

awk '
  /^```bash$/ { in_bash = 1; next }
  /^```$/ && in_bash { in_bash = 0; print ""; next }
  in_bash { print }
' "$ROOT/MANUAL_SETUP.md" >"$TEMP_DIR/manual-blocks.sh"
bash -n "$TEMP_DIR/manual-blocks.sh"

printf 'PASS: manual setup Bash blocks parse\n'
