# Environment setup guide

There are three levels of use; pick the one that fits you:

| Level | Who | What to install |
|---|---|---|
| A. Try it out / grading | Instructor, non-programming members | SQL Server + the QLTTTA installer (GitHub Releases) |
| B. Work with the database | Every member (presenting the database part) | SQL Server + SSMS or VS Code (mssql extension) |
| C. Develop the application | Team lead (+ Claude Code) | Level B + Qt 6, CMake, Ninja, an ODBC driver |

---

## 1. SQL Server and database initialization (required for every level)

### Windows
1. Install **SQL Server 2022 Developer** or **Express** (free) and **SSMS**.
2. Initialize the database in one of two ways:
   - PowerShell in the repo folder: `.\scripts\db_init.ps1` (Windows Authentication), or
     `.\scripts\db_init.ps1 -Server "localhost\SQLEXPRESS"` for the Express edition. SQL Server authentication:
     `-User sa -Password "<password>"` (or set `$env:SQL_PASSWORD`); sqlcmd inside a Docker container: `-Docker sql2022`.
   - Or open SSMS and run `database/00_create_database.sql` → `07_seed_data.sql` in order
     (SQLCMD Mode under *Query > SQLCMD Mode* is not required).

### macOS (Apple Silicon) / Linux
SQL Server runs in Docker:
1. Install Docker Desktop and enable *Settings > General > Use Rosetta for x86_64/amd64 emulation*.
2. Create a `.env` file in the repo root: `MSSQL_SA_PASSWORD=<strong password>`, then run `docker compose up -d`
   (this means you accept the SQL Server Developer Edition license terms). The container is named `imcp-mssql` and is
   set to the Vietnam time zone.
3. Initialize the database (uses the `sqlcmd` that is already inside the container):
   ```bash
   SQL_PASSWORD='<sa password>' ./scripts/db_init.sh --docker imcp-mssql
   ```
   Without Docker, drop `--docker ...` to use a `sqlcmd` installed on your machine (`SQL_SERVER` defaults to
   `localhost,1433`, `SQL_USER` to `sa`). In the examples elsewhere, `sql2022` is simply the name of another local
   container; use whatever name `docker ps` shows.
4. To view/run SQL: VS Code + the **SQL Server (mssql)** extension, connect to `localhost,1433` as user `sa`.

> The scripts are compatible with SQL Server **2012 and later** (no `CREATE OR ALTER`, `STRING_AGG`, ...).
> Seed data uses dates **relative to the day you run it**, so re-run `db_init` before a demo to get classes in
> progress, revenue for the current month, etc.

### Demo accounts (shared password: `Demo@2026`)

| Username | Role | Can see |
|---|---|---|
| `ql_quan` | Manager | Everything: students, classes, balances, revenue, payroll, accounts |
| `gvu_lan` | Academic staff (Quận 1 branch) | Students, classes, schedule, results, balances (no payroll/revenue) |
| `gvu_ha` | Academic staff (Thủ Đức branch) | Same as above |
| `kt_minh` | Accountant | Students (read-only), balances, revenue, payroll |
| `kt_tung` | Accountant | Same as above |
| `gv_john`, `gv_hoanganh`, `gv_hoa`, `gv_bao` | Teacher | Only their own classes, teaching schedule and pay |

