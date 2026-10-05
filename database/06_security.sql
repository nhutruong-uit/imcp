/* =====================================================================
   File   : 06_security.sql - Authentication & authorization
   Model:
     - Every application account = 1 USER with a password in the
       contained database => SQL Server authenticates it; the password is
       hashed and managed by the DBMS, never stored in an application table.
     - 4 ROLES, one per business role; permissions are GRANTed to roles,
       never to users.
     - Least privilege: business roles write data ONLY through procedures
       (EXECUTE) and read mostly through views (SELECT); direct table rights
       are limited to the catalogs and the few tables granted below. Thanks to
       ownership chaining (views/procedures and tables share the owner dbo),
       users reach the data through views/procedures without table rights.

   Login vs contained user:
     - A LOGIN is a server-level principal (stored in master); a classic database USER is mapped to a
       login. A contained USER ... WITH PASSWORD has no login: the QLTTTA database checks the password
       itself, so a connection must name the database (the application and sqlcmd -d QLTTTA do).
       It needs CONTAINMENT = PARTIAL and contained database authentication (00_create_database.sql)
       and travels with a backup (no orphaned users, shown in 09_backup_restore.sql).
     - The users are created by usp_Account_Create (CREATE USER + ALTER ROLE ... ADD MEMBER in dynamic
       SQL), called for the demo accounts at the end of 07_seed_data.sql (see section 7).
   GRANT / DENY / REVOKE:
     - GRANT gives a permission. DENY forbids it and always wins over a GRANT, even a GRANT received
       through another role. REVOKE only removes an earlier GRANT or DENY (back to "not granted"); this
       file needs no REVOKE because db_init builds the database from scratch.
     - Every DENY below blocks a right the role does not receive in this file anyway: it states the
       rule explicitly and keeps it true if someone later adds a GRANT or a fixed role (defense in depth).
   Ownership chaining: when a view/procedure and the tables it reads have the same owner (dbo), SQL
     Server checks the permission on the view/procedure only and does not look at the tables at all
     (neither GRANT nor DENY). That is why a teacher reads vw_Teacher_MyStudents although SELECT on
     STUDENT is denied (tests P01 and P02). The chain does not cover dynamic SQL or statements such as
     CREATE USER and BACKUP: usp_Account_Create, usp_Account_Lock, usp_Account_ResetPassword and
     usp_Backup therefore run WITH EXECUTE AS OWNER.
   Run order: db_init runs this file after 05 (every granted object must exist). The table rights are
   checked by T29 in 12_tests.sql (a new table right must be added there on purpose) and the role
   behavior by P01-P12 (EXECUTE AS USER).
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. ROLES */
-- One database role per business role (ACCOUNT.Role holds the matching code, e.g. MANAGER -> rl_Manager).
-- The IF makes the file re-runnable; AUTHORIZATION dbo: the role is owned by dbo.
IF DATABASE_PRINCIPAL_ID('rl_Manager')       IS NULL CREATE ROLE rl_Manager       AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_AcademicStaff') IS NULL CREATE ROLE rl_AcademicStaff AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_Accountant')    IS NULL CREATE ROLE rl_Accountant    AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_Teacher')       IS NULL CREATE ROLE rl_Teacher       AUTHORIZATION dbo;
GO

/* 2. Permissions shared by every signed-in user */
-- vw_CurrentAccount: role, name and branch of the signed-in user, read right after sign-in.
-- usp_Account_ChangePassword runs as the caller (no EXECUTE AS): a user may change only their own password.
GRANT SELECT  ON dbo.vw_CurrentAccount          TO rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher;
GRANT EXECUTE ON dbo.usp_Account_RecordLogin    TO rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher;
GRANT EXECUTE ON dbo.usp_Account_ChangePassword TO rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher;
-- Catalogs used by combo boxes (no sensitive data)
GRANT SELECT ON dbo.BRANCH  TO rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher;
GRANT SELECT ON dbo.PROGRAM TO rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher;
GRANT SELECT ON dbo.COURSE  TO rl_Manager, rl_AcademicStaff, rl_Accountant, rl_Teacher;
GRANT SELECT ON dbo.ROOM    TO rl_Manager, rl_AcademicStaff, rl_Teacher;
GO

