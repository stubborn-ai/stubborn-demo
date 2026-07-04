# Spring PetClinic Microservices — workspace E2E

Official [spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) indexed as a Stubborn workspace. This demo validates the jump from a single Spring app to a multi-service graph.

Tier policy matches the rest of the program: Docker is the canonical cross-platform path, WSL/bash is the fast local path, and PowerShell is a thin fallback only.

The upstream project is one Git repository with multiple service directories. Stubborn treats each service directory as a separate workspace repo:

- `api-gateway`
- `customers-service`
- `vets-service`
- `visits-service`

Supporting services such as config server, discovery server, genAI, tracing, admin, Grafana, and Prometheus are intentionally skipped for the first graph validation pass.

## What This Proves

Stage 1 proves that Stubborn can compose independently indexed service directories into one workspace latest view.

Stage 2 proves that explicit HTTP contract facts can bridge service boundaries without pretending SCIP alone understands microservice routing. The demo uses `stubborn index-contract` to write [`contracts/http.yml`](contracts/http.yml) into Stubborn schema v4 contract tables as `declared` evidence, and can browse the resulting `openapi ...` endpoint stable IDs with `stubborn list-contracts`.

## Quick Start

Docker path from repo root:

```bash
docker compose build toolchain
docker compose run --rm petclinic-ms-e2e
```

Host path:

```bash
cd spring-petclinic-microservices
./scripts/run-e2e.sh
```

Host runs require JDK 21+, Maven, `scip-java`, Python, and `stubborn` on `PATH`.

## MCP Smoke Test

After `./scripts/run-e2e.sh`, run `./scripts/mcp-smoke.sh` to verify the MCP surface against the real `petclinic-ms` workspace DB. The smoke check exercises `workspace_info`, `list_contracts`, and `get_context` on both the `CustomersServiceClient` consumer path and the `OwnerResource` provider path.

## Generated Artifacts

These are gitignored:

- `upstream/`
- `metadata/petclinic-workspace.db`
- `metadata/indexes/*.scip`
- `stub-output/*.stub.java`

## Cases

| Case | Target | Doc |
|------|--------|-----|
| visit-to-customer | `openapi customers-service:v1 GET /owners/{ownerId}` endpoint / `CustomersServiceClient` consumer | [cases/visit-to-customer-context.md](cases/visit-to-customer-context.md) |
| owner-impact-radius | `openapi customers-service:v1 GET /owners/{ownerId}` reverse traversal | [cases/owner-id-impact-radius.md](cases/owner-id-impact-radius.md) |

## Boundary

This demo should not claim that SCIP alone resolves HTTP, WebClient, Feign, or gateway route semantics. The honest claim is narrower and stronger: Stubborn can compose deterministic source graphs across service boundaries when service contracts are represented as explicit graph facts.

The `petclinic-contracts` source is stored as first-class contract evidence, not as SCIP symbols or ordinary `reference` edges. The verifier checks both structured API `contract_edges` / `contract_endpoints` and the `stubborn-dsl` `contracts:` block so the demo exercises evidence-aware output, not only graph reachability.
