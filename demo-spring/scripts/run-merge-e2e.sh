#!/usr/bin/env bash
# End-to-end: demo-spring save -> scip-java -> stubborn index --merge
set -euo pipefail

DEMO_ROOT="${DEMO_ROOT:-/demo}"
PROBE_RELATIVE_PATH="src/main/java/com/example/orders/service/MergeProbeService.java"
PROBE_PATH="${DEMO_ROOT}/${PROBE_RELATIVE_PATH}"
DB_PATH="${DEMO_ROOT}/metadata/symbols.db"
PROBE_DISPLAY_NAME="MergeProbeService"
WORKSPACE_ROOT="$(cd "${DEMO_ROOT}/../.." && pwd)"
export PYTHONPATH="${WORKSPACE_ROOT}/stubborn/src:${WORKSPACE_ROOT}/stubborn-mcp/src${PYTHONPATH:+:${PYTHONPATH}}"
probe_added=0
cleanup_complete=0

assert_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    exit 1
  fi
}

graph_state() {
  local db_path="$1"
  local display_name="$2"
  python3 - "${db_path}" "${display_name}" <<'PY'
import json
import sqlite3
import sys

from stubborn.store.reader import list_symbols
from stubborn.store.writer import read_info

db_path, display_name = sys.argv[1:3]
info = read_info(db_path)
probe_records = list_symbols(db_path, query=display_name, limit=10)
order_records = list_symbols(db_path, query="OrderService", limit=10)

conn = sqlite3.connect(db_path)
row = conn.execute(
    """
    SELECT relative_path
    FROM scip_symbol
    WHERE display_name = ?
    ORDER BY stable_id
    LIMIT 1
    """,
    (display_name,),
).fetchone()
conn.close()

print(json.dumps({
    "run_id": info.index_run_id,
    "mode": info.mode,
    "merge_count": info.merge_count,
    "probe_present": any(record.display_name == display_name for record in probe_records),
    "order_service_present": any(record.display_name == "OrderService" for record in order_records),
    "relative_path": row[0] if row else None,
}))
PY
}

