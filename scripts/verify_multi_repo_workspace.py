"""Verify multi-repo workspace graph composition through public CLI commands."""

from __future__ import annotations

import subprocess
import sys
import os
import shlex
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "multi-repo" / "fixtures"
TARGET = "semanticdb maven com/example/app/Controller#handle()."
DEFAULT_STUBBORN_CMD = [sys.executable, "-c", "from stubborn.cli import app; app()"]


def stubborn_cmd() -> list[str]:
    override = os.environ.get("STUBBORN_CMD")
    return shlex.split(override) if override else DEFAULT_STUBBORN_CMD


def run(*args: str) -> str:
    completed = subprocess.run(
        list(args),
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return completed.stdout


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
        "--workspace",
        "acme",
        "--repo",
        "repo-a",
    )
    jar_only = run(
        *stubborn_cmd(),
        "context",
        str(jar_only_db),
        "--workspace",
        "acme",
        "--target",
        TARGET,
    )
    if "Service" not in jar_only:
        sys.exit("expected signature-level Service leaf in jar-only context")
    if "Helper" in jar_only:
        sys.exit("jar-only context unexpectedly expanded into Helper")

    workspace_db = metadata / "workspace.db"
    workspace_db.unlink(missing_ok=True)
    for repo_key, fixture in (("repo-a", "repo-a.json"), ("repo-b", "repo-b.json")):
        run(
            *stubborn_cmd(),
            "index",
            "--scip",
            str(FIXTURES / fixture),
            "--out",
            str(workspace_db),
            "--workspace",
            "acme",
            "--repo",
            repo_key,
        )

    composed = run(
        *stubborn_cmd(),
        "context",
        str(workspace_db),
        "--workspace",
        "acme",
        "--target",
        TARGET,
    )
    for expected in ("Controller", "Service", "Helper"):
        if expected not in composed:
            sys.exit(f"workspace context missing {expected}")

    print("multi-repo workspace validation passed")


if __name__ == "__main__":
    main()
