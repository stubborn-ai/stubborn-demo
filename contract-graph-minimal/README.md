# Contract graph — minimal mixed workspace

Canonical **smallest** proof that Stubborn composes **code SCIP facts**, **OpenAPI
endpoint facts**, and **declared HTTP bindings** in one workspace database.

No Java, Maven, or scip-java required — JSON fixtures stand in for SCIP indexes.

Playbook: [CONTRACT-GRAPH-PLAYBOOK.md](https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/CONTRACT-GRAPH-PLAYBOOK.md).

## What this proves

| Layer | Input | Command |
|-------|-------|---------|
| Code (2 services) | `fixtures/*.json` | `stubborn index --workspace contract-minimal --repo …` |
| OpenAPI endpoints | `contracts/openapi.yml` | `stubborn index-openapi --service customers-service …` |
| Declared bindings | `contracts/bindings.json` | `stubborn index-contract` |
| Query | same `metadata/workspace.db` | `list-contracts`, `context` on endpoint + provider |

## Quick start

```bash
pip install "stubborn-stub[openapi]"
cd contract-graph-minimal
./scripts/run-e2e.sh
```

From `stubborn-demo` root:

```bash
python3 scripts/verify_contract_graph_minimal.py
```

Docker (from `stubborn-demo` root):

```bash
docker compose build toolchain
docker compose run --rm contract-graph-e2e
```

## Artifacts

Generated and gitignored:

- `metadata/workspace.db`

## Scale-up reference

For real Java microservices and MCP smoke, see
[`spring-petclinic-microservices`](../spring-petclinic-microservices/) and
[PETCLINIC-VALIDATION.md](https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/PETCLINIC-VALIDATION.md).
