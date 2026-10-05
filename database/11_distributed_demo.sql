/* =====================================================================
   File   : 11_distributed_demo.sql - DISTRIBUTED database demo per branch
   Idea (Chapter 5 - distributed databases):
     - PRIMARY HORIZONTAL fragmentation of STUDENT by BranchId: every branch
       keeps its own students at its own site.
     - DERIVED HORIZONTAL fragmentation: ENROLLMENT/RECEIPT follow the class of the branch.
     - REPLICATION of rarely changing catalogs: PROGRAM, COURSE.
     - Distribution transparency: a UNION ALL view (distributed partitioned view);
       CHECK (BranchId = ...) lets the optimizer read only the fragments it needs.
   The demo uses 2 databases on 1 server; in production each database lives on its
   own server and the view goes through a Linked Server: [SRV_TD].QLTTTA_BR02.dbo.STUDENT

   What this script builds (the derived fragmentation and the PROGRAM copy above are design only):
     - one site database per branch with its STUDENT fragment (only the columns the demo needs) and a
       CHECK constraint that is exactly the fragment predicate (BranchId = 'BR01' / 'BR02');
     - a copy of COURSE at each site: SELECT ... INTO copies it once (a snapshot); real replication
       would keep the copies in sync when the catalog changes;
     - the view that rebuilds STUDENT, the correctness check and the partition-elimination query.
   Correctness of a horizontal fragmentation (section 4 checks it):
     - completeness: every row of STUDENT is in some fragment;
     - disjointness: no row is in two fragments (the two predicates can never both be true);
     - reconstruction: STUDENT = the UNION ALL of the fragments. UNION ALL and not UNION: the fragments
       are disjoint, so there is no duplicate to remove.
   How to run: by hand as sa (it drops and recreates QLTTTA_BR01 / QLTTTA_BR02), after db_init.
   13_server_tests.sql runs this file itself (sqlcmd include) and checks it in S09-S13.
   ===================================================================== */
USE master;
GO
IF DB_ID(N'QLTTTA_BR01') IS NOT NULL BEGIN ALTER DATABASE QLTTTA_BR01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE QLTTTA_BR01; END;
IF DB_ID(N'QLTTTA_BR02') IS NOT NULL BEGIN ALTER DATABASE QLTTTA_BR02 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE QLTTTA_BR02; END;
CREATE DATABASE QLTTTA_BR01 COLLATE Vietnamese_CI_AS;
CREATE DATABASE QLTTTA_BR02 COLLATE Vietnamese_CI_AS;
GO

/* 1. Fragment STUDENT_BR01 = σ(BranchId = 'BR01')(STUDENT) at the District 1 site */
-- σ = selection of relational algebra: the fragment keeps the rows that satisfy the predicate. The CHECK
-- constraint stores the predicate in the table: a student of another branch is rejected (S11) and the
-- optimizer can trust it (section 5).
USE QLTTTA_BR01;
GO
CREATE TABLE dbo.STUDENT (
    StudentId VARCHAR(10) NOT NULL PRIMARY KEY, FullName NVARCHAR(100) NOT NULL, DateOfBirth DATE NOT NULL,
    Phone VARCHAR(15) NULL, Status NVARCHAR(20) NOT NULL,
    BranchId VARCHAR(10) NOT NULL CONSTRAINT CK_STUDENT_BranchId CHECK (BranchId = 'BR01'));
INSERT INTO dbo.STUDENT
SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA.dbo.STUDENT WHERE BranchId = 'BR01';
-- The course catalog is replicated at every site (SELECT ... INTO creates the table and copies the rows;
-- S10 checks that both copies equal QLTTTA.dbo.COURSE)
SELECT CourseId, CourseName, Level, Tuition INTO dbo.COURSE FROM QLTTTA.dbo.COURSE;
GO

/* 2. Fragment STUDENT_BR02 = σ(BranchId = 'BR02')(STUDENT) at the Thu Duc site */
USE QLTTTA_BR02;
GO
CREATE TABLE dbo.STUDENT (
    StudentId VARCHAR(10) NOT NULL PRIMARY KEY, FullName NVARCHAR(100) NOT NULL, DateOfBirth DATE NOT NULL,
    Phone VARCHAR(15) NULL, Status NVARCHAR(20) NOT NULL,
    BranchId VARCHAR(10) NOT NULL CONSTRAINT CK_STUDENT_BranchId CHECK (BranchId = 'BR02'));
INSERT INTO dbo.STUDENT
SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA.dbo.STUDENT WHERE BranchId = 'BR02';
SELECT CourseId, CourseName, Level, Tuition INTO dbo.COURSE FROM QLTTTA.dbo.COURSE;
GO

/* 3. Central site: a distributed view over the fragments (reconstructs STUDENT = BR01 ∪ BR02) */
-- The BR01 database plays the central site here. Users query the view as if STUDENT were one table
-- (distribution transparency). In production the second SELECT reads the remote fragment through a linked
-- server, [server].database.dbo.table (S13 of 13_server_tests.sql shows it).
USE QLTTTA_BR01;
GO
CREATE VIEW dbo.vw_Student_AllBranches
AS
SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA_BR01.dbo.STUDENT
UNION ALL
SELECT StudentId, FullName, DateOfBirth, Phone, Status, BranchId FROM QLTTTA_BR02.dbo.STUDENT;
GO

/* 4. Correctness of the fragmentation:
      - Completeness: the fragments together hold every row of the original table
      - Disjointness: no StudentId is in 2 fragments
      - Reconstruction: UNION ALL of the fragments = the original table */
-- Expected: OriginalTable = FragmentBR01 + FragmentBR02 = Reconstructed, and Overlap = 0 (S09 checks it).
SELECT (SELECT COUNT(*) FROM QLTTTA.dbo.STUDENT) AS OriginalTable,
       (SELECT COUNT(*) FROM QLTTTA_BR01.dbo.STUDENT) AS FragmentBR01,
       (SELECT COUNT(*) FROM QLTTTA_BR02.dbo.STUDENT) AS FragmentBR02,
       (SELECT COUNT(*) FROM dbo.vw_Student_AllBranches) AS Reconstructed,
       (SELECT COUNT(*) FROM QLTTTA_BR01.dbo.STUDENT a JOIN QLTTTA_BR02.dbo.STUDENT b ON a.StudentId = b.StudentId) AS Overlap;

/* 5. A query filtered by BranchId: the Execution Plan (Ctrl+M in SSMS) shows that only
      the BR02 fragment is scanned, thanks to the CHECK constraint (partition elimination). */
-- The optimizer sees that BranchId = 'BR02' contradicts the CHECK of the BR01 fragment, so it skips that
-- table without reading it (S12 checks the plan automatically).
SELECT StudentId, FullName FROM dbo.vw_Student_AllBranches WHERE BranchId = 'BR02';
GO
