/* =====================================================================
   File   : 02_functions.sql - Functions
   The three kinds of SQL Server functions:
     - Scalar function            : returns one value
     - Inline table-valued (ITVF) : returns the result of one SELECT
     - Multi-statement TVF        : fills a table variable with several statements
   What   : the user-defined functions (fn_) reused by views, procedures, triggers and tests:
            the time zone of the center (UTC <-> local time, today's date),
            an ISO weekday helper, who is signed in, final grade / classification / attendance,
            discounts, course recommendation, and table-valued functions for a teacher's
            schedule, a student's balance and the monthly revenue.
   Order  : third script of db_init (00 -> 07): after the tables they read, before the views,
            procedures and triggers that call them. 06_security.sql GRANTs SELECT on the
            table-valued functions to the roles that may use them.
   Defense: - scalar function: called in an expression, e.g. dbo.fn_FinalGrade(en.EnrollmentId)
              in a SELECT list (the dbo. prefix is required when calling a scalar function)
            - inline TVF: one SELECT with parameters, used in FROM like a view with parameters;
              SQL Server expands it into the calling query
            - multi-statement TVF: a small program that fills the table variable it returns
            - a function cannot change table data (only its own table variable), so every write
              stays in the procedures of 04_procedures.sql
            - fn_CurrentTeacherId + USER_NAME(): the row filter of the teacher views (03_views.sql)
            - fn_Today / fn_UtcToCenterTime / fn_CenterTimeToUtc (section 0): one definition of the
              center's time zone, so the scripts never read the server's local clock (checked by
              tst_conventions and test T32)
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 0. Time zone of the center. Instants are stored in UTC (columns ...Utc); business dates and reports ("today",
      revenue per month, payroll month) follow the center's local time. Vietnam has no daylight saving time, so a
      fixed offset is exact; TODATETIMEOFFSET/SWITCHOFFSET exist since SQL Server 2008 (AT TIME ZONE needs 2016).
        fn_CenterUtcOffset : offset of the center - the one place to change it (T32 checks the DATE defaults of
                             01_tables.sql, which cannot call a function, use the same offset)
        fn_UtcToCenterTime : UTC instant -> local date and time of the center
        fn_CenterTimeToUtc : local date and time of the center -> UTC instant (e.g. the start of a local day)
        fn_Today           : today's date in the center, whatever the time zone of the server
      Used by: fn_Today gives "today" to the procedures (default dates of students, enrollments, placement tests,
      certificates; the payroll month check; the dashboard), vw_OutstandingTuition and the seed data;
      fn_CenterTimeToUtc turns a local day or month into a UTC range for the revenue reports (usp_Dashboard_Stats,
      usp_Report_Revenue, fn_MonthlyRevenue); fn_UtcToCenterTime shows a stored instant in local time
      (vw_MonthlyRevenue, backup file names). Tests T31 (a receipt just after local midnight) and T32.
      Concepts: scalar functions, WITH SCHEMABINDING (the functions that call fn_CenterUtcOffset are bound to it,
      which is why they are dropped first above), DATETIMEOFFSET (TODATETIMEOFFSET attaches an offset to a
      date and time, SWITCHOFFSET moves it to another offset). */
