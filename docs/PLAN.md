# Plan and assignments - IE103 project, Group 1

**Report deadline: early November 2026.** The schedule below assumes the submission date is **Wednesday 4 Nov 2026**;
shift it if the instructor announces something different.

## 1. How we work

- **Programming**: the team lead + Claude Code (following `AGENTS.md`). The other members each **own an area**:
  they understand the corresponding part of the database in depth, test it with SSMS/VS Code, write that part of the
  report, make the slides and answer the oral-defense questions about it. All changes go through GitHub (issues/PRs);
  the commit history is the evidence.
- A 30-minute team meeting every Sunday evening (online): report progress against the checklist below.
- The instructor allows the use of AI, but **everyone must be able to answer every question about their own part**.
  When you ask Claude to explain something, re-run the statements yourself and take notes in your own words.

## 2. Assignments

| Member | Area owned | Files | Report parts | Demo during the defense |
|---|---|---|---|---|
| **Trương Quang Như** (NT, 25540022) | Architecture & application: Clean Architecture, Qt, ODBC connection, login, CI/CD, packaging; integration | `src/`, `tests/`, `.github/`, `scripts/package-*`, `packaging/` | Ch.6 (Presenting information), Ch.8, installation appendix | Run the app with the 4 roles, installers on Windows/Mac |
| **Đỗ Phạm Minh Trâm** (25540042) | Survey & analysis: the center's business processes, actors, use cases, DFD, ERD (Chen), CD | report Ch.1-2, ERD/CD figures | Ch.1, Ch.2, sections 3.1-3.2 | Present the problem, the ERD |
| **Nguyễn Việt Phú** (25540025) | Logical model & constraints: ERD → relations, 3NF normalization, data dictionary, integrity constraints, **triggers** | `01_tables.sql`, `05_triggers.sql` | Sections 3.3-3.7, 4.6 | Violate constraints live in SSMS (overpaying tuition, schedule clash, ...) |
| **Đỗ Bình Dương** (25540008) | Database programming: **stored procedures, functions, cursors**, transactions, SQL queries, **XML/XPath/XQuery** | `02_functions.sql`, `04_procedures.sql`, `08_demo_queries.sql` | Ch.4 (except 4.6) | Call `usp_Enrollment_Create`, `usp_Class_EvaluateResults` (cursor), XQuery queries |
| **Nguyễn Bảo Giang** (25540009) | Security & advanced models: **authentication, authorization, security views**, audit, **backup/restore**, import/export, distributed DB, OODB, NoSQL | `03_views.sql`, `06_security.sql`, `09`-`11_*.sql` | Ch.5, Ch.7 | Sign in to SSMS as `gv_john` and get blocked from table STUDENT; backup → restore; distributed view |

Everyone makes **the slides for their own part** (3-4 slides); the team lead merges them and unifies the template.

## 3. Schedule

| Week | Dates | Team lead (+ Claude Code) | Members | Milestone |
|---|---|---|---|---|
| 1 | 1-4 Oct | ✅ Complete database + seed data, Clean Architecture application skeleton, CI/CD, draft report | Install SQL Server + SSMS/VS Code, run `db_init`, try the 4 demo accounts | Everyone can run the database on their own machine |
| 2 | 5-11 Oct | **Classes** module (open a class, weekly schedule, generate sessions), **Enrollment**, **Tuition collection + PDF receipt**; first release to `main` | Read your files carefully, run every object in SSMS, record questions/suggestions as Issues; write a draft of your report part | v0.2 installer tested on one "clean" Windows machine |
| 3 | 12-18 Oct | Teacher modules: **Attendance**, **Grade entry**, **Result evaluation**; **Account management** (create/lock/reset password), **Backup** from the app | Finish your report part + SSMS screenshots; Trâm finalizes the ERD/CD; Giang prepares the security demo script | Report with all chapters (version 1) |
| 4 | 19-25 Oct | Statistical reports (revenue, class size, class results), Excel/XML import, UI polish; **feature freeze on 25 Oct** | Cross-review the report (everyone reads one chapter written by someone else), make your slides | Release `v1.0.0` on `main` |
| 5 | 26 Oct-1 Nov | Bug fixes, testing on clean Windows and Mac machines, re-take all screenshots, export the report to PDF | **Cross oral-defense practice**: everyone answers questions about another member's part; record a backup demo video | Final report + slides |
| 6 | 2-4 Nov | Submit the report, send the Release link (the instructor has been invited to the repo) | Rehearse one full presentation within the time limit | **Submission** |

## 4. Report checklist (to be reflected in the report's "Progress checklist" page)

Legend: `[x]` done, `[~]` partly done.

- [x] Problem analysis, data model design, database implementation (Lab 6 - comprehensive exercise)
- [x] Triggers, stored procedures, functions, cursors (Lab 2)
- [x] Authorization, authentication, backup/restore, import/export (Lab 3)
- [x] XQuery, XPath (Lab 5)
- [~] Reports: PDF/CSV export of lists from the app is done - parameterized reports and receipts are still needed
- [~] Application: Menu/Form - Students (full add/edit/delete), the dashboard and read-only list screens for every role
      are done; classes, enrollment, tuition, attendance and grades still need their data-entry forms
- [x] Advanced databases: distributed (demo), object-oriented, NoSQL (report)

## 5. Oral-defense preparation - frequently asked questions by area

**Analysis & ERD (Trâm)**: Why is ENROLLMENT a separate entity rather than an attribute? What is the (min,max)
cardinality between STUDENT and CLASS? How is the recursive "prerequisite" relationship of COURSE represented? What is
the difference between an ERD and a CD?

**Relational model & integrity constraints (Phú)**: Which normal form is the schema in? Why is `AmountPaid` (a derived
attribute) stored without violating 3NF or losing consistency? What is the context of the "paid = sum of receipts"
constraint and how is it checked? How do triggers handle several rows in `inserted`? How does INSTEAD OF differ from AFTER?

**Database programming (Dương)**: When do you use a function and when a procedure? Inline vs. multi-statement
table-valued functions? Why does `usp_Class_EvaluateResults` use a cursor, and could it be rewritten without one? What is
`SET XACT_ABORT ON` for? `.value()` vs. `.query()`? How do `.nodes()` + `CROSS APPLY` work?

**Security & advanced topics (Giang)**: How does a contained user differ from login + user, and what is the advantage
when backing up/restoring to another machine? What is ownership chaining, and why can a teacher read a view although
the STUDENT table is denied to them? How do DENY and REVOKE differ? What is the Full/Diff/Log strategy, what is the RPO?
Is horizontal fragmentation by branch complete, disjoint and reconstructible? If ENROLLMENT moved to MongoDB, embed or
reference?

**Application & architecture (Như)**: How many layers does Clean Architecture have, and why does the UI not call SQL
directly? Where is login authenticated? How does the app run on both Windows and macOS? How does CI/CD produce the
installers? Why SQL Server instead of SQLite?
