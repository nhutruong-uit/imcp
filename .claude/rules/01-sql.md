---
paths:
  - "database/**/*.sql"
---
# T-SQL rules (database/)

The grading focus of the course. `tst_conventions` (file checks) and `12_tests.sql` T28-T30 and T32 (catalog checks)
verify the marked (✔) rules automatically on every `test_all` / CI run.

## Compatibility and file layout
- ✔ **SQL Server 2012+** only: no `CREATE OR ALTER`, `DROP ... IF EXISTS`, `STRING_AGG`, `STRING_SPLIT`, `TRIM`,
  `CONCAT_WS`, `TRANSLATE`, JSON, `AT TIME ZONE`, row-level security, 2022 functions (`GREATEST`, `DATETRUNC`...).
  Re-runnable objects: `IF OBJECT_ID(N'dbo.x', N'P') IS NOT NULL DROP PROCEDURE dbo.x;` + `GO`, then `CREATE`.
- ✔ Every file starts with `USE QLTTTA; GO; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; GO` (server-level scripts -
  `00`, `09`, `11` - start with `USE master;`).
- The application never INSERTs/UPDATEs/DELETEs tables directly: every write goes through a procedure.
- Dynamic SQL only through `sys.sp_executesql` with parameters for values; identifiers that come from input are
  validated and wrapped in `QUOTENAME` (reference: `usp_Account_Create`, `usp_Account_Lock`); `EXECUTE AS OWNER`
  only where the caller needs rights it must not hold itself (accounts, backup).

## Language and naming (English)
- ✔ Everything is **English**: tables in UPPER_SNAKE_CASE (`STUDENT`, `CLASS_SESSION`), columns in PascalCase
  (`StudentId`, `EnrolledOn`), procedures `usp_<Entity>_<Verb>` (`usp_Student_Add`, `usp_Enrollment_Create`),
  functions `fn_` (`fn_FinalGrade`), views `vw_` (`vw_ClassDetails`, teacher views `vw_Teacher_My...`), triggers
  `trg_<TABLE>_<Purpose>` (`trg_RECEIPT_UpdateAmountPaid`), roles `rl_` (`rl_AcademicStaff`), comments in English.
  Constraints: `PK_<TABLE>`, `FK_<CHILD>_<PARENT>`, `CK_<TABLE>_<Column>`, `UQ_<TABLE>_...`, `DF_<TABLE>_<Column>`;
  indexes `IX_<TABLE>_...`, filtered unique indexes `UX_<TABLE>_...`; sequences `seq_<TABLE>` (checked by T28).
- Stored values are English text with the `N'...'` prefix (`N'Studying'`, `N'Bank transfer'`); codes without
  diacritics or spaces stay `VARCHAR` without `N` (`'MANAGER'`, `'PERCENT'`). Weekdays are ISO numbers
  (1 = Monday ... 7 = Sunday, `fn_Weekday`). People's names and addresses in the demo data stay Vietnamese
  (the database collation is `Vietnamese_CI_AS`).
- Business messages are English sentences (`THROW 50022, N'The student is already enrolled in this class.', 1;`).
  The application shows them in the UI language, so every new message is added to `kTemplates` in
  `src/infrastructure/db/DbMessages.cpp` (a message built from values becomes a template with `%1`, `%2`; keep each
  fixed part in one `N'...'` literal) and translated in `qlttta_vi.ts`. `tst_i18n` fails on an unregistered message.
- ✔ **Time** (`docs/DATABASE.md` section 7): an instant is a `DATETIME` column named `...Utc` holding UTC
  (`GETUTCDATE()`); a business date (`DATE`) is a day of the center (`dbo.fn_Today()`, offset in
  `dbo.fn_CenterUtcOffset`); convert with `fn_UtcToCenterTime` / `fn_CenterTimeToUtc` (filter a local day or month as
  a UTC range so the index on `...Utc` stays usable). Never `GETDATE()`, `SYSDATETIME()` or `CURRENT_TIMESTAMP`: the
  server's time zone depends on the machine (checked by T32 and `tst_conventions`).
- A new enumerated value displayed in the UI (new value in a `CHECK ... IN (...)`) needs an entry in `kEntries`
  (`src/presentation/common/DbValues.cpp`) and a Vietnamese translation (`tst_i18n` checks both); a new column shown
  in a list needs an entry in `kCatalog` (`src/presentation/common/Columns.cpp`).
- ✔ A new, renamed or removed table, column, foreign key or trigger is copied into the constants `TABLES`, `FKS` and
  `TRIGGERS` of `docs/data-map.html` in the same commit (checked by `tst_conventions`,
  `docs_dataMap_matchesScripts`); a new procedure step or app screen goes into its `STEPS` / `SCREENS` by hand.
  ✔ Renaming or dropping a procedure, view, function, trigger, constraint or index that the page names fails
  `docs_dataMapNames_existInScripts` until the page is updated.