/* 3. MANAGER: every business operation, account administration, backups */
-- db_datareader: fixed database role = SELECT on every table and view (reports, administration).
-- EXECUTE ON SCHEMA::dbo: a schema-level permission that covers every procedure of dbo, also the ones
-- created later (account administration usp_Account_*, usp_Backup, ...).
-- The catalog screens of the application write through the procedures of group J (usp_Branch_Add ...), covered
-- by EXECUTE ON SCHEMA: like every other business role, the manager holds no INSERT/UPDATE/DELETE right on a table
-- (T29, P26). Several catalog rules live only in those procedures (code format 50092, nothing suspended,
-- discontinued or left while still needed 50093/50094/50098, no prerequisite loop 50095, a used promotion keeps its
-- rule 50110/50111), so a direct write would skip them. Maintenance outside the application is the job of the
-- database owner (sa / Windows administrator), still guarded by the triggers.
ALTER ROLE db_datareader ADD MEMBER rl_Manager;
GRANT EXECUTE ON SCHEMA::dbo TO rl_Manager;
-- Not even the manager may change the audit log or delete financial documents
-- (second layer next to the INSTEAD OF triggers trg_AUDIT_LOG_ReadOnly and trg_RECEIPT_PreventDelete;
-- tested by P08 for RECEIPT, P14 and P15 for AUDIT_LOG)
DENY UPDATE, DELETE ON dbo.AUDIT_LOG TO rl_Manager;
DENY DELETE ON dbo.RECEIPT TO rl_Manager;
GO

/* 4. ACADEMIC STAFF: students, classes, schedules, enrollment, placement tests */
-- Reads through views, writes through the procedures of their screens (which apply the business rules).
-- COLUMN-level GRANT on TEACHER: a query that names only granted columns works; SELECT * or a query that
-- names HourlyRate fails with a permission error (test P06; P05: the accountant may read it).
GRANT SELECT ON dbo.vw_StudentOverview     TO rl_AcademicStaff;
GRANT SELECT ON dbo.vw_ClassDetails        TO rl_AcademicStaff;
GRANT SELECT ON dbo.vw_SessionDetails      TO rl_AcademicStaff;
GRANT SELECT ON dbo.vw_LearningResults     TO rl_AcademicStaff;
GRANT SELECT ON dbo.vw_OutstandingTuition  TO rl_AcademicStaff;
GRANT SELECT ON dbo.TEACHER (TeacherId, FullName, TeacherType, Nationality, Degree, BranchId, Status)
    TO rl_AcademicStaff; -- COLUMN-level permission: the hourly rate stays hidden
GRANT SELECT ON dbo.PROMOTION              TO rl_AcademicStaff;
GRANT SELECT ON dbo.GRADE_COMPONENT        TO rl_AcademicStaff;
GRANT SELECT ON dbo.PLACEMENT_TEST         TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_Add                TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_Update             TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_Delete             TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_Search             TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_Details            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_ExportXml          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Student_ImportXml          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Class_Create               TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_ClassSchedule_Add          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Class_GenerateSessions     TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Class_UpdateStatus         TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Class_EvaluateResults      TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Class_Update               TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_ClassSchedule_Remove       TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_ClassSchedule_ByClass      TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Session_Update             TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_Create          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_TransferClass   TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_UpdateStatus    TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_ByClass         TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_Search          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_PlacementTest_Add          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_PlacementTest_Search       TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Attendance_BySession       TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Attendance_Save            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Grade_Save                 TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Grade_ByClass              TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Course_FindBySkill         TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Course_Syllabus            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Teacher_FindByCertificate  TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Dashboard_Stats            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Report_ClassResults        TO rl_AcademicStaff;
GRANT SELECT  ON dbo.fn_TeacherSchedule             TO rl_AcademicStaff;
-- Academic staff can neither see payroll nor collect payments (tested by P07 and P16)
DENY SELECT ON dbo.PAYROLL TO rl_AcademicStaff;
DENY EXECUTE ON dbo.usp_Receipt_Create TO rl_AcademicStaff;
GO

