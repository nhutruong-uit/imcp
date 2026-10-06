---
paths:
  - "scripts/**"
  - ".github/**"
  - "docker-compose.yml"
  - "CMakePresets.json"
---
# Rules for scripts, CI and packaging

- Every script has **two versions doing the same steps**: `.sh` (macOS/Linux) and `.ps1` (Windows). Change one,
  change the other. The installer builders are the exception: `package-macos.sh` and `package-windows.ps1` only
  exist for their own platform; the pair `package.sh` / `package.ps1` picks the one of the current operating system
  (keep their options the same: `--qt-dir` / `-QtDir`).
- `.sh`: `#!/usr/bin/env bash` + `set -euo pipefail`; the repo root comes from `$(dirname "$0")`; a "Usage" comment
  block at the top of the file.
- `.ps1`: saved as **UTF-8 with BOM + CRLF** (Windows PowerShell 5.1 needs the BOM to read non-ASCII text such as the
  Vietnamese names in the database output), only syntax that runs on PowerShell 5.1 (no `??`, no ternary operator),
  `$ErrorActionPreference = "Stop"`, check `$LASTEXITCODE` after external commands; check the syntax with the
  `pwsh` parser before committing.
- ✔ (`tst_conventions`) every script has both versions and follows the `.sh`/`.ps1` format above.
- `scripts/setup_dev` (machine setup, `/imcp-setup`) checks before it installs and installs only what is missing, so
  it is safe to re-run; `--check` / `-Check` changes nothing. Components with their own license (SQL Server Developer,
  Docker Desktop, Microsoft ODBC Driver 18) are installed only with `--accept-licenses` / `-AcceptLicenses`: the member
  accepts them, never the script. It never asks for or types a password and never changes system security settings
  (sudo, group membership, SQL Server authentication mode) - it prints what the member must do. The steps differ per
  OS (Homebrew / winget + aqtinstall), so `setup_dev.ps1` runs `setup_dev.sh` on macOS/Linux; keep the options and the
  summary format of both the same, and its Qt version equal to the Windows job of `ci.yml`.
- `scripts/check_changes` checks what only git can see (format of the changed C++ lines, commit messages, tracked
  `build/`/`dist/`/`.env`); it is step 1 of `test_all` and runs on every PR into `develop`. The clang-format version
  of the team is pinned in `.clang-format-version` (CI installs it with `pip install clang-format==<version>`).
- Script comments and messages are English. `test_all` parses the `Verdict` column (`PASSED`/`FAILED`) of the
  summary tables printed by `database/12_tests.sql` and `database/13_server_tests.sql` (case codes `Txx`/`Pxx`/`Sxx`).
- Passwords only travel through environment variables (`SQL_PASSWORD`, `SQLCMDPASSWORD`;
  `docker exec -e SQLCMDPASSWORD` without a value) - never on the command line, never printed in logs; restore the
  environment afterwards.
- `checks.yml` (job `Checks (conventions + unit tests)`, Linux, no database) runs on every PR into `develop` and is a
  required check of that branch. Keep the job name (it is the required status check) and keep the job cheap - no SQL
  Server, no macOS/Windows.
- CI (`.github/workflows/ci.yml`) runs only on a merge into `develop`, on PRs into `main` (required by branch
  protection) and manually. Keep the three job names `macOS (Apple Silicon)`, `Windows (Qt + MinGW)` and
  `Full tests (Linux + SQL Server)`: renaming a job requires updating the required checks of `main`, otherwise every
  PR into `main` gets stuck.
- The first failing job stops the whole CI run: the job `Stop the run on the first failure` (not a required check,
  `actions: write` only) polls the jobs of the run and cancels it when one fails. GitHub's `fail-fast` only works
  inside a matrix, so keep this job when adding jobs; it must never fail on its own (API errors are retried).
- Every tool a job's `test_all` step needs is installed by the job itself (e.g. clang-format for `check_changes`, same
  install as `checks.yml`).
