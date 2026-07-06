"""Black-box verifier for multi-repo graph composition via the stubborn CLI.

Fixture merge rules and expected symbol names live in ``multi_repo_workspace.py``.
Unit tests in ``tests/test_multi_repo_workspace.py`` lock the merge behavior; this
script exercises the installed ``stubborn`` CLI end to end.
"""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

from multi_repo_workspace import (
    COMPOSED_FORWARD_EXPECTED,
    COMPOSED_REVERSE_EXPECTED,
    JAR_ONLY_FORBIDDEN,
    JAR_ONLY_EXPECTED,
    SERVICE_TARGET,
    TARGET,
    build_combined_fixture,
)

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "multi-repo" / "fixtures"
DEFAULT_STUBBORN_CMD = ["stubborn"]


def stubborn_cmd() -> list[str]:
    override = os.environ.get("STUBBORN_CMD")
    return shlex.split(override) if override else DEFAULT_STUBBORN_CMD


def run(*args: str) -> str:
    try:
        completed = subprocess.run(
            list(args),
            cwd=ROOT,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        return completed.stdout
    except subprocess.CalledProcessError as exc:
        output = exc.stdout or ""
        cmd = " ".join(args)
        raise SystemExit(f"command failed ({cmd}):\n{output}") from exc


def _assert_symbols_present(output: str, expected: tuple[str, ...], label: str) -> None:
    missing = [name for name in expected if name not in output]
    if missing:
        sys.exit(f"{label} missing {', '.join(missing)}")


def main() -> None:
    metadata = ROOT / "multi-repo" / "metadata"
    metadata.mkdir(parents=True, exist_ok=True)

    jar_only_db = metadata / "jar-only.db"
    jar_only_db.unlink(missing_ok=True)
    run(
        *stubborn_cmd(),
        "index",
        "--scip",
        str(FIXTURES / "repo-a.json"),
        "--out",
        str(jar_only_db),
    )
    jar_only = run(
        *stubborn_cmd(),
        "context",
        str(jar_only_db),
        "--target",
        TARGET,
    )
    _assert_symbols_present(jar_only, JAR_ONLY_EXPECTED, "jar-only context")
    for forbidden in JAR_ONLY_FORBIDDEN:
        if forbidden in jar_only:
            sys.exit(f"jar-only context unexpectedly expanded into {forbidden}")

    workspace_db = metadata / "workspace.db"
    workspace_db.unlink(missing_ok=True)
    combined_fixture = metadata / "combined-fixtures.json"
    with (FIXTURES / "repo-a.json").open(encoding="utf-8") as repo_a_file:
        repo_a = json.load(repo_a_file)
    with (FIXTURES / "repo-b.json").open(encoding="utf-8") as repo_b_file:
        repo_b = json.load(repo_b_file)
    combined_fixture.write_text(
        json.dumps(build_combined_fixture(repo_a, repo_b), indent=2),
        encoding="utf-8",
    )

    run(
        *stubborn_cmd(),
        "index",
        "--scip",
        str(combined_fixture),
        "--out",
        str(workspace_db),
    )

    composed = run(
        *stubborn_cmd(),
        "context",
        str(workspace_db),
        "--target",
        TARGET,
    )
    _assert_symbols_present(composed, COMPOSED_FORWARD_EXPECTED, "workspace context")

    reverse_context = run(
        *stubborn_cmd(),
        "context",
        str(workspace_db),
        "--target",
        SERVICE_TARGET,
    )
    _assert_symbols_present(reverse_context, COMPOSED_REVERSE_EXPECTED, "reverse context")

    print("multi-repo workspace validation passed")


if __name__ == "__main__":
    main()
