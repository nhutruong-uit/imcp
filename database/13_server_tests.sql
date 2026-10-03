/* =====================================================================
   File   : 13_server_tests.sql - Server-level tests: backup/restore (09), BULK INSERT import (10),
            distributed database (11), account lockout and password reset with real sign-ins
   - Unlike 12_tests.sql these cases cannot run inside BEGIN TRAN ... ROLLBACK: BACKUP/RESTORE,
     CREATE DATABASE and linked servers are server-level operations. The script creates scratch
     objects (database QLTTTA_T_Restored, the fragment databases of 11, backup files, loopback
     linked servers QLTTTA_T_LINK_*, account t_lockout) and removes them again at the end
     (and at the start, in case an earlier run stopped half-way).
   - Sign-ins are REAL: a loopback linked server (MSOLEDBSQL to this same instance) signs in as a
     contained user, so a locked account is rejected by SQL Server itself (error 18456), exactly
     like the application's sign-in.
   - Run as sysadmin after 07_seed_data.sql, through sqlcmd (scripts/test_all), with the variables
       DatabaseDir  the database folder of the repository as seen by sqlcmd (:r 11_distributed_demo.sql)
       CsvPath      database/samples/student_import.csv as seen by the SQL SERVER machine (BULK INSERT)
   - Same summary as 12_tests.sql (Verdict PASSED/FAILED; a "Rejected" case must match the message
     pattern in #Expected); any failing case ends the script with THROW 50099.

   How this test script works (the header of 12_tests.sql explains #Results, #Expected, the
   TRY/CATCH shape of a case and the summary; only the differences are listed here):
   - #Ctx keeps the values several batches need (folders, backup file names, the random password):
     a DECLAREd variable lives for one batch only, a #temp table for the whole session.
   - #usp_Cleanup and #usp_SignIn are TEMPORARY procedures (the # prefix): they exist only in this
     session, so the test adds no helper objects to QLTTTA.
   - The scratch data is real (no rollback), e.g. the promotion PR-S01 of S01 and the account
     t_lockout; #usp_Cleanup removes it. The demo accounts are only impersonated, never changed.
   - Order: SETUP (cleanup, folders, account t_lockout, linked servers) -> A. backup/restore ->
     B. BULK INSERT -> C. distributed database (runs 11_distributed_demo.sql itself) -> D. account
     lockout -> CLEANUP + SUMMARY. Later cases use what earlier ones built (S02 restores the files
     of S01, S03 signs in to the copy restored by S02, S16-S17 lock/unlock the account of the SETUP).
   How to run it:
   - Command line: scripts/test_all.sh (Windows: scripts\test_all.ps1) runs it as step 4 with sqlcmd
     and sets DatabaseDir and CsvPath (with --docker it first copies 11_distributed_demo.sql and the
     CSV into the container).
   - SSMS: connect as a sysadmin and switch on SQLCMD Mode (Query menu), needed for the include of
     11_distributed_demo.sql and for the two variables; define them first with two :setvar lines
     (do not commit them). The run passed when it ends without error 50099.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results;
CREATE TABLE #Results (
    TestId       VARCHAR(5)     NOT NULL,
    Description  NVARCHAR(200)  NOT NULL,
    Expected     NVARCHAR(20)   NOT NULL,   -- 'Rejected' or 'Succeeded'
    Actual       NVARCHAR(20)   NULL,
    Message      NVARCHAR(400)  NULL
);

-- System errors are matched on the object/constraint name or the error number (independent of the language)
IF OBJECT_ID('tempdb..#Expected') IS NOT NULL DROP TABLE #Expected;
CREATE TABLE #Expected (TestId VARCHAR(5) PRIMARY KEY, MessagePattern NVARCHAR(200) NULL);
INSERT #Expected VALUES
    ('S01', NULL), ('S02', NULL), ('S03', NULL), ('S04', NULL),
    ('S05', N'%usp_Backup%'),                   ('S06', N'%must be FULL, DIFF or LOG%'),
    ('S07', NULL), ('S08', NULL),
    ('S09', NULL), ('S10', NULL),               ('S11', N'%CK_STUDENT_BranchId%'),
    ('S12', NULL), ('S13', NULL),
    ('S14', NULL),                              ('S15', N'%cannot lock the account you are signed in with%'),
    ('S16', N'%18456%'),                        ('S17', NULL),
    ('S18', N'%usp_Account_Lock%'),            ('S19', NULL),
    ('S20', N'%must be FULL, DIFF or LOG%');

-- Values shared by the batches of this session: folders, backup files, the temporary password
IF OBJECT_ID('tempdb..#Ctx') IS NOT NULL DROP TABLE #Ctx;
CREATE TABLE #Ctx (Name VARCHAR(20) PRIMARY KEY, Value NVARCHAR(400) NOT NULL);
GO

/* ---------------- SETUP ---------------- */

