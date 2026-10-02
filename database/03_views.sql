/* =====================================================================
   File   : 03_views.sql - Views
   - Summary views used by the forms and reports
   - Security views: restrict ROWS (only the classes of the signed-in
     teacher) and COLUMNS (hide phone, email, tuition) => permissions are
     GRANTed on the views instead of the base tables.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1. vw_CurrentAccount: the signed-in user (read by the application after sign-in) */
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

/* 2. vw_StudentOverview: students + number of active classes + total balance due */
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
      (Schedule: "Mon 18:00-20:00, Wed 18:00-20:00"; the application localizes the day names) */
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

/* 4. vw_OutstandingTuition: enrollments with unpaid tuition (for the accountant) */
IF OBJECT_ID(N'dbo.vw_OutstandingTuition', N'V') IS NOT NULL DROP VIEW dbo.vw_OutstandingTuition;
GO
CREATE VIEW dbo.vw_OutstandingTuition
AS
SELECT en.EnrollmentId, st.StudentId, st.FullName AS StudentName,
       COALESCE(st.Phone, st.GuardianPhone) AS ContactPhone,
       cl.ClassId, cl.ClassName, cl.BranchId, en.EnrolledOn, en.TuitionDue, en.AmountPaid,
       en.TuitionDue - en.AmountPaid AS Balance,
       DATEDIFF(DAY, en.EnrolledOn, CAST(GETDATE() AS DATE)) AS DaysSinceEnrollment
FROM dbo.ENROLLMENT en
JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
JOIN dbo.CLASS cl   ON cl.ClassId = en.ClassId
WHERE en.TuitionDue > en.AmountPaid AND en.Status <> N'Left';
GO

/* 5. vw_MonthlyRevenue: revenue per month and branch */
IF OBJECT_ID(N'dbo.vw_MonthlyRevenue', N'V') IS NOT NULL DROP VIEW dbo.vw_MonthlyRevenue;
GO
CREATE VIEW dbo.vw_MonthlyRevenue
AS
SELECT YEAR(rc.PaidAt) AS Year, MONTH(rc.PaidAt) AS Month, cl.BranchId, br.BranchName,
       COUNT(*) AS ReceiptCount, SUM(rc.Amount) AS Revenue
FROM dbo.RECEIPT rc
JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
JOIN dbo.BRANCH br     ON br.BranchId = cl.BranchId
WHERE rc.Status = N'Valid'
GROUP BY YEAR(rc.PaidAt), MONTH(rc.PaidAt), cl.BranchId, br.BranchName;
GO

/* 6. vw_LearningResults: final grade, attendance and classification of every enrollment */
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

/* 7. vw_SessionDetails: detailed timetable, one row per session */
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
      again by the procedure that evaluates the results). */
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

/* ===== SECURITY VIEWS FOR TEACHERS (filtered by the signed-in user) ===== */

/* 9. vw_Teacher_MyClasses: only the classes of the signed-in teacher */
IF OBJECT_ID(N'dbo.vw_Teacher_MyClasses', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MyClasses;
GO
CREATE VIEW dbo.vw_Teacher_MyClasses
AS
SELECT cl.ClassId, cl.ClassName, co.CourseName, rm.RoomName, br.BranchName, cl.StartDate, cl.EndDate,
       cl.Status, dbo.fn_EnrolledCount(cl.ClassId) AS EnrolledCount
FROM dbo.CLASS cl
JOIN dbo.COURSE co  ON co.CourseId = cl.CourseId
JOIN dbo.ROOM rm    ON rm.RoomId = cl.RoomId
JOIN dbo.BRANCH br  ON br.BranchId = cl.BranchId
WHERE cl.TeacherId = dbo.fn_CurrentTeacherId();
GO

/* 10. vw_Teacher_MyStudents: students of the teacher's classes, WITHOUT phone/email/tuition */
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

/* 11. vw_Teacher_MySchedule: sessions taught by the signed-in teacher */
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

/* 12. vw_Teacher_MyGrades: component scores of the students in the teacher's classes */
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

/* 13. vw_Teacher_MyPay: payroll of the signed-in teacher only */
IF OBJECT_ID(N'dbo.vw_Teacher_MyPay', N'V') IS NOT NULL DROP VIEW dbo.vw_Teacher_MyPay;
GO
CREATE VIEW dbo.vw_Teacher_MyPay
AS
SELECT Month, Year, SessionCount, Hours, HourlyRate, Bonus, Deduction, TotalPay, Status
FROM dbo.PAYROLL
WHERE TeacherId = dbo.fn_CurrentTeacherId();
GO
