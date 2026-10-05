/* =====================================================================
   File   : 09_backup_restore.sql - Backup & restore
   Suggested strategy for the center:
     - FULL         : once a week (Sunday 23:00)
     - DIFFERENTIAL : every night (23:00)
     - LOG          : every 30 minutes during working hours
     => at most 30 minutes of data loss (RPO); restore = FULL + latest DIFF + the LOGs after it.
   The paths below are for SQL Server on Docker/Linux; on Windows use
   'C:\Backup\...'. Run as sa: BACKUP only needs db_owner (or db_backupoperator) of QLTTTA, but
   RESTORE into a new database needs the CREATE DATABASE right (sysadmin or dbcreator).

   Backup types:
     - FULL: the whole database, plus the part of the log needed to make the copy consistent.
     - DIFFERENTIAL: only the extents (blocks of 8 pages) changed since the latest FULL, so it grows
       during the week and a restore needs only the latest one.
     - LOG: the transaction log records since the previous LOG backup. It needs the FULL recovery
       model (00_create_database.sql) and a first FULL backup that starts the log chain.
     RPO (Recovery Point Objective) = the most data the center accepts to lose = the time between
     two backups (here the 30 minutes between LOG backups).
   Restore chain: FULL -> latest DIFF -> every LOG after it, in order. Every step but the last uses
   NORECOVERY: the database stays in the "restoring" state and accepts the next backup. The last step
   uses RECOVERY: unfinished transactions are undone and the database comes online (no further backup
   can be applied after that).
   What the script does: 1-4 back up QLTTTA and check the files, 5 restores the chain into a NEW
   database QLTTTA_Restored, 6-7 compare and show the history, 8 cleans up. It is run by hand (not by
   db_init); 13_server_tests.sql (S01-S03) checks the same chain automatically.
   Run it only on a demo database: its FULL and LOG backups are real (not COPY_ONLY), so on a database
   with its own backup plan they would become the new base of the differentials and take log records
   out of that plan's log chain.
   ===================================================================== */
USE master;
GO

DECLARE @Folder NVARCHAR(200) = N'/var/opt/mssql/data/';   -- Windows: 'C:\Backup\'
DECLARE @Full NVARCHAR(300) = @Folder + N'QLTTTA_demo_full.bak',
        @Diff NVARCHAR(300) = @Folder + N'QLTTTA_demo_diff.bak',
        @Log  NVARCHAR(300) = @Folder + N'QLTTTA_demo_log.trn';

/* 1. FULL backup - with CHECKSUM to detect damaged pages */
-- INIT overwrites the file instead of appending another backup set; STATS = 25 prints the progress every 25%.
BACKUP DATABASE QLTTTA TO DISK = @Full
WITH INIT, CHECKSUM, NAME = N'QLTTTA - Full', STATS = 25;

/* Simulate new data after the FULL backup */
INSERT INTO QLTTTA.dbo.PROMOTION (PromotionId, PromotionName, DiscountType, DiscountValue, StartDate, EndDate)
VALUES ('PR-DEMO', N'Backup demo promotion', 'AMOUNT', 200000, QLTTTA.dbo.fn_Today(), DATEADD(DAY, 7, QLTTTA.dbo.fn_Today()));

/* 2. DIFFERENTIAL backup: only the extents changed since the latest FULL */
BACKUP DATABASE QLTTTA TO DISK = @Diff
WITH DIFFERENTIAL, INIT, CHECKSUM, NAME = N'QLTTTA - Differential';

/* 3. Transaction LOG backup - requires the FULL recovery model */
-- The UPDATE runs after the DIFF backup, so only the LOG backup holds the value 300000.
UPDATE QLTTTA.dbo.PROMOTION SET DiscountValue = 300000 WHERE PromotionId = 'PR-DEMO';
BACKUP LOG QLTTTA TO DISK = @Log
WITH INIT, CHECKSUM, NAME = N'QLTTTA - Log';