-- Removes every scratch object of this script
-- Runs at the start (an earlier run may have stopped half-way) and at the end: linked servers, the scratch rows of
-- QLTTTA (user t_lockout, its ACCOUNT row, PR-S01), the scratch databases (SINGLE_USER WITH ROLLBACK IMMEDIATE
-- closes their open connections first), then the backup files listed in #Ctx (cursor).
IF OBJECT_ID('tempdb..#usp_Cleanup') IS NOT NULL DROP PROCEDURE #usp_Cleanup;
GO
CREATE PROCEDURE #usp_Cleanup
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @File NVARCHAR(400);
    -- Linked servers first: dropping them closes their connections to the scratch databases
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = N'QLTTTA_T_LINK_MAIN')
        EXEC master.dbo.sp_dropserver N'QLTTTA_T_LINK_MAIN', 'droplogins';
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = N'QLTTTA_T_LINK_COPY')
        EXEC master.dbo.sp_dropserver N'QLTTTA_T_LINK_COPY', 'droplogins';
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = N'QLTTTA_T_LINK_SA')
        EXEC master.dbo.sp_dropserver N'QLTTTA_T_LINK_SA', 'droplogins';

    EXEC QLTTTA.sys.sp_executesql N'IF DATABASE_PRINCIPAL_ID(N''t_lockout'') IS NOT NULL DROP USER t_lockout;';
    DELETE FROM QLTTTA.dbo.ACCOUNT WHERE Username = N't_lockout';
    DELETE FROM QLTTTA.dbo.PROMOTION WHERE PromotionId = 'PR-S01';

    IF DB_ID(N'QLTTTA_T_Restored') IS NOT NULL
    BEGIN
        ALTER DATABASE QLTTTA_T_Restored SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE QLTTTA_T_Restored;
    END;
    IF DB_ID(N'QLTTTA_BR01') IS NOT NULL
    BEGIN
        ALTER DATABASE QLTTTA_BR01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE QLTTTA_BR01;
    END;
    IF DB_ID(N'QLTTTA_BR02') IS NOT NULL
    BEGIN
        ALTER DATABASE QLTTTA_BR02 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE QLTTTA_BR02;
    END;

    -- Backup files written by this run (xp_delete_file 0 only deletes SQL Server backup files)
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT Value FROM #Ctx WHERE Name IN ('FullBackup', 'DiffBackup', 'LogBackup', 'AppBackup');
    OPEN c;
    FETCH NEXT FROM c INTO @File;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC master.sys.xp_delete_file 0, @File;
        END TRY
        BEGIN CATCH
            PRINT N'Could not delete ' + @File + N': ' + ERROR_MESSAGE();
        END CATCH;
        FETCH NEXT FROM c INTO @File;
    END;
    CLOSE c;
    DEALLOCATE c;
END;
GO

-- Signs in through a loopback linked server; returns the database user name or the error
-- OPENQUERY(server, query) sends the query to the linked server, which opens a NEW connection with the remote
-- user and password stored for it (sp_addlinkedsrvlogin) - a real sign-in, like the application. QUOTENAME
-- puts the server name in brackets, so it cannot break out of the dynamic SQL.
IF OBJECT_ID('tempdb..#usp_SignIn') IS NOT NULL DROP PROCEDURE #usp_SignIn;
GO
CREATE PROCEDURE #usp_SignIn
    @LinkedServer  SYSNAME,
    @SignedInAs    SYSNAME        OUTPUT,
    @Error         NVARCHAR(400)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Who TABLE (UserName SYSNAME);
    DECLARE @Sql NVARCHAR(400) = N'SELECT UserName FROM OPENQUERY(' + QUOTENAME(@LinkedServer)
                               + N', ''SELECT USER_NAME() AS UserName'');';
    SELECT @SignedInAs = NULL, @Error = NULL;
    BEGIN TRY
        -- Dynamic SQL: a failed remote sign-in is then catchable (in the same scope it ends the batch)
        INSERT @Who EXEC sys.sp_executesql @Sql;
        SELECT @SignedInAs = UserName FROM @Who;
    END TRY
    BEGIN CATCH
        SET @Error = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
    END CATCH;
END;
GO

EXEC #usp_Cleanup;
GO

-- Folders of this instance (Linux/Docker: /var/opt/mssql/data/, Windows: ...\MSSQL\Backup\ and \DATA\)
DECLARE @BackupDir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260)),
        @DataDir   NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
IF @BackupDir IS NULL SET @BackupDir = @DataDir;
IF RIGHT(@BackupDir, 1) NOT IN ('/', '\') SET @BackupDir += CASE WHEN CHARINDEX('/', @BackupDir) > 0 THEN '/' ELSE '\' END;
IF RIGHT(@DataDir, 1) NOT IN ('/', '\') SET @DataDir += CASE WHEN CHARINDEX('/', @DataDir) > 0 THEN '/' ELSE '\' END;
INSERT #Ctx VALUES ('DataDir', @DataDir),
                   ('FullBackup', @BackupDir + N'QLTTTA_T_full.bak'),
                   ('DiffBackup', @BackupDir + N'QLTTTA_T_diff.bak'),
                   ('LogBackup',  @BackupDir + N'QLTTTA_T_log.trn');

-- Temporary MANAGER account with a random password (the demo accounts are left untouched).
-- It is created BEFORE the backup, so the restored copy contains it too (S03).
-- (NEWID() without dashes is random; the prefix Aa1! adds lower/upper case, a digit and a symbol for the policy.)
DECLARE @Password NVARCHAR(128) = N'Aa1!' + REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''),
        @EmployeeId VARCHAR(10) = (SELECT TOP (1) em.EmployeeId FROM dbo.EMPLOYEE em
                                   WHERE NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT ac WHERE ac.EmployeeId = em.EmployeeId)
                                   ORDER BY em.EmployeeId);
INSERT #Ctx VALUES ('Password', @Password);
EXEC dbo.usp_Account_Create N't_lockout', @Password, 'MANAGER', @EmployeeId, NULL;

