#!/usr/bin/env python3
"""Generate a synthetic Stubborn contract graph for PetClinic microservices."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Any

from stubborn.store.reader import latest_index_run_ids, resolve_stable_id


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


def endpoint_symbol(workspace: str, endpoint: dict[str, Any]) -> dict[str, Any]:
    method = endpoint["method"].upper()
    service = endpoint["service"]
    path = endpoint["path"]
    stable_id = f"stubborn http {workspace}/{service} {method} {path}"
    return {
        "stable_id": stable_id,
        "display_name": endpoint.get("display_name") or f"{method} {path}",
        "kind": "interface",
        "signature": f"{method} http://{service}{path}",
        "documentation": "Synthetic HTTP contract endpoint for PetClinic microservices.",
    }


def build_bridge(db_path: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    workspace = manifest["workspace"]
    symbols_by_id: dict[str, dict[str, Any]] = {}
    edges: list[dict[str, str]] = []

    for endpoint in manifest.get("endpoints", []):
        endpoint_record = endpoint_symbol(workspace, endpoint)
        endpoint_id = endpoint_record["stable_id"]
        symbols_by_id[endpoint_id] = endpoint_record

        for consumer in endpoint.get("consumers", []):
            consumer_record = symbol_details(
                db_path,
                workspace=workspace,
                repo_key=consumer["repo"],
                display_name=consumer["display_name"],
                prefer_type=bool(consumer.get("prefer_type", True)),
            )
            symbols_by_id[consumer_record["stable_id"]] = consumer_record
            edges.append(
                {
                    "from": consumer_record["stable_id"],
                    "to": endpoint_id,
                    "edge_kind": "reference",
                }
            )

        for provider in endpoint.get("providers", []):
            provider_record = symbol_details(
                db_path,
                workspace=workspace,
                repo_key=provider["repo"],
                display_name=provider["display_name"],
                prefer_type=bool(provider.get("prefer_type", True)),
            )
            symbols_by_id[provider_record["stable_id"]] = provider_record
            edges.append(
                {
                    "from": endpoint_id,
                    "to": provider_record["stable_id"],
                    "edge_kind": "reference",
                }
            )

    return {
        "language": "java",
        "project_root": manifest.get("bridge_repo", "petclinic-contracts"),
        "documents": [
            {
                "relative_path": "contracts/http.yml",
                "symbols": sorted(symbols_by_id.values(), key=lambda item: item["stable_id"]),
                "edges": sorted(edges, key=lambda item: (item["from"], item["to"], item["edge_kind"])),
            }
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path, help="Workspace symbols.db")
    parser.add_argument("--manifest", required=True, type=Path, help="Contract manifest")
    parser.add_argument("--out", required=True, type=Path, help="Output JSON fixture")
    args = parser.parse_args()

    bridge = build_bridge(args.db, load_manifest(args.manifest))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(bridge, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {args.out} ({len(bridge['documents'][0]['symbols'])} symbols, {len(bridge['documents'][0]['edges'])} edges)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
