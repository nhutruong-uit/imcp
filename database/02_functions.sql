/* =====================================================================
   File   : 02_functions.sql - Functions
   The three kinds of SQL Server functions:
     - Scalar function            : returns one value
     - Inline table-valued (ITVF) : returns the result of one SELECT
     - Multi-statement TVF        : fills a table variable with several statements
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
        fn_Today           : today's date in the center, whatever the time zone of the server */
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
      1900-01-01 was a Monday. */
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
      USER_NAME() also follows EXECUTE AS USER = N'gv_john' used in the demos. */
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

/* 3. fn_EnrolledCount: number of students currently taking a class */
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
      Returns NULL while some grade components have no score yet. */
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

/* 5. fn_Classification: classification from the final grade */
IF OBJECT_ID(N'dbo.fn_Classification', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_Classification;
GO
CREATE FUNCTION dbo.fn_Classification (@Grade DECIMAL(4,2))
RETURNS NVARCHAR(20)
WITH SCHEMABINDING
AS
BEGIN
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

/* 6. fn_AttendanceRate: % of taught sessions attended (late counts as present) */
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
    RETURN CAST(100.0 * @PresentCount / @TaughtCount AS DECIMAL(5,2));
END;
GO

/* 7. fn_RecommendCourse: the best course for a placement-test score
      (the open course with the highest minimum score the student reached) */
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

/* 8. fn_DiscountAmount: discount of a promotion on a given date */
IF OBJECT_ID(N'dbo.fn_DiscountAmount', N'FN') IS NOT NULL DROP FUNCTION dbo.fn_DiscountAmount;
GO
CREATE FUNCTION dbo.fn_DiscountAmount (@PromotionId VARCHAR(10), @Tuition DECIMAL(12,0), @Date DATE)
RETURNS DECIMAL(12,0)
AS
BEGIN
    DECLARE @Discount DECIMAL(12,0) = 0;
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

/* 9. fn_TeacherSchedule (inline TVF): a teacher's sessions between two dates */
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

/* 10. fn_StudentBalance (inline TVF): unpaid tuition of a student */
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
       Months are those of the center: a receipt at 23:30 UTC on the 31st belongs to the next month. */
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