These are real **SQL Server users** (contained database users), so you can also sign in with SSMS
(*Options > Connection Properties > Connect to database: QLTTTA*) to demonstrate authorization.
Change the passwords immediately if you ever deploy this for real. What each role may do in the database is
summarized in [DATABASE.md](DATABASE.md#4-roles-and-permissions).

---

## 2. Running the application from the installer (level A)

Download the files from the repo's **Releases** page (the instructor is invited as a collaborator so they can download):

- **Windows**: `QLTTTA-x.y.z-windows-x64-setup.exe` (no administrator rights needed) or the `portable.zip`.
  If SmartScreen warns you: *More info* → *Run anyway* (the app is not commercially code-signed).
- **macOS 12+ (Apple Silicon)**: open the `.dmg` and drag `QLTTTA.app` into Applications. The first launch is blocked →
  *System Settings > Privacy & Security > Open Anyway* (or `xattr -dr com.apple.quarantine /Applications/QLTTTA.app`).
  The macOS build bundles the FreeTDS driver, so nothing else needs to be installed.

On the login screen open **Server settings** ("Cấu hình máy chủ" in Vietnamese) and enter `localhost,1433` (Docker)
or `localhost` / `PC-NAME\SQLEXPRESS` (Windows), database `QLTTTA`. The *Trust server certificate* option is on by
default because the Docker image uses a self-signed certificate; turn it off if your server has a certificate from
a trusted CA.

**Language:** the UI is available in Vietnamese (default) and English. Pick it in the language box at the bottom of
the login screen or in the header of the main window; the screen is rebuilt immediately (you stay logged in) and the
choice is remembered for the next start. Data stored in the database (names, branch names, business error messages
written by the database) is not translated.

Connection check without the GUI (for diagnosing errors; `QLTTTA_SERVER` is optional and overrides the saved server):
```bash
QLTTTA_USER=ql_quan QLTTTA_PASSWORD='Demo@2026' /Applications/QLTTTA.app/Contents/MacOS/QLTTTA --check-connection
```
It prints `OK: <full name> (<role>)` and exits with code 0, or `ERROR: <message>` and exits with code 1 (in the
language chosen last in the app).

---

## 3. Development environment (level C)

### macOS
```bash
brew install qt qt-unixodbc unixodbc freetds cmake ninja
# Microsoft driver (optional; the app uses FreeTDS when it is missing). You will be asked to accept the EULA:
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql18

cmake --preset macos-debug
cmake --build --preset macos-debug
ctest --preset macos-debug
open build/macos-debug/src/app/QLTTTA.app
```
Open the project with **Qt Creator** (*File > Open File or Project > CMakeLists.txt*) or VS Code (CMake Tools extension).

### Windows
1. Install the **Qt Online Installer** (a free Qt account is required) and select:
   *Qt 6.8.x > MinGW 64-bit*, *Developer and Designer Tools > MinGW 13.1 64-bit, CMake, Ninja*, *Qt Creator*.
2. Open Qt Creator → *Open Project* → choose `CMakeLists.txt` → choose the kit *Desktop Qt 6.8.x MinGW 64-bit* → Run.
3. Command line (PowerShell, with `C:\Qt\Tools\mingw1310_64\bin`, `C:\Qt\Tools\Ninja` and `C:\Qt\Tools\CMake_64\bin` on PATH):
   ```powershell
   $env:QT_ROOT_DIR = "C:\Qt\6.8.3\mingw_64"
   cmake --preset windows-debug; cmake --build --preset windows-debug; ctest --preset windows-debug
   ```

Requirements: C++17 compiler, Qt ≥ 6.7 with the Qt SQL, Qt SVG and Qt Linguist tools modules (all included in
Homebrew `qt` and in the default Qt installer components; CI uses Qt 6.8 LTS + MinGW on Windows and Homebrew Qt on
macOS), CMake ≥ 3.25 for the presets.

### Running the full test suite with one command (before every PR)
```bash
SQL_PASSWORD='<sa password>' ./scripts/test_all.sh --docker sql2022   # or drop --docker if sqlcmd is installed locally
```
It runs, in order: change checks against `origin/develop` (`scripts/check_changes.sh`: format of the changed C++
lines, commit messages, no build output / `.env` in the repository) → re-initialize the database →
`database/12_tests.sql` (42 cases: constraints, business rules, functions/triggers/cursors, XML, authorization, schema
conventions) → `database/13_server_tests.sql` (18 server-level cases: backup and restore, BULK INSERT of the sample
CSV, the distributed database of `11_distributed_demo.sql`, account lockout with real sign-ins) → build → unit tests
(incl. `tst_conventions`) → end-to-end GUI tests. It stops at the first failing step and exits with a non-zero code; details are written to `build/test-results/`. Add `--no-init` to skip the
database re-initialization. Optional environment variables: `SQL_SERVER`, `SQL_USER`, `QLTTTA_E2E_PASSWORD` (demo
account password, defaults to the one above), `PRESET` (CMake preset, default `macos-debug`, `linux-debug` on Linux),
`EXTRA_CMAKE_ARGS`, `SQL_CSV_PATH` (see below) and `CHANGE_BASE` (base branch of the change checks).
The change checks need `clang-format` and `git clang-format` of the team version (`.clang-format-version`):
`brew install clang-format`, or on any OS `pip install clang-format==<version>` (Windows: also possible with the
LLVM installer). Run them alone with `./scripts/check_changes.sh` (Windows: `.\scripts\check_changes.ps1`).
A skipped end-to-end test counts as a failure, so a missing password or an unreachable database cannot pass silently.
The last line is
`ALL TESTS PASSED: database 60/60 cases (12_tests + 13_server_tests), unit tests + end-to-end GUI tests passed.`

The server-level step needs a **sysadmin** login (`sa`, or a Windows account that is sysadmin) and the MSOLEDBSQL
provider (installed with SQL Server 2019+, also in the Docker image): it creates scratch databases `QLTTTA_T_*`, backup
files in the instance's default backup folder and loopback linked servers, and removes them again. The SQL Server
service itself reads the sample CSV for `BULK INSERT`: with `--docker`/`-Docker` the script copies it into the
container; otherwise it copies it to `/tmp` (macOS/Linux) or `%ProgramData%\QLTTTA` (Windows). If SQL Server runs on
another machine, copy `database/samples/student_import.csv` there and set `SQL_CSV_PATH` to its path on that machine.

On Windows (PowerShell, with `QT_ROOT_DIR` and PATH set as in section 3):
```powershell
.\scripts\test_all.ps1                                  # Windows Authentication, server "localhost"
.\scripts\test_all.ps1 -Server "localhost\SQLEXPRESS"   # Express edition
.\scripts\test_all.ps1 -Docker sql2022                  # SQL Server in Docker, sa password in $env:SQL_PASSWORD
```
(`-User/-Password`, `-NoInit` and `-Preset` are also available. On macOS the same script runs with `pwsh`.)

To test only the database (no Qt needed): open `database/12_tests.sql` in SSMS; it passes when the script finishes
without error `50099` (the `Verdict` column of the summary shows `PASSED`/`FAILED` per case).

> GitHub Actions (`ci.yml`) runs when something is merged into `develop`, on PRs into `main`, or when started by hand
> (`gh workflow run CI --ref <branch> -f reason="<what to check>"`, listed as "Manual CI on <branch>: <reason>").
> The macOS and Windows jobs build and run the unit tests (including the translation check `tst_i18n`; the
> end-to-end test is recorded as *Skipped* there). The job
> **Full tests (Linux + SQL Server)** starts SQL Server 2022 Developer in Docker and runs `test_all.sh` and then
> `test_all.ps1`, i.e. the whole suite above including the end-to-end GUI test (Qt 6.8 + Microsoft ODBC Driver 18 on
> Ubuntu), then the end-to-end test once more through FreeTDS, the driver bundled in the macOS `.dmg`. As soon as one
> job fails, the job **Stop the run on the first failure** cancels the whole run (the failed job keeps its red X, the
> others show as cancelled), so a red run does not keep spending macOS/Windows minutes. PRs into
> `develop` run only the fast **Checks** workflow (`checks.yml`: change checks + build + unit tests on Linux, no
> database), which is why the PR checklist still asks you to paste the local `test_all` result.

### End-to-end GUI tests (need a database loaded with the seed data)
`tests/tst_e2e_gui.cpp` types and clicks on the real screens against the real database: login, every role opening
every feature it is allowed to use, adding/editing/deleting a student, quick filter and the totals row, PDF/CSV export,
changing the password and switching the UI to English and back; data changed during the test is restored. The scenarios
run in Vietnamese. Without a password the test is skipped (as on CI).
```bash
QLTTTA_E2E_PASSWORD='Demo@2026' ctest --preset macos-debug -R e2e --output-on-failure
```
`QLTTTA_SERVER` selects another SQL Server (default `localhost,1433`).

### Building installers on your own machine
- macOS: `./scripts/package-macos.sh` → `dist/QLTTTA-x.y.z-macos-arm64.dmg`
- Windows: additionally install Inno Setup 6 and run `.\scripts\package-windows.ps1` → `dist\...-setup.exe` and `...-portable.zip`

CI does the same when something is merged into `main` (see [CONTRIBUTING.md](CONTRIBUTING.md)).

### Taking screenshots for the report
```bash
cmake --preset macos-debug -DQLTTTA_BUILD_TOOLS=ON && cmake --build --preset macos-debug
QT_QPA_PLATFORM=offscreen QLTTTA_SHOT_PASSWORD='Demo@2026' ./build/macos-debug/tools/qlttta_screenshots
# images are saved to docs/report/images/screens
```
Optional: `QLTTTA_SHOT_USERS` (comma-separated accounts), `QLTTTA_SHOT_DIR` (output folder), `QLTTTA_SERVER`,
`QLTTTA_SHOT_LANG` (`vi` by default - the report needs Vietnamese screenshots; with `en` the images go to
`build/screenshots/en` unless `QLTTTA_SHOT_DIR` is set, so the report images are never overwritten). File names are
fixed and do not depend on the UI language: `login.png`, `<account>_<feature>.png` (e.g. `gvu_lan_students.png`),
`<account>_student_form.png`.

### Translations (multi-language UI)
UI strings are written in English inside `tr("...")`; the Vietnamese texts live in
`resources/translations/qlttta_vi.ts` and are compiled into the app at build time. After adding or changing a string:
```bash
cmake --build --preset macos-debug --target update_translations   # lupdate: adds the new strings to the .ts file
```
Then translate the new entries with **Qt Linguist** (`open -a Linguist resources/translations/qlttta_vi.ts` on macOS,
or from the Qt installation on Windows) or directly in the XML, and rebuild. `ctest -R tst_i18n` fails while an entry
is unfinished. Details: [ARCHITECTURE.md](ARCHITECTURE.md#5-multi-language-ui-english--vietnamese).

---

## 4. Troubleshooting

| Symptom | Fix |
|---|---|
| `SSL Provider: OpenSSL library could not be loaded` (Microsoft driver on macOS) | The driver looks for OpenSSL in `/opt/homebrew/opt/openssl`: `ln -s openssl@3 /opt/homebrew/opt/openssl` |
| CMake reports the compiler is "broken", error `tapi ... unknown architecture arm64e` | The Command Line Tools SDK is newer than Xcode's. Add `-DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` when configuring (or `EXTRA_CMAKE_ARGS` for the scripts) |
| The app says "Cannot connect to SQL Server" ("Không kết nối được máy chủ SQL Server") | Check the SQL Server container/service, port 1433 and the firewall; on Windows Express use `localhost\SQLEXPRESS` and enable TCP/IP in SQL Server Configuration Manager |
| `Login failed for user '...'` when signing in to SSMS as a demo user (the app shows "Wrong username or password, or the account is locked") | Select the `QLTTTA` database in Connection Properties (the user lives inside the database; it is not a server-level login) |
| `EXECUTE permission was denied on fn_...` on SQL Server 2019+ | Re-run `00_create_database.sql` (it turns off Scalar UDF Inlining) or run `ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF` |
| Dashboard "today's sessions", account creation dates, ... are off by one day / 7 hours (SQL Server in Docker) | The container runs on UTC. `docker-compose.yml` sets `TZ=Asia/Ho_Chi_Minh`; for a container created with `docker run` add `-e TZ=Asia/Ho_Chi_Minh` (the container must be recreated), then re-run `db_init` |
| Vietnamese text is garbled in scripts run with sqlcmd | Add `-f 65001` (UTF-8) and `-I` (QUOTED_IDENTIFIER), as `scripts/db_init` does |
