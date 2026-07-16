# 0. First SAM Setup

**Language:** [한국어](README.md) | English

This is the shortest way to safely load a SAM API key into your current terminal
and confirm that a real `Hello SAM` call works.

> The key disappears when you close the current terminal window. Do not save or
> share API keys in Git, `.env` files, URLs, screenshots, or command history.

## macOS

### 1. Enter your key

Run the command below, paste your SAM key, then press Enter. The key will not be
shown while you type or paste it.

```bash
read -s "SAM_API_KEY?Enter SAM key: "
echo
export SAM_API_KEY
```

### 2. Check the key prefix

Print only the first 12 characters, not the full key.

```bash
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

### 1. Enter your key

Run the commands below, paste your SAM key, then press Enter. The key will not be
shown while you type or paste it.

```powershell
$secure = Read-Host "Enter SAM key" -AsSecureString
$env:SAM_API_KEY = (New-Object PSCredential "sam",$secure).GetNetworkCredential().Password
```

### 2. Check the key prefix

```powershell
$env:SAM_API_KEY.Substring(0,12) + "..."
```

### 3. Test Hello SAM

In PowerShell, do not use the macOS `curl`, `-H`, `-d`, or `\` line-continuation
syntax. Copy and run the full PowerShell block below.

```powershell
$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/v1/hello" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body (@{ greeting = "Hello SAM" } | ConvertTo-Json)

$response.joke
```

## Success Criteria

If you get one short joke back, your API key, network connection, SAM
authentication, and real model call are working. `Hello SAM` calls a real model,
so a small amount of SAM usage is recorded.
