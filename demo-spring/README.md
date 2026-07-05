# orders-demo — Stubborn E2E

A **small, modern** Spring Boot 3 application used as the primary end-to-end example for Stubborn.

| | |
|---|---|
| Java | 21 |
| Framework | Spring Boot 3.3 |
| Build | Maven |
| Domain | Orders API (controller → service → repository) |
| Source files | ~14 Java classes |

Designed to be extended with additional **cases** under [`cases/`](cases/) without growing into a monolith.

This demo follows the program policy: Docker is the canonical path, WSL/bash is the fast local path, and PowerShell is only a fallback launcher for Windows host users.

## Layout

```text
com.example.orders
├── OrdersApplication
├── web/          OrderController, OrderExceptionHandler
├── service/      OrderService, PaymentService, PaymentGateway
├── repository/   OrderRepository, InMemoryOrderRepository
├── domain/       Order, Customer, OrderStatus
├── dto/          CreateOrderRequest, OrderResponse
└── exception/    OrderNotFoundException
```

## Prerequisites

Choose **one** path:

### A. Docker (recommended — no local JDK/Maven/scip-java)

From the **stubborn-demo repo root**:

```bash
docker compose build
docker compose run --rm e2e
docker compose run --rm merge-e2e
```

See [docker/README.md](../docker/README.md).

### B. Host toolchain

- **JDK 21+**
- **Maven 3.9+**
- **Python 3**
- **[scip-java](https://github.com/sourcegraph/scip-java)** on `PATH`
- **Stubborn** installed in the active environment: `pip install stubborn-stub`

## Quick E2E (bash, host)

```bash
cd demo-spring
./scripts/run-e2e.sh
```

Outputs:

- `index.scip` — SCIP index from scip-java
- `metadata/symbols.db` — Stubborn SQLite graph
- `metadata/order-service.stub.java` — pruned LLM context for `OrderService` (`java-stub`)

## Merge / watch E2E (ADR-009)

Use this host script to validate the **contract-level** dev loop for incremental merge:

```bash
cd demo-spring
./scripts/run-merge-e2e.sh
```

What it proves:

- a clean snapshot index is created first
- saving a new Java source file produces a SCIP document for that `relative_path`
- `stubborn index --merge --paths ...` updates the **same** active `index_run`
- `list_symbols` can see the new symbol after merge
- deleting the same file and merging that path removes the symbol again

The script writes a temporary `MergeProbeService.java`, verifies the merge, then removes the file and restores the demo source tree.

Optional compact format:

```bash
stubborn context metadata/symbols.db \
  --target "<OrderService stable_id>" \
  --format stubborn-dsl \
  --out metadata/order-service.stubborn-dsl
```

See [Stubborn-DSL docs](https://github.com/stubborn-ai/stubborn/blob/main/docs/STUBBORN-DSL.md).

## Manual steps

```bash
# 1. Compile (scip-java index also compiles via Maven)
mvn -q -DskipTests package

# 2. Generate SCIP index
scip-java index
# → index.scip

# 3. Ingest into Stubborn
stubborn index --scip index.scip --out metadata/symbols.db
stubborn info metadata/symbols.db

# 4. Resolve target symbol (display name → stable_id)
#    Then emit context — exact stable_id depends on scip-java output, e.g.:
stubborn context metadata/symbols.db \
  --target "<OrderService stable_id from index>" \
  --out metadata/order-service.stub.java
```

Use the E2E script to resolve `OrderService` automatically from the SQLite index.

## Cursor MCP (v0.4+)

With the **stubborn-demo repo root** open as the Cursor workspace:

1. Install: `pip install stubborn-stub stubborn-mcp`
2. Ensure `metadata/symbols.db` exists (`./scripts/run-e2e.sh` or index step above)
3. Configure Cursor MCP with `command: stubborn-mcp` and `STUBBORN_DB` pointing at `demo-spring/metadata/symbols.db`
4. **Cursor Settings → MCP** → enable `stubborn` (green) → Reload if needed

Smoke-test without Cursor:

```bash
./scripts/mcp-smoke.sh
```

This smoke script requires `stubborn-mcp` to be installed in the same active
environment as `stubborn-stub`.

Agent workflow:

1. `workspace_info` with `workspace: "default"` if you want to confirm the current run kind
2. `list_contracts` with `workspace: "default"` to confirm there are no contract sources in this code-only demo
3. `list_symbols` with `query: "OrderService"`
4. `get_context` with the returned `stable_id`
5. `metrics` with `sources: demo-spring/src/main/java`

See [stubborn-mcp docs](https://github.com/stubborn-ai/stubborn-mcp/blob/main/docs/MCP.md).

## Run the app (optional)

```bash
mvn spring-boot:run
curl -X POST http://localhost:8080/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"customerEmail":"ada@example.com","customerName":"Ada","total":42.50}'
```

## Adding cases

See [`cases/README.md`](cases/README.md) for the case catalog pattern. New scenarios (e.g. pay flow, exception paths) should add focused docs and optional expected stub snippets — not more framework boilerplate.

## Related examples

| Example | Role |
|---------|------|
| [spring-petclinic](../spring-petclinic/) | Scale-up E2E vs official PetClinic (~375 symbols, ~90% savings) |
| [migration-bridge](../migration-bridge/) | Legacy migration integration (Duke's Bank) |
| [fixtures](../fixtures/) | Minimal SCIP files for unit tests |
