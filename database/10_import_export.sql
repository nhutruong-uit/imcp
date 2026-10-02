/* =====================================================================
   File   : 10_import_export.sql - Data import / export
   The approaches shown:
     1. XML export with FOR XML (procedure usp_Student_ExportXml)
     2. XML import with .nodes() (procedure usp_Student_ImportXml)
     3. BULK INSERT from a CSV file
     4. bcp / sqlcmd (command line) - CSV export
     5. Qt application: Excel/CSV/PDF export from the list and report screens
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. XML EXPORT: students of the Thu Duc branch */
EXEC dbo.usp_Student_ExportXml @BranchId = 'BR02';
GO

/* 2. XML IMPORT: data from another system / the export above (inside a demo transaction, then rolled back) */
BEGIN TRANSACTION;
EXEC dbo.usp_Student_ImportXml @BranchId = 'BR02', @Data = N'
<Students>
  <Student><FullName>Phạm Gia Hân</FullName><DateOfBirth>2001-04-12</DateOfBirth><Gender>Female</Gender>
           <Phone>0909555001</Phone><Email>han.pg@gmail.com</Email></Student>
  <Student><FullName>Trần Quốc Việt</FullName><DateOfBirth>1999-09-02</DateOfBirth><Gender>Male</Gender>
           <Phone>0909555002</Phone></Student>
  <Student><FullName>Nguyễn Văn An (duplicate phone - skipped)</FullName><DateOfBirth>2004-03-12</DateOfBirth>
           <Phone>0901000001</Phone></Student>
</Students>';
SELECT TOP (3) StudentId, FullName, Phone FROM dbo.STUDENT ORDER BY StudentId DESC;
ROLLBACK TRANSACTION;
GO

/* 3. BULK INSERT from a Unicode CSV (UTF-16 LE, with a header row) into a temporary table, then into STUDENT.
      DATAFILETYPE = 'widechar' reads Vietnamese text correctly on Windows and Linux, in every version.
      (Excel: File > Save As > "Unicode Text"; or convert UTF-8 to UTF-16 with Notepad++/iconv)
      Sample file: database/samples/student_import.csv (copy it to the SQL Server machine first:
      docker cp database/samples/student_import.csv <container>:/var/opt/mssql/data/) */
IF OBJECT_ID('tempdb..#StudentCsv') IS NOT NULL DROP TABLE #StudentCsv;
CREATE TABLE #StudentCsv (
    FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10), Phone VARCHAR(15), Email VARCHAR(100),
    BranchId VARCHAR(10));

BEGIN TRY
    BULK INSERT #StudentCsv
    FROM '/var/opt/mssql/data/student_import.csv'        -- Windows: 'C:\Data\student_import.csv'
    WITH (DATAFILETYPE = 'widechar', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);

    SELECT FullName, DateOfBirth, Gender, Phone, NULLIF(Email, '') AS Email, BranchId FROM #StudentCsv;
    -- Load into the main table through the procedure so the business rules apply (demo only, not committed):
    -- INSERT INTO dbo.STUDENT (FullName, DateOfBirth, Gender, Phone, Email, BranchId) SELECT ... FROM #StudentCsv;
END TRY
BEGIN CATCH
    PRINT N'The CSV file is not on the SQL Server machine yet: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 4. Command line (run in a terminal, not in SSMS):

   -- Export the outstanding tuition to CSV with sqlcmd
   sqlcmd -S localhost -d QLTTTA -U kt_minh -P "<password>" -C -s"," -W -f 65001 \
          -Q "SET NOCOUNT ON; SELECT EnrollmentId, StudentName, ClassName, Balance FROM dbo.vw_OutstandingTuition" \
          -o outstanding.csv

   -- Fast export/import of a whole table with bcp (Unicode character format -w)
   bcp QLTTTA.dbo.COURSE out course.dat -S localhost -U sa -P "<password>" -w -u
   bcp QLTTTA.dbo.COURSE_COPY in course.dat -S localhost -U sa -P "<password>" -w -u

   -- SSMS: right-click the database > Tasks > Import Data / Export Data (Import/Export Wizard)
*/
