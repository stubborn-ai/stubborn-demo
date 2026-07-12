#!/usr/bin/env bash
# Shared launcher preflight: stubborn doctor + optional stubborn-status (ADR-015/016).
# Source this file, then call stubborn_preflight [PROJECT_ROOT] [REQUIRE_PACKAGES].
#
# Exit codes: doctor/status exit 1 = blocking failure; 2 = warnings only (continues).
# Set SKIP_STUBBORN_STATUS=1 to skip federated status (e.g. minimal smoke scripts).

set -euo pipefail

STUBBORN_TROUBLESHOOTING_URL="https://github.com/stubborn-ai/stubborn/blob/main/docs/TROUBLESHOOTING.md"
STUBBORN_USER_JOURNEY_URL="https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/USER-JOURNEY.md"

stubborn_preflight() {
  local root="${1:-.}"
  local require="${2:-stubborn-stub}"

  if ! command -v stubborn >/dev/null 2>&1; then
    echo "Required command not found on PATH: stubborn" >&2
    echo "Install: pip install stubborn-stub" >&2
    echo "Troubleshooting: ${STUBBORN_TROUBLESHOOTING_URL}" >&2
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Required command not found on PATH: python3" >&2
    return 1
  fi

  echo "== stubborn preflight =="
  local doctor_code=0
  stubborn doctor "${root}" -q || doctor_code=$?
  if [[ "${doctor_code}" -eq 1 ]]; then
    echo "stubborn doctor failed (blocking). Run: stubborn doctor ${root}" >&2
    echo "Troubleshooting: ${STUBBORN_TROUBLESHOOTING_URL}" >&2
    return 1
  fi
  if [[ "${doctor_code}" -eq 2 ]]; then
    echo "stubborn doctor warnings (non-blocking). Run: stubborn doctor ${root}" >&2
  fi

  if [[ "${SKIP_STUBBORN_STATUS:-0}" == "1" ]]; then
    return 0
  fi

  if command -v stubborn-status >/dev/null 2>&1; then
    echo
    echo "== stubborn-status =="
    local status_code=0
    stubborn-status "${root}" --require "${require}" -q || status_code=$?
    if [[ "${status_code}" -ne 0 ]]; then
      stubborn-status "${root}" --require "${require}" >&2 || true
      echo "stubborn-status exit ${status_code}." >&2
      echo "Troubleshooting: ${STUBBORN_TROUBLESHOOTING_URL}" >&2
      echo "User journeys: ${STUBBORN_USER_JOURNEY_URL}" >&2
      return "${status_code}"
    fi
  else
    echo "Tip: pip install stubborn-status for federated doctor checks (optional)." >&2
    echo "User journeys: ${STUBBORN_USER_JOURNEY_URL}" >&2
  fi

  return 0
}
