#!/usr/bin/env bash
# End-to-end: spring-petclinic-microservices -> per-service SCIP -> workspace DB.
set -euo pipefail

PETCLINIC_MS_ROOT="${PETCLINIC_MS_ROOT:-/petclinic-ms}"
EXAMPLE_ROOT="${EXAMPLE_ROOT:-/opt/stubborn-demo/spring-petclinic-microservices}"
PIN_FILE="${EXAMPLE_ROOT}/upstream.pin"
METADATA_DIR="${EXAMPLE_ROOT}/metadata"
INDEXES_DIR="${METADATA_DIR}/indexes"
STUB_OUTPUT_DIR="${EXAMPLE_ROOT}/stub-output"
DB_PATH="${METADATA_DIR}/petclinic-workspace.db"
WORKSPACE="petclinic-ms"

SERVICES=(
  "api-gateway:spring-petclinic-api-gateway:api-gateway.scip"
  "customers-service:spring-petclinic-customers-service:customers-service.scip"
  "vets-service:spring-petclinic-vets-service:vets-service.scip"
  "visits-service:spring-petclinic-visits-service:visits-service.scip"
)

repo="$(grep '^repo=' "${PIN_FILE}" | cut -d= -f2- | tr -d '\r')"
commit="$(grep '^commit=' "${PIN_FILE}" | cut -d= -f2- | tr -d '\r')"

echo "== spring-petclinic-microservices workspace E2E (Docker) =="
echo "Pin: ${commit}"

if [ ! -d "${PETCLINIC_MS_ROOT}/.git" ]; then
    echo
    echo "[0/8] Clone upstream spring-petclinic-microservices..."
    git clone --filter=blob:none --no-checkout "${repo}" "${PETCLINIC_MS_ROOT}"
    git -C "${PETCLINIC_MS_ROOT}" checkout "${commit}"
else
    echo
    echo "[0/8] Upstream already cloned at ${PETCLINIC_MS_ROOT}"
    git -C "${PETCLINIC_MS_ROOT}" checkout "${commit}"
fi

echo
echo "[1/8] Maven compile..."
(
  cd "${PETCLINIC_MS_ROOT}"
  mvn -q -DskipTests package
)

mkdir -p "${METADATA_DIR}" "${INDEXES_DIR}" "${STUB_OUTPUT_DIR}"
rm -f "${DB_PATH}"

echo
echo "[2/8] Per-service scip-java indexes..."
for item in "${SERVICES[@]}"; do
    IFS=: read -r repo_key service_path index_name <<<"${item}"
    service_root="${PETCLINIC_MS_ROOT}/${service_path}"
    service_index="${service_root}/index.scip"
    target_index="${INDEXES_DIR}/${index_name}"
    rm -f "${service_index}"
    (
      cd "${service_root}"
      scip-java index --build-tool maven
    )
    mv -f "${service_index}" "${target_index}"
done

echo
echo "[3/8] Stubborn workspace indexes..."
for item in "${SERVICES[@]}"; do
    IFS=: read -r repo_key service_path index_name <<<"${item}"
    index_path="${INDEXES_DIR}/${index_name}"
    service_root="${PETCLINIC_MS_ROOT}/${service_path}"
    stubborn index \
        --scip "${index_path}" \
        --out "${DB_PATH}" \
        --workspace "${WORKSPACE}" \
        --repo "${repo_key}" \
        --project-root "${service_root}"
done

echo
echo "[4/8] Baseline workspace verification..."
stubborn info "${DB_PATH}" --workspace "${WORKSPACE}"
python3 /opt/stubborn-demo/scripts/verify_petclinic_ms_workspace.py \
    --db "${DB_PATH}" \
    --mode baseline

echo
echo "[5/7] Write HTTP contract evidence..."
stubborn index-contract \
    --out "${DB_PATH}" \
    --manifest "${EXAMPLE_ROOT}/contracts/http.yml"

echo
echo "[6/7] Cross-service context verification..."
python3 /opt/stubborn-demo/scripts/verify_petclinic_ms_workspace.py \
    --db "${DB_PATH}" \
    --mode bridged

echo
echo "[7/7] Emit sample sidecar stubs..."
python3 /opt/stubborn-demo/scripts/verify_petclinic_ms_workspace.py \
    --db "${DB_PATH}" \
    --mode emit-stubs \
    --stub-output "${STUB_OUTPUT_DIR}"

echo
echo "Done."
echo "  Upstream    : ${PETCLINIC_MS_ROOT} @ ${commit}"
echo "  SQLite graph: ${DB_PATH}"
echo "  Contract    : ${EXAMPLE_ROOT}/contracts/http.yml -> v4 contract tables"
echo "  Stubs       : ${STUB_OUTPUT_DIR}"
