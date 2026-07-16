# SAM Codex on Windows

**Language:** [한국어](windows.md) | English

This guide creates a dedicated `sam-codex` terminal command. It uses SAM only
for that command and leaves your normal `codex` profile unchanged.

| Mode | Command | Config home |
| --- | --- | --- |
| Default Codex | `codex` | `%USERPROFILE%\.codex` |
| SAM Codex | `sam-codex` | `%USERPROFILE%\.codex-sam` |

## 1. Install prerequisites

Install Git, Node.js LTS (which includes npm), and Codex CLI before cloning
`sam-public` or running the SAM installer.

```powershell
winget install -e --id Git.Git
winget install -e --id OpenJS.NodeJS.LTS
```

Close PowerShell completely, open a new window, then run:

```powershell
node --version
npm --version

# Run only if PowerShell reports that npm.ps1 scripts are blocked.
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

npm install -g @openai/codex@latest
git --version
codex --version
```

If `winget` is unavailable, install Git and the Node.js LTS package from their
official installers, then open a new PowerShell window before continuing.

### If `codex` is not found

Windows npm global commands normally live in the user npm prefix. Add that
prefix to the current and future user PATH, then verify again:

```powershell
npm prefix -g
Get-Command codex -ErrorAction SilentlyContinue
$npmBin = npm prefix -g
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$npmBin", "User")
$env:Path += ";$npmBin"
codex --version
```

If it is still not found, close every PowerShell window and open a new one.

## 2. Clone or update the installer

Clone the repository once. On later runs, update the existing checkout instead
of running `git clone` again.

```powershell
$Repo = "$HOME\sam-public"
if (Test-Path "$Repo\.git") {
  git -C $Repo pull --ff-only
}
elseif (Test-Path $Repo) {
  throw "$Repo exists but is not a Git checkout. Rename or remove it only after checking its contents."
}
else {
  git clone https://github.com/soonsoonLABS/sam-public.git $Repo
}

Set-Location "$Repo\code-agent"
```

## 3. Install the dedicated SAM command

Run the installer and paste the SAM API key only into its hidden prompt. The
key owner needs `agent:codex` or `agent:coding_agents` permission.

```powershell
Remove-Item Env:SAM_API_KEY -ErrorAction SilentlyContinue
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

The installer creates `%USERPROFILE%\bin\sam-codex.cmd`, adds its folder to
your user PATH, and stores the key locally in
`%USERPROFILE%\.sam-code-agent\env.ps1`. Open a new PowerShell window if
`sam-codex` is not immediately visible.

## 4. Use SAM Codex

Use `sam-codex`, not plain `codex`, for every SAM session:

```powershell
# Interactive Codex terminal UI with SAM
sam-codex

# Non-interactive smoke test
sam-codex exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

The expected smoke-test reply is exactly `SAM-CODEX-OK`. If the command is not
yet on PATH, use the full path:

```powershell
& "$HOME\bin\sam-codex.ps1" exec --sandbox read-only --skip-git-repo-check --ephemeral "Reply with exactly: SAM-CODEX-OK"
```

## 5. Change the SAM API key

Re-run the installer. Removing `SAM_API_KEY` from the current process is
important: it makes the installer show its hidden prompt instead of reusing an
inherited key.

```powershell
Set-Location "$HOME\sam-public\code-agent"
Remove-Item Env:SAM_API_KEY -ErrorAction SilentlyContinue
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

This overwrites only `%USERPROFILE%\.sam-code-agent\env.ps1`, not your normal
Codex settings. Revoke the old key in SAM when it is no longer needed.

## 6. Test the key directly

This checks the SAM key and `/openai/v1/responses` before involving Codex. It
does not print the key. The final line should be `SAM-CODEX-OK`.

```powershell
. "$HOME\.sam-code-agent\env.ps1"
$body = @{
  model = "sam-codex-agent"
  input = "Reply with exactly: SAM-CODEX-OK"
  stream = $false
  reasoning = @{ effort = "medium"; summary = "none" }
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://sam.soonsoon.ai/openai/v1/responses" `
  -Headers @{ Authorization = "Bearer $env:SAM_API_KEY" } `
  -ContentType "application/json" `
  -Body $body

$response.output_text
Remove-Item Env:SAM_API_KEY -ErrorAction SilentlyContinue
```

If this succeeds but `sam-codex exec` fails, the key and SAM route are working;
re-run the installer and use the dedicated command rather than plain `codex`.

## 7. Create a desktop shortcut

After the installer succeeds, create a `SAM-Codex` shortcut on the Windows
desktop. It opens the dedicated SAM Codex terminal UI.

```powershell
$Desktop = [Environment]::GetFolderPath("Desktop")
$Target = "$HOME\bin\sam-codex.cmd"
$Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $Desktop "SAM-Codex.lnk"))
$Shortcut.TargetPath = $Target
$Shortcut.WorkingDirectory = $HOME
$Shortcut.IconLocation = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe,0"
$Shortcut.Save()
```

Double-click `SAM-Codex` on the desktop to start a SAM session.

## Optional: temporarily switch the default Windows Codex desktop mode to SAM

The recommended dedicated path is `sam-codex` in a terminal. Use the desktop
switcher only after the CLI smoke test succeeds: it temporarily changes the
default `%USERPROFILE%\.codex\config.toml` mode so the ChatGPT desktop app uses
SAM. It does **not** provide both modes at once or install a separate
SAM-Codex desktop application.

Before switching, note the recovery path. The script saves the current Codex
config before replacing it. To immediately return the existing desktop app to
its previous profile, run this from `sam-public\code-agent`:

```powershell
powershell -ExecutionPolicy Bypass -File .\restore-windows-desktop-default.ps1
```

```powershell
Set-Location "$HOME\sam-public\code-agent"
powershell -ExecutionPolicy Bypass -File .\enable-windows-desktop-sam.ps1
```

Fully quit the ChatGPT/Codex desktop app and reopen it. To restore the normal
profile later:

```powershell
powershell -ExecutionPolicy Bypass -File .\restore-windows-desktop-default.ps1
```

The restore script puts the backed-up configuration back. If the desktop app
does not start or shows the wrong profile after switching, fully quit it, run
the restore command above, and reopen it. For a newly created SAM user
environment variable, the restore script also removes that variable; if you
already had a different user-level `SAM_API_KEY`, the switcher stops rather
than overwriting it.
