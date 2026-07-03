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

```bash
python scripts/verify_multi_repo_workspace.py
```
