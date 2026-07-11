"""Unit tests for contract-graph-minimal verifier constants."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


def _load_verifier_module():
    path = Path(__file__).resolve().parents[1] / "scripts" / "verify_contract_graph_minimal.py"
    spec = importlib.util.spec_from_file_location("verify_contract_graph_minimal", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ContractGraphMinimalTests(unittest.TestCase):
    def test_assets_exist(self) -> None:
        module = _load_verifier_module()
        root = module.DEMO_ROOT
        self.assertTrue((root / "fixtures" / "customers-service.json").is_file())
        self.assertTrue((root / "fixtures" / "visits-service.json").is_file())
        self.assertTrue((root / "contracts" / "openapi.yml").is_file())
        self.assertTrue((root / "contracts" / "bindings.json").is_file())

    def test_workspace_and_endpoint_constants(self) -> None:
        module = _load_verifier_module()
        self.assertEqual(module.WORKSPACE, "contract-minimal")
        self.assertTrue(module.ENDPOINT.startswith("openapi customers-service:v1 GET "))


if __name__ == "__main__":
    unittest.main()
