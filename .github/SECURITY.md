# Security policy

QLTTTA is an IE103 course project (an English-center management application on SQL Server). It is not a production
system, but we still take security reports seriously: the database permissions, the stored procedures and the
installers are part of what we are graded on.

## Supported versions
Only the latest release (see [Releases](https://github.com/nhutruong-uit/imcp/releases)) and the `develop` branch
receive fixes.

## Reporting a vulnerability
**Do not open a public issue or pull request for a vulnerability.**

1. Open [Report a vulnerability](https://github.com/nhutruong-uit/imcp/security/advisories/new) (the **Security** tab
   of the repository, *Report a vulnerability*). Only the team lead and you can see the report.
2. Describe what you found: the affected role or screen, the steps to reproduce, and what an attacker gains (for
   example "the academic staff role can read the monthly revenue"). A screenshot or a SQL snippet helps.
3. Never include real passwords, `.env` files or real student data in the report.

You get an answer within a few days (this is a student team, so it is best effort). We fix the problem on a private
branch when needed, publish the fix in a new release and credit you in the advisory if you want to.

## What is in scope
- Database permissions: a role reading or writing more than the matrix in `database/06_security.sql` allows.
- SQL injection or any other way to change data without going through a stored procedure.
- Secrets in the repository or in the installers.
- The GitHub workflows (for example a way to run untrusted code with a write token).

## What is not a vulnerability
- The demo accounts and their shared password in [docs/SETUP.md](../docs/SETUP.md): they are test data for a local
  demo database, never used on a real server.
- A problem that needs administrator (`sa`) access to the database server: that account can do everything by design.
