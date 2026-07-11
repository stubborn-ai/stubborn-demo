#!/usr/bin/env bash
# Thin demo entrypoint: pip install stubborn-stub, then run this script.
set -euo pipefail

if ! command -v stubborn >/dev/null 2>&1; then
  echo "Required command not found on PATH: stubborn" >&2
  echo "Install: pip install stubborn-stub" >&2
  exit 1
fi

exec stubborn try "$@"
