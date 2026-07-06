# Multi-Repo Workspace

Minimal validation for Stubborn workspace graph composition.

The fixtures model two source-available internal repos:

- `repo-a`: `Controller#handle()` references `com/example/lib/Service#` as a
  signature-level external dependency (`relative_path` is null).
- `repo-b`: defines `Service#` and its neighbor `Helper#`.

## Verification model

Validation is split into two layers:

1. **Unit tests** (`tests/test_multi_repo_workspace.py`) lock the fixture merge
   rules in `scripts/multi_repo_workspace.py`. They run in CI without the
   `stubborn` CLI and do not need Docker.
2. **Black-box verifier** (`scripts/verify_multi_repo_workspace.py`) exercises
   the installed `stubborn` CLI end to end via `multi-repo/scripts/run-e2e.sh`
   or the `multi-repo-e2e` Docker Compose service.

The verifier proves two cases:

| Case | Index input | `context` target | Expected symbols | Must not appear |
|------|-------------|------------------|------------------|-----------------|
| Jar-only | `repo-a.json` alone | `Controller#handle()` | `Service` | `Helper` |
| Composed | merged `repo-a` + `repo-b` | `Controller#handle()` | `Controller`, `Service`, `Helper` | — |
| Composed (reverse) | merged `repo-a` + `repo-b` | `Service#` | `Service`, `Helper` | `Controller` |

Reverse context checks the one-way edge model: `Service#` neighbors include
`Helper#`, but not `Controller#handle()` on the other side of the cross-repo
call edge.

### Why a combined fixture instead of per-repo indexing

The published `stubborn` CLI does not accept per-repo `--workspace` / `--repo`
flags that this demo would need for two sequential `index` runs into one DB.
The verifier therefore merges `repo-a.json` and `repo-b.json` into
`multi-repo/metadata/combined-fixtures.json` and runs a single `stubborn index`.

Merge rule: when both fixtures define the same `stable_id`, keep the provider
copy from `repo-b` and drop the jar-only stub from `repo-a` (the entry whose
`relative_path` is null). Without that deduplication, SQLite hits `stable_id`
uniqueness errors during indexing.

Do not treat `build_combined_fixture()` as casual preprocessing for other
demos — it encodes the multi-repo contract this verifier depends on.

## Host environment

- `./scripts/run-e2e.sh` expects `python3` and the installed `stubborn` CLI in
  the active environment.
- You may use your own virtual environment, but the script does not create or
  manage one for you.
- Recommended setup for local work is a user-owned `venv`, `uv`, or similar
  environment manager outside the repo tree.
- Override the CLI with `STUBBORN_CMD` when needed (for example
  `STUBBORN_CMD='python -m stubborn'`).

```bash
./scripts/run-e2e.sh
```
