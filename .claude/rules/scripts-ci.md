---
paths:
  - "scripts/**"
  - ".github/**"
  - "docker-compose.yml"
  - "CMakePresets.json"
---
# Rules for scripts, CI and packaging

- Every script has **two versions doing the same steps**: `.sh` (macOS/Linux) and `.ps1` (Windows). Change one,
  change the other.
- `.sh`: `#!/usr/bin/env bash` + `set -euo pipefail`; the repo root comes from `$(dirname "$0")`; a "Usage" comment
  block at the top of the file.
- `.ps1`: saved as **UTF-8 with BOM + CRLF** (Windows PowerShell 5.1 needs the BOM to read non-ASCII text such as the
  Vietnamese names in the database output), only syntax that runs on PowerShell 5.1 (no `??`, no ternary operator),
  `$ErrorActionPreference = "Stop"`, check `$LASTEXITCODE` after external commands; check the syntax with the
  `pwsh` parser before committing.
- Script comments and messages are English. `test_all` parses the `Verdict` column (`PASSED`/`FAILED`) of the
  summary table printed by `database/12_tests.sql`.
- Passwords only travel through environment variables (`SQL_PASSWORD`, `SQLCMDPASSWORD`;
  `docker exec -e SQLCMDPASSWORD` without a value) - never on the command line, never printed in logs; restore the
  environment afterwards.
- CI (`.github/workflows/ci.yml`) runs only on a merge into `develop`, on PRs into `main` (required by branch
  protection) and manually. Keep the two job names `macOS (Apple Silicon)` and `Windows (Qt + MinGW)`: renaming a job
  requires updating the required checks of `main`, otherwise every PR into `main` gets stuck.
- Do not add `paths-ignore` to the `pull_request` trigger of `main` (the required checks would never run).
- CI has no SQL Server and never accepts Microsoft's EULA on the user's behalf; database/e2e tests run locally through
  `test_all`.
