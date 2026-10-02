---
paths:
  - "docs/*.md"
  - "README.md"
  - "CLAUDE.md"
  - ".claude/**/*.md"
  - ".github/*.md"
---
# Rules for the repository docs (docs/*.md, README, CLAUDE.md, rules and skills)

The report (`docs/report/`) has its own rules (`05-report.md`). Everything here is **English**.

## Which doc to update
| Change | Doc |
|---|---|
| Database object, constraint, test case, demo script | `docs/DATABASE.md` (feature table, numbers) |
| Layer, pattern, driver behavior, new module recipe | `docs/ARCHITECTURE.md` |
| Command, environment variable, tool to install, test step, CI job | `docs/SETUP.md` (+ `CLAUDE.md` "Common commands") |
| Team workflow, branches, PR checklist, required checks | `docs/CONTRIBUTING.md` (+ `.github/pull_request_template.md`) |
| Repository layout | `README.md` |
| A convention | the numbered rule of its area in `.claude/rules/` - never only in `CLAUDE.md` |

## One fact in one place
- `CLAUDE.md` keeps the cross-cutting rules and pointers; the details live in the numbered rule files. When a fact
  must appear in several files (e.g. a command in `SETUP.md` and `CLAUDE.md`), change every copy in the same commit.
- Rule files are numbered in reading order (`00-` always applies, the others have `paths:` frontmatter). Mark a rule
  that a test or script checks with ✔ and name the check, so the reader knows it is enforced.
- ✔ Numbers about the database (procedures, triggers, views, functions, constraints, test cases, the
  `ALL TESTS PASSED` line) are checked by `tst_conventions` (`docs_databaseNumbers_matchScripts`): update them with the
  scripts. Do not add new hand-maintained counts elsewhere (e2e scenarios, lines of code) - describe instead, or add
  the count to that test.

## Style
- Short sentences, imperative for instructions; identifiers, paths and commands in backticks; relative links
  (`[SETUP.md](SETUP.md)`).
- Lines of at most 120 characters (tables and long commands excepted); a hyphen ` - ` as dash (no em dash).
- Commands must run as written (copy-paste), with the same flags as the scripts; never a real password (the demo
  password of `docs/SETUP.md` is test data).
