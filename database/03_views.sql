/* =====================================================================
   File   : 03_views.sql - Views
   - Summary views used by the forms and reports
   - Security views: restrict ROWS (only the classes of the signed-in
     teacher) and COLUMNS (hide phone, email, tuition) => permissions are
     GRANTed on the views instead of the base tables.
   What   : a view is a stored SELECT that is queried like a table. The first group joins and
            summarizes data for the screens, the Dashboard and the reports; the second group (the
            vw_Teacher_My* views) is the data a teacher may see.
   Order  : fourth script of db_init (00 -> 07): after the tables and functions they read, before
            the procedures that read some of them. 06_security.sql GRANTs SELECT on the views
            that a role reads directly.
   Defense: - views as the security layer: a business role gets SELECT on a view, not on the
              tables behind it. Ownership chaining: the view and its tables have the same owner
              (dbo), so SQL Server checks the permission on the view only and does not check the
              tables at all - even the DENY SELECT ON STUDENT of rl_Teacher does not block
              vw_Teacher_MyStudents (tests P01 and P02 of 12_tests.sql)
            - row filter by the signed-in user: WHERE ... = dbo.fn_CurrentTeacherId() (based on
              USER_NAME()) makes the same view return different rows to each teacher
            - column filter: the teacher views leave out phone, email and money columns
            - computed columns: FOR XML PATH string concatenation (vw_ClassDetails), scalar
              functions per row (vw_LearningResults), GROUP BY / HAVING (vw_CourseInvalidWeights)
            - no SELECT * (checked by test T30): a view lists its columns, so a new table column
              does not silently appear in it
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. vw_CurrentAccount: the signed-in user (read by the application after sign-in)
      One row (or none) for USER_NAME(): the account, its role code and the name and branch of the
      linked employee OR teacher. LEFT JOIN because only one of EmployeeId / TeacherId is filled
      (CK_ACCOUNT_Owner); COALESCE takes the value that is not NULL. COLLATE DATABASE_DEFAULT:
      see fn_CurrentRole in 02_functions.sql.
      Used by: usp_Account_RecordLogin returns this row to the application right after sign-in
      (SqlAuthGateway); the application then builds its menu from the role. SELECT is GRANTed to
      every role.
      Concepts: view filtered by the current user, LEFT JOIN + COALESCE. */
IF OBJECT_ID(N'dbo.vw_CurrentAccount', N'V') IS NOT NULL DROP VIEW dbo.vw_CurrentAccount;
GO
CREATE VIEW dbo.vw_CurrentAccount
AS
SELECT ac.Username, ac.Role, ac.EmployeeId, ac.TeacherId, ac.Status,
       COALESCE(em.FullName, te.FullName) AS FullName,
       COALESCE(em.BranchId, te.BranchId) AS BranchId
FROM dbo.ACCOUNT ac
LEFT JOIN dbo.EMPLOYEE em ON em.EmployeeId = ac.EmployeeId
LEFT JOIN dbo.TEACHER te  ON te.TeacherId = ac.TeacherId
WHERE ac.Username = USER_NAME() COLLATE DATABASE_DEFAULT;
GO

/* 2. vw_StudentOverview: students + number of active classes + total balance due
      The derived table t aggregates ENROLLMENT once per student: ActiveClassCount = enrollments
      with status Studying, TotalBalance = what is still owed on the enrollments that are not Left.
      LEFT JOIN + ISNULL(..., 0): a student without any enrollment still appears, with 0.
      Used by: usp_Student_Search (Students screen, SqlStudentRepository); SELECT is GRANTed to
      rl_AcademicStaff and rl_Accountant.
      Concepts: derived table with GROUP BY, conditional aggregation SUM(CASE ...), LEFT JOIN. */
IF OBJECT_ID(N'dbo.vw_StudentOverview', N'V') IS NOT NULL DROP VIEW dbo.vw_StudentOverview;
GO
CREATE VIEW dbo.vw_StudentOverview
AS
SELECT st.StudentId, st.FullName, st.DateOfBirth, st.Gender, st.Phone, st.Email,
       st.GuardianName, st.GuardianPhone, st.BranchId, br.BranchName, st.RegisteredOn, st.Status,
       ISNULL(t.ActiveClassCount, 0) AS ActiveClassCount,
       ISNULL(t.TotalBalance, 0)     AS TotalBalance
