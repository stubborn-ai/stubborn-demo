# Multi-Repo Workspace

Minimal validation for Stubborn workspace graph composition.

The fixtures model two source-available internal repos:

- `repo-a`: `Controller#handle()` references `com/example/lib/Service#` as a
  signature-level external dependency.
- `repo-b`: defines `Service#` and its neighbor `Helper#`.

Validation proves two cases:

1. With only `repo-a` indexed, `Service` is a leaf and `Helper` is not present.
2. With both repos indexed into the same workspace DB, `context --workspace`
   crosses from `repo-a` into `repo-b` and includes `Helper`.

Host environment:

- `./scripts/run-e2e.sh` expects `python3` and the installed `stubborn` CLI in
  the active environment.
- You may use your own virtual environment, but the script does not create or
  manage one for you.
- Recommended setup for local work is a user-owned `venv`, `uv`, or similar
  environment manager outside the repo tree.

```bash
./scripts/run-e2e.sh
```