/* 4. Verify the backup */
-- VERIFYONLY reads the whole file (and its checksums) without restoring it; HEADERONLY lists the backup sets
-- in the file; FILELISTONLY lists the logical data/log files inside, the names that MOVE needs in step 5.
RESTORE VERIFYONLY FROM DISK = @Full WITH CHECKSUM;
RESTORE HEADERONLY FROM DISK = @Full;
RESTORE FILELISTONLY FROM DISK = @Full;
GO

/* 5. Restore the FULL -> DIFF -> LOG chain into a NEW database (QLTTTA_Restored)
      so the running database is not touched. MOVE renames the physical files. */
-- Variables live for one batch only, so the paths are declared again after the batch separator.
DECLARE @Folder NVARCHAR(200) = N'/var/opt/mssql/data/';
DECLARE @Full NVARCHAR(300) = @Folder + N'QLTTTA_demo_full.bak',
        @Diff NVARCHAR(300) = @Folder + N'QLTTTA_demo_diff.bak',
        @Log  NVARCHAR(300) = @Folder + N'QLTTTA_demo_log.trn',
        @Mdf  NVARCHAR(300) = @Folder + N'QLTTTA_Restored.mdf',
        @Ldf  NVARCHAR(300) = @Folder + N'QLTTTA_Restored_log.ldf';

IF DB_ID(N'QLTTTA_Restored') IS NOT NULL
BEGIN
    ALTER DATABASE QLTTTA_Restored SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QLTTTA_Restored;
END;

-- SINGLE_USER WITH ROLLBACK IMMEDIATE (above) disconnects the other sessions so an old copy can be dropped.
-- The chain: FULL and DIFF WITH NORECOVERY (the copy keeps waiting for more backups), then the LOG WITH
-- RECOVERY (the copy comes online). MOVE gives the copy its own files next to the original database;
-- REPLACE allows writing over an existing database of that name.
RESTORE DATABASE QLTTTA_Restored FROM DISK = @Full
WITH MOVE N'QLTTTA' TO @Mdf, MOVE N'QLTTTA_log' TO @Ldf, NORECOVERY, REPLACE;

RESTORE DATABASE QLTTTA_Restored FROM DISK = @Diff WITH NORECOVERY;

RESTORE LOG QLTTTA_Restored FROM DISK = @Log WITH RECOVERY;   -- RECOVERY: brings the database online
GO

/* 6. Compare: the restored copy has the data created after the FULL backup (thanks to DIFF + LOG).
      Contained users travel with the database, so they can sign in right away,
      without the "orphaned user" problem of users mapped to server logins. */
-- Both rows should show 300000: the FULL had no PR-DEMO, the DIFF brought the row, the LOG the update.
-- authentication_type_desc = DATABASE marks a contained user (its password is stored in the database).
SELECT 'QLTTTA' AS DatabaseName, PromotionId, DiscountValue FROM QLTTTA.dbo.PROMOTION WHERE PromotionId = 'PR-DEMO'
UNION ALL
SELECT 'QLTTTA_Restored', PromotionId, DiscountValue FROM QLTTTA_Restored.dbo.PROMOTION WHERE PromotionId = 'PR-DEMO';

SELECT name, type_desc, authentication_type_desc
FROM QLTTTA_Restored.sys.database_principals
WHERE authentication_type_desc = 'DATABASE';
GO

/* 7. Backup history (msdb) */
SELECT TOP (10) bs.database_name, bs.type AS BackupType,      -- D = Full, I = Differential, L = Log
       bs.backup_start_date, bs.backup_finish_date,
       CAST(bs.backup_size / 1024.0 / 1024 AS DECIMAL(10,2)) AS SizeMB, bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'QLTTTA'
ORDER BY bs.backup_finish_date DESC;
GO

/* 8. Clean up the demo data */
-- The backup files stay on disk; the next run overwrites them (INIT).
DELETE FROM QLTTTA.dbo.PROMOTION WHERE PromotionId = 'PR-DEMO';
IF DB_ID(N'QLTTTA_Restored') IS NOT NULL
BEGIN
    ALTER DATABASE QLTTTA_Restored SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QLTTTA_Restored;
END;
GO
