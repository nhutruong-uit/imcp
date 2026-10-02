/* =====================================================================
   IE103 PROJECT - INFORMATION MANAGEMENT
   Topic  : English language center management system
   File   : 00_create_database.sql - Creates the QLTTTA database
   Run    : as a sysadmin (sa), SQL Server 2012 or later
   ===================================================================== */
USE master;
GO

-- 1. Enable contained database authentication.
--    Users can then have a password stored inside the database, with no
--    server-level login => backup/restore to another machine causes no "orphaned users".
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
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 15
    EXEC (N'USE QLTTTA; ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF;');
GO
