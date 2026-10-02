# CLAUDE.md - guide for Claude Code in the QLTTTA repo

IE103 course project (Information Management, UIT): an English-center management application. The grading focus
is the **SQL Server database**; the Qt application is the presentation part (menus/forms/reports). Team members must
be able to explain the code at the oral defense → always explain briefly **in Vietnamese** (in the chat) what you
changed.

## Common commands

```bash
# Database (SQL Server in Docker, container sql2022 or imcp-mssql)
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/db_init.sh --docker sql2022

# Build + test (macOS). If CMake reports a broken compiler: add -DCMAKE_OSX_SYSROOT=<Xcode SDK>
cmake --preset macos-debug && cmake --build --preset macos-debug && ctest --preset macos-debug

# FULL TEST SUITE (required before a PR): db_init -> 12_tests.sql -> 13_server_tests.sql -> build -> unit + e2e
# (CI runs the same suite on Linux - job "Full tests (Linux + SQL Server)")
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" ./scripts/test_all.sh --docker sql2022
# PowerShell version (Windows; runs on macOS with pwsh): keep the .sh/.ps1 versions doing the same steps
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" pwsh -File scripts/test_all.ps1 -Docker sql2022

# End-to-end GUI tests only, against the real database (10 scenarios; SKIPPED without the environment variable)
QLTTTA_E2E_PASSWORD='Demo@2026' ctest --preset macos-debug -R e2e --output-on-failure

# Refresh the translation file after adding/changing tr("...") strings, then translate the new entries
cmake --build --preset macos-debug --target update_translations   # -> resources/translations/qlttta_vi.ts

# Connection/login check without the GUI
QLTTTA_USER=ql_quan QLTTTA_PASSWORD='Demo@2026' build/macos-debug/src/app/QLTTTA.app/Contents/MacOS/QLTTTA --check-connection

# Update the report (or type /imcp-update-report): real data -> docx -> PDF (macOS + Word) -> check
SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" python3 docs/report/tools/export_data.py --docker sql2022
python3 docs/report/build_report.py && ./docs/report/tools/export_pdf.sh
swift docs/report/tools/check_pdf.swift check docs/report/IE103_Group1_Report.pdf

# Screenshots (visual check with real data; QLTTTA_SHOT_LANG=en for the English UI)
cmake --preset macos-debug -DQLTTTA_BUILD_TOOLS=ON && cmake --build --preset macos-debug
QT_QPA_PLATFORM=offscreen QLTTTA_SHOT_PASSWORD='Demo@2026' build/macos-debug/tools/qlttta_screenshots
```

## Detailed rules and shared skills
- `.claude/rules/`: general workflow + **result report template** (`00-general-workflow.md`, always applies) and rules
  per file type - `sql.md` (database/), `cpp-qt.md` (src/), `tests.md`, `scripts-ci.md`, `report.md`. Every member
  using Claude Code follows these files so that generated code has the same format and results are reported the
  same way.
- Skills: `/imcp-create-pr` (create/update an English PR after running `test_all`), `/imcp-update-report` (update the
  report: data from the database, screenshots, diagrams, docx, PDF, checks).

## Mandatory rules

### Language
- Everything is written in **English**: C++ code, CMake, scripts, CI, docs, commit messages and the database
  (objects `STUDENT`, `usp_Enrollment_Create`, columns `StudentId`, stored values `N'Studying'`, business messages,
  SQL comments). People's names and addresses in the demo data stay Vietnamese (the center is in Vietnam).
- UI strings are English inside `tr()`; the Vietnamese UI comes from `resources/translations/qlttta_vi.ts`
  (see `cpp-qt.md`), including the labels of stored database values (`DbValues`) and the database business
  messages (`DbMessages`). The user picks the language at runtime; Vietnamese is the default.
- The report (`docs/report/`) is written in Vietnamese; it quotes the (English) database identifiers.

### Database (`database/`)
- Compatible with **SQL Server 2012+**: no `CREATE OR ALTER`, `DROP ... IF EXISTS`, `STRING_AGG`, `TRIM`,
  `CONCAT_WS`, JSON, RLS. Use the pattern `IF OBJECT_ID(N'dbo.x', N'P') IS NOT NULL DROP PROCEDURE dbo.x; GO`.
