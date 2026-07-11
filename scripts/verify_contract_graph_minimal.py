"""Black-box verifier for minimal code + OpenAPI + manifest contract workspace."""

from __future__ import annotations

import os
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEMO_ROOT = ROOT / "contract-graph-minimal"
FIXTURES = DEMO_ROOT / "fixtures"
CONTRACTS = DEMO_ROOT / "contracts"
WORKSPACE = "contract-minimal"
ENDPOINT = "openapi customers-service:v1 GET /owners/{ownerId}"
PROVIDER_CLASS = "semanticdb maven com/example/customers/OwnerResource#"
CONSUMER_CLASS = "semanticdb maven com/example/visits/CustomersClient#"
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
    metadata = DEMO_ROOT / "metadata"
    metadata.mkdir(parents=True, exist_ok=True)
    db = metadata / "workspace.db"
    db.unlink(missing_ok=True)

    cmd = stubborn_cmd()
    run(
        *cmd,
        "index",
        "--scip",
        str(FIXTURES / "customers-service.json"),
        "--out",
        str(db),
        "--workspace",
        WORKSPACE,
        "--repo",
        "customers-service",
    )
    run(
        *cmd,
        "index",
        "--scip",
        str(FIXTURES / "visits-service.json"),
        "--out",
        str(db),
        "--workspace",
        WORKSPACE,
        "--repo",
        "visits-service",
    )
    run(
        *cmd,
        "index-openapi",
        "--openapi",
        str(CONTRACTS / "openapi.yml"),
        "--service",
        "customers-service",
        "--version",
        "v1",
        "--workspace",
        WORKSPACE,
        "--out",
        str(db),
    )
    run(
        *cmd,
        "index-contract",
        "--manifest",
        str(CONTRACTS / "bindings.json"),
        "--out",
        str(db),
        "--workspace",
        WORKSPACE,
    )

    listed = run(
        *cmd,
        "list-contracts",
        str(db),
        "--workspace",
        WORKSPACE,
        "--query",
        "owners",
    )
    if ENDPOINT not in listed:
        sys.exit(f"list-contracts missing endpoint:\n{listed}")

    endpoint_context = run(
        *cmd,
        "context",
        str(db),
        "--workspace",
        WORKSPACE,
        "--target",
        ENDPOINT,
        "--format",
        "stubborn-dsl",
    )
    for needle in ("contracts:", ENDPOINT, "schema path.ownerId"):
        if needle not in endpoint_context:
            sys.exit(f"endpoint context missing {needle!r}")

    provider_context = run(
        *cmd,
        "context",
        str(db),
        "--workspace",
        WORKSPACE,
        "--target",
        PROVIDER_CLASS,
        "--format",
        "stubborn-dsl",
        "--call-depth",
        "1",
    )
    for needle in ("contracts:", ENDPOINT, CONSUMER_CLASS.split("/")[-1].replace("#", "")):
        if needle not in provider_context:
            sys.exit(f"provider context missing {needle!r}")

    info = run(*cmd, "info", str(db), "--workspace", WORKSPACE)
    for needle in ("Code repos:", "Contract sources:", "Contract endpoints:"):
        if needle not in info:
            sys.exit(f"workspace info missing {needle!r}")

    print("contract-graph-minimal validation passed")


if __name__ == "__main__":
    main()
