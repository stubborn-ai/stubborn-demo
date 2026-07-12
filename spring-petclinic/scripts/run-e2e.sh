#!/usr/bin/env bash
# End-to-end: spring-petclinic (clone upstream + index + context).
set -euo pipefail

EXAMPLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${EXAMPLE_ROOT}/../.." && pwd)"
UPSTREAM_ROOT="${EXAMPLE_ROOT}/upstream"
PIN_FILE="${EXAMPLE_ROOT}/upstream.pin"

read_pin_value() {
  local key="$1"
  local line
  line="$(grep "^${key}=" "${PIN_FILE}" | head -n 1 || true)"
  if [[ -z "${line}" ]]; then
    echo "Missing ${key} in upstream.pin" >&2
    exit 1
  fi
  printf '%s\n' "${line#*=}" | tr -d '\r'
}

assert_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    exit 1
  fi
}

repo="$(read_pin_value repo)"
commit="$(read_pin_value commit)"

echo "== spring-petclinic E2E =="
echo "Pin: ${commit}"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/stubborn-preflight.sh"
stubborn_preflight "${EXAMPLE_ROOT}" || exit $?

assert_command git
assert_command mvn
assert_command scip-java
assert_command python3

if [[ ! -d "${UPSTREAM_ROOT}/.git" ]]; then
  echo
  echo "[0/6] Clone upstream..."
  git clone --filter=blob:none --no-checkout "${repo}" "${UPSTREAM_ROOT}"
  git -C "${UPSTREAM_ROOT}" checkout "${commit}"
else
  echo
  echo "[0/6] Use existing upstream at ${UPSTREAM_ROOT}"
  git -C "${UPSTREAM_ROOT}" checkout "${commit}"
fi

cd "${UPSTREAM_ROOT}"

echo
echo "[1/6] Maven compile..."
mvn -q -DskipTests package

echo
echo "[2/6] scip-java index..."
rm -f index.scip
scip-java index --build-tool maven

echo
echo "[3/6] stubborn index..."
metadata_dir="${EXAMPLE_ROOT}/metadata"
mkdir -p "${metadata_dir}"
db_path="${metadata_dir}/symbols.db"
rm -f "${db_path}"
stubborn index --scip index.scip --out "${db_path}"

echo
echo "[4/6] index summary..."
stubborn info "${db_path}"

echo
echo "[5/6] VetController context..."
target="$(python3 "${REPO_ROOT}/scripts/resolve_symbol.py" "${db_path}" --display-name VetController)"
stub_path="${metadata_dir}/vet-controller.stub.java"
stubborn context "${db_path}" --target "${target}" --out "${stub_path}"

echo
echo "[6/6] metrics + verify..."
stubborn metrics "${db_path}" --target "${target}" --sources src/main/java
python3 "${REPO_ROOT}/scripts/verify_petclinic_context.py" \
  --java-root "${UPSTREAM_ROOT}/src/main/java"

echo
echo "Done."
echo "  Upstream : ${UPSTREAM_ROOT} @ ${commit}"
echo "  SQLite   : ${db_path}"
echo "  Stub     : ${stub_path}"