/* 5. ACCOUNTANT: tuition, outstanding balances, revenue, payroll */
-- RECEIPT and PAYROLL are read directly (the Payroll list of the application joins PAYROLL with TEACHER).
-- The column list of TEACHER includes HourlyRate (payroll) but none of the contact details or the XML profile.
-- fn_MonthlyRevenue / fn_StudentBalance are table-valued functions, so they need SELECT, not EXECUTE.
GRANT SELECT ON dbo.vw_OutstandingTuition  TO rl_Accountant;
GRANT SELECT ON dbo.vw_MonthlyRevenue      TO rl_Accountant;
GRANT SELECT ON dbo.vw_ClassDetails        TO rl_Accountant;
GRANT SELECT ON dbo.vw_StudentOverview     TO rl_Accountant;
GRANT SELECT ON dbo.PROMOTION              TO rl_Accountant;
GRANT SELECT ON dbo.RECEIPT                TO rl_Accountant;
GRANT SELECT ON dbo.PAYROLL                TO rl_Accountant;
GRANT SELECT ON dbo.TEACHER (TeacherId, FullName, TeacherType, HourlyRate, BranchId, Status) TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Student_Search       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Enrollment_ByClass   TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Enrollment_Search    TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Receipt_Create       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Receipt_Cancel       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Receipt_Print        TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Receipt_Search       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Payroll_Finalize     TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Payroll_Adjust       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Payroll_MarkPaid     TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Report_Revenue       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Dashboard_Stats      TO rl_Accountant;
GRANT SELECT  ON dbo.fn_MonthlyRevenue        TO rl_Accountant;
GRANT SELECT  ON dbo.fn_StudentBalance        TO rl_Accountant;
-- Accountants can neither change grades nor enroll students (tested by P17 and P04)
DENY EXECUTE ON dbo.usp_Grade_Save        TO rl_Accountant;
DENY EXECUTE ON dbo.usp_Enrollment_Create TO rl_Accountant;
GO

-- Teacher role (next section): row-level security through views. The vw_Teacher_My* views filter on
-- dbo.fn_CurrentTeacherId() (USER_NAME() -> ACCOUNT.TeacherId), so each teacher sees only their own
-- classes, students, sessions, grades and pay; the granted procedures check the same thing themselves
-- (fn_CurrentRole / fn_CurrentTeacherId, tests P03, P20, P21). The DENYs on the tables do not break the
-- views thanks to ownership chaining (P01, P18, P19: STUDENT, RECEIPT and PAYROLL are refused; P02: the views
-- work).

/* 6. TEACHER: only the data of their own classes (through views filtered by the signed-in user) */
GRANT SELECT ON dbo.vw_Teacher_MyClasses   TO rl_Teacher;
GRANT SELECT ON dbo.vw_Teacher_MyStudents  TO rl_Teacher;
GRANT SELECT ON dbo.vw_Teacher_MySchedule  TO rl_Teacher;
GRANT SELECT ON dbo.vw_Teacher_MyGrades    TO rl_Teacher;
GRANT SELECT ON dbo.vw_Teacher_MyPay       TO rl_Teacher;
GRANT EXECUTE ON dbo.usp_Session_Update        TO rl_Teacher;
GRANT EXECUTE ON dbo.usp_Attendance_BySession  TO rl_Teacher;
GRANT EXECUTE ON dbo.usp_Attendance_Save       TO rl_Teacher;
GRANT EXECUTE ON dbo.usp_Grade_Save            TO rl_Teacher;
GRANT EXECUTE ON dbo.usp_Course_Syllabus       TO rl_Teacher;
-- Explicitly block sensitive data (DENY wins over GRANT)
DENY SELECT ON dbo.STUDENT TO rl_Teacher;
DENY SELECT ON dbo.RECEIPT TO rl_Teacher;
DENY SELECT ON dbo.PAYROLL TO rl_Teacher;
GO

/* 7. Demo accounts (the demo password is in docs/SETUP.md; change it in a real deployment).
      Their EMPLOYEE/TEACHER rows are created in 07_seed_data.sql,
      so the accounts are created at the end of the seed file.
      usp_Account_Create maps the role code to the database role (MANAGER -> rl_Manager,
      ACADEMIC_STAFF -> rl_AcademicStaff, ACCOUNTANT -> rl_Accountant, TEACHER -> rl_Teacher). */