## Format
- Keywords in **UPPERCASE** (`SELECT`, `JOIN`, `BEGIN TRY`), **4-space** indentation, every statement ends with `;`.
- ✔ Every procedure and trigger starts with `SET NOCOUNT ON;` (checked by T30).
- Always qualify the schema: `dbo.STUDENT`, `dbo.usp_Enrollment_Create`. Text values always use the `N'...'` prefix.
- Align parameters as in `usp_Student_Add`; optional parameters end with `= NULL`.
- Every object starts with **one comment line with its section code** (the groups of the file):
  `/* C5. usp_Enrollment_Cancel: cancel an enrollment, refund it when no session was attended */`.
  The header may continue with `Used by:`, `Rules:`/`Steps:` and `Concepts:` lines for readers who do not program
  (see `docs/CODE_TOUR.md`); inside the body, short numbered `--` comments before the non-obvious steps.
- Comments are read by tools too: never write a business message (`THROW 5xxxx, N'...'`), a `CHECK (Col IN (...))`
  list or a line with only `GO` inside a comment (`tst_i18n` scans the raw text; sqlcmd splits batches on `GO`).
  The report quotes some objects verbatim (`sql_object`/`sql_block` in `docs/report/content/`): explain those in
  the header before `CREATE`, or rebuild the report (`/imcp-update-report`) when their body changes.
- ✔ No `SELECT *` in procedures/views/functions (demo queries excepted; T30); never the `sp_` prefix.

## Template of a multi-step write procedure
```sql
/* C5. usp_Entity_Verb: <one-line description> */
IF OBJECT_ID(N'dbo.usp_Entity_Verb', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Entity_Verb;
GO
CREATE PROCEDURE dbo.usp_Entity_Verb
    @EntityId  VARCHAR(10),
    @Notes     NVARCHAR(200) = NULL,
    @NewId     VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Check the business rules first; English message (number from the group's range, see below)
    IF NOT EXISTS (SELECT 1 FROM dbo.ENTITY WHERE EntityId = @EntityId)
        THROW 50028, N'Entity not found.', 1;

    -- 2. Write the data in a transaction
    BEGIN TRY
        BEGIN TRANSACTION;
        ...
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
```
A procedure with a single write statement needs no TRY/TRANSACTION (like `usp_Student_Add`).

## THROW error-number ranges (one block of ten per procedure group - pick an unused number in the range)
| Group (section of 04_procedures.sql) | Range | | Group | Range |
|---|---|---|---|---|
| A. Students | 50001-50009 | | E. Attendance, grades, results | 50040-50049 |
| B. Classes, schedules, sessions | 50010-50019 | | F. Payroll | 50050-50059 |
| B6-B8. Class changes, slot removal | 50080-50089 | | I. Accounts | 50060-50069 |
| C. Enrollment, class transfer | 50020-50029 | | I7. Backup | 50070-50079 |
| D. Receipts | 50030-50039 | | J. Catalogs | 50090-50098 |
Every block is taken: a new group reuses a message of its own area or asks the team for a new range (50100...).
`50099` is reserved for the test scripts (`12_tests.sql`, `13_server_tests.sql`). Triggers use
`RAISERROR (N'...', 16, 1); ROLLBACK TRANSACTION;`. Numbers in use:
`grep -o "THROW 50[0-9]*" database/04_procedures.sql | sort -u`.

## Trigger template (always handle a SET of rows)
```sql
CREATE TRIGGER dbo.trg_TABLE_Purpose
ON dbo.TABLE_NAME
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(RelatedColumn) RETURN;         -- skip when the related column did not change
    IF EXISTS (SELECT 1 FROM inserted i JOIN ... WHERE <violation>)   -- join with inserted, NEVER a scalar variable
    BEGIN
        RAISERROR (N'<English message>.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO
```
Forbidden: `SELECT @x = Col FROM inserted` (reads a single row only), cursors inside triggers.

## Mandatory when adding/changing an object
1. `GRANT` to the right roles in `06_security.sql`. Business roles reach data through views/procedures (ownership
   chaining); table rights are limited to the permission matrix of T29 in `12_tests.sql` - a new table right means
   updating that matrix on purpose (and saying why in the PR).
2. A test case in `12_tests.sql` + its code and message pattern registered in `#Expected` (see `03-tests.md`); features
   that need server-level operations (backup, BULK INSERT, distributed, sign-in/lockout) go to `13_server_tests.sql`.
   New business messages: register them in `DbMessages.cpp` and translate them (see "Language and naming").
3. Re-run everything: `scripts/test_all.sh` (includes `db_init` from scratch) - not only the file you changed.
4. If the number of objects or content quoted in the report changes: run `/imcp-update-report`.