IF OBJECT_ID(N'dbo.fn_Today', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_Today;
IF OBJECT_ID(N'dbo.fn_UtcToCenterTime', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_UtcToCenterTime;
IF OBJECT_ID(N'dbo.fn_CenterTimeToUtc', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_CenterTimeToUtc;
IF OBJECT_ID(N'dbo.fn_CenterUtcOffset', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_CenterUtcOffset;
GO
CREATE FUNCTION dbo.fn_CenterUtcOffset ()
RETURNS VARCHAR(6)
WITH SCHEMABINDING
AS
BEGIN
    RETURN '+07:00';   -- Asia/Ho_Chi_Minh
END;
GO
CREATE FUNCTION dbo.fn_UtcToCenterTime (@Utc DATETIME)
RETURNS DATETIME
WITH SCHEMABINDING
AS
BEGIN
    RETURN CAST(SWITCHOFFSET(TODATETIMEOFFSET(@Utc, '+00:00'), dbo.fn_CenterUtcOffset()) AS DATETIME);
END;
GO
CREATE FUNCTION dbo.fn_CenterTimeToUtc (@CenterTime DATETIME)
RETURNS DATETIME
WITH SCHEMABINDING
AS
BEGIN
    RETURN CAST(SWITCHOFFSET(TODATETIMEOFFSET(@CenterTime, dbo.fn_CenterUtcOffset()), '+00:00') AS DATETIME);
END;
GO
CREATE FUNCTION dbo.fn_Today ()
RETURNS DATE
AS
BEGIN
    -- Same expression as the DATE defaults of 01_tables.sql
    RETURN CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), dbo.fn_CenterUtcOffset()) AS DATE);
END;
GO

/* 1. fn_Weekday: ISO 8601 day of the week (1 = Monday ... 7 = Sunday),
      independent of the server's SET DATEFIRST setting.
      1900-01-01 was a Monday.
      How: DATEDIFF counts the days since that Monday; % 7 gives 0 for a Monday ... 6 for a
      Sunday; + 1 turns it into 1..7 (valid for dates from 1900-01-01 on). DATEPART(WEEKDAY, ...)
      is not used because its result depends on SET DATEFIRST (language and server settings).
      Used by: usp_Class_GenerateSessions (matches a date with CLASS_SCHEDULE.Weekday), the seed
      data (Monday of the current week), test T22, 08_demo_queries.sql.
      Concepts: scalar function; WITH SCHEMABINDING binds the function to the schema, and for a
      function that reads no table SQL Server then records that it accesses no data (without it,
      SQL Server assumes the function may read data). */
IF OBJECT_ID(N'dbo.fn_Weekday', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_Weekday;
GO
CREATE FUNCTION dbo.fn_Weekday (@Date DATE)
RETURNS TINYINT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CAST(DATEDIFF(DAY, CAST('19000101' AS DATE), @Date) % 7 + 1 AS TINYINT);
END;
GO

/* 2. fn_CurrentTeacherId / fn_CurrentEmployeeId / fn_CurrentRole:
      map the USER working in the database (USER_NAME()) to its ACCOUNT row.
      USER_NAME() also follows EXECUTE AS USER = 'gv_john' used in the demos and tests.
      They return NULL when the user has no ACCOUNT row (fn_CurrentRole: members of db_owner or
      sysadmin then count as a manager).
      COLLATE DATABASE_DEFAULT is needed: in a contained database USER_NAME() has the catalog
      collation (Latin1_General_100_CI_AS_KS_WS_SC) while ACCOUNT.Username has the database
      collation (Vietnamese_CI_AS); comparing them without COLLATE fails with a collation conflict.
      Used by: fn_CurrentTeacherId filters the five vw_Teacher_My* views; fn_CurrentRole together
      with fn_CurrentTeacherId lets usp_Session_Update, usp_Attendance_Save, usp_Attendance_BySession
      and usp_Grade_Save refuse a teacher who works on another teacher's class; fn_CurrentRole hides
      the revenue in usp_Dashboard_Stats; fn_CurrentEmployeeId is the default employee of
      usp_Enrollment_Create and usp_Receipt_Create.
      Concepts: scalar functions; row-level security written by hand from the signed-in user
      (SQL Server 2012 has no security policies). */
IF OBJECT_ID(N'dbo.fn_CurrentRole', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_CurrentRole;
IF OBJECT_ID(N'dbo.fn_CurrentTeacherId', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_CurrentTeacherId;
IF OBJECT_ID(N'dbo.fn_CurrentEmployeeId', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_CurrentEmployeeId;
GO
CREATE FUNCTION dbo.fn_CurrentRole ()
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Role VARCHAR(20);
    SELECT @Role = Role FROM dbo.ACCOUNT WHERE Username = USER_NAME() COLLATE DATABASE_DEFAULT;
    -- dbo / sysadmin (whoever installed the database) counts as a manager
    IF @Role IS NULL AND (IS_MEMBER('db_owner') = 1 OR IS_SRVROLEMEMBER('sysadmin') = 1)
        SET @Role = 'MANAGER';
    RETURN @Role;
END;
GO
CREATE FUNCTION dbo.fn_CurrentTeacherId ()
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN (SELECT TeacherId FROM dbo.ACCOUNT WHERE Username = USER_NAME() COLLATE DATABASE_DEFAULT);
END;
GO
CREATE FUNCTION dbo.fn_CurrentEmployeeId ()
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN (SELECT EmployeeId FROM dbo.ACCOUNT WHERE Username = USER_NAME() COLLATE DATABASE_DEFAULT);
END;
GO

/* 3. fn_EnrolledCount: number of students currently taking a class
      Counts the enrollments with status Studying or Completed (On hold and Left free their seat):
      the same rule as trg_ENROLLMENT_CheckCapacity and the EnrolledCount of vw_ClassDetails.
      Used by: vw_Teacher_MyClasses, test T21, 08_demo_queries.sql.
      Concepts: scalar function returning the result of a subquery (COUNT). */
IF OBJECT_ID(N'dbo.fn_EnrolledCount', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_EnrolledCount;
GO
CREATE FUNCTION dbo.fn_EnrolledCount (@ClassId VARCHAR(10))
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*) FROM dbo.ENROLLMENT
            WHERE ClassId = @ClassId AND Status IN (N'Studying', N'Completed'));
END;
GO

/* 4. fn_FinalGrade: final grade = SUM(Score * Weight) / 100.
      Returns NULL while some grade components have no score yet.
      Steps: (1) @ComponentCount = the number of grade components of the course of the class;
      (2) @ScoredCount and @Total = the number of scores entered and their weighted sum;
      (3) NULL when the course has no component or a score is missing, otherwise the total rounded
      to 2 decimals. Dividing by 100 assumes the weights of the course add up to 100:
      usp_Class_EvaluateResults refuses a course listed by vw_CourseInvalidWeights.
      Used by: vw_LearningResults, usp_Class_EvaluateResults (first the missing-grade check, then
      the grade of each student), tests T17 and T23. The report quotes this function verbatim.
      Concepts: scalar function; SELECT @variable = aggregate assigns the result of a query to a
      variable. */
IF OBJECT_ID(N'dbo.fn_FinalGrade', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_FinalGrade;
GO
CREATE FUNCTION dbo.fn_FinalGrade (@EnrollmentId VARCHAR(10))
RETURNS DECIMAL(4,2)
AS
BEGIN
    DECLARE @ComponentCount INT, @ScoredCount INT, @Total DECIMAL(9,4);

    SELECT @ComponentCount = COUNT(*)
    FROM dbo.ENROLLMENT en
    JOIN dbo.CLASS cl            ON cl.ClassId = en.ClassId
    JOIN dbo.GRADE_COMPONENT gc  ON gc.CourseId = cl.CourseId
    WHERE en.EnrollmentId = @EnrollmentId;

    SELECT @ScoredCount = COUNT(*), @Total = SUM(gr.Score * gc.Weight) / 100
    FROM dbo.GRADE gr
    JOIN dbo.GRADE_COMPONENT gc ON gc.ComponentId = gr.ComponentId
    WHERE gr.EnrollmentId = @EnrollmentId;

    IF @ComponentCount = 0 OR @ScoredCount < @ComponentCount RETURN NULL;
    RETURN CAST(ROUND(@Total, 2) AS DECIMAL(4,2));
END;
GO

/* 5. fn_Classification: classification from the final grade
      >= 9 Excellent, >= 8 Very good, >= 6.5 Good, >= 5 Average, below 5 Failed; NULL stays NULL.
      The four passing labels are the values allowed by CK_CERTIFICATE_Classification; the
      application translates every label (DbValues).
      Used by: vw_LearningResults, usp_Class_EvaluateResults (classification on the certificate),
      test T16, 08_demo_queries.sql.
      Concepts: scalar function, searched CASE, WITH SCHEMABINDING (see fn_Weekday). */
IF OBJECT_ID(N'dbo.fn_Classification', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_Classification;
GO
CREATE FUNCTION dbo.fn_Classification (@Grade DECIMAL(4,2))
RETURNS NVARCHAR(20)
WITH SCHEMABINDING
AS
BEGIN
    -- CASE tests the WHEN branches from top to bottom and stops at the first true one,
    -- so each band only needs its lower bound
    RETURN CASE
        WHEN @Grade IS NULL THEN NULL
        WHEN @Grade >= 9   THEN N'Excellent'
        WHEN @Grade >= 8   THEN N'Very good'
        WHEN @Grade >= 6.5 THEN N'Good'
        WHEN @Grade >= 5   THEN N'Average'
        ELSE N'Failed'
    END;
END;
GO

/* 6. fn_AttendanceRate: % of taught sessions attended (late counts as present)
      = 100 x (marks Present or Late at taught sessions) / (taught sessions of the class).
      Only sessions with status Taught count; an absence (excused or not) and a missing mark both
      count as not attended. NULL when the class has no taught session yet (no division by zero);
      usp_Class_EvaluateResults then uses 100.
      Used by: vw_LearningResults, vw_Teacher_MyStudents, usp_Class_EvaluateResults (pass rule:
      attendance >= 80%), tests T18 and T23.
      Concepts: scalar function, two aggregate queries, decimal instead of integer division. */
IF OBJECT_ID(N'dbo.fn_AttendanceRate', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_AttendanceRate;
GO
CREATE FUNCTION dbo.fn_AttendanceRate (@EnrollmentId VARCHAR(10))
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @TaughtCount INT, @PresentCount INT;

    SELECT @TaughtCount = COUNT(*)
    FROM dbo.CLASS_SESSION se
    JOIN dbo.ENROLLMENT en ON en.ClassId = se.ClassId
    WHERE en.EnrollmentId = @EnrollmentId AND se.Status = N'Taught';

    SELECT @PresentCount = COUNT(*)
    FROM dbo.ATTENDANCE at
    JOIN dbo.CLASS_SESSION se ON se.SessionId = at.SessionId
    WHERE at.EnrollmentId = @EnrollmentId AND se.Status = N'Taught'
      AND at.Status IN (N'Present', N'Late');

    IF @TaughtCount = 0 RETURN NULL;
    -- 100.0 (not 100) makes the division decimal: with INT only, 100 * 7 / 8 would give 87, not 87.50
    RETURN CAST(100.0 * @PresentCount / @TaughtCount AS DECIMAL(5,2));
END;
GO

/* 7. fn_RecommendCourse: the best course for a placement-test score
      (the open course with the highest minimum score the student reached)
      A course without MinPlacementScore counts as minimum 0 (open to everybody); between courses
      with the same minimum the cheaper one wins. @ProgramId = NULL searches every program.
      Used by: trg_PLACEMENT_TEST_Recommend (fills PLACEMENT_TEST.RecommendedCourseId, called with
      @ProgramId = NULL).
      Concepts: scalar function, TOP (1) + ORDER BY, parameter with a default value (a caller of a
      scalar function must still pass every argument, NULL or the keyword DEFAULT). */
IF OBJECT_ID(N'dbo.fn_RecommendCourse', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_RecommendCourse;
GO
CREATE FUNCTION dbo.fn_RecommendCourse (@OverallScore DECIMAL(4,2), @ProgramId VARCHAR(10) = NULL)
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN (
        SELECT TOP (1) CourseId
        FROM dbo.COURSE
        WHERE Status = N'Open'
          AND ISNULL(MinPlacementScore, 0) <= @OverallScore
          AND (@ProgramId IS NULL OR ProgramId = @ProgramId)
        ORDER BY ISNULL(MinPlacementScore, 0) DESC, Tuition ASC);
END;
GO

/* 8. fn_DiscountAmount: discount of a promotion on a given date
      PERCENT: tuition x value / 100 rounded to the nearest 1,000 VND; AMOUNT: the fixed value.
      The discount never exceeds the tuition. 0 when the promotion does not exist or is not valid
      on @Date: the SELECT then finds no row and @Discount keeps its initial value 0.
      Used by: usp_Enrollment_Create (a discount of 0 for a given promotion code means "unknown or
      expired code", error 50025), test T19.
      Concepts: scalar function, CASE on a column, assigning a variable from a SELECT. */
IF OBJECT_ID(N'dbo.fn_DiscountAmount', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_DiscountAmount;
GO
CREATE FUNCTION dbo.fn_DiscountAmount (@PromotionId VARCHAR(10), @Tuition DECIMAL(12,0), @Date DATE)
RETURNS DECIMAL(12,0)
AS
BEGIN
    DECLARE @Discount DECIMAL(12,0) = 0;
    -- ROUND(x, -3): a negative length rounds to the left of the decimal point (to thousands)
    SELECT @Discount = CASE DiscountType
                           WHEN 'PERCENT' THEN ROUND(@Tuition * DiscountValue / 100, -3)
                           ELSE DiscountValue
                       END
    FROM dbo.PROMOTION
    WHERE PromotionId = @PromotionId AND @Date BETWEEN StartDate AND EndDate;

    IF @Discount > @Tuition SET @Discount = @Tuition;
    RETURN ISNULL(@Discount, 0);
END;
GO

/* 9. fn_TeacherSchedule (inline TVF): a teacher's sessions between two dates
      Filters on the teacher of each session (CLASS_SESSION.TeacherId); the branch shown is the
      branch of the session's room. An inline TVF is a single SELECT with parameters - a "view with
      parameters" that can be used in FROM or with CROSS APPLY.
      Used by: SELECT is GRANTed to rl_AcademicStaff (06_security.sql); 08_demo_queries.sql calls it
      with CROSS APPLY for every teacher.
      Concepts: inline table-valued function (RETURNS TABLE AS RETURN (SELECT ...)), CROSS APPLY. */
IF OBJECT_ID(N'dbo.fn_TeacherSchedule', N'IF') IS NOT NULL DROP FUNCTION dbo.fn_TeacherSchedule;
GO
CREATE FUNCTION dbo.fn_TeacherSchedule (@TeacherId VARCHAR(10), @FromDate DATE, @ToDate DATE)
RETURNS TABLE
AS
RETURN (
    SELECT se.SessionId, se.SessionDate, se.StartTime, se.EndTime, se.SessionNo,
           cl.ClassId, cl.ClassName, co.CourseName, rm.RoomName, br.BranchName, se.Status
    FROM dbo.CLASS_SESSION se
    JOIN dbo.CLASS cl   ON cl.ClassId = se.ClassId
    JOIN dbo.COURSE co  ON co.CourseId = cl.CourseId
    JOIN dbo.ROOM rm    ON rm.RoomId = se.RoomId
    JOIN dbo.BRANCH br  ON br.BranchId = rm.BranchId
    WHERE se.TeacherId = @TeacherId AND se.SessionDate BETWEEN @FromDate AND @ToDate
);
GO

/* 10. fn_StudentBalance (inline TVF): unpaid tuition of a student
       One row per enrollment of @StudentId that still owes money (TuitionDue > AmountPaid), except
       enrollments with status Left. Balance = TuitionDue - AmountPaid; both are stored in
       ENROLLMENT, so no receipt has to be summed here.
       Used by: SELECT is GRANTed to rl_Accountant (06_security.sql); 08_demo_queries.sql.
       Concepts: inline table-valued function. */
IF OBJECT_ID(N'dbo.fn_StudentBalance', N'IF') IS NOT NULL DROP FUNCTION dbo.fn_StudentBalance;
GO
CREATE FUNCTION dbo.fn_StudentBalance (@StudentId VARCHAR(10))
RETURNS TABLE
AS
RETURN (
    SELECT en.EnrollmentId, cl.ClassId, cl.ClassName, en.TuitionDue, en.AmountPaid,
           en.TuitionDue - en.AmountPaid AS Balance
    FROM dbo.ENROLLMENT en
    JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
    WHERE en.StudentId = @StudentId AND en.TuitionDue > en.AmountPaid
      AND en.Status <> N'Left'
);
GO

/* 11. fn_MonthlyRevenue (multi-statement TVF): revenue of the 12 months of a year;
       months without receipts still return 0 (used by reports and the chart).
       Months are those of the center: a receipt at 23:30 UTC on the 31st belongs to the next month.
       Steps: (1) the WHILE loop inserts 12 rows (Month 1-12 with 0 receipts and 0 revenue) into
       the table variable @Result; (2) the local year is turned into a UTC range (@FromUtc, @ToUtc)
       so the filter on PaidAtUtc can use the index IX_RECEIPT_PaidAtUtc; (3) UPDATE ... FROM joins
       @Result with the valid receipts of that range grouped by their local month
       (fn_UtcToCenterTime) and overwrites the months that have receipts; (4) RETURN hands back
       @Result. A plain GROUP BY query has no row for a month without receipts; filling the 12
       months first and then updating them takes several statements, which an inline TVF (one
       SELECT only) cannot have.
       @BranchId = NULL means every branch (the branch of the class the receipt pays for).
       Used by: the revenue chart of the Dashboard (SqlStatisticsRepository::monthlyRevenue), the
       report data export, 08_demo_queries.sql. SELECT is GRANTed to rl_Accountant; managers read it
       through db_datareader. Academic staff have no right on it, so their Dashboard chart shows a
       message instead. The report quotes this function verbatim.
       Concepts: multi-statement table-valued function, table variable, WHILE loop, UPDATE with a
       JOIN to a derived table, a sargable date range (the column is compared, not wrapped in a
       function). */
IF OBJECT_ID(N'dbo.fn_MonthlyRevenue', N'TF') IS NOT NULL DROP FUNCTION dbo.fn_MonthlyRevenue;
GO
CREATE FUNCTION dbo.fn_MonthlyRevenue (@Year INT, @BranchId VARCHAR(10) = NULL)
RETURNS @Result TABLE (
    Month         TINYINT        PRIMARY KEY,
    ReceiptCount  INT            NOT NULL,
    Revenue       DECIMAL(14,0)  NOT NULL
)
AS
BEGIN
    DECLARE @Month TINYINT = 1;
    WHILE @Month <= 12
    BEGIN
        INSERT INTO @Result (Month, ReceiptCount, Revenue) VALUES (@Month, 0, 0);
        SET @Month += 1;
    END;

    -- The local year as a UTC range keeps the filter on PaidAtUtc sargable
    DECLARE @FromUtc DATETIME = dbo.fn_CenterTimeToUtc(DATEFROMPARTS(@Year, 1, 1)),
            @ToUtc   DATETIME = dbo.fn_CenterTimeToUtc(DATEFROMPARTS(@Year + 1, 1, 1));

    UPDATE r
    SET ReceiptCount = t.ReceiptCount, Revenue = t.Revenue
    FROM @Result r
    JOIN (
        SELECT MONTH(dbo.fn_UtcToCenterTime(rc.PaidAtUtc)) AS Month, COUNT(*) AS ReceiptCount,
               SUM(rc.Amount) AS Revenue
        FROM dbo.RECEIPT rc
        JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
        JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
        WHERE rc.PaidAtUtc >= @FromUtc AND rc.PaidAtUtc < @ToUtc AND rc.Status = N'Valid'
          AND (@BranchId IS NULL OR cl.BranchId = @BranchId)
        GROUP BY MONTH(dbo.fn_UtcToCenterTime(rc.PaidAtUtc))
    ) t ON t.Month = r.Month;

    RETURN;
END;
GO
