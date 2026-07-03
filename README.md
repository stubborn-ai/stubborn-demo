# stubborn-demo

Runnable demo and validation projects for Stubborn.

This repo is the product-level demo surface for the Stubborn AI program. It keeps
large or story-driven validation projects out of the headless core repo while
still exercising the public CLI/API contracts.

## Demos

| Demo | Purpose |
|------|---------|
| [`demo-spring`](demo-spring/) | Small Spring Boot app for fast SCIP -> SQLite -> context validation |
| [`spring-petclinic`](spring-petclinic/) | Scale-up validation against a pinned upstream Spring PetClinic |
| [`dukesbank`](dukesbank/) | Legacy Java EE migration-oriented validation |
| [`migration-bridge`](migration-bridge/) | Minimal consumer sketch for migration workflows |

## Quick Start

Docker path:

```bash
docker compose build
docker compose run --rm e2e
docker compose run --rm merge-e2e
docker compose run --rm petclinic-e2e
```

Host path:

```powershell
cd demo-spring
./scripts/run-e2e.ps1
./scripts/run-merge-e2e.ps1
```

Host runs require JDK 21+, Maven, `scip-java`, and Stubborn on `PATH`.

## Repo Boundaries

- `stubborn` is the headless core: ingest, store, prune, weave, API, CLI.
- `stubborn-watch` is dev-loop orchestration: watch, debounce, external indexer, merge.
- `stubborn-mcp` is the agent/MCP surface over a prepared `symbols.db`.
- `stubborn-demo` owns runnable demos and black-box validation projects.

## Validation Scope

The demos prove behavior through public entrypoints:

```text
Java source -> scip-java -> stubborn index/merge -> symbols.db -> context/list_symbols/MCP
```

Generated artifacts such as `index.scip`, `metadata/`, Maven `target/`, and
upstream clones are intentionally gitignored.