- Every file starts with `USE QLTTTA; GO; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; GO`.
- Naming: tables in UPPERCASE without diacritics, columns in PascalCase, `usp_`/`fn_`/`vw_`/`trg_`, constraints
  `PK_/FK_/CK_/UQ_/DF_`.
- Business errors: `THROW 5xxxx, N'English message.', 1;` (procedures) or `RAISERROR + ROLLBACK` (triggers).
  The application shows the message in the UI language: every message is registered in
  `src/infrastructure/db/DbMessages.cpp` and translated in the `.ts` file (`tst_i18n` fails otherwise).
- Triggers must handle **sets** (several rows in inserted/deleted).
- New object → GRANT to the roles in `06_security.sql`; business roles have no rights on base tables.
- The application never INSERTs/UPDATEs tables directly: every write goes through a procedure.
- After a change: run `scripts/test_all.sh` (re-runs `db_init` from scratch + `12_tests.sql` + `13_server_tests.sql`),
  try it with a demo account.
- New business rule/constraint/permission → add a test case to `12_tests.sql` **and** register its code + message
  pattern in table `#Expected` (a "Rejected" case must be rejected for the right reason); features that need
  server-level operations (backup, BULK INSERT, distributed, sign-in/lockout) go to `13_server_tests.sql` (`Sxx`). Do not change the
  expectation of an existing case to make the tests green unless the specification really changed - then say so in
  the PR.

### C++ / Qt (`src/`)
- Clean Architecture, dependency direction: `presentation → application → domain ← infrastructure`; `app` wires them.
  `presentation` does **not** include `infrastructure/` and holds no SQL. SQL lives only in
  `infrastructure/repositories`.
- New modules follow the cookbook in `docs/ARCHITECTURE.md` section 4; the reference module is Students
  (`Student` → `IStudentRepository` → `StudentService` → `SqlStudentRepository` → `StudentPage`).
- Errors are returned as `Result<T>`/`VoidResult` (no exceptions across layers).
- Display text for codes lives in the presentation layer: roles/menu → `Labels`, column titles/formats → `Columns`
  (by column key), stored database values → `DbValues`. Logic never depends on displayed (translated) text.
  Domain/application keep codes only; their user messages use `tr()` (Qt Core).
- Procedures with OUTPUT parameters: batch `SET NOCOUNT ON; DECLARE @x ...; EXEC ... @Out = @x OUTPUT; SELECT @x;`.
  Values go through `SqlHelpers::execPrepared(q, m_db, sql, {values})` (keeps text Unicode with FreeTDS); NULLs
  are passed with `SqlHelpers::stringOrNull`.
- A new use case needs a unit test in `tests/` with a fake repository; a new screen must be opened by the e2e test
  (`everyRole_opensEveryFeature_withData` covers every feature in `Permissions`); new UI strings must be translated
  (`tst_i18n` fails on unfinished entries).
- C++17, Qt ≥ 6.7 (needed by `qt_add_translations(... SOURCE_TARGETS ...)`; Windows CI uses Qt 6.8 LTS + MinGW,
  macOS uses Homebrew Qt).

### Git
- The default branch on GitHub is `develop`. Work on `feature/...` branches, PR into `develop`; never push directly
  to `main`.
- Only `main` has branch protection (PR required + green CI on macOS, Windows and the Linux full tests + branch up to
  date with its base, applies to admins too). `develop` is not locked.
- Commit messages in English (Conventional Commits): `feat(students): ...`, `fix(db): ...`. No AI attribution
  lines in commits or PRs (no `Co-Authored-By: Claude ...`, no "Generated with Claude Code").
- **PRs (title + description) are written in English**: use the `/imcp-create-pr` skill
  (`.claude/skills/imcp-create-pr/SKILL.md`), which runs `test_all` before creating the PR.
- Never commit real passwords, `.env`, `build/`, `dist/`.

## Demo accounts
Shared password and list: `docs/SETUP.md`. Roles: `ql_quan` (manager), `gvu_lan` (academic staff),
`kt_minh` (accountant), `gv_john` (teacher).
