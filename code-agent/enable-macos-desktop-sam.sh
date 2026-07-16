#!/usr/bin/env bash
set -euo pipefail

SAM_HOME="${HOME}/.sam-code-agent"
ENV_FILE="${SAM_HOME}/env"
DEFAULT_CODEX_HOME="${HOME}/.codex"
DEFAULT_CONFIG="${DEFAULT_CODEX_HOME}/config.toml"
BACKUP_DIR="${SAM_HOME}/backups"
MANIFEST_FILE="${SAM_HOME}/desktop-switch.env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/templates/codex-config.toml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Run install-macos.sh first." >&2
  exit 1
fi
if [[ ! -f "${TEMPLATE}" ]]; then
  echo "Missing ${TEMPLATE}. Run this script from sam-public/code-agent." >&2
  exit 1
fi

# The installer writes a shell-escaped export. Do not enable xtrace here.
source "${ENV_FILE}"
if [[ -z "${SAM_API_KEY:-}" ]]; then
  echo "SAM_API_KEY is empty. Run install-macos.sh again and enter a valid SAM key." >&2
  exit 1
fi

existing_session_key=""
had_session_key=0
if existing_session_key="$(launchctl getenv SAM_API_KEY 2>/dev/null)"; then
  had_session_key=1
  if [[ -n "${existing_session_key}" && "${existing_session_key}" != "${SAM_API_KEY}" ]]; then
    echo "A different SAM_API_KEY is already set for this macOS login session." >&2
    echo "The desktop switcher will not overwrite it. Use sam-codex or replace it intentionally before retrying." >&2
    exit 1
  fi
fi
unset existing_session_key

mkdir -p "${DEFAULT_CODEX_HOME}" "${BACKUP_DIR}"
chmod 700 "${SAM_HOME}" "${BACKUP_DIR}" 2>/dev/null || true

had_config=0
backup_path=""
if [[ -f "${MANIFEST_FILE}" ]]; then
  had_config="$(awk -F= '$1 == "had_config" { print $2; exit }' "${MANIFEST_FILE}")"
  backup_path="$(awk -F= '$1 == "backup_path" { print substr($0, index($0, "=") + 1); exit }' "${MANIFEST_FILE}")"
  previous_had_session_key="$(awk -F= '$1 == "had_session_key" { print $2; exit }' "${MANIFEST_FILE}")"
  if [[ "${had_config}" != "0" && "${had_config}" != "1" ]]; then
    echo "Invalid desktop switch manifest. Restore manually from ${BACKUP_DIR}." >&2
    exit 1
  fi
  if [[ "${previous_had_session_key}" == "0" || "${previous_had_session_key}" == "1" ]]; then
    had_session_key="${previous_had_session_key}"
  fi
elif [[ -f "${DEFAULT_CONFIG}" ]]; then
  had_config=1
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="${BACKUP_DIR}/config.toml.${stamp}.bak"
  cp -p "${DEFAULT_CONFIG}" "${backup_path}"
  chmod 600 "${backup_path}"
fi

temporary_config="$(mktemp "${DEFAULT_CODEX_HOME}/.config.toml.XXXXXX")"
trap 'rm -f "${temporary_config}"' EXIT
cp "${TEMPLATE}" "${temporary_config}"
chmod 600 "${temporary_config}"
mv -f "${temporary_config}" "${DEFAULT_CONFIG}"

# This reaches GUI apps launched after this command. It is cleared at logout.
launchctl setenv SAM_API_KEY "${SAM_API_KEY}"

temporary_manifest="$(mktemp "${SAM_HOME}/.desktop-switch.env.XXXXXX")"
printf 'version=1\nenabled_at=%s\nhad_config=%s\nbackup_path=%s\nhad_session_key=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${had_config}" "${backup_path}" "${had_session_key}" > "${temporary_manifest}"
chmod 600 "${temporary_manifest}"
mv -f "${temporary_manifest}" "${MANIFEST_FILE}"

echo "Default Codex desktop profile switched to SAM."
echo "Config: ${DEFAULT_CONFIG}"
[[ -n "${backup_path}" ]] && echo "Backup: ${backup_path}" || echo "Backup: none; no previous config.toml existed."
echo
echo "Fully quit ChatGPT/Codex with Cmd-Q, then reopen it."
echo "After logout or reboot, run this switch command again before opening the desktop app."
echo "To restore: bash restore-macos-desktop-default.sh"
