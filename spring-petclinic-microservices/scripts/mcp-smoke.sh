#!/usr/bin/env bash
# Smoke-test MCP tools against spring-petclinic-microservices.
set -euo pipefail

EXAMPLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${EXAMPLE_ROOT}/../.." && pwd)"
DB_PATH="${EXAMPLE_ROOT}/metadata/petclinic-workspace.db"

if [[ ! -f "${DB_PATH}" ]]; then
  echo "petclinic workspace DB missing — run scripts/run-e2e.sh first." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/stubborn-preflight.sh"
stubborn_preflight "${EXAMPLE_ROOT}" "stubborn-stub,stubborn-mcp" || exit $?

export STUBBORN_DB="${DB_PATH}"

python3 - "${DB_PATH}" <<'PY'
from stubborn_mcp.server import get_context, list_contracts, workspace_info
from stubborn.store.reader import resolve_stable_id
import sys

db_path = sys.argv[1]
workspace_name = "petclinic-ms"

workspace = workspace_info(workspace_name)
print(
    "workspace_info:",
    workspace["code_repo_count"],
    "code repos,",
    workspace["contract_source_count"],
    "contract sources,",
    workspace["contract_endpoint_count"],
    "endpoint(s)",
)

if workspace["code_repo_count"] != 4:
    raise AssertionError(f"expected 4 code repos, got {workspace['code_repo_count']}")
if workspace["contract_source_count"] != 1:
    raise AssertionError(f"expected 1 contract source, got {workspace['contract_source_count']}")
if workspace["contract_endpoint_count"] != 2:
    raise AssertionError(f"expected 2 contract endpoints, got {workspace['contract_endpoint_count']}")

contracts = list_contracts(workspace=workspace_name)
print("list_contracts:", contracts["returned"], "endpoint(s)")
if contracts["returned"] != 2:
    raise AssertionError(f"expected 2 contract endpoints, got {contracts['returned']}")

contract_ids = {endpoint["stable_id"] for endpoint in contracts["contract_endpoints"]}
expected_contract_ids = {
    "openapi customers-service:v1 GET /owners/{ownerId}",
    "openapi visits-service:v1 GET /pets/visits",
}
missing_contracts = expected_contract_ids - contract_ids
if missing_contracts:
    raise AssertionError(
        f"missing expected contract endpoints: {', '.join(sorted(missing_contracts))}"
    )

forward_target = resolve_stable_id(
    db_path,
    display_name="CustomersServiceClient",
    workspace=workspace_name,
    repo_key="api-gateway",
)
forward = get_context(
    forward_target,
    db_path=db_path,
    workspace=workspace_name,
    format="stubborn-dsl",
    call_depth=4,
    max_symbols=120,
    max_tokens=16_000,
)
print("forward target:", forward_target)
print("forward context:", forward["symbol_count"], "symbols,", len(forward["contract_edges"]), "contract edge(s)")
if "contracts:" not in forward["text"]:
    raise AssertionError("forward context is missing the contracts block")
if "evidence=declared" not in forward["text"]:
    raise AssertionError("forward context is missing declared contract evidence")
if "openapi customers-service:v1 GET /owners/{ownerId}" not in forward["text"]:
    raise AssertionError("forward context is missing the customers contract endpoint")

reverse_target = resolve_stable_id(
    db_path,
    display_name="OwnerResource",
    workspace=workspace_name,
    repo_key="customers-service",
)
reverse = get_context(
    reverse_target,
    db_path=db_path,
    workspace=workspace_name,
    format="stubborn-dsl",
    call_depth=4,
    max_symbols=120,
    max_tokens=16_000,
)
print("reverse target:", reverse_target)
print("reverse context:", reverse["symbol_count"], "symbols,", len(reverse["contract_edges"]), "contract edge(s)")
if "contracts:" not in reverse["text"]:
    raise AssertionError("reverse context is missing the contracts block")
if "evidence=declared" not in reverse["text"]:
    raise AssertionError("reverse context is missing declared contract evidence")
if "openapi customers-service:v1 GET /owners/{ownerId}" not in reverse["text"]:
    raise AssertionError("reverse context is missing the customers contract endpoint")

print('MCP smoke OK. In Cursor: open stubborn-demo repo root, enable MCP server "stubborn".')
PY
