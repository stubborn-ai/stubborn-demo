#!/usr/bin/env python3
"""Verify Spring PetClinic Microservices workspace and contract bridge behavior."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from stubborn.api import get_context
from stubborn.store.reader import resolve_stable_id, workspace_run_summaries

REPO_ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_ROOT = REPO_ROOT / "spring-petclinic-microservices"
WORKSPACE = "petclinic-ms"
EXPECTED_REPOS = EXAMPLE_ROOT / "metadata" / "expected-workspace-symbols.txt"
EXPECTED_FORWARD = EXAMPLE_ROOT / "metadata" / "expected-visit-to-customer-types.txt"
EXPECTED_REVERSE = EXAMPLE_ROOT / "metadata" / "expected-owner-impact-types.txt"

FORWARD_TARGET = ("api-gateway", "CustomersServiceClient")
REVERSE_TARGET = ("customers-service", "OwnerResource")
BASELINE_FORBIDDEN = ("OwnerResource",)


def expected_lines(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]


def resolve(db_path: Path, repo_key: str, display_name: str) -> str:
    return resolve_stable_id(
        db_path,
        display_name=display_name,
        workspace=WORKSPACE,
        repo_key=repo_key,
    )


def context_text(db_path: Path, repo_key: str, display_name: str) -> tuple[str, str]:
    target = resolve(db_path, repo_key, display_name)
    result = get_context(
        target,
        db_path=db_path,
        workspace=WORKSPACE,
        call_depth=4,
        max_symbols=120,
        max_tokens=16_000,
    )
    return target, result.text


def assert_contains(text: str, required: list[str], label: str) -> None:
    missing = [name for name in required if name not in text]
    if missing:
        raise AssertionError(f"{label} missing expected names: {', '.join(missing)}")


def assert_absent(text: str, forbidden: tuple[str, ...], label: str) -> None:
    present = [name for name in forbidden if name in text]
    if present:
        raise AssertionError(f"{label} unexpectedly crossed HTTP boundary: {', '.join(present)}")


def verify_workspace(db_path: Path, *, expect_bridge: bool) -> None:
    summaries = workspace_run_summaries(db_path, workspace=WORKSPACE)
    repo_keys = {item.repo_key for item in summaries}
    required = set(expected_lines(EXPECTED_REPOS))
    missing = sorted(required - repo_keys)
    if missing:
        raise AssertionError(f"workspace missing repo summaries: {', '.join(missing)}")
    if expect_bridge and "petclinic-contracts" not in repo_keys:
        raise AssertionError("workspace missing petclinic-contracts bridge repo")
    if not expect_bridge and "petclinic-contracts" in repo_keys:
        raise AssertionError("baseline unexpectedly includes petclinic-contracts")

    print(f"workspace repos: {', '.join(sorted(repo_keys))}")
    print(f"workspace symbols: {sum(item.symbol_count for item in summaries)}")
    print(f"workspace edges: {sum(item.edge_count for item in summaries)}")


def verify_baseline(db_path: Path) -> None:
    verify_workspace(db_path, expect_bridge=False)
    target, text = context_text(db_path, *FORWARD_TARGET)
    assert_absent(text, BASELINE_FORBIDDEN, "baseline context")
    print(f"baseline target: {target}")
    print("baseline HTTP boundary check passed")


def verify_bridged(db_path: Path) -> None:
    verify_workspace(db_path, expect_bridge=True)

    forward_target, forward_text = context_text(db_path, *FORWARD_TARGET)
    assert_contains(forward_text, expected_lines(EXPECTED_FORWARD), "forward bridge context")
    print(f"forward target: {forward_target}")

    reverse_target, reverse_text = context_text(db_path, *REVERSE_TARGET)
    assert_contains(reverse_text, expected_lines(EXPECTED_REVERSE), "reverse bridge context")
    print(f"reverse target: {reverse_target}")
    print("contract bridge checks passed")


def emit_stubs(db_path: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    cases = [
        ("visit-to-customer.stub.java", FORWARD_TARGET),
        ("owner-impact-radius.stub.java", REVERSE_TARGET),
    ]
    for filename, target_spec in cases:
        target, text = context_text(db_path, *target_spec)
        output_path = output_dir / filename
        output_path.write_text(text, encoding="utf-8")
        print(f"wrote {output_path} for {target}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path, help="Workspace symbols.db")
    parser.add_argument(
        "--mode",
        required=True,
        choices=("baseline", "bridged", "emit-stubs"),
    )
    parser.add_argument("--stub-output", type=Path, default=EXAMPLE_ROOT / "stub-output")
    args = parser.parse_args()

    if not args.db.exists():
        print(f"Missing symbol graph: {args.db}", file=sys.stderr)
        return 1

    try:
        if args.mode == "baseline":
            verify_baseline(args.db)
        elif args.mode == "bridged":
            verify_bridged(args.db)
        else:
            emit_stubs(args.db, args.stub_output)
    except Exception as exc:
        print(f"verification failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
