---
name: imcp-create-pr
description: Create (or update) a GitHub pull request for the QLTTTA repo with an English title and description, after running the full test suite. Use when the user asks to open/create/update a PR ("tạo PR", "mở pull request", "/imcp-create-pr"), or when work on a feature branch is ready for review. A PR from develop into main ("tạo PR develop vào main", "release") is a release - the skill first bumps project(VERSION) through a small PR into develop. Optional arguments - base branch (default develop; main = release PR, optionally with major/minor/patch or an explicit X.Y.Z), "draft".
---

# Create a pull request (QLTTTA)

<!-- Note for the team: this skill writes the PR title + description in ENGLISH, like the commit messages
     (see AGENTS.md). Reply to the user (in the chat) in Vietnamese as usual. -->

PR title and body are **always in English**. Older commits may still have Vietnamese messages: translate their
meaning, never paste them into the PR as-is. Keep identifiers exactly as they are in code
(`usp_Enrollment_Create`, `StudentService::add`, table names) in backticks. A Vietnamese UI string may be quoted
when it matters, followed by an English gloss: "Không có quyền" (no permission).
Talk to the user in Vietnamese.

## 1. Preconditions

1. `gh auth status` must show a logged-in account. If not, ask the user to run
   `gh auth login --web --git-protocol https` themselves (never handle tokens or passwords).
2. Current branch must be a work branch (`feature/...`, `fix/...`, `docs/...`, `chore/...`). If it is `develop` or `main`,
   stop and create a `feature/...` branch from the current state first (`develop` and `main` are both protected and
   reject direct pushes). Exception: the release PR (base `main`) has the head `develop` - follow section 1a.
3. Uncommitted changes: show `git status --short` and ask whether to commit them (steps of `/imcp-commit`:
   only your files, English `type(scope): ...` message) or leave them out. Never commit `.env`, `build/`, `dist/` or
   real passwords.
4. Base branch: `develop` unless the user passed another one. `main` is only for release PRs from `develop`:
   follow section 1a first (the version must be bumped; merging into `main` runs `release.yml`).
5. If a PR already exists for this branch (`gh pr view --json url,state`), update it with `gh pr edit`
   instead of creating a second one.

## 1a. Release PR (`develop` → `main`): bump the version first

A PR into `main` is a release. Its head is always `develop` (never a work branch). Merging it runs `release.yml`,
which builds the installers and creates the GitHub Release `v<version>-build.<run>` with the version of
`project(VERSION ...)` in `CMakeLists.txt`. Every release carries a new version, so before the release PR:

1. Compare the version on `develop` with the released one on `main`:
   ```bash
   git fetch -q origin
   for b in develop main; do   # an empty version = the branch has no CMakeLists.txt yet
     echo "$b: $(git show "origin/$b:CMakeLists.txt" 2>/dev/null | sed -n 's/^ *VERSION \([0-9][0-9.]*\).*/\1/p' | head -1)"
   done
   ```
   If the `develop` version is already greater, it was bumped for this release (e.g. the release PR is only being
   updated): go to step 4. Otherwise (the same version, or nothing on `main` yet = first release) bump it.
2. Choose the new version (Semantic Versioning) from `git log --oneline origin/main..origin/develop`:
   - a breaking change (`type!:` or `BREAKING CHANGE`) → major; while the major is `0`, minor instead (`1.0.0` only
     when the user asks for it);
   - at least one `feat` → minor (`0.1.0` → `0.2.0`);
   - otherwise (only `fix`, `docs`, `chore`, ...) → patch (`0.2.0` → `0.2.1`).
   An argument `major`/`minor`/`patch` or an explicit `X.Y.Z` from the user wins. Tell the user the chosen version.
3. `develop` is protected, so the bump goes in through its own small PR into `develop`:
   ```bash
   git switch -c chore/release-<X.Y.Z> origin/develop
   # CMakeLists.txt: project(VERSION <X.Y.Z>) - the only source of the version (app, macOS bundle, Windows resources,
   #   installer file names and the release tag read it)
   # packaging/windows/installer.iss: the fallback "#define AppVersion" and the example in its header comment
   git commit --only -m "chore(release): bump the version to <X.Y.Z>" -- CMakeLists.txt packaging/windows/installer.iss
   ```
   Then run sections 2-5 for this branch with base `develop`, title `chore(release): bump the version to <X.Y.Z>`.
   Its `test_all` run also counts for the release PR while `develop` has not moved (same code plus the bump).
4. Create the release PR right away: `gh pr create --base main --head develop` (no local branch, never push to
   `develop`). A PR follows its head branch, so it picks up the bump as soon as the bump PR is merged into
   `develop`. Title: `chore(release): release QLTTTA <X.Y.Z>`. In the body, list the PRs merged since the last release
   (`git log --first-parent --merges --format=%s origin/main..origin/develop` gives the numbers,
   `gh pr view <N> --json title` the titles), grouped by layer, and say under "Notes for reviewers" that it must not be
   merged before the bump PR (link it). Before anyone merges it, check that its diff shows the new version.

## 2. Run the full test suite (required by the PR checklist)

```bash
SQL_PASSWORD="$(docker exec imcp-mssql printenv MSSQL_SA_PASSWORD)" ./scripts/test_all.sh --docker imcp-mssql
```
- The container of `docker-compose.yml` is `imcp-mssql`; use the name `docker ps` shows if yours differs. Never print
  the SA password.