- Do not add `paths-ignore` to the `pull_request` trigger of `main` (the required checks would never run).
- `release.yml` packages macOS on a pinned runner (`macos-15`, not `macos-latest`): the Homebrew libraries in the
  `.dmg` are built for the runner's macOS, so the runner sets the oldest macOS the app supports. `package-macos.sh`
  writes the real minimum (highest `minos` of the bundle) into `Info.plist` and the release notes show it; when you
  move the runner, update `docs/SETUP.md` ("macOS 15+"; the report and the user guide read the runner of
  `release.yml` through `macos_min_version()`). The Windows minimum is
  `MinVersion` in `packaging/windows/installer.iss` (Qt 6.8: Windows 10 version 1809).
- `pages.yml` publishes the project site `docs/index.html` (as `index.html`), the data map `docs/data-map.html` and
  the screenshots that the project site names (`docs/report/images/screens/*.png`, demo data, same relative path)
  to GitHub Pages when one of them changes on `develop`. One copy of every document: never publish the report,
  the user guide or other docs there (a copy would go out of date) - link them in the repository instead
  (✔ `tst_conventions`, `docs_projectSite_matchesRepository`: a local link of the project site must be the data
  map or such a screenshot). Only `develop` may deploy (environment `github-pages`).
- The `Full tests (Linux + SQL Server)` job runs SQL Server 2025 Developer in Docker and installs Microsoft ODBC
  Driver 18 (`msodbcsql18`), both with `ACCEPT_EULA=Y`: the repository owner accepted these two licenses for CI
  (development/test use only) on 2026-10-02, and the SQL Server 2025 one on 2026-10-06. Do not add other components
  that need their own Microsoft EULA (e.g. `mssql-tools18`) without asking - sqlcmd runs inside the SQL Server
  container (`test_all --docker`). The suite runs with ODBC Driver 18; the end-to-end test then runs again through
  FreeTDS (`tdsodbc`, the driver of the macOS .dmg), which guards the Unicode workaround of
  `SqlHelpers::execPrepared`.
  The sa password is random for every run (masked); never commit one.
- That job runs `test_all.sh` and then `test_all.ps1` (pwsh) against the same server, so both versions must keep
  working on Linux too (`linux-debug` preset).
- `.github/dependabot.yml` updates only the GitHub Actions of the workflows, one grouped PR per week into `develop`.
  Keep the commit prefix `chore(ci)`: `check_changes` rejects any other subject, so a Dependabot PR would be red. Those
  PRs are not made by `/imcp-create-pr` (the PR template does not apply); read the release notes of a major bump
  before merging. A new ecosystem (for example `docker-compose`) needs the same prefix and a reason: the SQL Server
  image of `docker-compose.yml` is pinned on purpose.
- GitHub features that live in **Settings**, not in a file (state on 2026-10-06; a member with admin rights changes
  them, so say so in the PR when a rule depends on one): secret scanning with push protection, Dependabot alerts and
  security updates, private vulnerability reporting (the report channel of `.github/SECURITY.md`), CodeQL code
  scanning in *default setup* (`actions` and `c-cpp`), Discussions and the automatic deletion of merged head
  branches. Never remove the `deletion` rule from the rulesets `protect-develop` / `protect-main`: it is what stops
  that automatic deletion from deleting `develop`, the head of every release PR.
  Code scanning is not a required check of `develop` or `main`;
  do not add a CodeQL workflow file next to the default setup (the two conflict). Issue forms live in
  `.github/ISSUE_TEMPLATE/` (blank issues are off in its `config.yml`); the labels they set (`bug`, `enhancement`)
  must exist.
- Claude Code never starts a manual CI run (`gh workflow run CI ...`) on its own - only when the user asks (the branch
  may still get commits, and a run blocks the macOS and Windows runners for several minutes).
  `.claude/settings.json` makes Claude ask before `gh workflow run`, `gh pr merge` and force pushes, and removes the
  AI attribution lines from commits and PRs.
