#!/usr/bin/env bash
# Smoke-test MCP tools against demo-spring (same calls Cursor agents make).
set -euo pipefail

DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STUBBORN_DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB_PATH="${DEMO_ROOT}/metadata/symbols.db"
SOURCES="${DEMO_ROOT}/src/main/java"

if [[ ! -f "${DB_PATH}" ]]; then
  echo "symbols.db missing — run scripts/run-e2e.sh first (or: stubborn index --scip index.scip --out metadata/symbols.db)" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${STUBBORN_DEMO_ROOT}/scripts/stubborn-preflight.sh"
stubborn_preflight "${DEMO_ROOT}" "stubborn-stub,stubborn-mcp" || exit $?

export STUBBORN_DB="${DB_PATH}"

python3 - "${SOURCES}" <<'PY'
import sys

from stubborn_mcp.server import get_context, list_contracts, list_symbols, metrics, workspace_info

sources = sys.argv[1]

workspace = workspace_info("default")
print("workspace_info:", workspace["code_repo_count"], "code repos,", workspace["contract_source_count"], "contract sources")
contracts = list_contracts(workspace="default")
print("list_contracts:", contracts["returned"], "endpoint(s)")
listing = list_symbols(query="OrderService", limit=3)
print("list_symbols:", listing["returned"], "hit(s)")
target = listing["symbols"][0]["stable_id"]
print("target:", target)

ctx = get_context(target)
print("get_context:", ctx["symbol_count"], "symbols, ~", ctx["estimated_tokens"], "tokens")
print("--- stub preview ---")
print(ctx["text"][:600])

kpi = metrics(target, sources)
print("--- metrics ---")
print("compression_ratio:", kpi["compression_ratio"])
print("token_savings_percent:", kpi["token_savings_percent"])
PY

echo
echo "MCP smoke OK. In Cursor: open stubborn-demo repo root, enable MCP server 'stubborn'."
