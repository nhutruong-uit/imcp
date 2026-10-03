---
name: imcp-setup
description: Set up a team member's computer for the QLTTTA repo in one go - detects the OS (macOS or Windows), checks what is installed and installs only what is missing to implement, test and fix bugs (Qt toolchain, clang-format of the team version, SQL Server, VS Code extensions, git/GitHub checks), then initializes the database and runs the full test suite. Use right after cloning the repo, on a new machine, or when a build/test fails because a tool is missing ("setup máy", "cài môi trường", "cài công cụ", "/imcp-setup"). Optional arguments - check (report only, change nothing), notest (skip the test suite), msodbc (also Microsoft ODBC Driver 18).
---

# Set up a development machine (QLTTTA)

<!-- Note for the team: the work is done by scripts/setup_dev.sh (macOS) and scripts/setup_dev.ps1 (Windows), so the
     same setup also works without Claude Code. This skill runs them, asks for the decisions only the member can make
     and explains the result. -->

Goal: a member who has just cloned the repo can build, run every test (`scripts/test_all`) and open a PR the same
day, without installing each tool by hand. Talk to the user in **Vietnamese**.

## 1. Pick the script for this OS
Detect the OS with `uname -s` (`Darwin` = macOS; `MINGW*`/`MSYS*`/`CYGWIN*` or `$env:OS` = `Windows_NT` = Windows).

| OS | Script (from the repo root) | Options |
|---|---|---|
| macOS (Apple Silicon or Intel) | `./scripts/setup_dev.sh` | `--check`, `--accept-licenses`, `--with-msodbc`, `--skip-tests`, `--container <name>` |
| Windows 10/11 | `powershell -ExecutionPolicy Bypass -File scripts/setup_dev.ps1` | `-Check`, `-AcceptLicenses`, `-WithMsOdbc`, `-SkipTests`, `-Docker <name>`, `-Server <instance>` |
| Linux | not covered | say so; point to the "Full tests" job of `.github/workflows/ci.yml` and `docs/SETUP.md` |

The script does the work; do not install the tools one by one yourself. If a step of the script is wrong for this
machine, fix the script (both versions, `04-scripts-ci.md`) in a separate branch rather than working around it.

## 2. Check first (changes nothing)
Run the script with `--check` / `-Check` and show the `==== Summary ====` lines as a Vietnamese table
(Thành phần | Trạng thái | Chi tiết). `OK`, `INSTALLED` and `WARN` are fine; `MISSING`, `SKIPPED`, `ACTION` and
`FAILED` need attention. With the argument `check`, stop here and report (section 6).

## 3. Ask once before changing the machine
If something is `MISSING`, ask the user (AskUserQuestion, one question per decision), naming exactly what will change:
1. **Install what is missing?** List the missing items and the lasting changes: Homebrew or winget packages; `pipx`
   (adds `~/.local/bin` to PATH in the shell profile); Windows: Qt, MinGW, CMake and Ninja in `C:\Qt` plus the user
   variables `QT_ROOT_DIR` and `PATH`; macOS: a `.env` file with a generated sa password for `docker-compose.yml`; the
   VS Code extensions of `.vscode/extensions.json`. The test step **re-initializes the local QLTTTA database** (local
   data changes are lost).
2. **Licenses** - only when SQL Server (or Docker Desktop on macOS) is missing. The script installs them only with
   `--accept-licenses` / `-AcceptLicenses`: SQL Server 2022 Developer Edition (free, development and test use only)
   and, on macOS, Docker Desktop (Docker Subscription Service Agreement: free for personal use, education and small
   companies). Never pass the flag without a clear "yes" from this user in this session; the repository owner's
   acceptance for CI does not cover a member's machine. If the answer is no, run without it and point to the manual
   way (`docs/SETUP.md` section 1).
