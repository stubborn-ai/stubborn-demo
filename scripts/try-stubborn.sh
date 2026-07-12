#!/usr/bin/env bash
# Thin demo entrypoint: pip install stubborn-stub, then run this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUBBORN_DEMO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKIP_STUBBORN_STATUS=1
# shellcheck source=/dev/null
source "${STUBBORN_DEMO_ROOT}/scripts/stubborn-preflight.sh"
stubborn_preflight "." || exit $?

exec stubborn try "$@"
