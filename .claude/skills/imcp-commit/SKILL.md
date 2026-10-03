---
name: imcp-commit
description: Commit changes in the QLTTTA repo the team way - only your own files, on a work branch, checked for forbidden files and secrets, C++ lines formatted, related quick tests run, and an English Conventional Commits message that passes scripts/check_changes. Use when the user asks to commit ("commit", "tạo commit", "commit giúp", "lưu thay đổi", "/imcp-commit") or when a piece of work is finished and must be committed before a PR. Optional arguments - a hint for the message, "push" (push the branch afterwards), "amend" (fix the last commit while it is not pushed), "notest" (skip the related tests).
---

# Commit changes (QLTTTA)

<!-- Note for the team: this skill writes the commit message in ENGLISH (see AGENTS.md) and checks it with the same
     rules as scripts/check_changes. Reply to the user (in the chat) in Vietnamese as usual. -->

Goal: whoever commits, every commit has the same shape, contains only the files of one logical change and passes
`scripts/check_changes`, so the history stays readable at the oral defense and `/imcp-create-pr` has nothing to fix.
Talk to the user in **Vietnamese**; the commit message is **English**.

Never: `git add -A`, `git add .`, `git commit -a`, `git stash`, `git reset`, `git checkout -- <file>`, `--no-verify`,
a force push, a commit on `main`, or an amend of a commit that is already pushed.

## 1. Branch and files
1. `git branch --show-current`: on `develop` or `main`, create a work branch from the current state first
   (`git switch -c feature/<short-name>`, or `fix/`, `docs/`, `chore/`) and tell the user. One session = one branch.
2. `git status --short` and `git diff --stat`: decide which paths belong to this commit - the files changed in this
   session plus the ones the user names. Changes that are not yours (another session, the user's own work in
   progress) stay out; when unsure, list them and ask (AskUserQuestion). Read the real diff, not only the file names.
3. Never commit: `.env`, `build/`, `dist/`, `.claude/settings.local.json`, `CLAUDE.md` / `CLAUDE.local.md` (Claude Code
   would read them instead of `AGENTS.md`), IDE files (`*.user`, `.vscode/*` except the two shared files), Word lock
   files (`~$*`). If one shows up as untracked, it is missing from `.gitignore`: say so, do not commit it.
4. One commit = one logical change. If the paths cover unrelated purposes (e.g. a bug fix + a README edit), propose
   a split - a list of commits with their paths and messages - and ask. Keep together what must change together, so
   every commit builds and passes the tests:

| When the commit has | It also needs (same commit) |
|---|---|
| new or changed `tr("...")` strings | `resources/translations/qlttta_vi.ts` (`tst_i18n`) |
| a new database object | its GRANT in `database/06_security.sql` (+ T29 matrix) and its case in `12_tests.sql` / `13_server_tests.sql` + `#Expected` |
| a new `THROW` message or `CHECK ... IN` value | `DbMessages.cpp` / `DbValues.cpp` + the translation |
| a changed number of procedures, triggers, cases... | the docs that quote it (`tst_conventions`, `06-docs.md`) |
| a change to a `.sh` script | the same change in its `.ps1` twin (`04-scripts-ci.md`) |
| a new `.cpp` / `.h` file | its `CMakeLists.txt` entry |

## 2. Stage and check (only your paths)
```bash
git add -- <paths>                                   # new, changed and deleted files of this commit only
git diff --cached --stat -- <paths>
git diff --cached -U0 -- <paths> | grep -niE '^\+.*(password|passwd|pwd|secret|token|api[_-]?key)[^=]*[=:]'
```
- The grep only flags lines to read: the demo password of `docs/SETUP.md` (test data) and environment variable
  names (`SQL_PASSWORD`, `SQLCMDPASSWORD`) are fine. A real password, a key or `.env` content: stop, unstage it
  (`git restore --staged -- <file>`), tell the user without repeating the value.
- C++ files (`*.cpp`, `*.h`): format the changed lines only, never `clang-format -i` on a whole existing file:
  ```bash
  git clang-format --diff --extensions h,cpp -- <C++ paths>   # "did not modify any files" = OK
  git clang-format --extensions h,cpp -- <C++ paths> && git add -- <C++ paths>   # otherwise fix and re-stage
  ```