-- Loopback linked servers to this same instance (the production design of 11: [SRV_TD].QLTTTA_BR02...)
-- A loopback linked server points back to this instance, so remote sign-ins can be tested on one machine.
-- MSOLEDBSQL = Microsoft OLE DB Driver for SQL Server; rpc out lets MAIN run EXEC (...) AT the linked server (S15).
DECLARE @DataSource NVARCHAR(200) =
    N'localhost' + ISNULL(N'\' + CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(128)), N'');
--   MAIN: signs in to QLTTTA as t_lockout; COPY: signs in to the restored copy as t_lockout
EXEC master.dbo.sp_addlinkedserver @server = N'QLTTTA_T_LINK_MAIN', @srvproduct = N'', @provider = N'MSOLEDBSQL',
     @datasrc = @DataSource, @catalog = N'QLTTTA', @provstr = N'TrustServerCertificate=yes';
EXEC master.dbo.sp_serveroption N'QLTTTA_T_LINK_MAIN', 'rpc out', 'true';
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'QLTTTA_T_LINK_MAIN', @useself = 'FALSE', @locallogin = NULL,
     @rmtuser = N't_lockout', @rmtpassword = @Password;
EXEC master.dbo.sp_addlinkedserver @server = N'QLTTTA_T_LINK_COPY', @srvproduct = N'', @provider = N'MSOLEDBSQL',
     @datasrc = @DataSource, @catalog = N'QLTTTA_T_Restored', @provstr = N'TrustServerCertificate=yes';
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'QLTTTA_T_LINK_COPY', @useself = 'FALSE', @locallogin = NULL,
     @rmtuser = N't_lockout', @rmtpassword = @Password;
--   SA: the current (sysadmin) login itself, to read the fragment databases remotely
EXEC master.dbo.sp_addlinkedserver @server = N'QLTTTA_T_LINK_SA', @srvproduct = N'', @provider = N'MSOLEDBSQL',
     @datasrc = @DataSource, @catalog = N'master', @provstr = N'TrustServerCertificate=yes';
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'QLTTTA_T_LINK_SA', @useself = 'TRUE';
GO

/* ---------------- A. BACKUP & RESTORE (09_backup_restore.sql) ---------------- */

-- S01: FULL -> DIFFERENTIAL -> LOG chain with CHECKSUM; every file is recorded in msdb and passes VERIFYONLY
--      Concepts: backup chain - FULL (whole database), DIFFERENTIAL (pages changed since the FULL), LOG (log records
--      since the last log backup; needs the FULL recovery model). WITH CHECKSUM verifies every page while writing,
--      RESTORE VERIFYONLY reads a backup file without restoring it, msdb.dbo.backupset records every backup.
--      PR-S01 is inserted after the FULL and changed after the DIFF, so S02 can tell which file brought which change.
DECLARE @Full NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'FullBackup'),
        @Diff NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'DiffBackup'),
        @Log  NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'LogBackup'),
        -- Backups of this run = backup sets after the latest one recorded so far (no clock: msdb times are local)
        @LastSetId INT = (SELECT ISNULL(MAX(backup_set_id), 0) FROM msdb.dbo.backupset), @Recorded INT;
BEGIN TRY
    BACKUP DATABASE QLTTTA TO DISK = @Full WITH INIT, FORMAT, CHECKSUM, NAME = N'QLTTTA - Test full';
    -- Data written after the FULL backup: only the DIFF and the LOG can bring it back
    INSERT INTO dbo.PROMOTION (PromotionId, PromotionName, DiscountType, DiscountValue, StartDate, EndDate)
    VALUES ('PR-S01', N'Restore test promotion', 'AMOUNT', 200000, '20260101', '20261231');
    BACKUP DATABASE QLTTTA TO DISK = @Diff WITH DIFFERENTIAL, INIT, FORMAT, CHECKSUM, NAME = N'QLTTTA - Test diff';
    UPDATE dbo.PROMOTION SET DiscountValue = 300000 WHERE PromotionId = 'PR-S01';
    BACKUP LOG QLTTTA TO DISK = @Log WITH INIT, FORMAT, CHECKSUM, NAME = N'QLTTTA - Test log';

    RESTORE VERIFYONLY FROM DISK = @Full WITH CHECKSUM;
    RESTORE VERIFYONLY FROM DISK = @Diff WITH CHECKSUM;
    RESTORE VERIFYONLY FROM DISK = @Log WITH CHECKSUM;
    SELECT @Recorded = COUNT(*)
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
    WHERE bs.database_name = N'QLTTTA' AND bs.has_backup_checksums = 1 AND bs.backup_set_id > @LastSetId
      AND ((bs.type = 'D' AND bmf.physical_device_name = @Full)
        OR (bs.type = 'I' AND bmf.physical_device_name = @Diff)
        OR (bs.type = 'L' AND bmf.physical_device_name = @Log));
    INSERT #Results VALUES ('S01', N'FULL + DIFF + LOG backup with CHECKSUM, RESTORE VERIFYONLY', N'Succeeded',
                            CASE WHEN @Recorded = 3 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(@Recorded, N'/3 backups recorded in msdb with checksums, all 3 files valid'));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S01', N'FULL + DIFF + LOG backup with CHECKSUM, RESTORE VERIFYONLY', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S02: restoring FULL -> DIFF -> LOG into a new database (MOVE) brings back the data changed after the FULL backup