FROM dbo.STUDENT st
JOIN dbo.BRANCH br ON br.BranchId = st.BranchId
LEFT JOIN (
    SELECT StudentId,
           SUM(CASE WHEN Status = N'Studying' THEN 1 ELSE 0 END) AS ActiveClassCount,
           SUM(CASE WHEN Status <> N'Left' THEN TuitionDue - AmountPaid ELSE 0 END) AS TotalBalance
    FROM dbo.ENROLLMENT
    GROUP BY StudentId
) t ON t.StudentId = st.StudentId;
GO

/* 3. vw_ClassDetails: class + course + teacher + room + enrollment + weekly schedule
      (Schedule: "Mon 18:00-20:00, Wed 18:00-20:00"; the application localizes the day names)
      EnrolledCount counts the Studying and Completed enrollments (same rule as fn_EnrolledCount);
      SeatsLeft = MaxStudents - EnrolledCount.
      Used by: the Classes screen and the class pickers of the enrollment and grade book screens
      (SqlClassRepository, SqlEnrollmentRepository, SqlGradeRepository); SELECT is GRANTed to
      rl_AcademicStaff and rl_Accountant.
      Concepts: join of six tables, correlated subquery, string concatenation with FOR XML PATH
      (the SQL Server 2012 way; STRING_AGG only exists from SQL Server 2017). */
