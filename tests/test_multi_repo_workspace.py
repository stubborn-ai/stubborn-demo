"""Unit tests for multi-repo fixture merge behavior."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from multi_repo_workspace import (  # noqa: E402
    COMPOSED_FORWARD_EXPECTED,
    COMPOSED_REVERSE_EXPECTED,
    JAR_ONLY_FORBIDDEN,
    JAR_ONLY_EXPECTED,
    SERVICE_TARGET,
    TARGET,
    build_combined_fixture,
)

FIXTURES = ROOT / "multi-repo" / "fixtures"


class BuildCombinedFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_a = json.loads((FIXTURES / "repo-a.json").read_text(encoding="utf-8"))
        cls.repo_b = json.loads((FIXTURES / "repo-b.json").read_text(encoding="utf-8"))
        cls.combined = build_combined_fixture(cls.repo_a, cls.repo_b)

    def _symbol_names(self, snapshot: dict) -> set[str]:
        return {
            symbol["display_name"]
            for doc in snapshot.get("documents", [])
            for symbol in doc.get("symbols", [])
        }

    def _stable_ids(self, snapshot: dict) -> list[str]:
        return [
            symbol["stable_id"]
            for doc in snapshot.get("documents", [])
            for symbol in doc.get("symbols", [])
        ]

    def test_target_constants_match_fixtures(self) -> None:
        repo_a_ids = self._stable_ids(self.repo_a)
        repo_b_ids = self._stable_ids(self.repo_b)
        self.assertIn(TARGET, repo_a_ids)
        self.assertIn(SERVICE_TARGET, repo_a_ids)
        self.assertIn(SERVICE_TARGET, repo_b_ids)

    def test_removes_signature_level_service_stub(self) -> None:
        service_symbols = [
            symbol
            for doc in self.combined["documents"]
            for symbol in doc["symbols"]
            if symbol["stable_id"] == SERVICE_TARGET
        ]
        self.assertEqual(len(service_symbols), 1)
        self.assertNotIn("relative_path", service_symbols[0])

    def test_includes_cross_repo_symbol_names(self) -> None:
        names = self._symbol_names(self.combined)
        for expected in COMPOSED_FORWARD_EXPECTED:
            self.assertIn(expected, names)

    def test_preserves_controller_to_service_edge(self) -> None:
        edges = {
            (edge["from"], edge["to"])
            for doc in self.combined["documents"]
            for edge in doc.get("edges", [])
        }
        self.assertIn(
            (
                TARGET,
                SERVICE_TARGET,
            ),
            edges,
        )

    def test_preserves_service_to_helper_edge(self) -> None:
        edges = {
            (edge["from"], edge["to"])
            for doc in self.combined["documents"]
            for edge in doc.get("edges", [])
        }
        self.assertIn(
            (
                SERVICE_TARGET,
                "semanticdb maven com/example/lib/Helper#",
            ),
            edges,
        )

    def test_expectation_constants_document_verifier_contract(self) -> None:
        self.assertEqual(JAR_ONLY_EXPECTED, ("Service",))
        self.assertEqual(JAR_ONLY_FORBIDDEN, ("Helper",))
        self.assertEqual(COMPOSED_FORWARD_EXPECTED, ("Controller", "Service", "Helper"))
        self.assertEqual(COMPOSED_REVERSE_EXPECTED, ("Service", "Helper"))


if __name__ == "__main__":
    unittest.main()