3. **Microsoft ODBC Driver 18** - optional, default no (also a Microsoft license): the app uses FreeTDS on macOS and
   the built-in "SQL Server" driver on Windows. Add `--with-msodbc` / `-WithMsOdbc` only when the user asked (`msodbc`)
   or wants the same driver as CI.

If nothing is missing, skip the questions and go on with the verify run (step 4 without install options); still say
that it re-initializes the local database.

## 4. Run
- The first run downloads a lot (Qt, SQL Server: 10-40 minutes). Create `build/setup/` (gitignored), run the script
  in the background with its output in `build/setup/setup.log`, then wait for the completion notification - do not
  poll:
  `./scripts/setup_dev.sh --accept-licenses > build/setup/setup.log 2>&1`
  (Windows: `powershell -ExecutionPolicy Bypass -File scripts/setup_dev.ps1 -AcceptLicenses > build/setup/setup.log 2>&1`).
  Add `--skip-tests` / `-SkipTests` for the argument `notest`.
- Windows: tell the user beforehand that installers show a UAC prompt (Git, sqlcmd, SQL Server) and they must click
  **Yes**; afterwards they need a **new terminal** (PATH and `QT_ROOT_DIR` changed).
- Read the Summary of the log, and the lines above any `FAILED`. Never print the sa password or the content of `.env`,
  never commit `.env`.

## 5. Handle what is left, then re-run
The script only installs what is missing, so re-run it after each fix until the summary says `Ready`.

| Summary line | What to do |
|---|---|
| `ACTION Homebrew` | the user installs it from https://brew.sh in their own terminal (it asks for their password) |
| `ACTION Xcode Command Line Tools` | the user finishes the install dialog that opened |
| `ACTION Docker Desktop` | open Docker Desktop once, accept its terms, enable *Settings > General > Use Rosetta for x86_64/amd64 emulation* |
| `ACTION git identity` | ask for the name and email, then run `git config --global user.name/user.email` with the user's OK |
| `ACTION GitHub CLI login` | the user runs `gh auth login --web --git-protocol https` (never handle tokens) |
| `ACTION SQL Server ... restart` (Windows) | restart Windows, then re-run |
| `ACTION Demo sign-in` (Windows) | the instance accepts Windows Authentication only: the user switches to mixed mode in SSMS (*server Properties > Security*) and restarts the service - a server security setting, so it is their decision |
| `FAILED ... port 1433` | another SQL Server uses the port: reuse it with `--container <name>` / `-Docker <name>`, or stop it |
| `FAILED scripts/test_all...` | read `build/test-results/` and the `docs/SETUP.md` Troubleshooting table; fix the cause, never a test |

Never do on the user's behalf: type or ask for passwords, run `sudo`, accept a license without their yes, change system
security settings (group membership, SQL Server authentication mode), run `gh workflow run`.

## 6. Report (Vietnamese, in the chat)
```markdown
**Kết quả:** <máy đã sẵn sàng / còn N việc> - <macOS/Windows, SQL Server: container `...` / instance `...`>

| Thành phần | Trạng thái | Ghi chú |
|---|---|---|
| Qt, CMake, Ninja, ODBC | OK | Qt 6.x (Homebrew) |

**Tests:** `<lệnh đã chạy>` → <dòng `ALL TESTS PASSED: ...` thật, hoặc bước bị lỗi>; <phần chưa chạy và vì sao>

**Việc bạn cần tự làm:** <các dòng ACTION còn lại, kèm lệnh>

**Bước tiếp theo:**
- Chạy app: <lệnh của máy này>; đăng nhập `ql_quan` (mật khẩu demo: `docs/SETUP.md`)
- Trước mỗi PR: <lệnh test_all của máy này, như dòng "Before every PR" của script>
- Đọc `AGENTS.md`, `docs/CONTRIBUTING.md`, `docs/ARCHITECTURE.md` (module mẫu: Students); xong việc dùng `/imcp-create-pr`
```
Paste the real result of the test suite; never write "tested" when it did not run.
