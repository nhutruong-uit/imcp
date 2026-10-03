---
name: imcp-review-codebase
description: Review the whole QLTTTA code base (or only what changed since the last codebase review) for clean code, clean architecture, database design, hard-coded values, bugs, docs and fit with the course context - automated checks first, one checklist per area, every finding verified - then record the review in docs/reviews/ and move the "last reviewed commit" marker so the next review starts from there. Use when the user asks to review/audit the code base rather than one PR ("review code base", "review toàn bộ code", "rà soát dự án", "audit", "/imcp-review-codebase"). Arguments - "full" (ignore the marker, review everything), "since <commit>", area filters (db, cpp, tests, scripts, docs, report), "fix" (fix the findings on a new branch), "mark" (only move the marker after a merged review).
---

# Review the code base (QLTTTA)

<!-- Note for the team: /imcp-review checks ONE pull request or branch; this skill audits the code base and keeps a
     marker (docs/reviews/LAST_REVIEWED) so a later run reviews only the commits that came after it. -->

Goal: a periodic audit that checks the same things in the same order and never reviews the same commit twice. Talk
to the user in **Vietnamese**; everything written in the repository (review log, fixes, commits, PR) is **English**.

Never review, fix or commit in the user's working tree (other sessions may have uncommitted work there), never push to
`develop`/`main`, never start a manual CI run, and never approve or merge.

## 1. Scope - what has not been reviewed yet
```bash
git fetch -q origin
git show origin/develop:docs/reviews/LAST_REVIEWED   # the marker as the team sees it (merged into develop)
BASE=$(git show origin/develop:docs/reviews/LAST_REVIEWED | sed -n 's/^commit: *//p')
git cat-file -e "$BASE^{commit}" && echo "marker ok"
git log --oneline --no-merges "$BASE"..origin/develop -- . ':(exclude)docs/reviews'
git diff --stat "$BASE" origin/develop -- . ':(exclude)docs/reviews'
```
- The marker names the **last commit covered by a review** (the tip of the previous review branch). A tree diff from it
  to `origin/develop` is exactly what nobody has reviewed yet, whether the review PR was merged or squashed.
- Nothing listed: say "không có commit mới kể từ lần review `<short hash>` ngày `<date>`" and stop (unless "full").
- "full", "since <commit>", or a missing/unknown marker: review every tracked file (or the diff from that commit).
- Read the open items of the last log (`docs/reviews/<date>-codebase.md`, rows with the Status `Deferred`): they are
  still open and are re-checked, not re-discovered.
- Out of scope: generated files (`docs/report/*.docx|pdf`, `docs/report/data/*`, `docs/user-guide/*.docx|pdf`,
  images, `qlttta_vi.ts` - checked by `tst_i18n` only), `build/`, `dist/`.

## 2. Workspace - a worktree on a new branch
```bash
DATE=$(date +%Y-%m-%d)
git worktree add -b "fix/codebase-review-$DATE" ".claude/worktrees/codebase-review-$DATE" origin/develop
git -C ".claude/worktrees/codebase-review-$DATE" branch --unset-upstream   # pushes go to its own branch
```
Work only inside the worktree (`.claude/worktrees/` is gitignored). Without "fix" the branch only gets the review log
and the marker.

## 3. Automated checks first (report the real output)
1. `./scripts/check_changes.sh origin/develop` - format of changed C++ lines, commit messages, forbidden files.
2. Build from scratch and list the warnings: `cmake --preset <p> && cmake --build --preset <p> --clean-first 2>&1 |
   grep 'warning:' | sort | uniq -c` (macOS: add `-DCMAKE_OSX_SYSROOT=<Xcode SDK>` if CMake reports a broken compiler).
3. `ctest --preset <p> -E e2e --output-on-failure` (`tst_conventions`, `tst_i18n`, unit tests).
4. Database in scope: `scripts/test_all` re-initializes the local database - ask before running it the first time.
   The SQL Server container may be shared with other sessions (their `test_all` re-creates `QLTTTA` under yours):
   look at `sys.dm_exec_sessions` first, or propose a private container for the run (same image, another port,
   `SQL_SERVER=localhost,<port>` so the end-to-end test uses it too) and remove it at the end.
5. Scripts in scope: also `pwsh -File scripts/test_all.ps1 ...` - CI runs both versions.
A failing check is a finding by itself; do not repeat what the check message already says.

## 4. Review per area (read the rule file of the area first)
For a full review, run one read-only subagent per area in parallel (Agent tool, `general-purpose`), each told to read
the rule file, verify every finding in the code and return `severity, file:line, problem, failure scenario, fix,
confidence`. For an incremental review, read the diff of each area yourself
(`git diff "$BASE" origin/develop -- <area>`) and open the surrounding code: a change can break a caller that did
not change.

