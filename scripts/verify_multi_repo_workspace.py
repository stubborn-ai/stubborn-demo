"""Verify multi-repo workspace graph composition through CLI and graph API."""

from __future__ import annotations

import json
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
    if "Service" not in jar_only:
        sys.exit("expected signature-level Service leaf in jar-only context")
    if "Helper" in jar_only:
        sys.exit("jar-only context unexpectedly expanded into Helper")

    workspace_db = metadata / "workspace.db"
    workspace_db.unlink(missing_ok=True)
    combined_fixture = metadata / "combined-fixtures.json"
    with (FIXTURES / "repo-a.json").open(encoding="utf-8") as f:
        repo_a = json.load(f)
    with (FIXTURES / "repo-b.json").open(encoding="utf-8") as f:
        repo_b = json.load(f)

    repo_b_symbol_ids = {
        symbol["stable_id"]
        for doc in repo_b.get("documents", [])
        for symbol in doc.get("symbols", [])
    }
    combined_documents = []
    for doc in repo_a.get("documents", []):
        symbols = [
            symbol
            for symbol in doc.get("symbols", [])
            if not (
                symbol.get("stable_id") in repo_b_symbol_ids
                and symbol.get("relative_path") is None
            )
        ]
        combined_doc = dict(doc)
        combined_doc["symbols"] = symbols
        combined_documents.append(combined_doc)
    combined_documents.extend(repo_b.get("documents", []))

    combined = {
        "language": "java",
        "project_root": "multi-repo",
        "documents": combined_documents,
    }
    combined_fixture.write_text(json.dumps(combined, indent=2), encoding="utf-8")

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
    for expected in ("Controller", "Service", "Helper"):
        if expected not in composed:
            sys.exit(f"workspace context missing {expected}")

    reverse_context = run(
        *stubborn_cmd(),
        "context",
        str(workspace_db),
        "--target",
        SERVICE_TARGET,
    )
    for expected in ("Service", "Helper"):
        if expected not in reverse_context:
            sys.exit(f"reverse context missing {expected}")

    print("multi-repo workspace validation passed")


if __name__ == "__main__":
    main()