--      Concepts: restore sequence - FULL and DIFF WITH NORECOVERY (the database waits for more backups), LOG WITH
--      RECOVERY (opens it); MOVE gives the copy new file paths, so QLTTTA itself is untouched. DiscountValue = 300000
--      can only come from the LOG backup.
DECLARE @Full NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'FullBackup'),
        @Diff NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'DiffBackup'),
        @Log  NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'LogBackup'),
        @Mdf  NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'DataDir') + N'QLTTTA_T_Restored.mdf',
        @Ldf  NVARCHAR(400) = (SELECT Value FROM #Ctx WHERE Name = 'DataDir') + N'QLTTTA_T_Restored_log.ldf',
        @DataName SYSNAME = (SELECT name FROM QLTTTA.sys.database_files WHERE type = 0),
        @LogName  SYSNAME = (SELECT name FROM QLTTTA.sys.database_files WHERE type = 1),
        @Value DECIMAL(12, 2), @DifferentCounts INT;
BEGIN TRY
    RESTORE DATABASE QLTTTA_T_Restored FROM DISK = @Full
    WITH MOVE @DataName TO @Mdf, MOVE @LogName TO @Ldf, NORECOVERY, REPLACE, CHECKSUM;
    RESTORE DATABASE QLTTTA_T_Restored FROM DISK = @Diff WITH NORECOVERY, CHECKSUM;
    RESTORE LOG QLTTTA_T_Restored FROM DISK = @Log WITH RECOVERY, CHECKSUM;

    -- Dynamic SQL: the restored database does not exist yet when this batch is compiled
    EXEC sys.sp_executesql N'
        SELECT @v = DiscountValue FROM QLTTTA_T_Restored.dbo.PROMOTION WHERE PromotionId = ''PR-S01'';
        SELECT @d = (CASE WHEN (SELECT COUNT(*) FROM QLTTTA.dbo.STUDENT)    = (SELECT COUNT(*) FROM QLTTTA_T_Restored.dbo.STUDENT)    THEN 0 ELSE 1 END)
                  + (CASE WHEN (SELECT COUNT(*) FROM QLTTTA.dbo.ENROLLMENT) = (SELECT COUNT(*) FROM QLTTTA_T_Restored.dbo.ENROLLMENT) THEN 0 ELSE 1 END)
                  + (CASE WHEN (SELECT COUNT(*) FROM QLTTTA.dbo.RECEIPT)    = (SELECT COUNT(*) FROM QLTTTA_T_Restored.dbo.RECEIPT)    THEN 0 ELSE 1 END);',
        N'@v DECIMAL(12, 2) OUTPUT, @d INT OUTPUT', @v = @Value OUTPUT, @d = @DifferentCounts OUTPUT;
    INSERT #Results VALUES ('S02', N'Restore FULL -> DIFF -> LOG into a new database (WITH MOVE)', N'Succeeded',
                            CASE WHEN @Value = 300000 AND @DifferentCounts = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(N'PR-S01 in the copy = ', ISNULL(CONVERT(NVARCHAR(20), @Value), N'missing'),
                                   N' (expected 300000, written after the DIFF backup); STUDENT/ENROLLMENT/RECEIPT counts differ: ',
                                   @DifferentCounts));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S02', N'Restore FULL -> DIFF -> LOG into a new database (WITH MOVE)', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S03: contained users travel with the restored copy: the same users exist and can sign in right away
--      Concept: contained database users (CREATE USER ... WITH PASSWORD) are stored inside the database, not as
--      logins in master, so a restored copy has no orphaned users to repair. Checked by comparing the users and
--      by a real sign-in to the copy through QLTTTA_T_LINK_COPY.
DECLARE @Missing INT, @SignedInAs SYSNAME, @Error NVARCHAR(400);
BEGIN TRY
    EXEC sys.sp_executesql N'
        SELECT @m = COUNT(*) FROM (
            SELECT name FROM QLTTTA.sys.database_principals WHERE authentication_type_desc = ''DATABASE''
            EXCEPT
            SELECT name FROM QLTTTA_T_Restored.sys.database_principals WHERE authentication_type_desc = ''DATABASE'') x;',
        N'@m INT OUTPUT', @m = @Missing OUTPUT;
    EXEC #usp_SignIn N'QLTTTA_T_LINK_COPY', @SignedInAs OUTPUT, @Error OUTPUT;
    INSERT #Results VALUES ('S03', N'Contained users travel with the backup (no orphaned users)', N'Succeeded',
                            CASE WHEN @Missing = 0 AND @SignedInAs = N't_lockout' THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(@Missing, N' contained users missing in the copy; sign-in to the copy: ',
                                   ISNULL(N'signed in as ' + @SignedInAs, @Error)));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S03', N'Contained users travel with the backup (no orphaned users)', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S04: the manager backs up from the application (usp_Backup, EXECUTE AS OWNER): a valid FULL file in msdb
--      The manager needs only EXECUTE on usp_Backup; the BACKUP statement runs as the owner of the procedure.
--      The file name is kept in #Ctx so #usp_Cleanup deletes it.
DECLARE @File NVARCHAR(400), @Recorded INT;
BEGIN TRY
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Backup @Type = 'FULL', @FilePath = @File OUTPUT;
    REVERT;
    INSERT #Ctx VALUES ('AppBackup', @File);
    RESTORE VERIFYONLY FROM DISK = @File;
    SELECT @Recorded = COUNT(*)
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
    WHERE bs.database_name = N'QLTTTA' AND bs.type = 'D' AND bmf.physical_device_name = @File;
    INSERT #Results VALUES ('S04', N'Manager runs usp_Backup FULL', N'Succeeded',
                            CASE WHEN @Recorded = 1 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(N'Valid backup file ', @File, N', recorded in msdb: ', @Recorded));
END TRY
BEGIN CATCH
    IF USER_NAME() <> N'dbo' REVERT;
    INSERT #Results VALUES ('S04', N'Manager runs usp_Backup FULL', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S05: academic staff run usp_Backup (EXECUTE is granted to rl_Manager only)
--      Concept: permission on a procedure - rl_Manager has EXECUTE through GRANT EXECUTE ON SCHEMA::dbo.
DECLARE @File NVARCHAR(400);
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Backup @Type = 'FULL', @FilePath = @File OUTPUT;
    REVERT;
    INSERT #Ctx VALUES ('AppBackup', @File);
    INSERT #Results VALUES ('S05', N'Academic staff run usp_Backup', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('S05', N'Academic staff run usp_Backup', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S06: an unknown backup type
