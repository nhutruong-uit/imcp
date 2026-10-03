# AGENTS.md - guide for coding agents in the QLTTTA repo

Project instructions for AI coding agents. Claude Code (v2.1.277 or later) reads this file directly at the start of
every session, together with `.claude/rules/`. Do not add a `CLAUDE.md` or `CLAUDE.local.md` next to it: Claude Code
then reads those instead and skips this file.

IE103 course project (Information Management, UIT): an English-center management application. The grading focus
is the **SQL Server database**; the Qt application is the presentation part (menus/forms/reports). Team members must
be able to explain the code at the oral defense → always explain briefly **in Vietnamese** (in the chat) what you
changed.

## Common commands

```bash
# New machine (or type /imcp-setup): install what is missing, init the database, run test_all; --check changes nothing
# (Windows: powershell -ExecutionPolicy Bypass -File scripts/setup_dev.ps1 -Check, then -AcceptLicenses)
./scripts/setup_dev.sh --check
./scripts/setup_dev.sh --accept-licenses

# Database (SQL Server in Docker, container sql2022 or imcp-mssql)
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/db_init.sh --docker sql2022

# Build + test (macOS). If CMake reports a broken compiler: add -DCMAKE_OSX_SYSROOT=<Xcode SDK>
cmake --preset macos-debug && cmake --build --preset macos-debug && ctest --preset macos-debug

# FULL TEST SUITE (required before a PR): change checks -> db_init -> 12_tests.sql -> 13_server_tests.sql
#   -> build -> unit tests (incl. tst_conventions) + e2e. CI runs the same suite on Linux ("Full tests" job)
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/test_all.sh --docker sql2022
# PowerShell version (Windows; runs on macOS with pwsh): keep the .sh/.ps1 versions doing the same steps
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" pwsh -File scripts/test_all.ps1 -Docker sql2022

# Only the change checks (format of the changed C++ lines, commit messages) / only the repository conventions
./scripts/check_changes.sh
ctest --preset macos-debug -R conventions --output-on-failure

# End-to-end GUI tests only, against the real database (SKIPPED without the environment variable)
QLTTTA_E2E_PASSWORD='Demo@2026' ctest --preset macos-debug -R e2e --output-on-failure

# Refresh the translation file after adding/changing tr("...") strings, then translate the new entries
cmake --build --preset macos-debug --target update_translations   # -> resources/translations/qlttta_vi.ts

# Connection/login check without the GUI
QLTTTA_USER=ql_quan QLTTTA_PASSWORD='Demo@2026' build/macos-debug/src/app/QLTTTA.app/Contents/MacOS/QLTTTA --check-connection

# Update the report (or type /imcp-update-report): real data -> docx -> PDF (macOS + Word) -> check
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" python3 docs/report/tools/export_data.py --docker sql2022
python3 docs/report/build_report.py && ./docs/report/tools/export_pdf.sh
swift docs/report/tools/check_pdf.swift check docs/report/IE103_Group1_Report.pdf

# Update the user guide (or type /imcp-update-guide; Vietnamese, for end users): docx -> PDF (macOS + Word)
python3 docs/user-guide/build_user_guide.py
./docs/report/tools/export_pdf.sh docs/user-guide/QLTTTA_User_Guide.docx

# Screenshots (visual check with real data; QLTTTA_SHOT_LANG=en for the English UI)
cmake --preset macos-debug -DQLTTTA_BUILD_TOOLS=ON && cmake --build --preset macos-debug
QT_QPA_PLATFORM=offscreen QLTTTA_SHOT_PASSWORD='Demo@2026' build/macos-debug/tools/qlttta_screenshots
```

## Rules, settings and skills (shared by the whole team)
- `.claude/rules/` (numbered in reading order): `00-general-workflow.md` (workflow, **result report template**,
  Definition of Done - always applies), then one file per area, loaded when such a file is touched: `01-sql.md`
  (database/), `02-cpp-qt.md` (src/), `03-tests.md` (tests/, test scripts), `04-scripts-ci.md` (scripts/, .github/),
  `05-report.md` (docs/report/, docs/user-guide/), `06-docs.md` (other docs). The detailed rules live there, not here.
- `.claude/settings.json`: no AI attribution in commits/PRs, asks before `gh workflow run` / `gh pr merge` / force
  push, and a hook that formats every C++ file Claude edits (`.claude/hooks/format-cpp.sh`).
- Skills: `/imcp-setup` (set up a member's machine for this OS: tools, database, `test_all`), `/imcp-commit`
  (commit only your files: checks, related tests, English message), `/imcp-create-pr`
  (English PR after `test_all`), `/imcp-review` (review a PR or branch against these rules), `/imcp-update-report`
  (report: data from the database, screenshots, diagrams, docx, PDF, checks), `/imcp-update-guide` (user guide:
  follow app changes, screenshots, Windows placeholders, docx, PDF).

## Mandatory rules (all areas)
- **Language**: everything in the repository is **English** - C++ code, CMake, scripts, CI, docs, commit messages,
  and the database (objects `STUDENT`, `usp_Enrollment_Create`, columns `StudentId`, stored values `N'Studying'`,
  business messages, SQL comments). People's names and addresses in the demo data stay Vietnamese. UI strings are
  English in `tr()` and translated in `resources/translations/qlttta_vi.ts` (also the labels of stored database
  values `DbValues` and the database messages `DbMessages`); Vietnamese is the default UI language. Only the report
  (`docs/report/`) and the user guide (`docs/user-guide/`) are Vietnamese.
- **Architecture**: `presentation → application → domain ← infrastructure` (`app` wires them); SQL only in
  `src/infrastructure/repositories`, every database write through a procedure, values through
  `SqlHelpers::execPrepared`. Reference module: Students; cookbook: `docs/ARCHITECTURE.md` section 4.
- **Database**: SQL Server **2012+** syntax, naming and file layout of `01-sql.md`; a new object is GRANTed in
  `06_security.sql` and every new rule/constraint/permission gets a test case in `12_tests.sql` (or
  `13_server_tests.sql` for server-level features) registered in `#Expected`. Never change the expectation of an
  existing case to make the tests green unless the specification really changed - then say so in the PR.
- **Enforced by tests** (`test_all`, CI): `tst_conventions` (SQL syntax and headers, layers, SQL location, scripts,
  numbers quoted in the docs, the data map `docs/data-map.html`), `12_tests.sql` T28-T30 and T32 (naming,
  permission matrix, `SET NOCOUNT ON`, UTC times), `tst_i18n` (translations and database messages), `check_changes`
  (format of the changed lines, commit messages). Fix the code, not the check.
- **Git**: default branch `develop`; work on `feature/...`/`fix/...`/`docs/...`/`chore/...` branches and PR into
  `develop`; never push directly to `main` (protected: PR + green CI on macOS, Windows and the Linux full tests +
  branch up to date). Conventional Commits in English (`feat(students): ...`, `fix(db): ...`), no AI attribution
  lines; commits through `/imcp-commit`. PRs in English through `/imcp-create-pr`, which runs `test_all` first.
  Never commit real passwords, `.env`, `build/`, `dist/`. Do not start a manual CI run unless the user asks.

## Demo accounts
Shared password and list: `docs/SETUP.md`. Roles: `ql_quan` (manager), `gvu_lan` (academic staff),
`kt_minh` (accountant), `gv_john` (teacher).
