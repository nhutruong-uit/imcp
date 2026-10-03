# Team workflow

## Git branches

```
feature/<short-name>  ──PR──▶  develop  ──PR (team lead reviews)──▶  main  ──▶  GitHub Release (installers)
fix/<short-name>               (default branch;                (protected; CI required)   (packaged automatically)
docs/<short-name>               CI runs after the merge)
```

- `develop` is the default branch on GitHub. Work on a `feature/...`, `fix/...` or `docs/...` branch and open a Pull
  Request into `develop`; **never push directly** to `main`.
- **CI** (`ci.yml`: build + unit tests on macOS and Windows, plus the full `test_all` suite - database, server-level,
  unit and end-to-end tests - on Linux against SQL Server in Docker) runs when something is merged into `develop`, on
  every PR into `main`, and when started by hand: `gh workflow run CI --ref <branch> -f reason="<what to check>"` or
  *Actions > CI > Run workflow* (the run is listed as "Manual CI on <branch>: <reason>"). Pushes to work branches do
  not run CI. **PRs into `develop`** run the fast **Checks** workflow (`checks.yml`: `check_changes` + build + unit
  tests incl. `tst_conventions` on Linux, no database); it is not a required check, so still run `scripts/test_all`
  locally before merging (see the checklist below and [SETUP.md](SETUP.md)). Reviewers use `/imcp-review`.
- PR `develop → main` = release: `release.yml` packages `.exe` / `.zip` / `.dmg` and creates a Release tagged
  `vX.Y.Z-build.N`. Before releasing, bump `project(VERSION ...)` in `CMakeLists.txt` if there are new features.
- *Branch protection* is enabled for `main` only: a PR is required, the three CI jobs (`macOS (Apple Silicon)`,
  `Windows (Qt + MinGW)`, `Full tests (Linux + SQL Server)`) must be green and the branch must be up to date with
  `main` before merging. It also applies to admins; force pushes and branch deletion are blocked. No reviewer is
  required (the team lead can merge once CI is green). `develop` is not locked, but the team still works through PRs.
- PR title, description and commit messages are written **in English**. With Claude Code: type
  `/imcp-create-pr`. (A private repo needs GitHub Pro; students can get it for free via the GitHub Student Developer
  Pack.)

## How do non-programming members contribute?

Start with [CODE_TOUR.md](CODE_TOUR.md): it explains how to read the SQL scripts and the C++ code without a
programming background, and where to find the code behind each business rule.

Everyone contributes through GitHub (the commit history is the evidence of who did what at the oral defense):
1. Open an **Issue** when you find a data/business bug or want to suggest something (labels: `database`, `report`, `app`).
2. Edit documentation/report: create a `docs/...` branch directly in the GitHub web UI (*Edit file* →
   *Create a new branch* → PR).
3. Edit the SQL scripts you own: use **GitHub Desktop** (Windows/macOS) to clone, create a branch, commit, push and open a PR.
4. Review the Vietnamese UI texts: open `resources/translations/qlttta_vi.ts` in **Qt Linguist** and correct the
   translations (the English source strings are fixed by the code).

## Conventions

### Language
- Everything in the repository is written in **English**: C++ code, CMake, scripts, CI configuration, docs, commit
  messages and the database (objects, columns, stored values, business messages, SQL comments). People's names and
  addresses in the demo data stay Vietnamese. Only the course report (`docs/report/`) and the user guide
  (`docs/user-guide/`) are Vietnamese.
- The UI is bilingual: English source strings in the code, Vietnamese translation in
  `resources/translations/qlttta_vi.ts` (including the stored database values and the database messages);
  Vietnamese is the default UI language.

### Commits (English, Conventional Commits)
```
feat(students): add search by guardian phone number
fix(db): fix the schedule-clash trigger for classes without an end date
docs(report): add section 3.7 on integrity constraints
```
With Claude Code, type `/imcp-commit`: it commits only your files, checks them (forbidden files, secrets, format of
the changed C++ lines, related tests) and writes a message that passes `scripts/check_changes`.

### Database (`database/`)
- Tables in UPPER_SNAKE_CASE (`STUDENT`, `CLASS_SESSION`), columns in PascalCase (`StudentId`, `FullName`), constraints
  named `PK_`, `FK_<CHILD>_<PARENT>`, `CK_<TABLE>_<Column>`, `UQ_`, `DF_`; prefixes `usp_` (procedure,
  `usp_<Entity>_<Verb>`), `fn_`, `vw_`, `trg_`, `rl_` (role).
- Text is always `NVARCHAR` with the `N'...'` prefix (names and addresses are Vietnamese).
- Stay compatible with **SQL Server 2012** (no `CREATE OR ALTER`, `DROP ... IF EXISTS`, `STRING_AGG`, `TRIM`, JSON).
  Use the pattern `IF OBJECT_ID(N'dbo.x', N'P') IS NOT NULL DROP PROCEDURE dbo.x; GO`.