--      Proves usp_Backup checks its input (THROW 50070) before it builds the dynamic BACKUP statement.
DECLARE @File NVARCHAR(400);
BEGIN TRY
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Backup @Type = 'WEEKLY', @FilePath = @File OUTPUT;
    REVERT;
    INSERT #Results VALUES ('S06', N'usp_Backup with an unknown backup type', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('S06', N'usp_Backup with an unknown backup type', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S20: a NULL backup type
--      Proves usp_Backup refuses NULL too (THROW 50070): "@Type NOT IN (...)" is UNKNOWN for NULL, so without its own
--      test the procedure would build a NULL file path and fail with a system error.
DECLARE @File NVARCHAR(400);
BEGIN TRY
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Backup @Type = NULL, @FilePath = @File OUTPUT;
    REVERT;
    INSERT #Results VALUES ('S20', N'usp_Backup with a NULL backup type', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('S20', N'usp_Backup with a NULL backup type', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- B. CSV IMPORT WITH BULK INSERT (10_import_export.sql) ---------------- */

-- S07: BULK INSERT of the Unicode sample file (same options as 10): every row arrives with its Vietnamese text
--      Concepts: BULK INSERT with DATAFILETYPE widechar reads the UTF-16 file, so the Vietnamese letters survive;
--      EXCEPT against the expected rows finds any difference. The SQL Server SERVICE reads the file, so CsvPath is
--      a path on the server machine. Dynamic SQL because BULK INSERT takes the file name only as a literal.
IF OBJECT_ID('tempdb..#StudentCsv') IS NOT NULL DROP TABLE #StudentCsv;
CREATE TABLE #StudentCsv (
    FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10), Phone VARCHAR(15), Email VARCHAR(100),
    BranchId VARCHAR(10));
DECLARE @Expected TABLE (
    FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10), Phone VARCHAR(15), Email VARCHAR(100),
    BranchId VARCHAR(10));
-- Content of database/samples/student_import.csv (an empty Email becomes NULL)
INSERT @Expected VALUES
    (N'Lê Minh Tâm',  '20020615', N'Male',   '0909666001', 'tam.lm@example.com',  'BR01'),
    (N'Ngô Thị Hạnh', '19981103', N'Female', '0909666002', 'hanh.nt@example.com', 'BR01'),
    (N'Phan Đức Huy', '20040127', N'Male',   '0909666003', NULL,                  'BR02');
DECLARE @Sql NVARCHAR(MAX) = N'BULK INSERT #StudentCsv FROM N''' + REPLACE(N'$(CsvPath)', N'''', N'''''')
    + N''' WITH (DATAFILETYPE = ''widechar'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''\n'', TABLOCK);',
        @Rows INT, @Different INT;
BEGIN TRY
    EXEC sys.sp_executesql @Sql;
    SELECT @Rows = COUNT(*) FROM #StudentCsv;
    SELECT @Different = COUNT(*) FROM (
        SELECT FullName, DateOfBirth, Gender, Phone, NULLIF(Email, '') AS Email, BranchId FROM #StudentCsv
        EXCEPT
        SELECT FullName, DateOfBirth, Gender, Phone, Email, BranchId FROM @Expected) x;
    INSERT #Results VALUES ('S07', N'BULK INSERT of a UTF-16 CSV keeps the Vietnamese text', N'Succeeded',
                            CASE WHEN @Rows = 3 AND @Different = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(@Rows, N' rows imported (expected 3), ', @Different, N' different from the file'));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S07', N'BULK INSERT of a UTF-16 CSV keeps the Vietnamese text', N'Succeeded', N'Rejected',
                            ERROR_MESSAGE() + N' (CsvPath = $(CsvPath))');
END CATCH;
GO

