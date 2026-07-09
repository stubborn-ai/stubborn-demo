# stubborn-demo

Runnable demo and validation projects for Stubborn.

This repo is the product-level demo surface for the Stubborn AI program. It keeps
large or story-driven validation projects out of the headless core repo while
still exercising the public CLI/API contracts.

## Execution tiers

| Tier | Default for | Entry point |
|------|-------------|-------------|
| Docker | Most users and CI | `docker compose build` + `docker compose run --rm ...` |
| WSL/bash | Fast local validation on Linux, macOS, or Windows via WSL2 | Bash host scripts under `demo-spring/`, `spring-petclinic/`, `spring-petclinic-microservices/`, and `dukesbank/` |
| PowerShell fallback | Windows host users who need a fallback | Historical `*.ps1` scripts in git history, or thin wrappers that call the same targets |

## Demos

| Demo | Purpose |
|------|---------|
| [`demo-spring`](demo-spring/) | Small Spring Boot app for fast SCIP -> SQLite -> context validation and MCP smoke |
| [`multi-repo`](multi-repo/) | Workspace graph validation for source-available internal repos |
| [`spring-petclinic`](spring-petclinic/) | Scale-up validation against a pinned upstream Spring PetClinic |
| [`spring-petclinic-microservices`](spring-petclinic-microservices/) | Multi-service workspace validation with explicit HTTP contract evidence |
| [`dukesbank`](dukesbank/) | Legacy Java EE migration-oriented validation |
| [`migration-bridge`](migration-bridge/) | Minimal consumer sketch for migration workflows |

## Quick Start

Docker path:

```bash
docker compose build
docker compose run --rm e2e
docker compose run --rm merge-e2e
docker compose run --rm multi-repo-e2e
docker compose run --rm petclinic-e2e
docker compose run --rm petclinic-ms-e2e
```

Host path:

```bash
cd demo-spring
./scripts/run-e2e.sh
./scripts/run-merge-e2e.sh
cd ../multi-repo
./scripts/run-e2e.sh
```

Host runs require JDK 21+, Maven, `scip-java`, `python3`, and the installed
`stubborn-stub` package / `stubborn` CLI in the active environment.
`mcp-smoke.sh` scripts additionally require `stubborn-mcp` installed.
Optional preflight: `pip install stubborn-status && stubborn-status --json`.
They do not create or manage a Python virtual environment; use your own
`venv`, `uv`, or equivalent if you want isolation.
Some demos also require explicit roots:
- `multi-repo` expects `stubborn` installed in the current environment.
- `dukesbank` expects `BANK_ROOT` to point at the bank module directory.
- `spring-petclinic` and `spring-petclinic-microservices` clone pinned upstream
  repos into their own local `upstream/` directories.

On Windows, prefer WSL2 for the host path. Treat PowerShell as a fallback launcher only.

## Repo Boundaries

- `stubborn` is the headless core: ingest, store, prune, weave, API, CLI.
- `stubborn-watch` is dev-loop orchestration: watch, debounce, external indexer, merge.
- `stubborn-mcp` is the source-neutral agent/MCP surface over a prepared `symbols.db`.
- `stubborn-status` aggregates federated `doctor --json` for terminal, CI, and IDE bridges ([`stubborn-status`](https://pypi.org/project/stubborn-status/) **0.1.0b1**).
- `stubborn-demo` owns runnable demos and black-box validation projects.

## Validation Scope

The demos prove behavior through public entrypoints:

```text
Java source -> scip-java -> stubborn index/merge -> symbols.db -> context/list_symbols/list_contracts/MCP
OpenAPI/manifest -> stubborn index-openapi/index-contract -> contract tables -> list_contracts/context
```

Generated artifacts such as `index.scip`, `metadata/`, Maven `target/`, and
upstream clones are intentionally gitignored.

## Launcher contracts

Explicit environment variables, CLI flags, Docker service mapping, and CI
workflows are indexed in the program hub:

- [DEMO-LAUNCHERS.md](https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/DEMO-LAUNCHERS.md)
- [PETCLINIC-VALIDATION.md](https://github.com/stubborn-ai/stubborn-hub/blob/main/docs/PETCLINIC-VALIDATION.md) (monolith + microservices contract evidence)