- Every file starts with `USE QLTTTA; GO; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; GO`.
- Business errors: `THROW 5xxxx, N'English message.', 1;` in procedures, `RAISERROR` + `ROLLBACK` in triggers.
  The application shows them in the UI language: register every new message in
  `src/infrastructure/db/DbMessages.cpp` and translate it in `qlttta_vi.ts` (`tst_i18n` reads the SQL scripts and
  fails otherwise). Triggers must handle **sets** (several rows in `inserted`/`deleted`).
- The application never inserts/updates tables directly; every write goes through a procedure.
- New objects must be `GRANT`ed to the right roles in `06_security.sql`.
- New business rules, constraints or permissions need a test case in `12_tests.sql` **and** an entry (case code +
  message pattern) in the `#Expected` table, so a "Rejected" case only passes when it is rejected for the right
  reason. Do not change the expectation of an existing case just to make the tests green, unless the
  specification really changed; say so in the PR.
- A new enumerated value (`CHECK ... IN (N'...')`) needs an entry in `src/presentation/common/DbValues.cpp` and a
  Vietnamese translation (`tst_i18n` reads `01_tables.sql` and fails otherwise); a new column shown in a list needs an entry in
  `src/presentation/common/Columns.cpp`.
- After editing, re-run the whole `scripts/db_init` to make sure the scripts work from scratch.

### C++ / Qt
- Follow the dependency direction in [ARCHITECTURE.md](ARCHITECTURE.md): `presentation` must not include
  `infrastructure`, and SQL lives only in `infrastructure/repositories`.
- Errors are returned as `Result<T>` / `VoidResult` (no exceptions across layers).
- English names: classes PascalCase (`StudentService`), functions/variables camelCase (`add`, `filter`), members
  `m_...`. Database names only inside SQL strings; C++ names follow them (`StudentId` → `Student::id`).
- Every user-visible string goes through `tr("English text")`; after adding strings run the `update_translations`
  target and translate them in `qlttta_vi.ts` (see [SETUP.md](SETUP.md#translations-multi-language-ui)). Display text
  for codes belongs to `Labels`/`Columns`/`DbValues`, never to domain/application, and no logic may depend on
  displayed (translated) text - use codes, column keys and stored values.
- Format with `clang-format` (the `.clang-format` file in the repo root; in Qt Creator: *Beautifier*) - the team
  version is in `.clang-format-version` (`brew install clang-format`, or `pip install clang-format==<version>`);
  format only the lines you changed (`git clang-format`). `scripts/check_changes` (step 1 of `test_all`) fails on
  unformatted changed lines; Claude Code formats its edits by itself (hook in `.claude/settings.json`).
- Cursor and VS Code: install the recommended `clangd` extension (`.vscode/extensions.json`) and do not install
  Microsoft C/C++ (`cpptools`) next to it - the two IntelliSense engines conflict. Configuring
  (`cmake --preset <name>`) symlinks `compile_commands.json` to the repository root (gitignored), which is where
  clangd looks, so Qt and project headers resolve on macOS, Windows and Linux. Reconfigure after switching presets.
  Shared editor settings live in `.vscode/settings.json`.
- Every new use case needs at least one unit test in `tests/` (with a fake repository), and every new screen must be
  opened by the end-to-end test (it covers every feature listed in `Permissions` automatically).

## Pull Request checklist
GitHub pre-fills every new PR with `.github/pull_request_template.md` (same sections as `/imcp-create-pr`):
- [ ] `scripts/test_all.sh` (Windows: `scripts\test_all.ps1`) reports **ALL TESTS PASSED** (change checks, database,
      server-level, unit tests incl. `tst_conventions` and translations, end-to-end) - paste the result line into the PR
- [ ] If the database changed: `06_security.sql` is updated (and the permission matrix of `T29`); new business rules
      have test cases in `12_tests.sql` / `13_server_tests.sql` (+ `#Expected`); new messages are in `DbMessages.cpp`
- [ ] New UI strings are translated in `resources/translations/qlttta_vi.ts`
- [ ] Commit messages in English (`type(scope): summary`), no AI attribution lines (checked by `check_changes`)
- [ ] Tried with the demo account of the relevant role, in Vietnamese and English when the UI changed
- [ ] Documentation/report updated if the design or a number they quote changed

## Using Claude Code (allowed by the instructor)
- Read `AGENTS.md` in the repo root and `.claude/rules/`: Claude Code applies the conventions above automatically.
  It needs Claude Code v2.1.277 or later, which reads `AGENTS.md` by itself. Do not create a `CLAUDE.md` or
  `CLAUDE.local.md`: Claude Code would read it instead of `AGENTS.md`.
- After cloning, type `/imcp-setup`: it checks your machine, installs what is missing (it asks first), creates the
  database and runs `test_all` (`scripts/setup_dev`, see [SETUP.md](SETUP.md#one-command-setup-recommended)).
- Every member must be able to **understand and explain** their own area: when you ask Claude to write or change
  something, ask it to explain each statement and run it yourself in SSMS.
- Never commit secrets (real passwords, `.env` files).