| Area | Rules | Check |
|---|---|---|
| Database design (`01`-`03`, `06`, `07`) | `01-sql.md` | normal forms and stored derived columns (each one maintained by a trigger and tested), keys and sequences, data types and lengths, `NULL`/`DEFAULT`/`CHECK`/`FK`/`UNIQUE` that the business rules of `docs/DATABASE.md` section 6 need, indexes for FK joins and filters, views without duplicate rows, sargable predicates, least-privilege GRANT/DENY (T29 matrix), time rules (`...Utc`, `fn_Today`) |
| Database logic (`04`, `05`, `08`-`13`) | `01-sql.md`, `03-tests.md` | business logic and boundary dates, `NULL` handling, money rounding, check-then-write races (`UPDLOCK, HOLDLOCK`), `SET XACT_ABORT ON` + rollback in multi-step writes, set-based triggers, dynamic SQL with `sp_executesql` + `QUOTENAME`, `THROW` numbers in the group range and registered in `DbMessages.cpp`, test cases that really compare a result, loose `#Expected` patterns, date-dependent (flaky) cases |
| C++ architecture (`src/`) | `02-cpp-qt.md`, `docs/ARCHITECTURE.md` | dependency direction, database names or SQL outside `infrastructure`, business rules duplicated or living in pages, god classes, ports that fit the use cases |
| C++ clean code and bugs (`src/`, `tools/`) | `02-cpp-qt.md` | `Result<T>` on every error path, `execPrepared`/`stringOrNull`, null `QVariant`, UTC instants shown with `Format::dateTime`, ownership/parents, signals connected twice, model/proxy row mapping, duplicated code, dead code, magic numbers, colors outside `Theme`, every visible string in `tr()`, no logic on displayed text |
| Tests (`tests/`, `12`/`13`) | `03-tests.md` | each use case and rule has a test that fails when the code is broken, fakes behave like the real repository, e2e restores its data and waits with `QTRY_*`, names `subject_condition_expectedResult` |
| Scripts / CI (`scripts/`, `.github/`) | `04-scripts-ci.md` | `.sh`/`.ps1` parity, `set -euo pipefail`, exit codes not swallowed by pipes, passwords only in environment variables, hard-coded container names/versions, PowerShell 5.1 syntax, CI job names, steps that can pass silently |
| Docs (`README.md`, `AGENTS.md`, `docs/*.md`, `.claude/`) | `06-docs.md` | every path, command, flag, class and object name exists (grep it), numbers match (`tst_conventions`), one fact in one place, English, fits a student course project and the oral defense |
| Report / user guide sources | `05-report.md` | no hand-typed numbers from the database, names quoted from the code still exist, Vietnamese text |

Hard-coded values: a value in logic that belongs to a table, a parameter, a setting or one named constant (server
names, ports, credentials, IDs, rates, limits, paths). Demo seed data and test fixtures are not hard-coding.
"Fits the context": the IE103 syllabus (`docs/DATABASE.md` section 5), SQL Server 2012+, a team that must explain
every statement - flag code that is clever where the pattern of the reference module is simpler.

**Verify before reporting.** Every subagent finding is re-read in the code by you: confirm it, downgrade it or drop
it. Check that no constraint, trigger, test or doc elsewhere already handles it. A finding without a `file:line` and a
concrete fix is not reported.

## 5. Report and log
Severity: **Phải sửa** (wrong result, data integrity, security, broken rule or test), **Nên sửa** (design weakness,
missing test/constraint/index, stale doc), **Gợi ý** (optional). Chat report (Vietnamese):
```markdown
**Phạm vi:** <full | `<base>`..`<head>`: n commit, m file> · **Kiểm tra tự động:** check_changes <..>; build <x warnings>; unit <x/y>; test_all <.. hoặc "không chạy - lý do">

| # | Mức độ | Khu vực | File:dòng | Vấn đề | Đề xuất |
|---|---|---|---|---|---|
| 1 | Phải sửa | Database | `database/04_procedures.sql:120` | ... | ... |

**Điểm tốt:** <what to keep doing> · **Không sửa / để sau:** <finding + reason>
```
Write the same findings in English to `docs/reviews/<DATE>-codebase.md` (template: the newest log in that folder):
scope (base and head commits), automated results, the findings table with a **Status** column (`Fixed in <hash>`,
`Deferred - <reason>`, `Won't fix - <reason>`), what is done well. Deferred items stay listed until a later review
closes them.

## 6. Fix ("fix", or when the user agrees after the report)
- One commit per area or logical change, through the steps of `/imcp-commit` (only your paths, English message);
  follow the reference implementations of `00-general-workflow.md`.
- Every fixed bug gets a test that fails without the fix (`12_tests.sql` case + `#Expected`, unit test, or
  `tst_conventions` slot for a convention). Never loosen an existing expectation; a changed specification is
  explained in the log and the PR.
- Keep the scope: a fix that needs a design decision of the team (new table, permission change, behavior users will
  notice) is reported and deferred, or asked about (AskUserQuestion) - not decided alone.
- Database fixes keep the docs that quote numbers in step (`tst_conventions`), the report sources when quoted objects
  change (`/imcp-update-report` afterwards) and the user guide when users notice the change (`/imcp-update-guide`).
- Run `scripts/test_all` before the last commit and paste the real summary line.

## 7. Mark the reviewed commits (always the last commit of the branch)
1. Fill the Status column of the log with the fix commit hashes (`git log --oneline origin/develop..HEAD`).
2. Write `docs/reviews/LAST_REVIEWED` with the **current HEAD of the branch** (the last fix commit, or `origin/develop`
   when nothing was fixed) - the commit that will contain the marker cannot name itself, and it only touches
   `docs/reviews/`, which the scope command excludes:
   ```
   commit: <full hash of HEAD>
   develop: <full hash of origin/develop that was reviewed>
   date: <DATE>
   log: docs/reviews/<DATE>-codebase.md
   ```
3. Add a row to the history table of `docs/reviews/README.md`, then commit only `docs/reviews/`:
   `docs(reviews): record the codebase review of <DATE>`.
4. Never write the marker after merging `develop` into the review branch: the merged commits were not reviewed and
   would become ancestors of the marker. Update the branch (conflicts) only after the marker commit.
5. "mark" alone (the review was done elsewhere): only steps 2-3 on a `docs/...` branch from `origin/develop`.
6. Open the PR with `/imcp-create-pr` (it runs `test_all`). The marker becomes the team's baseline once the PR is
   merged into `develop`; until then the next run still starts from the old marker on `origin/develop`.

Finish with the session report of `00-general-workflow.md` section 3 (Vietnamese), listing the deferred findings under
"Open items / decisions".
