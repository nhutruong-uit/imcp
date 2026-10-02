# General workflow for generating/changing code (applies to every team member)

Goal: whichever member asks Claude Code for work, the result has **the same structure, the same format and the same
kind of report**, so the team lead can merge it without rework and everyone can explain it at the oral defense.

## 1. Mandatory steps
1. **Understand the request**: which layer it belongs to (database / domain / application / infrastructure /
   presentation / tests / report). Read the rules for that file type in `.claude/rules/` and the **reference
   implementation** before writing:
   - Database: `usp_Student_Add` (`04_procedures.sql`), `trg_RECEIPT_UpdateAmountPaid` (`05_triggers.sql`)
   - C++: the Students module (`Student` → `IStudentRepository` → `StudentService` → `SqlStudentRepository` →
     `StudentPage`)
   - Tests: `tests/tst_application.cpp` (fake repository), `tests/tst_e2e_gui.cpp`, `tests/tst_i18n.cpp`,
     `database/12_tests.sql`, `database/13_server_tests.sql` (server-level)
2. **Follow the reference**: same naming, same file layout, same error handling. Do not invent a new style when a
   reference exists.
3. **Smallest scope**: change only what was asked. Do not rename/move files, reformat whole files or fix unrelated
   things "while you are there" - list them under "Suggestions" in the report instead.
4. **Format what you changed**: for C++ run `git clang-format` (formats changed lines only; do not run
   `clang-format -i` on whole existing files).
5. **Test**: add/update tests for the change (see `tests.md`) and run the related tests; before a PR run
   `scripts/test_all.sh` (Windows: `scripts\test_all.ps1`). Never change the expectation of an existing test to make
   it green.
6. **Report the result with the template in section 3.**

## 2. Shared conventions
- Talk to team members in **Vietnamese** (chat). Everything written in the repository - C++ identifiers, comments,
  CMake, scripts, CI, docs, the database (objects, columns, stored values, business messages, SQL comments) - is
  **English**; comments are short and explain *why*. Only the report (`docs/report/`) is Vietnamese.
- UI strings: English in `tr("...")`, translated to Vietnamese in `resources/translations/qlttta_vi.ts`; stored
  database values and database messages are translated there too (`DbValues`, `DbMessages`).
- Database naming (`STUDENT`, `usp_Enrollment_Create`, `StudentId`): see `sql.md`.
- Commit messages in English `type(scope): description` (feat, fix, test, docs, ci, refactor, chore), without AI
  attribution lines (`Co-Authored-By: Claude ...`);
  PRs in English through `/imcp-create-pr`.
- When `git status` shows changes that are not yours (someone/another session is working): do **not** `git add -A`,
  stash, checkout or reset. Commit **only your paths**: `git commit --only -m "..." -- <your files>`
  (a plain `git commit` takes the WHOLE staging area, including a `git mv` someone else staged), then check
  `git show --stat HEAD` before pushing and tell the user.
- Never put real passwords, `.env`, `build/`, `dist/` in a commit or an answer (the demo password in `docs/SETUP.md`
  is test data).
- Ask when an ambiguous request affects the database design or the permissions; otherwise follow the existing
  references and state your assumptions.

## 3. Result report template (end of every work session; written in Vietnamese in the chat)
```markdown
**Result:** <1-2 sentences: what was done>

| File | Change | Reason |
|---|---|---|
| `database/04_procedures.sql` | added `usp_...` | ... |

**Tests:** `<command that ran>` → <real result, e.g. "39/39 cases passed", "5/5 tests passed">; <what could not be
tested, and why>

**For the oral defense** (for the member who owns this part):
- <course concepts used: set-based trigger, ownership chaining, cursor...>
- <why this approach rather than another>

**Open items / decisions:** <work not done, suggestions, questions for the team lead>
```
Never write "tested" when nothing ran; paste the real numbers.

## 4. Definition of Done
- [ ] Follows the layer rules + the reference; no SQL outside `infrastructure/repositories`
- [ ] New database objects are GRANTed in `06_security.sql` and have a test case in `12_tests.sql` (+ `#Expected`)
- [ ] New use cases have unit tests; new screens are opened by the e2e test through `Permissions`
- [ ] New UI strings are in `tr()` and translated in `qlttta_vi.ts` (`tst_i18n` green)
- [ ] `git clang-format` clean; the build adds no warnings
- [ ] Tests were run and their real result reported; docs/report updated when the design changed
      (`/imcp-update-report`)
