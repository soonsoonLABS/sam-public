#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="${HOME}/.sam-code-agent"
MANIFEST_FILE="${SAM_HOME}/desktop-switch.env"
DEFAULT_CODEX_HOME="${HOME}/.codex"
DEFAULT_CONFIG="${DEFAULT_CODEX_HOME}/config.toml"

if [[ ! -f "${MANIFEST_FILE}" ]]; then
  echo "No macOS desktop switch manifest found. Nothing to restore."
  exit 0
fi

had_config="$(awk -F= '$1 == "had_config" { print $2; exit }' "${MANIFEST_FILE}")"
backup_path="$(awk -F= '$1 == "backup_path" { print substr($0, index($0, "=") + 1); exit }' "${MANIFEST_FILE}")"
had_session_key="$(awk -F= '$1 == "had_session_key" { print $2; exit }' "${MANIFEST_FILE}")"

if [[ "${had_config}" == "1" ]]; then
  if [[ -z "${backup_path}" || ! -f "${backup_path}" ]]; then
    echo "Backup config was expected but was not found: ${backup_path}" >&2
    exit 1
  fi
  mkdir -p "${DEFAULT_CODEX_HOME}"
  temporary_config="$(mktemp "${DEFAULT_CODEX_HOME}/.config.toml.XXXXXX")"
  trap 'rm -f "${temporary_config}"' EXIT
  cp "${backup_path}" "${temporary_config}"
  chmod 600 "${temporary_config}"
  mv -f "${temporary_config}" "${DEFAULT_CONFIG}"
  echo "Restored previous Codex desktop config: ${DEFAULT_CONFIG}"
elif [[ "${had_config}" == "0" ]]; then
  rm -f "${DEFAULT_CONFIG}"
  echo "Removed SAM desktop config. No previous config.toml existed."
else
  echo "Invalid desktop switch manifest. Nothing was changed." >&2
  exit 1
fi

if [[ "${had_session_key}" == "0" ]]; then
  launchctl unsetenv SAM_API_KEY
  echo "Cleared the SAM_API_KEY GUI-session value created for the desktop switch."
elif [[ "${had_session_key}" == "1" ]]; then
  echo "An existing SAM_API_KEY GUI-session value predated the switch, so it was left unchanged."
else
  echo "Legacy desktop-switch manifest: SAM_API_KEY GUI-session value was left unchanged."
fi

rm -f "${MANIFEST_FILE}"
echo
echo "Fully quit ChatGPT/Codex with Cmd-Q, then reopen it."
