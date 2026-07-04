#!/usr/bin/env bash
# Thin host wrapper for the multi-repo workspace validation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_ROOT="$(cd "${DEMO_ROOT}/.." && pwd)"
export PYTHONPATH="${WORKSPACE_ROOT}/stubborn/src:${WORKSPACE_ROOT}/stubborn-mcp/src${PYTHONPATH:+:${PYTHONPATH}}"
if [[ -x "${WORKSPACE_ROOT}/.tooling/venv/bin/python" ]]; then
  export STUBBORN_CMD="${WORKSPACE_ROOT}/.tooling/venv/bin/python -c 'from stubborn.cli import app; app()'"
fi

cd "${DEMO_ROOT}"
exec python3 scripts/verify_multi_repo_workspace.py
