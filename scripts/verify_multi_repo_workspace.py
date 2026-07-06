"""Verify multi-repo workspace graph composition through CLI and graph API."""

from __future__ import annotations

import subprocess
import os
import shlex
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "multi-repo" / "fixtures"
TARGET = "semanticdb maven com/example/app/Controller#handle()."
SERVICE_TARGET = "semanticdb maven com/example/lib/Service#"
DEFAULT_STUBBORN_CMD = ["stubborn"]


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


def graph_names(db_path: Path, target: str) -> set[str]:
    script = """
from stubborn.config import ContextBudget
from stubborn.graph.prune import prune_context
import sys

graph = prune_context(
    sys.argv[1],
    sys.argv[2],
    workspace="acme",
    budget=ContextBudget(call_closure_depth=2, max_symbols=20),
)
for symbol in graph.symbols:
    if symbol.display_name:
        print(symbol.display_name)
"""
    output = run(sys.executable, "-c", script, str(db_path), target)
    return {line.strip() for line in output.splitlines() if line.strip()}


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

    reverse_names = graph_names(workspace_db, SERVICE_TARGET)
    for expected in ("handle", "Service", "Helper"):
        if expected not in reverse_names:
            sys.exit(f"reverse workspace context missing {expected}")

    print("multi-repo workspace validation passed")


if __name__ == "__main__":
    main()
