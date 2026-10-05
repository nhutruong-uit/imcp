---
name: imcp-review
description: Review a pull request or branch of the QLTTTA repo against the team rules (.claude/rules) the same way every time - automated checks first, then the checklist of every area the change touches, reported with a fixed template. Use when the team lead or a member asks to review a PR/branch ("review PR", "xem PR", "duyệt PR", "/imcp-review"). Arguments - PR number/URL or branch name (default - the current branch against develop); add "comment" to post the review on GitHub.
---

# Review a change against the team rules (QLTTTA)

<!-- Note for the team: this skill reviews ONE pull request or branch; /imcp-review-codebase audits the whole code
     base from the last reviewed commit on (docs/reviews/). -->

Goal: whoever reviews, the same rules are checked in the same order and the result has the same format, so members
get consistent feedback and the code stays in one style. Talk to the user in **Vietnamese**; a review posted on
GitHub is written in **English**.

Never approve, merge, push, start a manual CI run (`gh workflow run`) or post on GitHub unless the user asks for it.

## 1. Get the change (without touching the user's working tree)
- PR: `gh pr view <n> --json number,title,baseRefName,headRefName,author,files,commits,body` and `gh pr diff <n>`.
- Branch: `git fetch origin` then `git diff origin/develop...<branch>` and `git log --oneline origin/develop..<branch>`.
- To run checks, use a temporary worktree:
  `git worktree add --detach "<scratch>/review-<n>" <head>` (for a PR: `git fetch origin pull/<n>/head` first),
  and remove it at the end (`git worktree remove --force ...`). Never `checkout`/`stash`/`reset` in the user's tree.

## 2. Automated checks (in the worktree; report the real output)
1. `./scripts/check_changes.sh origin/<base>` - format of the changed C++ lines, commit messages, forbidden files.
2. Build + unit tests: `cmake --preset <preset> && cmake --build --preset <preset> &&
   ctest --preset <preset> -E e2e --output-on-failure` (includes `tst_conventions`, `tst_i18n`).
3. Database or e2e changes: the full `scripts/test_all` needs SQL Server and **re-initializes the local database** -
   ask the user before running it. Otherwise say it was not run and rely on the author's pasted result.
A failing check is a finding by itself (severity "must fix"); do not repeat what the check already explains.

## 3. Checklist per area (read the rule file of every touched area first)
- **Database** (`01-sql.md`): SQL Server 2012 syntax, file header, `IF OBJECT_ID ... DROP` + `GO`, naming
  (T28), triggers handle sets (no `SELECT @x = ... FROM inserted`), `THROW` number in the group's range and the
  message registered in `DbMessages.cpp` + translated, GRANT in `06_security.sql` and the T29 matrix, writes only
  through procedures, dynamic SQL with `sp_executesql` parameters / `QUOTENAME`, no `SELECT *`.
- **C++ / Qt** (`02-cpp-qt.md`): layer of each new file and the 7 parts of a module, `Result<T>` instead of
  exceptions, `execPrepared` + `stringOrNull`, every user-visible string in `tr()` and translated, no logic on
  displayed text, `objectName`/`testId` for widgets the tests use, colors only in `Theme`.
- **Tests** (`03-tests.md`): a unit test with a fake repository for a new use case, a DB case (+ `#Expected` with the
  right message pattern) for a new rule, e2e restores its data, test names `subject_condition_expectedResult`.
  Look for **weakened expectations**: changed/removed `#Expected` patterns, `QCOMPARE`/`QVERIFY` values, skipped
  cases - only acceptable when the specification changed and the PR says so.
- **Scripts / CI** (`04-scripts-ci.md`): `.sh` and `.ps1` changed together, BOM + CRLF, passwords only through
  environment variables, CI job names unchanged, no new component with its own EULA.
- **Docs** (`06-docs.md`, `05-report.md`): the docs of the table "Which doc to update" follow the change, numbers
  updated, commands runnable; report content changed through `docs/report/content/*.py` only.
- **Git / scope**: English Conventional Commits, no AI attribution, no secrets or build output, no unrelated changes
  ("while I was there" edits belong in another PR).
- **Oral defense**: could the owner of the area explain every statement? Flag code that is clever where a simpler
  pattern of the reference module exists.

## 4. Report (Vietnamese, in the chat)
```markdown
**Kết luận:** <Approve / Request changes / Comment> - <1 câu lý do>

**Kiểm tra tự động:** check_changes <kết quả>; build + unit <x/y passed>; test_all <kết quả hoặc "không chạy - lý do">

| Mức độ | File:dòng | Rule | Vấn đề | Đề xuất |
|---|---|---|---|---|
| Phải sửa | `database/04_procedures.sql:120` | 01-sql.md - triggers handle sets | ... | ... |

**Điểm tốt:** <what follows the rules well, so the author keeps doing it>
**Câu hỏi cho tác giả:** <decisions the reviewer cannot make>
```
Severity: **Phải sửa** (breaks a rule or a test, wrong result, security), **Nên sửa** (convention, readability,
missing doc), **Gợi ý** (optional). Every finding names the rule file and points to a line; no finding without a
concrete fix.

## 5. Posting on GitHub (only when the user asks - "comment")
Write the same findings in English to a temporary file and post one review:
`gh pr review <n> --comment --body-file <file>` (`--request-changes` only if the user says so). Never `--approve`
or merge on your own; in the Claude desktop app, prefer the `ccd_pr` tools to read CI status once.