IF OBJECT_ID(N'dbo.vw_ClassDetails', N'V') IS NOT NULL DROP VIEW dbo.vw_ClassDetails;
GO
CREATE VIEW dbo.vw_ClassDetails
AS
SELECT cl.ClassId, cl.ClassName, cl.CourseId, co.CourseName, co.Level, pg.ProgramName,
       cl.BranchId, br.BranchName, cl.TeacherId, te.FullName AS TeacherName, cl.RoomId, rm.RoomName,
       cl.StartDate, cl.EndDate, cl.MaxStudents,
       ISNULL(en.EnrolledCount, 0)                  AS EnrolledCount,
       cl.MaxStudents - ISNULL(en.EnrolledCount, 0) AS SeatsLeft,
       cl.Tuition, cl.Status,
       -- Schedule as one text: the subquery returns ", Mon 18:00-20:00" for every weekly slot;
       -- FOR XML PATH('') glues those rows into one value, TYPE + .value('.', ...) turns it back
       -- into plain text (also undoing XML escapes such as &amp;) and STUFF(..., 1, 2, ...) removes
       -- the first ", ". CONVERT(..., 108) formats a time as hh:mi:ss and LEFT(..., 5) keeps hh:mi.
       STUFF((SELECT N', ' + CASE cs.Weekday WHEN 1 THEN N'Mon' WHEN 2 THEN N'Tue' WHEN 3 THEN N'Wed'
                                             WHEN 4 THEN N'Thu' WHEN 5 THEN N'Fri' WHEN 6 THEN N'Sat'
                                             ELSE N'Sun' END
                     + N' ' + LEFT(CONVERT(NVARCHAR(8), cs.StartTime, 108), 5)
                     + N'-' + LEFT(CONVERT(NVARCHAR(8), cs.EndTime, 108), 5)
              FROM dbo.CLASS_SCHEDULE cs WHERE cs.ClassId = cl.ClassId ORDER BY cs.Weekday
              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(200)'), 1, 2, N'') AS Schedule
FROM dbo.CLASS cl
JOIN dbo.COURSE co   ON co.CourseId = cl.CourseId
JOIN dbo.PROGRAM pg  ON pg.ProgramId = co.ProgramId
JOIN dbo.BRANCH br   ON br.BranchId = cl.BranchId
JOIN dbo.TEACHER te  ON te.TeacherId = cl.TeacherId
JOIN dbo.ROOM rm     ON rm.RoomId = cl.RoomId
LEFT JOIN (
    SELECT ClassId, COUNT(*) AS EnrolledCount FROM dbo.ENROLLMENT
    WHERE Status IN (N'Studying', N'Completed') GROUP BY ClassId
) en ON en.ClassId = cl.ClassId;
GO

/* 4. vw_OutstandingTuition: enrollments with unpaid tuition (for the accountant)
      One row per enrollment that still owes money and is not Left. ContactPhone = the student's
      phone, or the guardian's phone when the student has none (COALESCE); DaysSinceEnrollment
      shows how old the debt is.
      Used by: the Outstanding tuition screen (SqlListRepository), the payment form of the Tuition collection
      screen (SqlTuitionRepository::outstanding), usp_Dashboard_Stats (TotalOutstanding), the sqlcmd export
      example of 10_import_export.sql, the e2e GUI test; SELECT is GRANTed to rl_AcademicStaff and
      rl_Accountant.
      Concepts: view with a row filter, COALESCE, DATEDIFF. */
IF OBJECT_ID(N'dbo.vw_OutstandingTuition', N'V') IS NOT NULL DROP VIEW dbo.vw_OutstandingTuition;
GO
CREATE VIEW dbo.vw_OutstandingTuition
AS
SELECT en.EnrollmentId, st.StudentId, st.FullName AS StudentName,
       COALESCE(st.Phone, st.GuardianPhone) AS ContactPhone,
       cl.ClassId, cl.ClassName, cl.BranchId, en.EnrolledOn, en.TuitionDue, en.AmountPaid,
       en.TuitionDue - en.AmountPaid AS Balance,
       DATEDIFF(DAY, en.EnrolledOn, dbo.fn_Today()) AS DaysSinceEnrollment
FROM dbo.ENROLLMENT en
JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
JOIN dbo.CLASS cl   ON cl.ClassId = en.ClassId
WHERE en.TuitionDue > en.AmountPaid AND en.Status <> N'Left';
GO

/* 5. vw_MonthlyRevenue: revenue per month (of the center's local time) and branch
      Only valid receipts count (cancelled ones are left out); the branch is the branch of the
      class the receipt pays for. Unlike fn_MonthlyRevenue, a month without receipts has no row.
      CROSS APPLY converts PaidAtUtc to the center's local time once per receipt (PaidAtCenter),
      and that value gives the year and month to group by.
      Used by: the Revenue screen (SqlListRepository); SELECT is GRANTed to rl_Accountant.
      Concepts: GROUP BY over several joined tables, CROSS APPLY to compute a value once, YEAR() /
      MONTH() as grouping keys. */
IF OBJECT_ID(N'dbo.vw_MonthlyRevenue', N'V') IS NOT NULL DROP VIEW dbo.vw_MonthlyRevenue;
GO
CREATE VIEW dbo.vw_MonthlyRevenue
AS
SELECT YEAR(ct.PaidAtCenter) AS Year, MONTH(ct.PaidAtCenter) AS Month, cl.BranchId, br.BranchName,
       COUNT(*) AS ReceiptCount, SUM(rc.Amount) AS Revenue
FROM dbo.RECEIPT rc
CROSS APPLY (SELECT dbo.fn_UtcToCenterTime(rc.PaidAtUtc) AS PaidAtCenter) ct   -- converted once per receipt
JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
JOIN dbo.BRANCH br     ON br.BranchId = cl.BranchId
WHERE rc.Status = N'Valid'
GROUP BY YEAR(ct.PaidAtCenter), MONTH(ct.PaidAtCenter), cl.BranchId, br.BranchName;
GO

/* 6. vw_LearningResults: final grade, attendance and classification of every enrollment
      FinalGrade, Classification and AttendanceRate are computed live by scalar functions for each
      row (FinalGrade is NULL until every score is entered); Result is the stored value written by
      usp_Class_EvaluateResults. fn_Classification(fn_FinalGrade(...)) is the nested call that made
      00_create_database.sql turn off scalar UDF inlining.
      Used by: the Learning results screen (SqlListRepository), usp_Report_ClassResults,
      08_demo_queries.sql; SELECT is GRANTed to rl_AcademicStaff.
      Concepts: view calling scalar functions per row, nested function call. */
IF OBJECT_ID(N'dbo.vw_LearningResults', N'V') IS NOT NULL DROP VIEW dbo.vw_LearningResults;
GO
CREATE VIEW dbo.vw_LearningResults
AS
SELECT en.EnrollmentId, en.ClassId, cl.ClassName, en.StudentId, st.FullName AS StudentName,
       dbo.fn_FinalGrade(en.EnrollmentId)                         AS FinalGrade,
       dbo.fn_Classification(dbo.fn_FinalGrade(en.EnrollmentId))  AS Classification,
       dbo.fn_AttendanceRate(en.EnrollmentId)                     AS AttendanceRate,
       en.Result, en.Status
FROM dbo.ENROLLMENT en
JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
JOIN dbo.CLASS cl   ON cl.ClassId = en.ClassId;
GO

/* 7. vw_SessionDetails: detailed timetable, one row per session
      Room and teacher come from the session itself (CLASS_SESSION), not from the class.
      Used by: the Timetable & attendance screen (SqlSessionRepository, one week at a time; its SessionId
      opens the attendance and the session form); SELECT is GRANTed to rl_AcademicStaff.
      Concepts: multi-table join view. */
IF OBJECT_ID(N'dbo.vw_SessionDetails', N'V') IS NOT NULL DROP VIEW dbo.vw_SessionDetails;
GO
CREATE VIEW dbo.vw_SessionDetails
AS
SELECT se.SessionId, se.ClassId, cl.ClassName, se.SessionNo, se.SessionDate, se.StartTime, se.EndTime,
       se.RoomId, rm.RoomName, cl.BranchId, se.TeacherId, te.FullName AS TeacherName,
       se.Description, se.Status
FROM dbo.CLASS_SESSION se
JOIN dbo.CLASS cl   ON cl.ClassId = se.ClassId
JOIN dbo.ROOM rm    ON rm.RoomId = se.RoomId
JOIN dbo.TEACHER te ON te.TeacherId = se.TeacherId;
GO

/* 8. vw_CourseInvalidWeights: courses whose grade weights do not add up to 100%
      (SQL Server has no deferred constraints, so this is checked by a view and
      again by the procedure that evaluates the results).
      LEFT JOIN + ISNULL(SUM(...), 0): a course without any grade component is listed too (total 0).
      HAVING filters the groups after GROUP BY (WHERE runs before grouping and cannot test SUM).
      An empty result means every course is consistent.
      Used by: usp_Class_EvaluateResults (refuses a course listed here, error 50044).
      Concepts: GROUP BY + HAVING, a multi-row integrity rule checked through a view. */
IF OBJECT_ID(N'dbo.vw_CourseInvalidWeights', N'V') IS NOT NULL DROP VIEW dbo.vw_CourseInvalidWeights;
GO
CREATE VIEW dbo.vw_CourseInvalidWeights
AS
SELECT co.CourseId, co.CourseName, ISNULL(SUM(gc.Weight), 0) AS TotalWeight
FROM dbo.COURSE co
LEFT JOIN dbo.GRADE_COMPONENT gc ON gc.CourseId = co.CourseId
GROUP BY co.CourseId, co.CourseName
HAVING ISNULL(SUM(gc.Weight), 0) <> 100;
GO

/* ===== SECURITY VIEWS FOR TEACHERS (filtered by the signed-in user) =====
   Every view below filters with dbo.fn_CurrentTeacherId(): the TeacherId of the ACCOUNT row of
   USER_NAME(). The same SELECT therefore returns gv_john's rows to gv_john and other rows to
   another teacher; for a user without a TeacherId the function returns NULL, the comparison with
   NULL is never true, and the view is empty. rl_Teacher gets SELECT on these views and an explicit
   DENY on STUDENT, RECEIPT and PAYROLL (06_security.sql); ownership chaining still lets the views
   read those tables. */

/* 9. vw_Teacher_MyClasses: only the classes of the signed-in teacher
      Row filter: classes whose main teacher (CLASS.TeacherId) is the signed-in teacher.
      Used by: the My classes screen (SqlListRepository; CourseId opens the syllabus), the class list of the
      My grade book screen (SqlGradeRepository), test P02; SELECT is GRANTed to rl_Teacher.
      Concepts: security view (row filter by the signed-in user), ownership chaining. */
IF OBJECT_ID(N'dbo.vw_Teacher_MyClasses', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MyClasses;
GO
CREATE VIEW dbo.vw_Teacher_MyClasses
AS
SELECT cl.ClassId, cl.ClassName, cl.CourseId, co.CourseName, rm.RoomName, br.BranchName, cl.StartDate, cl.EndDate,
       cl.Status, dbo.fn_EnrolledCount(cl.ClassId) AS EnrolledCount
FROM dbo.CLASS cl
JOIN dbo.COURSE co  ON co.CourseId = cl.CourseId
JOIN dbo.ROOM rm    ON rm.RoomId = cl.RoomId
JOIN dbo.BRANCH br  ON br.BranchId = cl.BranchId
WHERE cl.TeacherId = dbo.fn_CurrentTeacherId();
GO

/* 10. vw_Teacher_MyStudents: students of the teacher's classes, WITHOUT phone/email/tuition
       Row filter: the enrollments of the classes whose main teacher is the signed-in teacher.
       Column filter: only IDs, names, gender, enrollment status and attendance rate - no contact
       data and no money. rl_Teacher has DENY SELECT on STUDENT, yet this view reads STUDENT:
       the view and the table are both owned by dbo (ownership chaining), so SQL Server checks
       only the SELECT permission on the view.
       Used by: My classes screen - Students (SqlClassRepository::students), test P02 of 12_tests.sql; SELECT is
       GRANTed to rl_Teacher. The report quotes this view verbatim.
       Concepts: security view (row and column filter), ownership chaining, GRANT on a view
       instead of the table. */
IF OBJECT_ID(N'dbo.vw_Teacher_MyStudents', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MyStudents;
GO
CREATE VIEW dbo.vw_Teacher_MyStudents
AS
SELECT en.EnrollmentId, cl.ClassId, cl.ClassName, st.StudentId, st.FullName AS StudentName, st.Gender,
       en.Status, dbo.fn_AttendanceRate(en.EnrollmentId) AS AttendanceRate
FROM dbo.ENROLLMENT en
JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
JOIN dbo.CLASS cl   ON cl.ClassId = en.ClassId
WHERE cl.TeacherId = dbo.fn_CurrentTeacherId();
GO

/* 11. vw_Teacher_MySchedule: sessions taught by the signed-in teacher
       Filters on the teacher of each session (CLASS_SESSION.TeacherId), not on the main teacher
       of the class, so it follows who teaches each session.
       Used by: the Teaching schedule screen (SqlSessionRepository, one week at a time; its SessionId opens
       the attendance and the session form); SELECT is GRANTed to rl_Teacher.
       Concepts: security view (row filter by the signed-in user). */
IF OBJECT_ID(N'dbo.vw_Teacher_MySchedule', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MySchedule;
GO
CREATE VIEW dbo.vw_Teacher_MySchedule
AS
SELECT se.SessionId, se.ClassId, cl.ClassName, se.SessionNo, se.SessionDate, se.StartTime, se.EndTime,
       rm.RoomName, se.Description, se.Status
FROM dbo.CLASS_SESSION se
JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
JOIN dbo.ROOM rm  ON rm.RoomId = se.RoomId
WHERE se.TeacherId = dbo.fn_CurrentTeacherId();
GO

/* 12. vw_Teacher_MyGrades: component scores of the students in the teacher's classes
       One row per (enrollment, grade component of the course): the JOIN with GRADE_COMPONENT
       builds every pair and the LEFT JOIN with GRADE (on both EnrollmentId and ComponentId) adds
       the score when it exists, so a missing score shows as NULL - like a grading sheet with
       empty cells. Grades are saved through usp_Grade_Save, not through this view.
       Used by: My grade book screen (SqlGradeRepository::cells); SELECT is GRANTed to rl_Teacher
       (06_security.sql).
       Concepts: security view, LEFT JOIN on two columns to show missing values. */
IF OBJECT_ID(N'dbo.vw_Teacher_MyGrades', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MyGrades;
GO
CREATE VIEW dbo.vw_Teacher_MyGrades
AS
SELECT en.EnrollmentId, cl.ClassId, st.StudentId, st.FullName AS StudentName,
       gc.ComponentId, gc.ComponentName, gc.Weight, gr.Score
FROM dbo.ENROLLMENT en
JOIN dbo.STUDENT st          ON st.StudentId = en.StudentId
JOIN dbo.CLASS cl            ON cl.ClassId = en.ClassId
JOIN dbo.GRADE_COMPONENT gc  ON gc.CourseId = cl.CourseId
LEFT JOIN dbo.GRADE gr       ON gr.EnrollmentId = en.EnrollmentId AND gr.ComponentId = gc.ComponentId
WHERE cl.TeacherId = dbo.fn_CurrentTeacherId();
GO

/* 13. vw_Teacher_MyPay: payroll of the signed-in teacher only
       Only the rows WHERE TeacherId = fn_CurrentTeacherId(); TeacherId itself is not shown.
       rl_Teacher has DENY SELECT on PAYROLL, but with an unbroken ownership chain the table
       permission (even a DENY) is not checked when the data is read through this view.
       Used by: the My pay screen (SqlListRepository); SELECT is GRANTed to rl_Teacher.
       Concepts: security view, ownership chaining. */
IF OBJECT_ID(N'dbo.vw_Teacher_MyPay', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MyPay;
GO
CREATE VIEW dbo.vw_Teacher_MyPay
AS
SELECT Month, Year, SessionCount, Hours, HourlyRate, Bonus, Deduction, TotalPay, Status
FROM dbo.PAYROLL
WHERE TeacherId = dbo.fn_CurrentTeacherId();
GO
