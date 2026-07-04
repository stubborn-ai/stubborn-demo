# Spring PetClinic Microservices — workspace E2E

Official [spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) indexed as a Stubborn workspace. This demo validates the jump from a single Spring app to a multi-service graph.

The upstream project is one Git repository with multiple service directories. Stubborn treats each service directory as a separate workspace repo:

- `api-gateway`
- `customers-service`
- `vets-service`
- `visits-service`

Supporting services such as config server, discovery server, genAI, tracing, admin, Grafana, and Prometheus are intentionally skipped for the first graph validation pass.

## What This Proves

Stage 1 proves that Stubborn can compose independently indexed service directories into one workspace latest view.

Stage 2 proves that explicit HTTP contract facts can bridge service boundaries without pretending SCIP alone understands microservice routing. The contract bridge is generated from [`contracts/http.yml`](contracts/http.yml) into a small JSON fixture and indexed as `petclinic-contracts`.

## Quick Start

Docker path from repo root:

```bash
docker compose build toolchain
docker compose run --rm petclinic-ms-e2e
```

Host path:

```powershell
cd spring-petclinic-microservices
./scripts/run-e2e.ps1
```

Host runs require JDK 21+, Maven, `scip-java`, Python, and `stubborn` on `PATH`.

## Generated Artifacts

These are gitignored:

- `upstream/`
- `metadata/petclinic-workspace.db`
- `metadata/indexes/*.scip`
- `metadata/bridge/petclinic-contracts.json`
- `stub-output/*.stub.java`

## Cases

| Case | Target | Doc |
|------|--------|-----|
| visit-to-customer | `CustomersServiceClient` / `OwnerResource` contract bridge | [cases/visit-to-customer-context.md](cases/visit-to-customer-context.md) |
| owner-impact-radius | `OwnerResource` reverse traversal through contracts | [cases/owner-id-impact-radius.md](cases/owner-id-impact-radius.md) |

## Boundary

This demo should not claim that SCIP alone resolves HTTP, WebClient, Feign, or gateway route semantics. The honest claim is narrower and stronger: Stubborn can compose deterministic source graphs across service boundaries when service contracts are represented as explicit graph facts.

The current `petclinic-contracts` bridge is a v3-compatible seed validation. It
indexes declared contract bindings as ordinary `reference` edges so the existing
workspace graph can traverse them. Evidence tiers are documented in
[`CONTRACT-GRAPH.md`](https://github.com/stubborn-ai/stubborn/blob/main/docs/CONTRACT-GRAPH.md),
but they are not yet persisted or rendered by `stubborn context`. A future schema
version must make contract evidence first-class before this demo can claim
evidence-aware output.