-- S08: the imported rows are loaded through usp_Student_Add, so the business rules apply (rolled back)
--      Concepts: staging table (#StudentCsv) + cursor calling a procedure per row, so every rule of a manual
--      entry (checks, CHECK constraints, generated StudentId) also applies to imported rows.
DECLARE @FullName NVARCHAR(100), @DateOfBirth DATE, @Gender NVARCHAR(10), @Phone VARCHAR(15), @Email VARCHAR(100),
        @BranchId VARCHAR(10), @Id VARCHAR(10), @Added INT, @Matching INT;
BEGIN TRY
    BEGIN TRAN;
    DECLARE @Before INT = (SELECT COUNT(*) FROM dbo.STUDENT);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT FullName, DateOfBirth, Gender, Phone, NULLIF(Email, ''), BranchId FROM #StudentCsv;
    OPEN c;
    FETCH NEXT FROM c INTO @FullName, @DateOfBirth, @Gender, @Phone, @Email, @BranchId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_Student_Add @FullName = @FullName, @DateOfBirth = @DateOfBirth, @Gender = @Gender,
             @Phone = @Phone, @Email = @Email, @BranchId = @BranchId, @StudentId = @Id OUTPUT;
        FETCH NEXT FROM c INTO @FullName, @DateOfBirth, @Gender, @Phone, @Email, @BranchId;
    END;
    CLOSE c;
    DEALLOCATE c;
    SET @Added = (SELECT COUNT(*) FROM dbo.STUDENT) - @Before;
    SELECT @Matching = COUNT(*) FROM dbo.STUDENT s JOIN #StudentCsv i ON i.Phone = s.Phone AND i.FullName = s.FullName
                                                                      AND i.BranchId = s.BranchId;
    ROLLBACK;
    INSERT #Results VALUES ('S08', N'Imported CSV rows loaded through usp_Student_Add', N'Succeeded',
                            CASE WHEN @Added = 3 AND @Matching = 3 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(@Added, N' students added (expected 3), ', @Matching, N' match the file (rolled back)'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('S08', N'Imported CSV rows loaded through usp_Student_Add', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- C. DISTRIBUTED DATABASE (runs the real 11_distributed_demo.sql) ---------------- */
-- The include line below is a sqlcmd command: it inserts 11_distributed_demo.sql here, so the cases test the real
-- demo script, not a copy (it re-creates the fragment databases QLTTTA_BR01 and QLTTTA_BR02).
:r $(DatabaseDir)/11_distributed_demo.sql
GO
-- 11_distributed_demo.sql ends in the database QLTTTA_BR01
USE QLTTTA;
GO

-- S09: primary horizontal fragmentation of STUDENT is complete, disjoint and reconstructible (UNION ALL view)
--      Complete: BR01 + BR02 row counts = STUDENT; disjoint: no StudentId in both fragments; reconstructible: the
--      UNION ALL view equals STUDENT (EXCEPT in both directions). Concept: correctness rules of fragmentation.
DECLARE @Original INT = (SELECT COUNT(*) FROM QLTTTA.dbo.STUDENT),
        @Fragments INT = (SELECT COUNT(*) FROM QLTTTA_BR01.dbo.STUDENT) + (SELECT COUNT(*) FROM QLTTTA_BR02.dbo.STUDENT),
        @Overlap INT = (SELECT COUNT(*) FROM QLTTTA_BR01.dbo.STUDENT a JOIN QLTTTA_BR02.dbo.STUDENT b ON b.StudentId = a.StudentId),
        @Different INT;
BEGIN TRY
    SELECT @Different = (SELECT COUNT(*) FROM (
                             SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA.dbo.STUDENT
                             EXCEPT
                             SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA_BR01.dbo.vw_Student_AllBranches) x)
                      + (SELECT COUNT(*) FROM (
                             SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA_BR01.dbo.vw_Student_AllBranches
                             EXCEPT
                             SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA.dbo.STUDENT) y);
    INSERT #Results VALUES ('S09', N'Fragmentation of STUDENT: complete, disjoint, reconstructible', N'Succeeded',
                            CASE WHEN @Original > 0 AND @Fragments = @Original AND @Overlap = 0 AND @Different = 0
                                 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(N'STUDENT ', @Original, N' rows, BR01 + BR02 = ', @Fragments, N', overlap ', @Overlap,
                                   N', rows differing after UNION ALL ', @Different));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S09', N'Fragmentation of STUDENT: complete, disjoint, reconstructible', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S10: the replicated catalog (COURSE) is identical at every site
--      Concept: replication - a full copy of a rarely changing table at every site (EXCEPT in both directions).
DECLARE @Different INT;
BEGIN TRY
    SELECT @Different = (SELECT COUNT(*) FROM (SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA.dbo.COURSE
                                               EXCEPT SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA_BR01.dbo.COURSE) a)
                      + (SELECT COUNT(*) FROM (SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA_BR01.dbo.COURSE
                                               EXCEPT SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA.dbo.COURSE) b)
                      + (SELECT COUNT(*) FROM (SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA.dbo.COURSE
                                               EXCEPT SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA_BR02.dbo.COURSE) c)
                      + (SELECT COUNT(*) FROM (SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA_BR02.dbo.COURSE
                                               EXCEPT SELECT CourseId, CourseName, Level, Tuition FROM QLTTTA.dbo.COURSE) d);
    INSERT #Results VALUES ('S10', N'Replicated COURSE catalog identical at both sites', N'Succeeded',
                            CASE WHEN @Different = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(@Different, N' rows differ between the central COURSE and the replicas'));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S10', N'Replicated COURSE catalog identical at both sites', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S11: the CHECK of a fragment rejects a student of another branch (fragment predicate BranchId = 'BR02')
--      Concept: the CHECK constraint CK_STUDENT_BranchId is the fragment definition; it also lets the optimizer
--      skip fragments (S12).
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO QLTTTA_BR02.dbo.STUDENT (StudentId, FullName, DateOfBirth, Phone, Status, BranchId)
    VALUES ('ST99999', N'Học Viên Khác Chi Nhánh', '20000101', NULL, N'Studying', 'BR01');
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('S11', N'Fragment BR02 receives a BR01 student', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('S11', N'Fragment BR02 receives a BR01 student', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S12: a query on the view filtered by BranchId = 'BR02' reads ONLY the BR02 fragment (partition elimination
--      thanks to the CHECK constraints), measured with the index usage statistics of each fragment
--      sys.dm_db_index_usage_stats counts the scans/seeks/lookups of each table: only the counter of BR02 may grow.
--      Concept: distributed partitioned view with partition elimination.
DECLARE @Reads01 BIGINT, @Reads02 BIGINT, @After01 BIGINT, @After02 BIGINT, @Rows INT,
        @Expected INT = (SELECT COUNT(*) FROM QLTTTA.dbo.STUDENT WHERE BranchId = 'BR02');
BEGIN TRY
    SELECT @Reads01 = ISNULL(SUM(user_scans + user_seeks + user_lookups), 0) FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID(N'QLTTTA_BR01') AND object_id = OBJECT_ID(N'QLTTTA_BR01.dbo.STUDENT');
    SELECT @Reads02 = ISNULL(SUM(user_scans + user_seeks + user_lookups), 0) FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID(N'QLTTTA_BR02') AND object_id = OBJECT_ID(N'QLTTTA_BR02.dbo.STUDENT');

    SELECT @Rows = COUNT(*) FROM QLTTTA_BR01.dbo.vw_Student_AllBranches WHERE BranchId = 'BR02';

    SELECT @After01 = ISNULL(SUM(user_scans + user_seeks + user_lookups), 0) FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID(N'QLTTTA_BR01') AND object_id = OBJECT_ID(N'QLTTTA_BR01.dbo.STUDENT');
    SELECT @After02 = ISNULL(SUM(user_scans + user_seeks + user_lookups), 0) FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID(N'QLTTTA_BR02') AND object_id = OBJECT_ID(N'QLTTTA_BR02.dbo.STUDENT');
    INSERT #Results VALUES ('S12', N'Query on the view by BranchId reads only one fragment', N'Succeeded',
                            CASE WHEN @Rows = @Expected AND @After01 = @Reads01 AND @After02 > @Reads02
                                 THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(@Rows, N'/', @Expected, N' BR02 rows; reads of fragment BR01 +', @After01 - @Reads01,
                                   N', of fragment BR02 +', @After02 - @Reads02));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S12', N'Query on the view by BranchId reads only one fragment', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S13: production design of 11 - the remote fragment is read through a linked server ([server].database.dbo.table)
--      Concept: four-part name linked_server.database.schema.table; local BR01 + remote BR02 must equal STUDENT.
DECLARE @Remote INT, @Union INT, @Local INT = (SELECT COUNT(*) FROM QLTTTA_BR02.dbo.STUDENT),
        @Original INT = (SELECT COUNT(*) FROM QLTTTA.dbo.STUDENT);
BEGIN TRY
    EXEC sys.sp_executesql N'SELECT @n = COUNT(*) FROM QLTTTA_T_LINK_SA.QLTTTA_BR02.dbo.STUDENT;',
         N'@n INT OUTPUT', @n = @Remote OUTPUT;
    EXEC sys.sp_executesql N'
        SELECT @n = COUNT(*) FROM (SELECT StudentId FROM QLTTTA_BR01.dbo.STUDENT
                                   UNION ALL
                                   SELECT StudentId FROM QLTTTA_T_LINK_SA.QLTTTA_BR02.dbo.STUDENT) s;',
         N'@n INT OUTPUT', @n = @Union OUTPUT;
    INSERT #Results VALUES ('S13', N'Remote fragment read through a linked server', N'Succeeded',
                            CASE WHEN @Remote = @Local AND @Union = @Original THEN N'Succeeded' ELSE N'Rejected' END,
                            CONCAT(N'Remote BR02 ', @Remote, N'/', @Local, N' rows; local BR01 + remote BR02 = ', @Union,
                                   N'/', @Original));
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('S13', N'Remote fragment read through a linked server', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- D. ACCOUNT LOCKOUT AND PASSWORD RESET WITH REAL SIGN-INS ---------------- */

-- S14: control case - before locking, the temporary account signs in (so S16 fails only because of the lock)
--      Also proves that the linked servers and the account of the SETUP work at all.
DECLARE @SignedInAs SYSNAME, @Error NVARCHAR(400);
EXEC #usp_SignIn N'QLTTTA_T_LINK_MAIN', @SignedInAs OUTPUT, @Error OUTPUT;
INSERT #Results VALUES ('S14', N'Active account signs in', N'Succeeded',
                        CASE WHEN @SignedInAs = N't_lockout' THEN N'Succeeded' ELSE N'Rejected' END,
                        ISNULL(N'Signed in as ' + @SignedInAs, @Error));
GO

-- S15: a manager signed in as t_lockout tries to lock their own account (ORIGINAL_LOGIN() check)
--      EXEC (...) AT runs the call on the linked server, i.e. really as t_lockout. Inside EXECUTE AS OWNER,
--      USER_NAME() is the owner, so usp_Account_Lock compares with ORIGINAL_LOGIN() (the real caller).
DECLARE @Status NVARCHAR(20);
BEGIN TRY
    EXEC sys.sp_executesql N'EXEC (N''EXEC dbo.usp_Account_Lock @Username = N''''t_lockout'''', @Lock = 1;'') AT QLTTTA_T_LINK_MAIN;';
    INSERT #Results VALUES ('S15', N'A manager locks their own account', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    SET @Status = (SELECT Status FROM dbo.ACCOUNT WHERE Username = N't_lockout');
    INSERT #Results VALUES ('S15', N'A manager locks their own account', N'Rejected', N'Rejected',
                            ERROR_MESSAGE() + N' (status: ' + ISNULL(@Status, N'?') + N')');
