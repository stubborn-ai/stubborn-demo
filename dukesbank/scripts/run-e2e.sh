#!/usr/bin/env bash
# Duke's Bank bank module -> scip-java -> stubborn context (AccountControllerBean)
set -euo pipefail

EXAMPLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${EXAMPLE_ROOT}/../.." && pwd)"
export PYTHONPATH="${REPO_ROOT}/stubborn/src:${REPO_ROOT}/stubborn-mcp/src${PYTHONPATH:+:${PYTHONPATH}}"

bank_root="${BANK_ROOT:-}"
if [[ -z "${bank_root}" ]]; then
  bank_root="$(cd "${REPO_ROOT}/../../dukesbank/src/j2eetutorial14/examples/bank" 2>/dev/null && pwd || true)"
fi
if [[ -z "${bank_root}" || ! -d "${bank_root}" ]]; then
  echo "Duke's Bank module not found. Clone dukesbank as a sibling of this repo (or set BANK_ROOT)." >&2
  exit 1
fi

assert_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    exit 1
  fi
}

echo "== Duke's Bank stubborn E2E =="
echo "Bank module: ${bank_root}"

assert_command mvn
assert_command scip-java
assert_command stubborn
assert_command python3

cd "${bank_root}"

echo
echo "[1/6] Maven compile..."
mvn -q -DskipTests package

echo
echo "[2/6] scip-java index..."
rm -f index.scip
scip-java index
if [[ ! -f index.scip ]]; then
  echo "index.scip was not created" >&2
  exit 1
fi

db_path="${EXAMPLE_ROOT}/metadata/symbols.db"
mkdir -p "$(dirname "${db_path}")"
rm -f "${db_path}"

echo
echo "[3/6] stubborn index..."
stubborn index --scip index.scip --out "${db_path}"

echo
echo "[4/6] resolve AccountControllerBean..."
target="$(python3 "${REPO_ROOT}/scripts/resolve_symbol.py" "${db_path}" --display-name AccountControllerBean)"
if [[ -z "${target}" ]]; then
  echo "AccountControllerBean symbol not found" >&2
  exit 1
fi
echo "Target: ${target}"

echo
echo "[5/6] emit java-stub + stubborn-dsl..."
stub_path="${EXAMPLE_ROOT}/metadata/account-controller.stub.java"
dsl_path="${EXAMPLE_ROOT}/metadata/account-controller.stubborn-dsl"
stubborn context "${db_path}" --target "${target}" --out "${stub_path}"
stubborn context "${db_path}" --target "${target}" --format stubborn-dsl \
  --member-signatures neighbors --javadoc summary --out "${dsl_path}"

echo
echo "[6/6] metrics..."
stubborn metrics "${db_path}" --target "${target}" --sources src

echo
echo "Done."
echo "  SQLite graph : ${db_path}"
echo "  java-stub    : ${stub_path}"
echo "  stubborn-dsl : ${dsl_path}"
echo
echo "Verify: python3 scripts/verify_dukesbank_context.py (from repo root)"
