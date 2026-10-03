/* =====================================================================
   IE103 PROJECT - INFORMATION MANAGEMENT
   Topic  : English language center management system
   File   : 00_create_database.sql - Creates the QLTTTA database
   Run    : as a sysadmin (sa), SQL Server 2012 or later
   What   : a server-level script (it runs in master, not in QLTTTA): it switches on contained
            database authentication for the server, drops an old QLTTTA (all its data is lost)
            and creates an empty QLTTTA with the options explained below.
   Order  : first script of db_init (scripts/db_init.sh / .ps1), which runs 00 to 07 in order:
            database, tables, functions, views, procedures, triggers, security, seed data.
   Settings (what to explain at the oral defense):
     - contained database authentication (step 1): a server-wide option set with sp_configure.
       It must be on before a contained database can be created and before its users can sign in
       with their password.
     - SINGLE_USER WITH ROLLBACK IMMEDIATE (step 2): disconnects every other session and rolls back
       its open transaction; otherwise DROP DATABASE fails while somebody is still connected.
     - CONTAINMENT = PARTIAL (step 3): the database can hold contained users (a user with its own
       password and no login in master). usp_Account_Create creates them, so the accounts travel
       with a backup to another server. SQL Server only offers NONE and PARTIAL.
     - COLLATE Vietnamese_CI_AS (step 3): the default collation of every text column - Vietnamese
       sort order, CI = case-insensitive ("an" = "An"), AS = accent-sensitive ("an" <> "ân").
       The catalog of a contained database (user names, USER_NAME()) keeps its own fixed collation
       (Latin1_General_100_CI_AS_KS_WS_SC), which is why the code compares USER_NAME() with
       COLLATE DATABASE_DEFAULT.
     - RECOVERY FULL (step 4): the transaction log keeps every change until a LOG backup, so the
       FULL + DIFFERENTIAL + LOG backup chain of 09_backup_restore.sql and usp_Backup is possible
       (BACKUP LOG is not allowed in the SIMPLE recovery model).
     - TSQL_SCALAR_UDF_INLINING = OFF (step 5): see the comment of step 5.
   ===================================================================== */
USE master;
GO

-- 1. Enable contained database authentication.
--    Users can then have a password stored inside the database, with no
--    server-level login => backup/restore to another machine causes no "orphaned users".
--    RECONFIGURE applies the new value at once (this option needs no restart).
EXEC sp_configure 'contained database authentication', 1;
RECONFIGURE;
GO

-- 2. Drop the old database (if any) to start from scratch
IF DB_ID(N'QLTTTA') IS NOT NULL
BEGIN
    ALTER DATABASE QLTTTA SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QLTTTA;
END
GO

-- 3. Create the database: partially contained, Vietnamese collation
--    (names keep their Vietnamese spelling and sort correctly: "Đỗ" comes after "Dương").
CREATE DATABASE QLTTTA
    CONTAINMENT = PARTIAL
    COLLATE Vietnamese_CI_AS;
GO

-- 4. FULL recovery model so the transaction log can be backed up too
ALTER DATABASE QLTTTA SET RECOVERY FULL;
GO

-- 5. SQL Server 2019+ inlines scalar functions automatically (Scalar UDF Inlining). When an inlined
--    function wraps a call to another function (e.g. fn_Classification(fn_FinalGrade(...)) in
--    vw_LearningResults), the ownership chain breaks => a user with only SELECT on the view gets
--    "EXECUTE permission was denied". Turn the feature off for the database (2012-2017 do not have it).
--    ProductMajorVersion 15 = SQL Server 2019. The statement runs as a dynamic string because this
--    script runs in master (the USE inside the string switches to QLTTTA for that string only) and
--    because an older version would reject the unknown option while compiling the whole batch.
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 15
    EXEC (N'USE QLTTTA; ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF;');
GO