json_field() {
  local json="$1"
  local field="$2"
  python3 - "${json}" "${field}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
value = payload[sys.argv[2]]
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

cleanup() {
  if [[ -f "${PROBE_PATH}" ]]; then
    rm -f "${PROBE_PATH}"
  fi

  if [[ "${probe_added}" == "1" && "${cleanup_complete}" != "1" ]]; then
    echo "warning: merge E2E did not finish cleanly; attempting metadata cleanup" >&2
    (
      cd "${DEMO_ROOT}"
      rm -f index.scip
      scip-java index
      if [[ -f "${DB_PATH}" ]]; then
        stubborn index --scip index.scip --out "${DB_PATH}" --merge --paths "${PROBE_RELATIVE_PATH}" >/dev/null
      fi
    ) || true
  fi
}
trap cleanup EXIT

echo "== orders-demo merge E2E =="
assert_command mvn
assert_command scip-java
assert_command stubborn
assert_command python3

if [[ -f "${PROBE_PATH}" ]]; then
  echo "Refusing to overwrite existing probe source: ${PROBE_PATH}" >&2
  exit 1
fi

cd "${DEMO_ROOT}"

echo
echo "[1/8] Maven compile baseline..."
mvn -q -DskipTests package

echo
echo "[2/8] scip-java index baseline..."
rm -f index.scip
scip-java index
if [[ ! -f index.scip ]]; then
  echo "index.scip was not created" >&2
  exit 1
fi

echo
echo "[3/8] stubborn snapshot index..."
mkdir -p metadata
rm -f "${DB_PATH}"
stubborn index --scip index.scip --out "${DB_PATH}"
stubborn info "${DB_PATH}"

before="$(graph_state "${DB_PATH}" "${PROBE_DISPLAY_NAME}")"
if [[ "$(json_field "${before}" probe_present)" == "true" ]]; then
  echo "${PROBE_DISPLAY_NAME} unexpectedly exists before merge test starts" >&2
  exit 1
fi
baseline_run_id="$(json_field "${before}" run_id)"

echo
echo "[4/8] Save a new Java source file..."
cat > "${PROBE_PATH}" <<'JAVA'
package com.example.orders.service;

import org.springframework.stereotype.Service;

@Service
public class MergeProbeService {

    public String probe() {
        return "merge-ok";
    }
}
JAVA
probe_added=1

echo
echo "[5/8] Re-index after save..."
rm -f index.scip
scip-java index
if [[ ! -f index.scip ]]; then
  echo "index.scip was not recreated after adding the probe source" >&2
  exit 1
fi

echo
echo "[6/8] Merge just the changed path..."
stubborn index --scip index.scip --out "${DB_PATH}" --merge --paths "${PROBE_RELATIVE_PATH}"
stubborn info "${DB_PATH}"

after="$(graph_state "${DB_PATH}" "${PROBE_DISPLAY_NAME}")"
if [[ "$(json_field "${after}" probe_present)" != "true" ]]; then
  echo "${PROBE_DISPLAY_NAME} was not visible via list_symbols after merge" >&2
  exit 1
fi
if [[ "$(json_field "${after}" order_service_present)" != "true" ]]; then
  echo "OrderService disappeared after path-scoped merge" >&2
  exit 1
fi
if [[ "$(json_field "${after}" run_id)" != "${baseline_run_id}" ]]; then
  echo "Expected merge to update index_run_id=${baseline_run_id}, got $(json_field "${after}" run_id)" >&2
  exit 1
fi
if [[ "$(json_field "${after}" mode)" != "merged" ]]; then
  echo "Expected merged mode after path-scoped update, got $(json_field "${after}" mode)" >&2
  exit 1
fi
if [[ "$(json_field "${after}" merge_count)" -lt 1 ]]; then
  echo "Expected merge_count >= 1 after merge, got $(json_field "${after}" merge_count)" >&2
  exit 1
fi
if [[ "$(json_field "${after}" relative_path)" != "${PROBE_RELATIVE_PATH}" ]]; then
  echo "Expected ${PROBE_DISPLAY_NAME} relative_path to be ${PROBE_RELATIVE_PATH}, got $(json_field "${after}" relative_path)" >&2
  exit 1
fi

echo
echo "[7/8] Delete the temporary source file..."
rm -f "${PROBE_PATH}"

echo
echo "[8/8] Re-index and merge the deletion..."
rm -f index.scip
scip-java index
stubborn index --scip index.scip --out "${DB_PATH}" --merge --paths "${PROBE_RELATIVE_PATH}"

final="$(graph_state "${DB_PATH}" "${PROBE_DISPLAY_NAME}")"
if [[ "$(json_field "${final}" probe_present)" == "true" ]]; then
  echo "${PROBE_DISPLAY_NAME} still exists after merging the deletion" >&2
  exit 1
fi
if [[ "$(json_field "${final}" order_service_present)" != "true" ]]; then
  echo "OrderService disappeared after merge cleanup" >&2
  exit 1
fi
if [[ "$(json_field "${final}" run_id)" != "${baseline_run_id}" ]]; then
  echo "Cleanup merge changed index_run_id from ${baseline_run_id} to $(json_field "${final}" run_id)" >&2
  exit 1
fi
if [[ "$(json_field "${final}" merge_count)" -lt 2 ]]; then
  echo "Expected merge_count >= 2 after add/remove cycle, got $(json_field "${final}" merge_count)" >&2
  exit 1
fi
cleanup_complete=1

echo
echo "Done."
echo "  SQLite graph : ${DB_PATH}"
echo "  Source tree  : restored (probe file removed)"
echo "  Verified     : save -> scip-java -> stubborn index --merge -> list_symbols"
