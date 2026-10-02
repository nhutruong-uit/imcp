/* =====================================================================
   File   : 06_security.sql - Authentication & authorization
   Model:
     - Every application account = 1 USER with a password in the
       contained database => SQL Server authenticates it; the password is
       hashed and managed by the DBMS, never stored in an application table.
     - 4 ROLES, one per business role; permissions are GRANTed to roles,
       never to users.
     - Least privilege: business roles have NO permission on the base
       tables, only EXECUTE on procedures and SELECT on views. Thanks to
       ownership chaining (views/procedures and tables share the owner dbo),
       users reach the data through views/procedures without table rights.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. ROLES */
IF DATABASE_PRINCIPAL_ID('rl_Manager')       IS NULL CREATE ROLE rl_Manager       AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_AcademicStaff') IS NULL CREATE ROLE rl_AcademicStaff AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_Accountant')    IS NULL CREATE ROLE rl_Accountant    AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID('rl_Teacher')       IS NULL CREATE ROLE rl_Teacher       AUTHORIZATION dbo;
GO

/* 2. Permissions shared by every signed-in user */
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
ALTER ROLE db_datareader ADD MEMBER rl_Manager;
GRANT EXECUTE ON SCHEMA::dbo TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.BRANCH           TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.ROOM             TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.PROGRAM          TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.COURSE           TO rl_Manager;
GRANT INSERT, UPDATE, DELETE ON dbo.GRADE_COMPONENT TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.EMPLOYEE         TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.TEACHER          TO rl_Manager;
GRANT INSERT, UPDATE ON dbo.PROMOTION        TO rl_Manager;
-- Not even the manager may change the audit log or delete financial documents
DENY UPDATE, DELETE ON dbo.AUDIT_LOG TO rl_Manager;
DENY DELETE ON dbo.RECEIPT TO rl_Manager;
GO

/* 4. ACADEMIC STAFF: students, classes, schedules, enrollment, placement tests */
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
GRANT EXECUTE ON dbo.usp_Session_Update             TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_Create          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_TransferClass   TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_UpdateStatus    TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Enrollment_ByClass         TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_PlacementTest_Add          TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Attendance_BySession       TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Attendance_Save            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Grade_Save                 TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Course_FindBySkill         TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Course_Syllabus            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Teacher_FindByCertificate  TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Dashboard_Stats            TO rl_AcademicStaff;
GRANT EXECUTE ON dbo.usp_Report_ClassResults        TO rl_AcademicStaff;
GRANT SELECT  ON dbo.fn_TeacherSchedule             TO rl_AcademicStaff;
-- Academic staff can neither see payroll nor collect payments
DENY SELECT ON dbo.PAYROLL TO rl_AcademicStaff;
DENY EXECUTE ON dbo.usp_Receipt_Create TO rl_AcademicStaff;
GO

/* 5. ACCOUNTANT: tuition, outstanding balances, revenue, payroll */
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
GRANT EXECUTE ON dbo.usp_Receipt_Create       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Receipt_Cancel       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Receipt_Print        TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Payroll_Finalize     TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Report_Revenue       TO rl_Accountant;
GRANT EXECUTE ON dbo.usp_Dashboard_Stats      TO rl_Accountant;
GRANT SELECT  ON dbo.fn_MonthlyRevenue        TO rl_Accountant;
GRANT SELECT  ON dbo.fn_StudentBalance        TO rl_Accountant;
-- Accountants can neither change grades nor enroll students
DENY EXECUTE ON dbo.usp_Grade_Save        TO rl_Accountant;
DENY EXECUTE ON dbo.usp_Enrollment_Create TO rl_Accountant;
GO

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
      so the accounts are created at the end of the seed file. */
