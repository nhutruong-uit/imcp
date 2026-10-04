/* =====================================================================
   File   : 10_import_export.sql - Data import / export
   The approaches shown:
     1. XML export with FOR XML (procedure usp_Student_ExportXml)
     2. XML import with .nodes() (procedure usp_Student_ImportXml)
     3. BULK INSERT from a CSV file
     4. bcp / sqlcmd (command line) - CSV export
     5. Qt application: Excel/CSV/PDF export from the list and report screens

   Run by hand as sa after db_init (not part of db_init); every demo leaves the data unchanged.
   13_server_tests.sql repeats the BULK INSERT of part 3 (S07, S08); 12_tests.sql T26 checks the
   XML export/import procedures.
   Ideas for the oral defense:
     - FOR XML PATH turns rows into an XML document and .nodes() + .value() turns an XML document back
       into rows: the same format can travel to another system and back.
     - BULK INSERT is executed BY THE SERVER: the file path is read by the SQL Server service on its
       own machine (inside the container for Docker), not by the client. It needs the server
       permission ADMINISTER BULK OPERATIONS (bulkadmin role or sa).
     - Data is loaded into a temporary table (staging) first, checked, and only then written to the
       real tables through the procedures, so the business rules still apply.
     - bcp and sqlcmd are command-line tools for files on the CLIENT machine.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. XML EXPORT: students of the Thu Duc branch */
-- usp_Student_ExportXml uses FOR XML PATH('Student'), ROOT('Students'), TYPE: one Student element per row,
-- StudentId and BranchId as attributes, the result is a single XML value (the input format of part 2).
EXEC dbo.usp_Student_ExportXml @BranchId = 'BR02';
GO

/* 2. XML IMPORT: data from another system / the export above (inside a demo transaction, then rolled back) */
-- usp_Student_ImportXml shreds the document with .nodes('/Students/Student') + .value() and skips a row whose
-- phone or email already exists (the third student has the phone of ST00001). The procedure has its own
-- BEGIN/COMMIT TRANSACTION: inside this outer transaction its COMMIT only lowers @@TRANCOUNT, so the outer
-- ROLLBACK still undoes the import.
BEGIN TRANSACTION;
EXEC dbo.usp_Student_ImportXml @BranchId = 'BR02', @Data = N'
<Students>
  <Student><FullName>Phạm Gia Hân</FullName><DateOfBirth>2001-04-12</DateOfBirth><Gender>Female</Gender>
           <Phone>0909555001</Phone><Email>han.pg@example.com</Email></Student>
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
-- Staging: the file goes into the temporary table #StudentCsv first (tempdb, visible to this session only),
-- so the rows can be checked before they reach STUDENT.
-- Options: FIRSTROW = 2 skips the header row; FIELDTERMINATOR / ROWTERMINATOR = comma and new line;
-- TABLOCK locks the whole table during the load, which makes bulk loading faster.
-- The lines of the file end with LF. Written '\n', SQL Server on Windows looks for CR+LF (0 rows imported) and on
-- Linux for LF, so the LF character itself is given: NCHAR(10). BULK INSERT takes the file name and the options
-- only as literals, so the statement is built as text and run with sp_executesql (dynamic SQL).
-- TRY/CATCH: when the file is missing, the script prints a hint instead of stopping.
IF OBJECT_ID('tempdb..#StudentCsv') IS NOT NULL DROP TABLE #StudentCsv;
CREATE TABLE #StudentCsv (
    FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10), Phone VARCHAR(15), Email VARCHAR(100),
    BranchId VARCHAR(10));

DECLARE @File NVARCHAR(260) = N'/var/opt/mssql/data/student_import.csv';   -- Windows: N'C:\Data\student_import.csv'
DECLARE @Sql NVARCHAR(MAX) = N'BULK INSERT #StudentCsv FROM N''' + REPLACE(@File, N'''', N'''''')
    + N''' WITH (DATAFILETYPE = ''widechar'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = '''
    + NCHAR(10) + N''', TABLOCK);';
BEGIN TRY
    EXEC sys.sp_executesql @Sql;

    SELECT FullName, DateOfBirth, Gender, Phone, NULLIF(Email, '') AS Email, BranchId FROM #StudentCsv;
    -- NULLIF(Email, '') turns an empty Email field into NULL.
    -- Load into the main table through the procedure so the business rules apply: call usp_Student_Add for
    -- each row with a cursor, as S08 of 13_server_tests.sql does (demo only, not committed). A direct
    -- set-based INSERT like the line below is shorter but skips the checks of the procedure:
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
   (kt_minh is a contained user, so -d must name the database; -C trusts the server certificate,
    -s"," sets the column separator, -W removes trailing spaces, -f 65001 writes UTF-8, -o the output file)

   -- Fast export/import of a whole table with bcp (Unicode character format -w)
   bcp QLTTTA.dbo.COURSE out course.dat -S localhost -U sa -P "<password>" -w -u
   bcp QLTTTA.dbo.COURSE_COPY in course.dat -S localhost -U sa -P "<password>" -w -u
   (out writes the table to a file, in loads the file into an EXISTING table: COURSE_COPY must be created
    first with the same columns; -u trusts the server certificate. The file is on the client machine.)

   -- SSMS: right-click the database > Tasks > Import Data / Export Data (Import/Export Wizard)
*/
