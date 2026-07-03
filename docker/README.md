# Docker environment

Reproducible toolchain for Stubborn without installing JDK, Maven, or scip-java locally.

## Image contents

| Tool | Version |
|------|---------|
| JDK | Eclipse Temurin 21 |
| Maven | distro package (Noble) |
| scip-java | `0.12.3` (`scip-java_2.13`, via Coursier) |
| Python | 3.x + `stubborn` CLI installed from the Docker build arg `STUBBORN_SPEC` |

## Quick start

From the **repository root**:

```bash
# Build image
docker compose build

# Run demo-spring E2E (writes artifacts to demo-spring/metadata/)
docker compose run --rm e2e

# Run demo-spring merge E2E (save -> --merge -> list_symbols)
docker compose run --rm merge-e2e

# Run spring-petclinic scale-up E2E (~5 min first run; clones upstream)
docker compose run --rm petclinic-e2e

# Duke's Bank Step 7 (requires sibling dukesbank clone at ../../dukesbank)
docker compose run --rm dukesbank-e2e

# Inspect outputs on the host
ls demo-spring/metadata/
cat demo-spring/metadata/order-service.stub.java

# Stubborn-DSL (after indexing):
docker compose run --rm cli context /demo/metadata/symbols.db \
  --target "<stable_id>" --format stubborn-dsl
```

See [Stubborn-DSL docs](https://github.com/stubborn-ai/stubborn/blob/main/docs/STUBBORN-DSL.md).

## Services

| Service | Purpose |
|---------|---------|
| `e2e` | Runs `docker/run-e2e.sh` on mounted `demo-spring` |
| `merge-e2e` | Runs `docker/run-merge-e2e.sh` on mounted `demo-spring` |
| `petclinic-e2e` | Clones pinned spring-petclinic, full scale-up pipeline |
| `shell` | Interactive bash with full toolchain |
| `cli` | Run arbitrary `stubborn` commands |

### Interactive shell

```bash
docker compose run --rm shell
# inside container:
cd /demo && mvn -q -DskipTests package
scip-java index
stubborn index --scip index.scip --out metadata/symbols.db
```

### One-off CLI

```bash
docker compose run --rm cli info /demo/metadata/symbols.db
```

Mount your own project by editing `docker-compose.yml` or:

```bash
docker compose run --rm \
  -v /path/to/your/java/project:/demo \
  e2e
```

## Build arguments

```bash
docker compose build --build-arg SCIP_JAVA_VERSION=0.12.3
docker compose build --build-arg STUBBORN_SPEC=stubborn-stub
```

## Windows notes

- Use Docker Desktop with Linux containers.
- Generated files appear under `demo-spring\metadata\` via bind mount.
- PowerShell users can still use `demo-spring/scripts/run-e2e.ps1` on the host.

## Related

- [demo-spring/README.md](../demo-spring/README.md) — demo app and cases
- [spring-petclinic/README.md](../spring-petclinic/README.md) — scale-up E2E
- [SCIP ingest docs](https://github.com/stubborn-ai/stubborn/blob/main/docs/SCIP-INGEST.md) — SCIP ingest details
