# 0. Test the SAM environment and shared API key

**Language:** [한국어](README.md) | English

Store one `SAM_API_KEY` for both `sam-codex` and `sam-claude` in the standard
local folder, `~/.sam/`. Test the environment, key, and two Coding Agent grants
separately before installation.

## Standard path

```text
~/.sam/
  env       # macOS/Linux
  env.ps1   # Windows PowerShell
  skills/   # SAM skill documents for agents
```

Do not create a different key file for each agent. Restart already-running
CLIs and agents after replacing the key.

## 1. Test the SAM environment

Check connectivity and readiness without a key. This does not generate model
output.

```bash
curl -fsS --max-time 10 https://sam.soonsoon.ai/readyz
```

```powershell
(Invoke-WebRequest -TimeoutSec 10 -Uri "https://sam.soonsoon.ai/readyz").StatusCode
```

A readiness JSON response or HTTP `200` confirms the network, DNS, TLS, and SAM
entrypoint. It does not validate your key or a model provider.

## 2. Save the shared SAM API key

Use hidden input. Never paste the key value into a literal command.

### macOS / Linux

```bash
mkdir -p "$HOME/.sam"
chmod 700 "$HOME/.sam"
printf "Enter SAM API key: "
stty -echo
IFS= read -r SAM_API_KEY
stty echo
printf "\n"
printf 'export SAM_API_KEY=%q\n' "$SAM_API_KEY" > "$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
unset SAM_API_KEY
source "$HOME/.sam/env"
```

### Windows PowerShell

```powershell
$SamHome = Join-Path $HOME ".sam"
New-Item -ItemType Directory -Force -Path $SamHome | Out-Null
$secure = Read-Host "Enter SAM API key" -AsSecureString
$key = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
$safeKey = $key.Replace("'", "''")
Set-Content -Path (Join-Path $SamHome "env.ps1") -Encoding UTF8 `
  -Value "`$env:SAM_API_KEY = '$safeKey'"
icacls (Join-Path $SamHome "env.ps1") /inheritance:r `
  /grant:r "$($env:USERNAME):F" | Out-Null
. (Join-Path $SamHome "env.ps1")
$key = $null
$safeKey = $null
```

Do not print the full key or a prefix. Installers reuse the existing standard
key, or update it when the current terminal contains a new `SAM_API_KEY`.

## 3. Test the key and Coding Agent grants

Use the same key for both OpenAI/Codex and Anthropic/Claude Code discovery.
Neither request generates model output.

### macOS / Linux

```bash
source "$HOME/.sam/env"

curl -sS --max-time 15 -o /dev/null \
  -w "SAM OpenAI discovery: HTTP %{http_code}\n" \
  https://sam.soonsoon.ai/v2/openai/models \
  -H "Authorization: Bearer $SAM_API_KEY"

curl -sS --max-time 15 -o /dev/null \
  -w "SAM Anthropic discovery: HTTP %{http_code}\n" \
  https://sam.soonsoon.ai/v2/anthropic/v1/models \
  -H "Authorization: Bearer $SAM_API_KEY"
```

### Windows PowerShell

```powershell
. "$HOME\.sam\env.ps1"
$headers = @{ Authorization = "Bearer $env:SAM_API_KEY" }

(Invoke-WebRequest -TimeoutSec 15 `
  -Uri "https://sam.soonsoon.ai/v2/openai/models" `
  -Headers $headers).StatusCode

(Invoke-WebRequest -TimeoutSec 15 `
  -Uri "https://sam.soonsoon.ai/v2/anthropic/v1/models" `
  -Headers $headers).StatusCode
```

## Interpret the result

| Result | Meaning | Action |
| --- | --- | --- |
| Both return `200` | Key and both Coding Agent grants are valid | Continue |
| `401 AUTH_INVALID` | Invalid or revoked key | Check the active key in SAM and save it again |
| `403` | Key is known but lacks the Agent grant | Check the account/key Coding Agent grant |
| `404` | Old or incorrect base URL | Use the V2 URLs in this guide |
| timeout / HTTP `000` | Network or SAM runtime problem | Report readiness and discovery separately |

HTTP `200` from `/readyz` proves only infrastructure readiness. Do not diagnose
the CLI or run a paid generation test until authenticated discovery succeeds.

## Optional: test a real generation

`Hello SAM` calls a real model and may record a small amount of SAM usage. Run
it only after no-generation discovery succeeds.

```bash
curl -sS -X POST https://sam.soonsoon.ai/v1/hello \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"Hello SAM"}'
```

## Delete the shared key

Remove both `sam-codex` and `sam-claude` first, then run:

```bash
./remove-shared-key-macos.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\remove-shared-key-windows.ps1
```

Finally run `unset SAM_API_KEY` in each already-open macOS/Linux terminal.
