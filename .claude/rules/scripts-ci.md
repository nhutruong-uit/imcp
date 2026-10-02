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
  summary tables printed by `database/12_tests.sql` and `database/13_server_tests.sql` (case codes `Txx`/`Pxx`/`Sxx`).
- Passwords only travel through environment variables (`SQL_PASSWORD`, `SQLCMDPASSWORD`;
  `docker exec -e SQLCMDPASSWORD` without a value) - never on the command line, never printed in logs; restore the
  environment afterwards.
- CI (`.github/workflows/ci.yml`) runs only on a merge into `develop`, on PRs into `main` (required by branch
  protection) and manually. Keep the three job names `macOS (Apple Silicon)`, `Windows (Qt + MinGW)` and
  `Full tests (Linux + SQL Server)`: renaming a job requires updating the required checks of `main`, otherwise every
  PR into `main` gets stuck.
- Do not add `paths-ignore` to the `pull_request` trigger of `main` (the required checks would never run).
- The `Full tests (Linux + SQL Server)` job runs SQL Server 2022 Developer in Docker and installs Microsoft ODBC
  Driver 18 (`msodbcsql18`), both with `ACCEPT_EULA=Y`: the repository owner accepted these two licenses for CI
  (development/test use only) on 2026-10-02. Do not add other components that need their own Microsoft EULA (e.g.
  `mssql-tools18`) without asking - sqlcmd runs inside the SQL Server container (`test_all --docker`). FreeTDS is not
  used there: Qt's ODBC plugin disables Unicode for FreeTDS, so strings would be sent as `varchar` (code page 1258).
  The sa password is random for every run (masked); never commit one.
- That job runs `test_all.sh` and then `test_all.ps1` (pwsh) against the same server, so both versions must keep
  working on Linux too (`linux-debug` preset).
