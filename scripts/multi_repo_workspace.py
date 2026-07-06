"""Helpers for the multi-repo workspace black-box verifier."""

from __future__ import annotations

from typing import Any

TARGET = "semanticdb maven com/example/app/Controller#handle()."
SERVICE_TARGET = "semanticdb maven com/example/lib/Service#"

JAR_ONLY_EXPECTED = ("Service",)
JAR_ONLY_FORBIDDEN = ("Helper",)
COMPOSED_FORWARD_EXPECTED = ("Controller", "Service", "Helper")
COMPOSED_REVERSE_EXPECTED = ("Service", "Helper")


def build_combined_fixture(repo_a: dict[str, Any], repo_b: dict[str, Any]) -> dict[str, Any]:
    """Merge per-repo JSON fixtures into one indexable SCIP snapshot.

    ``repo-a`` models a consumer repo that references ``Service#`` as a
    signature-level external stub (``relative_path`` is null). ``repo-b`` models
    the provider repo that owns the real ``Service#`` source plus ``Helper#``.

    The verifier indexes this combined snapshot in one ``stubborn index`` run
    because the published CLI does not accept per-repo ``--workspace`` /
    ``--repo`` flags. When both sides define the same ``stable_id``, keep the
    provider copy from ``repo-b`` and drop the jar-only stub from ``repo-a`` so
    the SQLite graph does not hit ``stable_id`` uniqueness errors.
    """
    repo_b_symbol_ids = {
        symbol["stable_id"]
        for doc in repo_b.get("documents", [])
        for symbol in doc.get("symbols", [])
    }
    combined_documents: list[dict[str, Any]] = []
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

    return {
        "language": "java",
        "project_root": "multi-repo",
        "documents": combined_documents,
    }
