# 0. First SAM Setup

**Language:** [한국어](README.md) | English

This guide stores a SAM API key in the user's standard local SAM folder,
`~/.sam/`, loads it into the current terminal, and verifies a real `Hello SAM`
call.

> The key file stays only on the user's device, outside Git. Do not put API keys
> in docs, issues, command history, URLs, screenshots, or shared messages.

## Standard Path

```text
~/.sam/
  env       # macOS/Linux
  env.ps1   # Windows PowerShell
  skills/   # SAM skill documents for agents
```

Point every agent to this path. Do not create alternate key files such as
`~/.config/sam/.env`. After replacing a key, restart any already-running CLI or
agent process so it reads the new value.

The Codex installer stores `SAM_CODEX_API` in this file and also exposes the
same value as `SAM_API_KEY` for existing general-purpose SAM tooling.

## macOS

### 1. Save the key

Run the command below, paste your SAM key, then press Enter. The key will not be
shown while you type or paste it.

```bash
mkdir -p "$HOME/.sam"
chmod 700 "$HOME/.sam"
read -s "SAM_API_KEY?Enter SAM key: "
echo
printf "export SAM_API_KEY='%s'\n" "$SAM_API_KEY" > "$HOME/.sam/env"
chmod 600 "$HOME/.sam/env"
source "$HOME/.sam/env"
```

### 2. Check the key prefix

Print only the first 12 characters, not the full key.

```bash
source "$HOME/.sam/env"
echo "${SAM_API_KEY:0:12}..."
```

### 3. Test Hello SAM

An English greeting returns a short one-line English joke.

```bash
curl -s -X POST https://sam.soonsoon.ai/v1/hello \
  -H "Authorization: Bearer $SAM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"greeting":"Hello SAM"}' \
  | sed -E 's/.*"joke":"([^"]*)".*/\1/'
```

## Windows PowerShell

### 1. Save the key

Run the commands below, paste your SAM key, then press Enter. The key will not be
shown while you type or paste it.

```powershell
$SamHome = Join-Path $HOME ".sam"
New-Item -ItemType Directory -Force -Path $SamHome | Out-Null
$secure = Read-Host "Enter SAM key" -AsSecureString
$key = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
Set-Content -Path (Join-Path $SamHome "env.ps1") -Encoding UTF8 -Value "`$env:SAM_API_KEY = '$key'"
icacls (Join-Path $SamHome "env.ps1") /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
. (Join-Path $SamHome "env.ps1")
```

### 2. Check the key prefix

```powershell
. "$HOME\.sam\env.ps1"
$env:SAM_API_KEY.Substring(0,12) + "..."
```

### 3. Test Hello SAM

In PowerShell, do not use the macOS `curl`, `-H`, `-d`, or `\` line-continuation
syntax. Copy and run the full PowerShell block below.

```powershell
(Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/v1/hello" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body (@{ greeting = "Hello SAM" } | ConvertTo-Json)).joke
```

## Replace the Key

To replace the key, rerun the save step above and overwrite only `~/.sam/env` or
`~/.sam/env.ps1`. Revoke the old key in SAM web under **API Keys**.

## Success Criteria

If you get one short joke back, your API key, network connection, SAM
authentication, and real model call are working. `Hello SAM` calls a real model,
so a small amount of SAM usage is recorded.
