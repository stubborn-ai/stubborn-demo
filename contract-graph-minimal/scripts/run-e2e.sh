#!/usr/bin/env bash
# Minimal mixed workspace: code fixtures + OpenAPI + declared bindings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

assert_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    exit 1
  fi
}

assert_command python3
assert_command stubborn

cd "${DEMO_ROOT}"
exec python3 scripts/verify_contract_graph_minimal.py