- If the user staged only part of a file on purpose (`git diff --cached` and `git diff` both show it), ask whether to
  commit only the staged part; then use a plain `git commit -F` (after checking that the index holds nothing else)
  instead of `--only` in step 4, which takes the whole file.

## 3. Related quick tests (skip with "notest"; the full `test_all` is the job of `/imcp-create-pr`)
Preset: `macos-debug` on macOS, `linux-debug` on Linux, `windows-debug` on Windows.

| Touched | Run |
|---|---|
| `src/`, `tests/`, `tools/`, CMake | `cmake --preset <p> && cmake --build --preset <p> && ctest --preset <p> -E e2e --output-on-failure` |
| `resources/translations/` only | the line above with `-R i18n` instead of `-E e2e` |
| `scripts/` | `bash -n <file>.sh`; `.ps1` with the `pwsh` parser; then `ctest --preset <p> -R conventions` |
| `database/` | needs SQL Server and **re-initializes the local database**: ask first, then run `scripts/test_all`; otherwise write "not run" |
| docs that quote database numbers | `ctest --preset <p> -R conventions` |
| other docs, `.claude/`, report sources | nothing beyond step 5 |

A failing test stops the commit: show the failure and fix the code, never the expectation of an existing test.

## 4. Message and commit
```
<type>(<scope>): <summary>

<body - optional for a small change: why, then what, wrapped at 72 characters>
```
- ✔ (`check_changes`) type is one of `feat fix test docs ci build refactor style chore perf revert`; scope is
  lowercase `[a-z0-9._-]+` and optional; subject is ASCII (English) and at most 100 characters; no AI attribution
  line (`Co-Authored-By: Claude`, "Generated with Claude Code") anywhere in the message.
- Summary: imperative, lowercase first word, no final period, aim for 72 characters - `add`, not `Added`/`adds`.
- Type: `feat` new behavior (app or database), `fix` bug, `test` tests only, `docs` docs/report/user guide/rules,
  `ci` workflows, `build` CMake/presets/packaging, `refactor` same behavior, `style` formatting only, `chore`
  tooling and config (`.claude/`, `.gitignore`, editor), `perf`, `revert`.
- Scope: the area most affected, as used in the history (`git log --format=%s -30`): `db`, `app`, a module name
  (`students`, `enrollments`), `report`, `user-guide`, `rules`, `claude`, `setup`, `tools`, `e2e`, `ci`, `build`.
  Leave it out when the change spans many areas.
- Body: English, identifiers exactly as in code (`usp_Enrollment_Create`), the reason a reviewer cannot read from the
  diff; `Closes #<n>` when the user names an issue. A Vietnamese UI string may be quoted with an English gloss.

Write the message to a temporary file (no shell quoting problems with backticks) and commit only your paths:
```bash
MSG="$(mktemp)"                                       # write the message here with the Write tool
git commit --only -F "$MSG" -- <paths>                # ignores whatever else is staged
git show --stat HEAD                                  # exactly the intended files?
```
"amend": only when `git branch -r --contains HEAD` prints nothing (not pushed) and HEAD is the commit just made for
this work - `git commit --amend --only -F "$MSG" -- <paths>` (no paths: reword only). Otherwise make a new commit.

## 5. Verify, push, report
1. `git fetch -q origin && ./scripts/check_changes.sh` (Windows: `.\scripts\check_changes.ps1`). A failure on the
   new commit: fix it (amend, not pushed yet). A failure caused by other commits or someone else's uncommitted
   files: report it, do not rewrite their work.
2. "push" or the user asks: `git push -u origin HEAD` (never `--force`, never `develop`/`main`). Otherwise do not
   push. Suggest `/imcp-create-pr` when the branch is ready for review.
3. Report in Vietnamese:
```markdown
**Commit:** `<short hash>` `<subject>` trên nhánh `<branch>` (<đã push / chưa push>)

| File | Thay đổi |
|---|---|
| `database/04_procedures.sql` | thêm `usp_...` |

**Kiểm tra:** check_changes <kết quả>; <test đã chạy> → <kết quả thật> hoặc "không chạy - <lý do>"
**Không đưa vào commit:** <đường dẫn + lý do (việc của phiên khác, file cấm...)> hoặc "không có"
**Bước tiếp:** <commit tiếp theo khi tách / push / `/imcp-create-pr`>
```
Never write that a test passed when it did not run. When the commit ends a work session, the session report of
`00-general-workflow.md` section 3 still applies.