END CATCH;
GO

-- S16: the manager locks t_lockout => DENY CONNECT, status Locked, and SQL Server refuses the sign-in
--      usp_Account_Lock runs DENY CONNECT TO the user (dynamic SQL) and sets ACCOUNT.Status; both are checked first,
--      then a real sign-in must fail with error 18456 - the lock is enforced by SQL Server, not by the application.
--      A lock that was not recorded raises error 50099 inside the TRY: Rejected, but without 18456 => FAILED.
DECLARE @SignedInAs SYSNAME, @Error NVARCHAR(400), @Status NVARCHAR(20), @Denied INT;
BEGIN TRY
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Account_Lock @Username = N't_lockout', @Lock = 1;
    REVERT;
    SET @Status = (SELECT Status FROM dbo.ACCOUNT WHERE Username = N't_lockout');
    SET @Denied = (SELECT COUNT(*) FROM sys.database_permissions
                   WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID(N't_lockout')
                     AND permission_name = 'CONNECT' AND state = 'D');
    IF @Status <> N'Locked' OR @Denied <> 1
        THROW 50099, N'usp_Account_Lock did not record the lock (status / DENY CONNECT).', 1;
    EXEC #usp_SignIn N'QLTTTA_T_LINK_MAIN', @SignedInAs OUTPUT, @Error OUTPUT;
    IF @SignedInAs IS NOT NULL
        INSERT #Results VALUES ('S16', N'Locked account signs in', N'Rejected', N'Succeeded', N'Signed in as ' + @SignedInAs);
    ELSE
        INSERT #Results VALUES ('S16', N'Locked account signs in', N'Rejected', N'Rejected', @Error);
