#!/usr/bin/env bash
# End-to-end: demo-spring -> scip-java -> stubborn context
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="${DEMO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

cd "${DEMO_ROOT}"

assert_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    exit 1
  fi
}

echo "== orders-demo E2E =="
assert_command mvn
assert_command scip-java
assert_command stubborn
assert_command python3

echo
echo "[1/5] Maven compile..."
mvn -q -DskipTests package

echo
echo "[2/5] scip-java index..."
rm -f index.scip
scip-java index
if [[ ! -f index.scip ]]; then
  echo "index.scip was not created" >&2
  exit 1
fi

echo
echo "[3/5] stubborn index..."
mkdir -p metadata
db_path="${DEMO_ROOT}/metadata/symbols.db"
rm -f "${db_path}"
stubborn index --scip index.scip --out "${db_path}"

echo
echo "[4/5] index summary..."
stubborn info "${db_path}"

echo
echo "[5/5] resolve OrderService + emit context..."
target="$(python3 - "${db_path}" <<'PY'
import sqlite3
import sys

db_path = sys.argv[1]
conn = sqlite3.connect(db_path)
row = conn.execute(
    """
    SELECT stable_id FROM scip_symbol
    WHERE display_name = 'OrderService'
       OR stable_id LIKE '%OrderService#%'
    ORDER BY length(stable_id)
    LIMIT 1
    """
).fetchone()
if not row:
    raise SystemExit('OrderService symbol not found in index')
print(row[0])
PY
)"

echo "Target: ${target}"
stub_path="${DEMO_ROOT}/metadata/order-service.stub.java"
stubborn context "${db_path}" --target "${target}" --out "${stub_path}"

echo
echo "Done."
echo "  SCIP index : ${DEMO_ROOT}/index.scip"
echo "  SQLite graph: ${db_path}"
echo "  LLM stub    : ${stub_path}"
echo
echo "See cases/order-service-context.md for expected neighbors."
