---
paths:
  - "docs/*.md"
  - "README.md"
  - "AGENTS.md"
  - ".claude/**/*.md"
  - ".github/*.md"
---
# Rules for the repository docs (docs/*.md, README, AGENTS.md, rules and skills)

The report (`docs/report/`) and the user guide (`docs/user-guide/`) have their own rules (`05-report.md`).
Everything here is **English**.

## Which doc to update
| Change | Doc |
|---|---|
| Database object, constraint, test case, demo script | `docs/DATABASE.md` (feature table, numbers) |
| Table, column, foreign key, trigger, business step, app screen | `docs/data-map.html` (constants at the top of its script) |
| Layer, pattern, driver behavior, new module recipe | `docs/ARCHITECTURE.md` |
| Command, environment variable, tool to install, test step, CI job | `docs/SETUP.md` (+ `AGENTS.md` "Common commands") |
| Team workflow, branches, PR checklist, required checks | `docs/CONTRIBUTING.md` (+ `.github/pull_request_template.md`) |
| Repository layout | `README.md` |
| A flow, layer or business rule that a non-programmer must be able to follow (who checks what, which test) | `docs/CODE_TOUR.md` (sections 5-6) |
| A convention | the numbered rule of its area in `.claude/rules/` - never only in `AGENTS.md` |

## One fact in one place
- `AGENTS.md` keeps the cross-cutting rules and pointers; the details live in the numbered rule files. When a fact
  must appear in several files (e.g. a command in `SETUP.md` and `AGENTS.md`), change every copy in the same commit.
- Rule files are numbered in reading order (`00-` always applies, the others have `paths:` frontmatter). Mark a rule
  that a test or script checks with ✔ and name the check, so the reader knows it is enforced.
- ✔ Numbers about the database (procedures, triggers, views, functions, constraints, test cases, the
  `ALL TESTS PASSED` line) are checked by `tst_conventions` (`docs_databaseNumbers_matchScripts`): update them with the
  scripts. Do not add new hand-maintained counts elsewhere (e2e scenarios, lines of code) - describe instead, or add
  the count to that test.
- ✔ `docs/data-map.html` copies the schema into its constants `TABLES`, `FKS` and `TRIGGERS`; `tst_conventions`
  (`docs_dataMap_matchesScripts`) compares them with `01_tables.sql` and `05_triggers.sql`. The page computes its
  counts from these constants - never type a count into it.
- ✔ The business flow and app flow of `docs/data-map.html` are written by hand, but `tst_conventions` checks their
  skeleton: every `usp_`/`vw_`/`fn_`/`trg_`/`seq_`/`CK_`/`UQ_`/`UX_`/`IX_` name exists in `database/01-05`
  (`docs_dataMapNames_existInScripts`) and `SCREENS` is the menu of `Permissions::allowedFeatures` with the names
  of `Labels::feature` (`docs_dataMapScreens_matchPermissions`). Whether an explanation is still right is up to
  the author and the reviewer.

## Style
- Short sentences, imperative for instructions; identifiers, paths and commands in backticks; relative links
  (`[SETUP.md](SETUP.md)`).
- Lines of at most 120 characters (tables and long commands excepted); a hyphen ` - ` as dash (no em dash).
- Commands must run as written (copy-paste), with the same flags as the scripts; never a real password (the demo
  password of `docs/SETUP.md` is test data).