END TRY
BEGIN CATCH
    IF USER_NAME() <> N'dbo' REVERT;
    INSERT #Results VALUES ('S16', N'Locked account signs in', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S17: after unlocking (GRANT CONNECT), the same account signs in again
--      Proves the lock is reversible: the status returns to Active and the sign-in works.
DECLARE @SignedInAs SYSNAME, @Error NVARCHAR(400), @Status NVARCHAR(20);
BEGIN TRY
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Account_Lock @Username = N't_lockout', @Lock = 0;
    REVERT;
    SET @Status = (SELECT Status FROM dbo.ACCOUNT WHERE Username = N't_lockout');
    EXEC #usp_SignIn N'QLTTTA_T_LINK_MAIN', @SignedInAs OUTPUT, @Error OUTPUT;
    INSERT #Results VALUES ('S17', N'Unlocked account signs in again', N'Succeeded',
                            CASE WHEN @Status = N'Active' AND @SignedInAs = N't_lockout' THEN N'Succeeded' ELSE N'Rejected' END,
                            N'Status ' + ISNULL(@Status, N'?') + N', ' + ISNULL(N'signed in as ' + @SignedInAs, @Error));
END TRY
BEGIN CATCH
    IF USER_NAME() <> N'dbo' REVERT;
    INSERT #Results VALUES ('S17', N'Unlocked account signs in again', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S18: academic staff lock an account (EXECUTE is granted to rl_Manager only)
--      Concept: permission on a procedure (no GRANT EXECUTE for rl_AcademicStaff).
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Account_Lock @Username = N't_lockout', @Lock = 1;
    REVERT;
    INSERT #Results VALUES ('S18', N'Academic staff lock an account', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('S18', N'Academic staff lock an account', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- S19: the manager resets the password of t_lockout (usp_Account_ResetPassword, EXECUTE AS OWNER)
--      Proves the reset with real sign-ins: after the reset the account signs in with the new password, and the
--      old password is refused (error 18456). The linked server login of MAIN is switched to each password in
--      turn (sp_addlinkedsrvlogin replaces it). #Ctx keeps the current password for any later batch.
--      Concept: ALTER USER ... WITH PASSWORD without OLD_PASSWORD, allowed because the procedure runs as dbo.
DECLARE @Old NVARCHAR(128) = (SELECT Value FROM #Ctx WHERE Name = 'Password');
DECLARE @New NVARCHAR(128) = N'Bb2@' + REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N'');
DECLARE @SignedNew SYSNAME, @ErrorNew NVARCHAR(400), @SignedOld SYSNAME, @ErrorOld NVARCHAR(400);
BEGIN TRY
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Account_ResetPassword @Username = N't_lockout', @NewPassword = @New;
    REVERT;
    UPDATE #Ctx SET Value = @New WHERE Name = 'Password';
    EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'QLTTTA_T_LINK_MAIN', @useself = 'FALSE', @locallogin = NULL,
         @rmtuser = N't_lockout', @rmtpassword = @New;
    EXEC #usp_SignIn N'QLTTTA_T_LINK_MAIN', @SignedNew OUTPUT, @ErrorNew OUTPUT;
    EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'QLTTTA_T_LINK_MAIN', @useself = 'FALSE', @locallogin = NULL,
         @rmtuser = N't_lockout', @rmtpassword = @Old;
    EXEC #usp_SignIn N'QLTTTA_T_LINK_MAIN', @SignedOld OUTPUT, @ErrorOld OUTPUT;
    INSERT #Results VALUES ('S19', N'Reset password: the new one signs in, the old one is refused', N'Succeeded',
        CASE WHEN @SignedNew = N't_lockout' AND @SignedOld IS NULL AND @ErrorOld LIKE N'%18456%'
             THEN N'Succeeded' ELSE N'Wrong result' END,
        N'new password: ' + ISNULL(N'signed in as ' + @SignedNew, @ErrorNew) + N'; old password: '
        + ISNULL(N'signed in as ' + @SignedOld, LEFT(@ErrorOld, 120)));
END TRY
BEGIN CATCH
    IF USER_NAME() <> N'dbo' REVERT;
    INSERT #Results VALUES ('S19', N'Reset password: the new one signs in, the old one is refused', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- CLEANUP + SUMMARY ---------------- */
EXEC #usp_Cleanup;
GO

-- Same summary as in 12_tests.sql (see the comments there); the cleanup runs first, so the scratch objects are
-- gone even when the verdict is FAILED
IF OBJECT_ID('tempdb..#Summary') IS NOT NULL DROP TABLE #Summary;
SELECT COALESCE(r.TestId, e.TestId) AS TestId,
       ISNULL(r.Description, N'(test case did not run)') AS Description, r.Expected, r.Actual,
       CASE WHEN r.TestId IS NOT NULL AND e.TestId IS NOT NULL AND r.Expected = r.Actual
                 AND (e.MessagePattern IS NULL OR r.Message LIKE e.MessagePattern)
            THEN N'PASSED' ELSE N'FAILED' END AS Verdict,
       r.Message
INTO #Summary
FROM #Results r
FULL OUTER JOIN #Expected e ON e.TestId = r.TestId;

SELECT TestId, Description, Expected, Actual, Verdict, Message FROM #Summary ORDER BY TestId;
SELECT COUNT(*) AS TotalCases, SUM(CASE WHEN Verdict = N'PASSED' THEN 1 ELSE 0 END) AS PassedCases FROM #Summary;

-- Makes the run fail: sqlcmd -b returns exit code 1 (scripts/test_all stops), SSMS shows error 50099
IF EXISTS (SELECT 1 FROM #Summary WHERE Verdict <> N'PASSED')
    THROW 50099, N'Some server-level test cases FAILED (see the summary table above).', 1;
GO
