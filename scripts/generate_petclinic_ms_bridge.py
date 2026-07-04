#!/usr/bin/env python3
"""Write PetClinic microservice contract evidence into a Stubborn v4 workspace DB."""

from __future__ import annotations

import argparse
import json
import sqlite3
import re
from pathlib import Path
from typing import Any

from stubborn.store.reader import latest_index_run_ids, resolve_stable_id
from stubborn.store.writer import (
    ContractBindingRecord,
    ContractEndpointRecord,
    ContractSchemaConstraintRecord,
    ContractSnapshot,
    IndexWriter,
)

_PATH_PARAM_RE = re.compile(r"\{([^}/]+)\}")


def load_manifest(path: Path) -> dict[str, Any]:
    """Load JSON-compatible YAML without adding a PyYAML dependency."""
    return json.loads(path.read_text(encoding="utf-8"))


def symbol_details(
    db_path: Path,
    *,
    workspace: str,
    repo_key: str,
    display_name: str,
    prefer_type: bool,
) -> dict[str, Any]:
    stable_id = resolve_stable_id(
        db_path,
        display_name=display_name,
        prefer_type=prefer_type,
        workspace=workspace,
        repo_key=repo_key,
    )

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        run_id = latest_index_run_ids(conn, workspace=workspace, repo_key=repo_key)[0]
        row = conn.execute(
            """
            SELECT stable_id, display_name, kind, signature, documentation
            FROM scip_symbol
            WHERE index_run_id = ? AND stable_id = ?
            """,
            (run_id, stable_id),
        ).fetchone()
    finally:
        conn.close()

    if row is None:
        raise ValueError(f"Resolved symbol vanished: {repo_key}:{display_name} -> {stable_id}")

    return {
        "stable_id": row["stable_id"],
        "display_name": row["display_name"],
        "kind": row["kind"],
        "signature": row["signature"],
        "documentation": row["documentation"],
        "relative_path": None,
    }


def endpoint_stable_id(endpoint: dict[str, Any]) -> str:
    method = endpoint["method"].upper()
    service = endpoint["service"]
    version = endpoint.get("version", "v1")
    path = endpoint["path"]
    return f"openapi {service}:{version} {method} {path}"


def path_constraints(path: str) -> tuple[ContractSchemaConstraintRecord, ...]:
    return tuple(
        ContractSchemaConstraintRecord(
            location="path",
            field_path=match.group(1),
            required=True,
        )
        for match in _PATH_PARAM_RE.finditer(path)
    )


def build_contract_snapshot(db_path: Path, manifest: dict[str, Any]) -> ContractSnapshot:
    workspace = manifest["workspace"]
    endpoints: list[ContractEndpointRecord] = []

    for endpoint in manifest.get("endpoints", []):
        bindings: list[ContractBindingRecord] = []

        for consumer in endpoint.get("consumers", []):
            consumer_record = symbol_details(
                db_path,
                workspace=workspace,
                repo_key=consumer["repo"],
                display_name=consumer["display_name"],
                prefer_type=bool(consumer.get("prefer_type", True)),
            )
            bindings.append(
                ContractBindingRecord(
                    code_stable_id=consumer_record["stable_id"],
                    role="consumer",
                    evidence="declared",
                    source="manual:contracts/http.yml",
                )
            )

        for provider in endpoint.get("providers", []):
            provider_record = symbol_details(
                db_path,
                workspace=workspace,
                repo_key=provider["repo"],
                display_name=provider["display_name"],
                prefer_type=bool(provider.get("prefer_type", True)),
            )
            bindings.append(
                ContractBindingRecord(
                    code_stable_id=provider_record["stable_id"],
                    role="provider",
                    evidence="declared",
                    source="manual:contracts/http.yml",
                )
            )

        method = endpoint["method"].upper()
        version = endpoint.get("version", "v1")
        path = endpoint["path"]
        endpoints.append(
            ContractEndpointRecord(
                stable_id=endpoint_stable_id(endpoint),
                protocol="http",
                service=endpoint["service"],
                version=version,
                method_or_verb=method,
                address=path,
                display_name=endpoint.get("display_name") or f"{method} {path}",
                schema_constraints=path_constraints(path),
                bindings=tuple(bindings),
            )
        )

    return ContractSnapshot(
        scip_source="contracts/http.yml",
        project_root=manifest.get("bridge_repo", "petclinic-contracts"),
        language="openapi",
        endpoints=tuple(endpoints),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path, help="Workspace symbols.db")
    parser.add_argument("--manifest", required=True, type=Path, help="Contract manifest")
    args = parser.parse_args()

    manifest = load_manifest(args.manifest)
    snapshot = build_contract_snapshot(args.db, manifest)
    run_id = IndexWriter(args.db).write_contract(
        snapshot,
        workspace=manifest["workspace"],
        repo_key=manifest.get("bridge_repo", "petclinic-contracts"),
    )
    binding_count = sum(len(endpoint.bindings) for endpoint in snapshot.endpoints)
    print(
        "wrote contract evidence "
        f"(index_run_id={run_id}, endpoints={len(snapshot.endpoints)}, bindings={binding_count})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