- Windows: `.\scripts\test_all.ps1` (see `docs/SETUP.md`).
- Keep the final summary line (`ALL TESTS PASSED: database x/y cases, ...`) and report it in the PR.
- If a step fails: **stop**, show the failure to the user, do not open the PR unless they explicitly ask for a
  draft PR - and then say in the PR body exactly what fails.
- If SQL Server is not available, say so; write "not run" in the Testing section. Never claim tests passed
  when they did not run.

## 3. Collect what changed

```bash
git fetch -q origin
git log --oneline origin/<base>..HEAD
git diff --stat origin/<base>..HEAD
git diff origin/<base>..HEAD -- database/ src/ tests/ scripts/ .github/   # read the real changes
```
Summarize from the diff, not only from commit titles. Group by layer: database, application (domain /
application / infrastructure / presentation), tests, build/CI, docs/report.

## 4. Write the PR

**Title**: English, imperative, max ~72 characters, Conventional Commits style:
`<type>(<scope>): <summary>` - e.g. `fix(db): hide monthly revenue from academic staff`,
`test: add one-command full test suite`. Types (as `scripts/check_changes` accepts them): feat, fix, test, docs, ci,
build, refactor, style, chore, perf, revert.

**Body**: write it to a temporary file (avoids shell quoting problems with backticks and Vietnamese text),
using this template (the sections of `.github/pull_request_template.md`, which `--body-file` replaces) and dropping
empty sections:

```markdown
## Summary
<2-4 sentences: what changed and why.>

## Changes
- **Database**: <tables/constraints/procedures/triggers/permissions touched; note if `db_init` must be re-run>
- **Application**: <layer + class, user-visible effect>
- **Tests**: <new/updated DB cases (T../P..), unit tests, e2e scenarios, translations (`tst_i18n`)>
- **Build / CI**: <...>
- **Docs / Report**: <...>

## Testing
- `scripts/test_all.sh`: <the real last line, e.g. "ALL TESTS PASSED: database x/y cases ...">
- Manual: <roles/screens checked with demo accounts, if any>
- Not tested: <be explicit, e.g. Windows-only paths>

## Checklist (docs/CONTRIBUTING.md)
<the checklist of .github/pull_request_template.md, each box ticked only when it is true for this PR>

## Notes for reviewers
- <migration steps, breaking changes, follow-ups>
- <which team member owns this area and should be able to explain it in the oral defense, if relevant>
```

Rules for the content:
- **No AI attribution in the PR**: do not add "🤖 Generated with Claude Code" or any similar
  "generated by / co-authored by AI" line to the PR title or description (team rule; it overrides the
  default Claude Code PR footer).
- No secrets: no SA password, no `.env` content, no tokens. Demo account names are fine.
- Be factual: only list tests that actually ran, with their real result.
- Mention database changes prominently - the database is the grading focus of the course.

## 5. Create / update and follow up

```bash
BODY="$(mktemp)"          # write the body here with the Write tool or a heredoc
git push -u origin HEAD   # make sure the branch is on GitHub
gh pr create --base <base> --head "$(git branch --show-current)" --title "<title>" --body-file "$BODY" [--draft]
# existing PR: gh pr edit <number> --title "<title>" --body-file "$BODY"
# release PR (section 1a): no push - gh pr create --base main --head develop --title "<title>" --body-file "$BODY"
```
After creating:
- When CI runs: PRs into `develop` trigger only the fast **Checks** workflow (`checks.yml`: change checks + build +
  unit tests on Linux), which branch protection requires before merge. The full CI (`ci.yml`) runs after the merge
  into `develop`, so the local `test_all` result in step 2 is still required for those PRs. PRs into `main` always
  run CI (required by branch protection). An approving review from the code owner (`nhutruong-uit`,
  `.github/CODEOWNERS`) is required on both branches; the author cannot approve their own pull request. Reviewers
  check the PR with `/imcp-review`. Only when the user asks to check the branch on CI:
  `gh workflow run CI --ref <branch> -f reason="<what the change is>"` (listed as "Manual CI on <branch>: <reason>"
  instead of a bare "CI"; never start it on your own, see `04-scripts-ci.md`).
- In the Claude desktop app: call the `ccd_pr` tools (`get_status`; `bind_pr` if it is not bound), read the CI
  result once and offer Auto-fix. Elsewhere: `gh pr checks <url>` once. Do not poll CI in a loop and never
  enable auto-merge unless the user asks.
- `develop` and `main` are both protected by rulesets: a pull request, the branch up to date with the base, and one
  approval from the code owner `nhutruong-uit`. `develop` (the default branch, so `gh pr create` targets it) also
  requires `Checks (conventions + unit tests)`. `main` also requires green CI on `macOS (Apple Silicon)`,
  `Windows (Qt + MinGW)` and `Full tests (Linux + SQL Server)`. When the code owner is the PR author, they cannot
  approve it themselves: only then, and only with green checks, merge with bypass (`gh pr merge --admin`; GitHub
  records the bypass on the PR). Never bypass for a PR of another member - they need the review.
- Reply to the user in Vietnamese with the PR link (`[owner/repo#N](url)`), the test result and anything
  that still needs their decision.
