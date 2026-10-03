---
paths:
  - "tests/**"
  - "database/12_tests.sql"
  - "database/13_server_tests.sql"
---
# Testing rules

## Names and structure of C++ tests (Qt Test)
- Test function names: `subject_condition_expectedResult` - e.g. `addStudent_invalid_doesNotCallRepository`.
- Unit tests (`tst_domain`, `tst_application`, `tst_sqlerrormapper`, `tst_sqlhelpers`, `tst_i18n`,
  `tst_conventions`): no database needed; use cases are tested with **fake repositories** written in the test file
  (reference: `FakeStudentRepository` in `tst_application.cpp`).
- `tst_conventions` reads the repository files (like `tst_i18n`) and checks the conventions of the rules: SQL Server
  2012 syntax and script headers, include directions between layers, SQL text and `execPrepared` only in the
  infrastructure, `.sh`/`.ps1` format and pairs, the database numbers quoted in `docs/DATABASE.md` / `docs/SETUP.md`.
  A new convention that can be read from the files gets a slot there (failure message = `file:line: what to do`).
- New test for an existing suite: add a private slot to the right file. New suite:
  `qlttta_add_test(tst_xxx <libraries>)` in `tests/CMakeLists.txt`.
- No translator is installed in unit tests, so messages are in English (the source language); Vietnamese texts are
  checked in `tst_i18n`.

## End-to-end (`tst_e2e_gui.cpp`, needs a real database, SKIPPED without `QLTTTA_E2E_PASSWORD`)
- Act like a user: `login(...)` through `LoginDialog`, `w.openFeature(Feature::...)`, find widgets by `objectName`
  (or the `testId` property).
- The scenarios run in Vietnamese (`useVietnamese()` in `initTestCase`/`cleanup`); English is covered by
  `language_switchToEnglish_rebuildsUi`.
- Type Vietnamese text with `typeText()` (not `QTest::keyClicks` with accented characters); handle modal dialogs with
  `QTimer::singleShot` or `MessageBoxCatcher`; wait with `QTRY_*` (no fixed `QTest::qWait`).
- **Restore the data** (delete what you added, revert what you edited) - other tests rely on the seed data.
- New features in `Permissions` are opened automatically by `everyRole_opensEveryFeature_withData` (it also checks
  that every column key has a title in `Columns`); the main business flow still needs its own scenario.

## Database tests (`database/12_tests.sql`)
- Case codes: `Txx` (constraints, business rules, processing results) or `Pxx` (permissions, via
  `EXECUTE AS USER ... REVERT`); use the next unused number.
- Section D (T28-T30, T32) checks the **schema conventions** from the catalog views: naming, the permission matrix of
  the business roles (T29 - the spec of `06_security.sql`; a new table right is added there on purpose),
  `SET NOCOUNT ON` / no `SELECT *` and the time conventions (T32). They read metadata only, so they need no
  transaction.
- Each case runs in `BEGIN TRAN ... ROLLBACK` (leaves no data), writes into `#Results`, and is **registered in
  `#Expected`**: a "Rejected" case with its message pattern (`N'%is full%'`; for system errors use the
  object/constraint name, e.g. `N'%CK_STUDENT_Email%'`), a "Succeeded" case with `NULL`.
- A success case must **compare the result with an independently computed value or a prepared scenario** (see
  T17-T24), not only "runs without error".
- The script follows the database conventions (English, see `01-sql.md`); the summary column `Verdict` is
  `PASSED`/`FAILED` (parsed by `scripts/test_all`):
```sql
-- T28: <description>
BEGIN TRY
    BEGIN TRAN;
    <violating statement>;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T28', N'<description>', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T28', N'<description>', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO
```

## Server-level tests (`database/13_server_tests.sql`)
- For what cannot run inside `BEGIN TRAN ... ROLLBACK`: backup/restore, BULK INSERT, the distributed database
  (`:r 11_distributed_demo.sql`), real sign-ins (account lockout). Case codes `Sxx`, registered in `#Expected` like in
  `12_tests.sql`, same summary table and `THROW 50099`.
- Real sign-ins go through the loopback linked servers `QLTTTA_T_LINK_*` (`#usp_SignIn`) as the temporary account
  `t_lockout` - never lock or change a demo account.
- Every scratch object is named `QLTTTA_T_...`/`t_...` and removed by `#usp_Cleanup` (run at the start and at the end).
  Paths come from `SERVERPROPERTY(...)` and the sqlcmd variables `DatabaseDir`/`CsvPath` (set by `test_all`), so the
  script runs on Linux/Docker and on Windows.

## Before saying "done"
- Run `scripts/test_all.sh` (or at least `ctest --preset ...` + `12_tests.sql` + `13_server_tests.sql`) and paste the
  real result.
- Suspect a "falsely green" test: break one line of code/SQL on purpose, the test must turn red, then revert.
- Do not delete or loosen the expectation of an existing test unless the specification really changed - say why in the
  report/PR.
