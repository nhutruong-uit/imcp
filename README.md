# QLTTTA - English Center Management System

Course project for **IE103 - Information Management** · Class IE103.Q21.VB2 · University of Information Technology (UIT), VNU-HCM
Supervisor: Dr. Võ Phương Bình · **Group 1**

A desktop application for **Windows and macOS** that manages a chain of English-language centers: students, courses,
classes and timetables, enrollment, tuition and outstanding balances, attendance, grades, certificates and teacher payroll.
The UI is available in **Vietnamese and English** (switchable at runtime).
The focus is the **SQL Server database**: integrity constraints, stored procedures, functions, triggers, cursors,
views, authorization, backup/restore and XML/XQuery. The Qt application is the presentation layer (menus, forms, reports).

| Component | Technology |
|---|---|
| Database | Microsoft SQL Server 2012+ (T-SQL), contained database users |
| Application | C++17, Qt 6 Widgets, Qt SQL (ODBC), Qt Linguist (UI translations: Vietnamese / English) |
| Architecture | Clean Architecture: domain / application / infrastructure / presentation |
| Build & CI | CMake + Ninja, GitHub Actions (build, unit tests, `.exe` / `.zip` / `.dmg` packaging) |

> **Language note.** Code, database (objects, stored values, business messages), docs, scripts and CI are in English.
> The UI ships with a Vietnamese translation (default) and English; the Vietnamese UI also translates the values and
> messages that come from the database. Only the course report (`docs/report/`) is written in Vietnamese.

## Quick start

```bash
# 1. Initialize the database (SQL Server must be running, e.g. a Docker container named "sql2022")
SQL_PASSWORD='<sa password>' ./scripts/db_init.sh --docker sql2022

# 2. Build and run the application (macOS, Qt from Homebrew)
cmake --preset macos-debug && cmake --build --preset macos-debug
open build/macos-debug/src/app/QLTTTA.app
```

For Windows, see [docs/SETUP.md](docs/SETUP.md), which also lists the demo accounts (manager, academic staff,
accountant, teacher).

## Repository layout

```
database/            SQL Server scripts: 00 create DB ... 07 seed data, 08-11 demos (queries / backup / import / distributed),
                     12-13 test suites (13 = server level), samples/ (CSV for BULK INSERT)
src/domain/          Entities + business rules (no dependency on the database or the UI)
src/application/     Use cases (services), ports (repository interfaces), role/menu permission matrix
src/infrastructure/  ODBC connection, repositories that call stored procedures, settings storage
src/presentation/    Qt Widgets UI (role-based menu, forms, PDF/CSV export of reports, i18n)
src/app/             Composition root (creates and wires the layers)
tests/               Unit tests (Qt Test, fake repositories), translation checks, end-to-end GUI test against a real database
tools/               Screenshot generator used for the report
resources/           Icons, the QSS style sheet and translations/qlttta_vi.ts (Vietnamese UI)
packaging/           Icons, Info.plist, Inno Setup installer, end-user install notes
scripts/             Database init, change checks, full test run, macOS/Windows packaging
.github/workflows/   Checks (PRs into develop), CI (build, unit + full tests) and Release (installers)
docs/                Documentation + the project report (docs/report)
```

## Documentation

- [docs/SETUP.md](docs/SETUP.md) - environment setup on macOS/Windows, database initialization, demo accounts, test run, packaging
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Clean Architecture, request flow, naming conventions, how to add a new module, multi-language UI
- [docs/DATABASE.md](docs/DATABASE.md) - database design, object catalog, roles and permissions, mapping to the course syllabus
- [docs/PLAN.md](docs/PLAN.md) - schedule up to the submission date, member assignments, oral-defense preparation
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) - Git/GitHub workflow, coding conventions, working with Claude Code
- [docs/report/](docs/report/) - the project report (.docx, .pdf; written in Vietnamese for the course) and the script that generates it

## Team

| No. | Name | Student ID | Main responsibility |
|---|---|---|---|
| 1 | Trương Quang Như (team lead) | 25540022 | Architecture, application development, CI/CD, integration |
| 2 | Đỗ Phạm Minh Trâm | 25540042 | Domain survey, requirements analysis, ERD/CD |
| 3 | Nguyễn Việt Phú | 25540025 | Relational model, normalization, integrity constraints, triggers |
| 4 | Đỗ Bình Dương | 25540008 | Stored procedures, functions, cursors, SQL queries, XQuery |
| 5 | Nguyễn Bảo Giang | 25540009 | Data security, backup/restore, import/export, advanced databases |

Detailed assignments: [docs/PLAN.md](docs/PLAN.md).
