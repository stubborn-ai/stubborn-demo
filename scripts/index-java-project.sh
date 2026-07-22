#!/usr/bin/env bash
# Index a real Java/Maven or Gradle project: build (optional) -> scip-java -> stubborn index.
#
# Run from your project root, or pass the project path as the first argument.
# Does not modify core (ADR-015): orchestration lives in stubborn-demo only.
#
# Usage:
#   ./index-java-project.sh [PROJECT_ROOT] [--no-build] [--query NAME] [--db PATH]
#
# Requires: pip install "stubborn-stub[scip]"; JDK 21+ + scip-java for full index (or --no-build with existing index.scip)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/stubborn-preflight.sh"

usage() {
  cat <<'EOF'
Index a Java project for Stubborn (scip-java -> metadata/symbols.db).

Usage:
  index-java-project.sh [PROJECT_ROOT] [OPTIONS]

Options:
  --no-build       Skip mvn/gradle build; if index.scip exists, skip scip-java too
  --query NAME     list-symbols filter after index (default: list sample symbols)
  --db PATH        SQLite output (default: metadata/symbols.db under project root)
  -h, --help       Show this help

Examples:
  cd ~/my-spring-app && /path/to/stubborn-demo/scripts/index-java-project.sh
  index-java-project.sh ~/my-spring-app --query OrderService
  index-java-project.sh . --no-build              # reuse existing index.scip
  index-java-project.sh . --no-build --db /tmp/symbols.db

Install: pip install "stubborn-stub[scip]"
scip-java: https://github.com/sourcegraph/scip-java#installation (Coursier: cs install scip-java)
Docs:    https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/USER-JOURNEY.md#journey-c--real-java--spring-project
EOF
}

PROJECT_ROOT="."
NO_BUILD=0
QUERY=""
DB_REL="metadata/symbols.db"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --no-build)
      NO_BUILD=1
      shift
      ;;
    --query)
      QUERY="${2:?--query requires a value}"
      shift 2
      ;;
    --db)
      DB_REL="${2:?--db requires a value}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ "${PROJECT_ROOT}" == "." ]]; then
        PROJECT_ROOT="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

PROJECT_ROOT="$(cd "${PROJECT_ROOT}" && pwd)"
if [[ "${DB_REL}" = /* ]]; then
  DB_PATH="${DB_REL}"
else
  DB_PATH="${PROJECT_ROOT}/${DB_REL}"
fi

assert_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    exit 1
  fi
}

scip_java_install_hint() {
  cat <<'EOF' >&2
scip-java is not on PATH. Stubborn needs a SCIP index before it can build symbols.db.

Install scip-java (pick one):
  Coursier:  cs install scip-java
  Docs:      https://github.com/sourcegraph/scip-java#installation

No local JDK/Maven/scip-java? Use Docker from stubborn-demo:
  docker compose build && docker compose run --rm e2e

Already have index.scip in the project root? Re-run with --no-build to skip build + scip-java.
EOF
}

echo "== Stubborn: index Java project =="
echo "Project: ${PROJECT_ROOT}"
echo "Database: ${DB_PATH}"
echo

stubborn_preflight "${PROJECT_ROOT}" || exit $?

SCIP_PATH="${PROJECT_ROOT}/index.scip"
REUSE_SCIP=0
if [[ "${NO_BUILD}" -eq 1 && -f "${SCIP_PATH}" ]]; then
  REUSE_SCIP=1
fi

if [[ -f "${PROJECT_ROOT}/pom.xml" ]]; then
  BUILD_TOOL="maven"
elif [[ -f "${PROJECT_ROOT}/build.gradle" \
  || -f "${PROJECT_ROOT}/build.gradle.kts" \
  || -f "${PROJECT_ROOT}/settings.gradle" \
  || -f "${PROJECT_ROOT}/settings.gradle.kts" ]]; then
  BUILD_TOOL="gradle"
else
  echo "No pom.xml or Gradle build files in ${PROJECT_ROOT}" >&2
  echo "Expected: pom.xml (Maven) or build.gradle(.kts) / settings.gradle(.kts) (Gradle)." >&2
  echo "Stubborn Journey C expects a Maven or Gradle Java project." >&2
  exit 1
fi

cd "${PROJECT_ROOT}"

if [[ "${NO_BUILD}" -eq 0 ]]; then
  echo "[1/4] Build (${BUILD_TOOL})..."
  if [[ "${BUILD_TOOL}" == "maven" ]]; then
    assert_command mvn
    mvn -q -DskipTests package
  else
    if [[ -x "./gradlew" ]]; then
      ./gradlew --no-daemon -q classes
    elif command -v gradle >/dev/null 2>&1; then
      gradle -q classes
    else
      echo "Gradle project but no ./gradlew and no gradle on PATH." >&2
      echo "Build manually, then re-run with --no-build." >&2
      exit 1
    fi
  fi
else
  echo "[1/4] Build skipped (--no-build)."
fi

echo
if [[ "${REUSE_SCIP}" -eq 1 ]]; then
  echo "[2/4] scip-java skipped (--no-build, reusing ${SCIP_PATH})."
elif command -v scip-java >/dev/null 2>&1; then
  echo "[2/4] scip-java index..."
  rm -f index.scip
  if [[ "${BUILD_TOOL}" == "maven" ]]; then
    scip-java index --build-tool maven
  else
    scip-java index --build-tool gradle
  fi
else
  scip_java_install_hint
  exit 1
fi

if [[ ! -f index.scip ]]; then
  echo "index.scip was not created in ${PROJECT_ROOT}" >&2
  if [[ "${REUSE_SCIP}" -eq 0 ]]; then
    echo "Fix the build/scip-java step, or place index.scip here and re-run with --no-build." >&2
  fi
  exit 1
fi

echo
echo "[3/4] stubborn index..."
mkdir -p "$(dirname "${DB_PATH}")"
stubborn index --scip index.scip --out "${DB_PATH}"

echo
echo "[4/4] Summary..."
stubborn info "${DB_PATH}"
echo
stubborn doctor "${PROJECT_ROOT}" --db "${DB_PATH}" || true

echo
echo "== Symbols =="
if [[ -n "${QUERY}" ]]; then
  stubborn list-symbols "${DB_PATH}" --query "${QUERY}" | head -20
else
  echo "(pass --query YourClass to filter; showing first matches for 'Service' and 'Controller')"
  stubborn list-symbols "${DB_PATH}" --query Service | head -10 || true
  stubborn list-symbols "${DB_PATH}" --query Controller | head -10 || true
fi

echo
echo "== Next steps =="
echo "  1. Context — copy a stable_id from list-symbols above:"
echo "     stubborn context ${DB_PATH} --target \"<stable_id>\" --out context.stub.java"
echo "  2. Dev loop (save → scip-java → merge):"
echo "     pip install stubborn-watch"
echo "     stubborn-watch watch --root ${PROJECT_ROOT} --db ${DB_PATH}"
echo "  3. Cursor MCP (after index succeeds):"
echo "     pip install stubborn-mcp"
echo "     export STUBBORN_DB=${DB_PATH}"
echo "     # add stubborn-mcp to Cursor MCP config; see stubborn-mcp README"
echo "  4. Health check: stubborn doctor ${PROJECT_ROOT} --db ${DB_PATH}"
echo "  Journey: https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/USER-JOURNEY.md#journey-c--real-java--spring-project"
echo
echo "Done."
echo "  SCIP: ${SCIP_PATH}"
echo "  DB:   ${DB_PATH}"
