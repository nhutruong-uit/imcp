<!--
  Write the PR in English (title: "type(scope): summary", e.g. "fix(db): hide monthly revenue from academic staff").
  With Claude Code, /imcp-create-pr fills this template for you. Delete the sections that do not apply.
-->
## Summary
<!-- 2-4 sentences: what changed and why. -->

## Changes
- **Database**: <!-- tables/constraints/procedures/triggers/permissions touched; say if db_init must be re-run -->
- **Application**: <!-- layer + class, user-visible effect -->
- **Tests**: <!-- new/updated DB cases (Txx/Pxx/Sxx), unit tests, e2e scenarios, translations -->
- **Build / CI**:
- **Docs / Report**:

## Testing
- `scripts/test_all.sh` (Windows: `scripts\test_all.ps1`): <!-- paste the real last line: "ALL TESTS PASSED: database x/y cases ..." -->
- Manual: <!-- roles/screens tried with the demo accounts, Vietnamese and English -->
- Not tested: <!-- be explicit, e.g. Windows-only paths -->

## Checklist (docs/CONTRIBUTING.md)
- [ ] `test_all` reports **ALL TESTS PASSED** (change checks, database, server-level, unit incl. `tst_conventions` and translations, end-to-end)
- [ ] Database changes: `06_security.sql` updated (and the permission matrix of `T29`), new rules have cases in `12_tests.sql` / `13_server_tests.sql` (+ `#Expected`), new messages in `DbMessages.cpp`
- [ ] New UI strings translated in `resources/translations/qlttta_vi.ts`
- [ ] Commit messages in English, `type(scope): summary`, no AI attribution lines
- [ ] Docs/report updated if the design or a number they quote changed

## Notes for reviewers
<!-- migration steps, follow-ups, which member owns this area for the oral defense -->
