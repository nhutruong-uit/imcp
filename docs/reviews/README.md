# Codebase reviews

A codebase review audits the whole repository (or only what changed since the previous review) for clean code,
clean architecture, database design, hard-coded values, bugs, docs and fit with the course context. It is run with
the Claude Code skill `/imcp-review-codebase` (`.claude/skills/imcp-review-codebase/SKILL.md`); a single pull request
is reviewed with `/imcp-review` instead.

## Files in this folder

| File | Content |
|---|---|
| `LAST_REVIEWED` | The marker: the last commit covered by a review, the `develop` commit that was reviewed, the date and the log |
| `<date>-codebase.md` | The log of one review: scope, automated results, every finding with its status, what is done well |

## How the marker works

`LAST_REVIEWED` names the tip of the last review branch (its fixes included). Everything that is an ancestor of that
commit has been reviewed, so the next review only looks at the difference between that commit and `develop`:

```bash
BASE=$(git show origin/develop:docs/reviews/LAST_REVIEWED | sed -n 's/^commit: *//p')
git log --oneline --no-merges "$BASE"..origin/develop -- . ':(exclude)docs/reviews'
git diff --stat "$BASE" origin/develop -- . ':(exclude)docs/reviews'
```

- The diff compares two trees, so it is right whether the review PR was merged or squashed.
- The commit that writes the marker only touches `docs/reviews/`, which the commands above leave out.
- The marker counts once the review PR is merged into `develop`; until then the next review starts from the old one.
- A finding marked `Deferred` in a log stays open: the next review checks it again until a log closes it.

## History

| Date | Reviewed `develop` | Marker (last reviewed commit) | Log | Fix PR |
|---|---|---|---|---|
| 2026-10-03 | `024144d` | see `LAST_REVIEWED` | [2026-10-03-codebase.md](2026-10-03-codebase.md) | branch `fix/codebase-review` |
