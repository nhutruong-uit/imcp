/* =====================================================================
   File   : 04_procedures.sql - Stored procedures
   Conventions:
     - Prefix usp_ (user stored procedure). Never sp_: SQL Server always
       looks for sp_ procedures in master first => slower, and they can
       clash with system procedures.
     - The application NEVER writes to tables directly; every business
       operation goes through a procedure => business rules are checked
       in the database, permissions are GRANT EXECUTE.
     - Business errors: THROW 5xxxx (SQL Server 2012+) with an English
       message; the application shows it in the user's language.
     - Transactions: SET XACT_ABORT ON + TRY/CATCH + ROLLBACK.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =====================================================================
   A. STUDENTS
   ===================================================================== */

/* A1. usp_Student_Add: add a student, return the new ID through an OUTPUT parameter */
IF OBJECT_ID(N'dbo.usp_Student_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Add;
GO
CREATE PROCEDURE dbo.usp_Student_Add
    @FullName       NVARCHAR(100),
    @DateOfBirth    DATE,
    @Gender         NVARCHAR(10),
    @Phone          VARCHAR(15)   = NULL,
    @Email          VARCHAR(100)  = NULL,
    @Address        NVARCHAR(200) = NULL,
    @Occupation     NVARCHAR(50)  = NULL,
    @GuardianName   NVARCHAR(100) = NULL,
    @GuardianPhone  VARCHAR(15)   = NULL,
    @BranchId       VARCHAR(10),
    @Notes          NVARCHAR(500) = NULL,
    @RegisteredOn   DATE          = NULL,
    @StudentId      VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(ISNULL(@FullName, N''))) = N''
        THROW 50001, N'The student''s full name must not be empty.', 1;
    IF @Phone IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Phone = @Phone)
        THROW 50002, N'The phone number is already used by another student.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Email = @Email)
        THROW 50003, N'The email is already used by another student.', 1;

    DECLARE @New TABLE (StudentId VARCHAR(10));
    INSERT INTO dbo.STUDENT (FullName, DateOfBirth, Gender, Phone, Email, Address, Occupation,
                             GuardianName, GuardianPhone, BranchId, Notes, RegisteredOn)
    OUTPUT inserted.StudentId INTO @New
    VALUES (LTRIM(RTRIM(@FullName)), @DateOfBirth, @Gender, NULLIF(@Phone, ''), NULLIF(@Email, ''), @Address,
            @Occupation, @GuardianName, NULLIF(@GuardianPhone, ''), @BranchId, @Notes,
            ISNULL(@RegisteredOn, dbo.fn_Today()));

    SELECT @StudentId = StudentId FROM @New;
END;
GO

/* A2. usp_Student_Update */
IF OBJECT_ID(N'dbo.usp_Student_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Update;
GO
CREATE PROCEDURE dbo.usp_Student_Update
    @StudentId      VARCHAR(10),
    @FullName       NVARCHAR(100),
    @DateOfBirth    DATE,
    @Gender         NVARCHAR(10),
    @Phone          VARCHAR(15)   = NULL,
    @Email          VARCHAR(100)  = NULL,
    @Address        NVARCHAR(200) = NULL,
    @Occupation     NVARCHAR(50)  = NULL,
    @GuardianName   NVARCHAR(100) = NULL,
    @GuardianPhone  VARCHAR(15)   = NULL,
    @BranchId       VARCHAR(10),
    @Status         NVARCHAR(20),
    @Notes          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentId = @StudentId)
        THROW 50004, N'Student not found.', 1;
    IF @Phone IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Phone = @Phone AND StudentId <> @StudentId)
        THROW 50002, N'The phone number is already used by another student.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Email = @Email AND StudentId <> @StudentId)
        THROW 50003, N'The email is already used by another student.', 1;

    UPDATE dbo.STUDENT
    SET FullName = LTRIM(RTRIM(@FullName)), DateOfBirth = @DateOfBirth, Gender = @Gender,
        Phone = NULLIF(@Phone, ''), Email = NULLIF(@Email, ''), Address = @Address,
        Occupation = @Occupation, GuardianName = @GuardianName, GuardianPhone = NULLIF(@GuardianPhone, ''),
        BranchId = @BranchId, Status = @Status, Notes = @Notes
    WHERE StudentId = @StudentId;
END;
GO

/* A3. usp_Student_Delete: only a student who never enrolled can be deleted */
IF OBJECT_ID(N'dbo.usp_Student_Delete', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Delete;
GO
CREATE PROCEDURE dbo.usp_Student_Delete
    @StudentId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE StudentId = @StudentId)
        THROW 50005, N'The student has an enrollment history and cannot be deleted. Change the status to "Dropped out" instead.', 1;

    DELETE FROM dbo.PLACEMENT_TEST WHERE StudentId = @StudentId;
    DELETE FROM dbo.STUDENT WHERE StudentId = @StudentId;
    IF @@ROWCOUNT = 0
        THROW 50004, N'Student not found.', 1;
END;
GO

/* A4. usp_Student_Search: search by ID, name or phone; filter by branch/status */
IF OBJECT_ID(N'dbo.usp_Student_Search', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Search;
GO
CREATE PROCEDURE dbo.usp_Student_Search
    @Keyword   NVARCHAR(100) = NULL,
    @BranchId  VARCHAR(10)   = NULL,
    @Status    NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Pattern NVARCHAR(102) = N'%' + LTRIM(RTRIM(ISNULL(@Keyword, N''))) + N'%';

    SELECT StudentId, FullName, DateOfBirth, Gender, Phone, Email, GuardianName, GuardianPhone,
           BranchId, BranchName, RegisteredOn, Status, ActiveClassCount, TotalBalance
    FROM dbo.vw_StudentOverview
    WHERE (StudentId LIKE @Pattern OR FullName LIKE @Pattern OR Phone LIKE @Pattern OR GuardianPhone LIKE @Pattern)
      AND (@BranchId IS NULL OR BranchId = @BranchId)
      AND (@Status IS NULL OR Status = @Status)
    ORDER BY StudentId DESC;
END;
GO

/* A5. usp_Student_Details: one student with the full profile */
IF OBJECT_ID(N'dbo.usp_Student_Details', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Details;
GO
CREATE PROCEDURE dbo.usp_Student_Details
    @StudentId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT StudentId, FullName, DateOfBirth, Gender, Phone, Email, Address, Occupation,
           GuardianName, GuardianPhone, BranchId, RegisteredOn, Status, Notes
    FROM dbo.STUDENT
    WHERE StudentId = @StudentId;
END;
GO

/* =====================================================================
   B. CLASSES - WEEKLY SCHEDULES - SESSIONS
   ===================================================================== */

/* B1. usp_Class_Create: open a new class; the tuition defaults to the course tuition */
IF OBJECT_ID(N'dbo.usp_Class_Create', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Class_Create;
GO
CREATE PROCEDURE dbo.usp_Class_Create
    @ClassName    NVARCHAR(100),
    @CourseId     VARCHAR(10),
    @BranchId     VARCHAR(10),
    @TeacherId    VARCHAR(10),
    @RoomId       VARCHAR(10),
    @StartDate    DATE,
    @MaxStudents  INT           = 20,
    @Tuition      DECIMAL(12,0) = NULL,
    @ClassId      VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.COURSE WHERE CourseId = @CourseId AND Status = N'Open')
        THROW 50010, N'The course does not exist or is no longer offered.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.TEACHER WHERE TeacherId = @TeacherId AND Status = N'Teaching')
        THROW 50011, N'The teacher does not exist or is no longer teaching.', 1;

    IF @Tuition IS NULL
        SELECT @Tuition = Tuition FROM dbo.COURSE WHERE CourseId = @CourseId;

    DECLARE @New TABLE (ClassId VARCHAR(10));
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @New
    VALUES (@ClassName, @CourseId, @BranchId, @TeacherId, @RoomId, @StartDate, @MaxStudents, @Tuition);

    SELECT @ClassId = ClassId FROM @New;
END;
GO

/* B2. usp_ClassSchedule_Add: add a weekly time slot to a class
       (trigger trg_CLASS_SCHEDULE_CheckConflict checks room/teacher clashes) */
IF OBJECT_ID(N'dbo.usp_ClassSchedule_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_ClassSchedule_Add;
GO
CREATE PROCEDURE dbo.usp_ClassSchedule_Add
    @ClassId    VARCHAR(10),
    @Weekday    TINYINT,
    @StartTime  TIME(0),
    @EndTime    TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SCHEDULE WHERE ClassId = @ClassId AND Weekday = @Weekday)
        UPDATE dbo.CLASS_SCHEDULE SET StartTime = @StartTime, EndTime = @EndTime
        WHERE ClassId = @ClassId AND Weekday = @Weekday;
    ELSE
        INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime)
        VALUES (@ClassId, @Weekday, @StartTime, @EndTime);
END;
GO

/* B3. usp_Class_GenerateSessions: generate SessionCount sessions from the start date
       following the weekly schedule (WHILE loop over the days), update the end date. */
IF OBJECT_ID(N'dbo.usp_Class_GenerateSessions', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Class_GenerateSessions;
GO
CREATE PROCEDURE dbo.usp_Class_GenerateSessions
    @ClassId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SessionCount INT, @Date DATE, @TeacherId VARCHAR(10), @RoomId VARCHAR(10),
            @SessionNo INT = 0, @StartTime TIME(0), @EndTime TIME(0), @LastDate DATE;

    SELECT @SessionCount = co.SessionCount, @Date = cl.StartDate, @TeacherId = cl.TeacherId, @RoomId = cl.RoomId
    FROM dbo.CLASS cl JOIN dbo.COURSE co ON co.CourseId = cl.CourseId
    WHERE cl.ClassId = @ClassId;

    IF @SessionCount IS NULL
        THROW 50012, N'Class not found.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.CLASS_SCHEDULE WHERE ClassId = @ClassId)
        THROW 50013, N'The class has no weekly schedule yet.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId AND Status <> N'Scheduled')
        THROW 50014, N'The class already has taught or cancelled sessions; its sessions cannot be regenerated.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId;

        WHILE @SessionNo < @SessionCount
        BEGIN
            SELECT @StartTime = StartTime, @EndTime = EndTime
            FROM dbo.CLASS_SCHEDULE
            WHERE ClassId = @ClassId AND Weekday = dbo.fn_Weekday(@Date);

            IF @@ROWCOUNT = 1
            BEGIN
                SET @SessionNo += 1;
                INSERT INTO dbo.CLASS_SESSION (ClassId, SessionNo, SessionDate, StartTime, EndTime, RoomId, TeacherId)
                VALUES (@ClassId, @SessionNo, @Date, @StartTime, @EndTime, @RoomId, @TeacherId);
                SET @LastDate = @Date;
            END;
            SET @Date = DATEADD(DAY, 1, @Date);
        END;

        UPDATE dbo.CLASS SET EndDate = @LastDate WHERE ClassId = @ClassId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @SessionNo AS SessionsCreated, @LastDate AS EndDate;
END;
GO

/* B4. usp_Class_UpdateStatus */
IF OBJECT_ID(N'dbo.usp_Class_UpdateStatus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Class_UpdateStatus;
GO
CREATE PROCEDURE dbo.usp_Class_UpdateStatus
    @ClassId  VARCHAR(10),
    @Status   NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Status = N'Cancelled' AND EXISTS (SELECT 1 FROM dbo.RECEIPT rc
                                          JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
                                          WHERE en.ClassId = @ClassId AND rc.Status = N'Valid')
        THROW 50015, N'Some students of this class have paid tuition; refund or transfer them before cancelling the class.', 1;

    UPDATE dbo.CLASS SET Status = @Status WHERE ClassId = @ClassId;
    IF @@ROWCOUNT = 0
        THROW 50012, N'Class not found.', 1;
END;
GO

/* B5. usp_Session_Update: the teacher confirms a session was taught / records its content */
IF OBJECT_ID(N'dbo.usp_Session_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Session_Update;
GO
CREATE PROCEDURE dbo.usp_Session_Update
    @SessionId    INT,
    @Status       NVARCHAR(20),
    @Description  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SessionTeacherId VARCHAR(10);
    SELECT @SessionTeacherId = TeacherId FROM dbo.CLASS_SESSION WHERE SessionId = @SessionId;

    IF @SessionTeacherId IS NULL
        THROW 50016, N'Session not found.', 1;
    IF dbo.fn_CurrentRole() = 'TEACHER' AND @SessionTeacherId <> dbo.fn_CurrentTeacherId()
        THROW 50017, N'You can only update sessions you teach.', 1;

    UPDATE dbo.CLASS_SESSION
    SET Status = @Status, Description = ISNULL(@Description, Description)
    WHERE SessionId = @SessionId;
END;
GO

/* =====================================================================
   C. ENROLLMENT
   ===================================================================== */

/* C1. usp_Enrollment_Create: enroll a student in a class (multi-step transaction)
       - The class must be enrolling/in progress and have free seats (re-checked by a trigger)
       - Entry requirement: passed the prerequisite course OR a high enough placement score
       - No schedule clash with another class the student is taking
       - Discount from the promotion */
IF OBJECT_ID(N'dbo.usp_Enrollment_Create', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_Create;
GO
CREATE PROCEDURE dbo.usp_Enrollment_Create
    @StudentId     VARCHAR(10),
    @ClassId       VARCHAR(10),
    @PromotionId   VARCHAR(10) = NULL,
    @EnrolledOn    DATE        = NULL,
    @EmployeeId    VARCHAR(10) = NULL,
    @EnrollmentId  VARCHAR(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CourseId VARCHAR(10), @Tuition DECIMAL(12,0), @ClassStatus NVARCHAR(20),
            @Prerequisite VARCHAR(10), @MinScore DECIMAL(4,2), @Discount DECIMAL(12,0),
            @StartDate DATE, @EndDate DATE, @Msg NVARCHAR(2048);

    SET @EnrolledOn = ISNULL(@EnrolledOn, dbo.fn_Today());
    SET @EmployeeId = COALESCE(@EmployeeId, dbo.fn_CurrentEmployeeId());

    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentId = @StudentId AND Status <> N'Dropped out')
        THROW 50020, N'The student does not exist or has dropped out.', 1;

    SELECT @CourseId = cl.CourseId, @Tuition = cl.Tuition, @ClassStatus = cl.Status,
           @Prerequisite = co.PrerequisiteCourseId, @MinScore = co.MinPlacementScore,
           @StartDate = cl.StartDate, @EndDate = ISNULL(cl.EndDate, DATEADD(MONTH, 6, cl.StartDate))
    FROM dbo.CLASS cl JOIN dbo.COURSE co ON co.CourseId = cl.CourseId
    WHERE cl.ClassId = @ClassId;

    IF @CourseId IS NULL
        THROW 50012, N'Class not found.', 1;
    IF @ClassStatus NOT IN (N'Enrolling', N'In progress')
        THROW 50021, N'The class no longer accepts enrollments.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE StudentId = @StudentId AND ClassId = @ClassId)
        THROW 50022, N'The student is already enrolled in this class.', 1;

    -- Entry requirement
    IF (@Prerequisite IS NOT NULL OR @MinScore IS NOT NULL)
       AND NOT EXISTS (   -- passed the prerequisite course
            SELECT 1 FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
            WHERE en.StudentId = @StudentId AND en.Result = N'Passed' AND cl.CourseId = @Prerequisite)
       AND NOT EXISTS (   -- or the latest placement test reaches the minimum score
            SELECT 1 FROM (SELECT TOP (1) OverallScore FROM dbo.PLACEMENT_TEST
                           WHERE StudentId = @StudentId ORDER BY TestDate DESC, TestId DESC) pl
            WHERE pl.OverallScore >= ISNULL(@MinScore, 0))
    BEGIN
        SET @Msg = N'The student does not meet the entry requirement of course ' + @CourseId
                 + N' (complete the prerequisite course or score at least '
                 + ISNULL(CAST(@MinScore AS NVARCHAR(10)), N'0') + N' in the placement test).';
        THROW 50023, @Msg, 1;
    END;

    -- No schedule clash with another class the student is taking
    IF EXISTS (
        SELECT 1
        FROM dbo.ENROLLMENT en
        JOIN dbo.CLASS cl2           ON cl2.ClassId = en.ClassId
        JOIN dbo.CLASS_SCHEDULE cs2  ON cs2.ClassId = cl2.ClassId
        JOIN dbo.CLASS_SCHEDULE cs   ON cs.ClassId = @ClassId AND cs.Weekday = cs2.Weekday
        WHERE en.StudentId = @StudentId AND en.Status = N'Studying'
          AND cl2.Status IN (N'Enrolling', N'In progress')
          AND cs.StartTime < cs2.EndTime AND cs2.StartTime < cs.EndTime
          AND cl2.StartDate <= @EndDate
          AND ISNULL(cl2.EndDate, DATEADD(MONTH, 6, cl2.StartDate)) >= @StartDate)
        THROW 50024, N'The class schedule clashes with another class the student is taking.', 1;

    SET @Discount = CASE WHEN @PromotionId IS NULL THEN 0
                         ELSE dbo.fn_DiscountAmount(@PromotionId, @Tuition, @EnrolledOn) END;
    IF @PromotionId IS NOT NULL AND @Discount = 0
        THROW 50025, N'The promotion code does not exist or has expired.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @New TABLE (EnrollmentId VARCHAR(10));
        INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, EnrolledOn, BaseTuition, PromotionId, DiscountAmount,
                                    EnrolledByEmployeeId)
        OUTPUT inserted.EnrollmentId INTO @New
        VALUES (@StudentId, @ClassId, @EnrolledOn, @Tuition, @PromotionId, @Discount, @EmployeeId);

        UPDATE dbo.STUDENT SET Status = N'Studying'
        WHERE StudentId = @StudentId AND Status IN (N'Prospective', N'On hold');

        COMMIT TRANSACTION;
        SELECT @EnrollmentId = EnrollmentId FROM @New;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C2. usp_Enrollment_TransferClass: move a student to another class of the SAME course,
       keeping the payment history (ClassId is updated in one transaction). */
IF OBJECT_ID(N'dbo.usp_Enrollment_TransferClass', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_TransferClass;
GO
CREATE PROCEDURE dbo.usp_Enrollment_TransferClass
    @EnrollmentId  VARCHAR(10),
    @NewClassId    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OldClassId VARCHAR(10), @StudentId VARCHAR(10);

    SELECT @OldClassId = ClassId, @StudentId = StudentId FROM dbo.ENROLLMENT
    WHERE EnrollmentId = @EnrollmentId AND Status IN (N'Studying', N'On hold');
    IF @OldClassId IS NULL
        THROW 50026, N'Active enrollment not found.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.CLASS a JOIN dbo.CLASS b ON a.CourseId = b.CourseId
                   WHERE a.ClassId = @OldClassId AND b.ClassId = @NewClassId
                     AND b.Status IN (N'Enrolling', N'In progress'))
        THROW 50027, N'A student can only be transferred to an open class of the same course.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE StudentId = @StudentId AND ClassId = @NewClassId)
        THROW 50022, N'The student is already enrolled in this class.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- Attendance in the old class means nothing for the new class
        DELETE at FROM dbo.ATTENDANCE at JOIN dbo.CLASS_SESSION se ON se.SessionId = at.SessionId
        WHERE at.EnrollmentId = @EnrollmentId AND se.ClassId = @OldClassId;

        UPDATE dbo.ENROLLMENT SET ClassId = @NewClassId, Status = N'Studying' WHERE EnrollmentId = @EnrollmentId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C3. usp_Enrollment_UpdateStatus: put on hold / leave / resume */
IF OBJECT_ID(N'dbo.usp_Enrollment_UpdateStatus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_UpdateStatus;
GO
CREATE PROCEDURE dbo.usp_Enrollment_UpdateStatus
    @EnrollmentId  VARCHAR(10),
    @Status        NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ENROLLMENT SET Status = @Status WHERE EnrollmentId = @EnrollmentId;
    IF @@ROWCOUNT = 0
        THROW 50026, N'Enrollment not found.', 1;

    -- The student has no class in progress any more => update the student's status
    UPDATE st SET Status = CASE @Status WHEN N'On hold' THEN N'On hold' ELSE N'Dropped out' END
    FROM dbo.STUDENT st JOIN dbo.ENROLLMENT en ON en.StudentId = st.StudentId
    WHERE en.EnrollmentId = @EnrollmentId AND @Status IN (N'On hold', N'Left')
      AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT x WHERE x.StudentId = st.StudentId AND x.Status = N'Studying');
END;
GO

/* C4. usp_Enrollment_ByClass: students of a class */
IF OBJECT_ID(N'dbo.usp_Enrollment_ByClass', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_ByClass;
GO
CREATE PROCEDURE dbo.usp_Enrollment_ByClass
    @ClassId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT en.EnrollmentId, st.StudentId, st.FullName AS StudentName, st.Gender,
           COALESCE(st.Phone, st.GuardianPhone) AS ContactPhone,
           en.EnrolledOn, en.TuitionDue, en.AmountPaid, en.TuitionDue - en.AmountPaid AS Balance,
           en.Status, en.FinalGrade, en.Result
    FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
    WHERE en.ClassId = @ClassId
    ORDER BY st.FullName;
END;
GO

/* =====================================================================
   D. TUITION
   ===================================================================== */

/* D1. usp_Receipt_Create: record a receipt; a trigger updates ENROLLMENT.AmountPaid
       and blocks payments above the tuition due. */
IF OBJECT_ID(N'dbo.usp_Receipt_Create', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Receipt_Create;
GO
CREATE PROCEDURE dbo.usp_Receipt_Create
    @EnrollmentId   VARCHAR(10),
    @Amount         DECIMAL(12,0),
    @PaymentMethod  NVARCHAR(20)  = N'Cash',
    @Description    NVARCHAR(200) = NULL,
    @PaidAtUtc      DATETIME      = NULL,
    @EmployeeId     VARCHAR(10)   = NULL,
    @ReceiptId      VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @EmployeeId = COALESCE(@EmployeeId, dbo.fn_CurrentEmployeeId());

    IF @EmployeeId IS NULL
        THROW 50030, N'The current account is not linked to an employee who can collect payments.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE EnrollmentId = @EnrollmentId AND Status <> N'Left')
        THROW 50031, N'Valid enrollment not found.', 1;

    DECLARE @New TABLE (ReceiptId VARCHAR(10));
    INSERT INTO dbo.RECEIPT (EnrollmentId, PaidAtUtc, Amount, PaymentMethod, CollectedByEmployeeId, Description)
    OUTPUT inserted.ReceiptId INTO @New
    VALUES (@EnrollmentId, ISNULL(@PaidAtUtc, GETUTCDATE()), @Amount, @PaymentMethod, @EmployeeId,
            ISNULL(@Description, N'Tuition payment'));

    SELECT @ReceiptId = ReceiptId FROM @New;
END;
GO

/* D2. usp_Receipt_Cancel: cancel a receipt (no physical delete - keeps the audit trail) */
IF OBJECT_ID(N'dbo.usp_Receipt_Cancel', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Receipt_Cancel;
GO
CREATE PROCEDURE dbo.usp_Receipt_Cancel
    @ReceiptId  VARCHAR(10),
    @Reason     NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    IF LTRIM(RTRIM(ISNULL(@Reason, N''))) = N''
        THROW 50032, N'A reason is required to cancel a receipt.', 1;

    UPDATE dbo.RECEIPT SET Status = N'Cancelled', CancelReason = @Reason
    WHERE ReceiptId = @ReceiptId AND Status = N'Valid';
    IF @@ROWCOUNT = 0
        THROW 50033, N'No valid receipt found to cancel.', 1;
END;
GO

/* D3. usp_Receipt_Print: data for printing a receipt */
IF OBJECT_ID(N'dbo.usp_Receipt_Print', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Receipt_Print;
GO
CREATE PROCEDURE dbo.usp_Receipt_Print
    @ReceiptId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT rc.ReceiptId, rc.PaidAtUtc, rc.Amount, rc.PaymentMethod, rc.Description, rc.Status,
           st.StudentId, st.FullName AS StudentName, cl.ClassId, cl.ClassName, co.CourseName,
           en.TuitionDue, en.AmountPaid, en.TuitionDue - en.AmountPaid AS Balance,
           em.FullName AS CollectedBy, br.BranchName, br.Address AS BranchAddress, br.Phone AS BranchPhone
    FROM dbo.RECEIPT rc
    JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
    JOIN dbo.STUDENT st    ON st.StudentId = en.StudentId
    JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
    JOIN dbo.COURSE co     ON co.CourseId = cl.CourseId
    JOIN dbo.EMPLOYEE em   ON em.EmployeeId = rc.CollectedByEmployeeId
    JOIN dbo.BRANCH br     ON br.BranchId = cl.BranchId
    WHERE rc.ReceiptId = @ReceiptId;
END;
GO

/* =====================================================================
   E. ACADEMICS: PLACEMENT TESTS - ATTENDANCE - GRADES - RESULTS
   ===================================================================== */

/* E1. usp_PlacementTest_Add (a trigger recommends the matching course) */
IF OBJECT_ID(N'dbo.usp_PlacementTest_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_PlacementTest_Add;
GO
CREATE PROCEDURE dbo.usp_PlacementTest_Add
    @StudentId       VARCHAR(10),
    @ListeningScore  DECIMAL(4,2),
    @SpeakingScore   DECIMAL(4,2),
    @ReadingScore    DECIMAL(4,2),
    @WritingScore    DECIMAL(4,2),
    @TeacherId       VARCHAR(10)   = NULL,
    @Notes           NVARCHAR(200) = NULL,
    @TestDate        DATE          = NULL,
    @TestId          VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @New TABLE (TestId VARCHAR(10));
    INSERT INTO dbo.PLACEMENT_TEST (StudentId, TestDate, ListeningScore, SpeakingScore, ReadingScore, WritingScore,
                                    GradedByTeacherId, Notes)
    OUTPUT inserted.TestId INTO @New
    VALUES (@StudentId, ISNULL(@TestDate, dbo.fn_Today()), @ListeningScore, @SpeakingScore, @ReadingScore,
            @WritingScore, @TeacherId, @Notes);

    SELECT @TestId = TestId FROM @New;
    SELECT pl.TestId, pl.OverallScore, pl.RecommendedCourseId, co.CourseName AS RecommendedCourse
    FROM dbo.PLACEMENT_TEST pl LEFT JOIN dbo.COURSE co ON co.CourseId = pl.RecommendedCourseId
    WHERE pl.TestId = @TestId;
END;
GO

/* E2. usp_Attendance_Save: save the attendance of one student at one session
       (a teacher only takes attendance for the sessions they teach) */
IF OBJECT_ID(N'dbo.usp_Attendance_Save', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Attendance_Save;
GO
CREATE PROCEDURE dbo.usp_Attendance_Save
    @SessionId     INT,
    @EnrollmentId  VARCHAR(10),
    @Status        NVARCHAR(20),
    @Notes         NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_CurrentRole() = 'TEACHER'
       AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE SessionId = @SessionId
                                                         AND TeacherId = dbo.fn_CurrentTeacherId())
        THROW 50040, N'You can only take attendance for sessions you teach.', 1;

    IF EXISTS (SELECT 1 FROM dbo.ATTENDANCE WHERE SessionId = @SessionId AND EnrollmentId = @EnrollmentId)
        UPDATE dbo.ATTENDANCE SET Status = @Status, Notes = @Notes
        WHERE SessionId = @SessionId AND EnrollmentId = @EnrollmentId;
    ELSE
        INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status, Notes)
        VALUES (@SessionId, @EnrollmentId, @Status, @Notes);
END;
GO

/* E3. usp_Attendance_BySession: attendance list of a session (including students not marked yet) */
IF OBJECT_ID(N'dbo.usp_Attendance_BySession', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Attendance_BySession;
GO
CREATE PROCEDURE dbo.usp_Attendance_BySession
    @SessionId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_CurrentRole() = 'TEACHER'
       AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE SessionId = @SessionId
                                                         AND TeacherId = dbo.fn_CurrentTeacherId())
        THROW 50040, N'You can only view the attendance of sessions you teach.', 1;

    SELECT en.EnrollmentId, st.StudentId, st.FullName AS StudentName,
           ISNULL(at.Status, N'Present') AS Status, at.Notes,
           CASE WHEN at.EnrollmentId IS NULL THEN 0 ELSE 1 END AS IsSaved
    FROM dbo.CLASS_SESSION se
    JOIN dbo.ENROLLMENT en      ON en.ClassId = se.ClassId AND en.Status IN (N'Studying', N'Completed')
    JOIN dbo.STUDENT st         ON st.StudentId = en.StudentId
    LEFT JOIN dbo.ATTENDANCE at ON at.SessionId = se.SessionId AND at.EnrollmentId = en.EnrollmentId
    WHERE se.SessionId = @SessionId
    ORDER BY st.FullName;
END;
GO

/* E4. usp_Grade_Save: enter/change the score of one grade component
       (a teacher only grades their own classes; no changes after the class finished) */
IF OBJECT_ID(N'dbo.usp_Grade_Save', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Grade_Save;
GO
CREATE PROCEDURE dbo.usp_Grade_Save
    @EnrollmentId  VARCHAR(10),
    @ComponentId   INT,
    @Score         DECIMAL(4,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ClassTeacherId VARCHAR(10), @ClassStatus NVARCHAR(20);

    SELECT @ClassTeacherId = cl.TeacherId, @ClassStatus = cl.Status
    FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
    WHERE en.EnrollmentId = @EnrollmentId;

    IF @ClassTeacherId IS NULL
        THROW 50026, N'Enrollment not found.', 1;
    IF dbo.fn_CurrentRole() = 'TEACHER' AND @ClassTeacherId <> dbo.fn_CurrentTeacherId()
        THROW 50041, N'You can only enter grades for classes you teach.', 1;
    IF @ClassStatus = N'Finished'
        THROW 50042, N'The class has finished and its results are final; grades can no longer be changed.', 1;

    IF EXISTS (SELECT 1 FROM dbo.GRADE WHERE EnrollmentId = @EnrollmentId AND ComponentId = @ComponentId)
        UPDATE dbo.GRADE SET Score = @Score, EnteredAtUtc = GETUTCDATE(), EnteredBy = ORIGINAL_LOGIN()
        WHERE EnrollmentId = @EnrollmentId AND ComponentId = @ComponentId;
    ELSE
        INSERT INTO dbo.GRADE (EnrollmentId, ComponentId, Score) VALUES (@EnrollmentId, @ComponentId, @Score);
END;
GO

/* E5. usp_Class_EvaluateResults: end-of-course results for the whole class with a CURSOR.
       For each student: final grade + attendance rate; Passed when grade >= 5 and
       attendance >= 80%; a certificate is issued to students who passed. */
IF OBJECT_ID(N'dbo.usp_Class_EvaluateResults', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Class_EvaluateResults;
GO
CREATE PROCEDURE dbo.usp_Class_EvaluateResults
    @ClassId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CourseId VARCHAR(10), @EnrollmentId VARCHAR(10), @Grade DECIMAL(4,2), @Attendance DECIMAL(5,2),
            @Result NVARCHAR(20), @PassedCount INT = 0, @FailedCount INT = 0, @MissingCount INT = 0,
            @IssuedOn DATE, @Msg NVARCHAR(2048);

    SELECT @CourseId = CourseId, @IssuedOn = ISNULL(EndDate, dbo.fn_Today())
    FROM dbo.CLASS WHERE ClassId = @ClassId AND Status IN (N'In progress', N'Finished');
    IF @CourseId IS NULL
        THROW 50043, N'The class does not exist or has not started yet.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_CourseInvalidWeights WHERE CourseId = @CourseId)
        THROW 50044, N'The grade component weights of the course do not add up to 100%.', 1;

    -- Check first: every student must have all scores
    SELECT @MissingCount = COUNT(*) FROM dbo.ENROLLMENT
    WHERE ClassId = @ClassId AND Status IN (N'Studying', N'Completed')
      AND dbo.fn_FinalGrade(EnrollmentId) IS NULL;
    IF @MissingCount > 0
    BEGIN
        SET @Msg = N'Grades are still missing for ' + CAST(@MissingCount AS NVARCHAR(10)) + N' student(s).';
        THROW 50045, @Msg, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE cur_Enrollment CURSOR LOCAL FAST_FORWARD FOR
            SELECT EnrollmentId FROM dbo.ENROLLMENT
            WHERE ClassId = @ClassId AND Status IN (N'Studying', N'Completed')
            ORDER BY EnrollmentId;

        OPEN cur_Enrollment;
        FETCH NEXT FROM cur_Enrollment INTO @EnrollmentId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Grade = dbo.fn_FinalGrade(@EnrollmentId);
            SET @Attendance = ISNULL(dbo.fn_AttendanceRate(@EnrollmentId), 100);
            SET @Result = CASE WHEN @Grade >= 5 AND @Attendance >= 80 THEN N'Passed' ELSE N'Failed' END;

            UPDATE dbo.ENROLLMENT
            SET FinalGrade = @Grade, Result = @Result, Status = N'Completed'
            WHERE EnrollmentId = @EnrollmentId;

            IF @Result = N'Passed'
            BEGIN
                SET @PassedCount += 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.CERTIFICATE WHERE EnrollmentId = @EnrollmentId)
                    INSERT INTO dbo.CERTIFICATE (EnrollmentId, SerialNumber, IssuedOn, FinalGrade, Classification)
                    VALUES (@EnrollmentId, 'EC' + CONVERT(VARCHAR(4), YEAR(@IssuedOn)) + '-' + @EnrollmentId,
                            @IssuedOn, @Grade, dbo.fn_Classification(@Grade));
            END
            ELSE
                SET @FailedCount += 1;

            FETCH NEXT FROM cur_Enrollment INTO @EnrollmentId;
        END;

        CLOSE cur_Enrollment;
        DEALLOCATE cur_Enrollment;

        UPDATE dbo.CLASS SET Status = N'Finished' WHERE ClassId = @ClassId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @PassedCount AS PassedCount, @FailedCount AS FailedCount;
END;
GO

/* =====================================================================
   F. TEACHER PAYROLL
   ===================================================================== */

/* F1. usp_Payroll_Finalize: finalize the monthly pay of every teacher with a CURSOR.
       Pay = hours taught x hourly rate; a 500,000 VND bonus for 20 sessions or more. */
IF OBJECT_ID(N'dbo.usp_Payroll_Finalize', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Payroll_Finalize;
GO
CREATE PROCEDURE dbo.usp_Payroll_Finalize
    @Month  TINYINT,
    @Year   SMALLINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TeacherId VARCHAR(10), @HourlyRate DECIMAL(12,0), @SessionCount INT, @Hours DECIMAL(6,2),
            @Bonus DECIMAL(12,0), @TeacherCount INT = 0;

    IF DATEFROMPARTS(@Year, @Month, 1) > dbo.fn_Today()
        THROW 50050, N'Payroll cannot be finalized for a future month.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE cur_Teacher CURSOR LOCAL FAST_FORWARD FOR
            SELECT te.TeacherId, te.HourlyRate, COUNT(se.SessionId),
                   CAST(SUM(DATEDIFF(MINUTE, se.StartTime, se.EndTime)) / 60.0 AS DECIMAL(6,2))
            FROM dbo.TEACHER te
            JOIN dbo.CLASS_SESSION se ON se.TeacherId = te.TeacherId
            WHERE se.Status = N'Taught' AND MONTH(se.SessionDate) = @Month AND YEAR(se.SessionDate) = @Year
            GROUP BY te.TeacherId, te.HourlyRate;

        OPEN cur_Teacher;
        FETCH NEXT FROM cur_Teacher INTO @TeacherId, @HourlyRate, @SessionCount, @Hours;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Bonus = CASE WHEN @SessionCount >= 20 THEN 500000 ELSE 0 END;

            IF EXISTS (SELECT 1 FROM dbo.PAYROLL WHERE TeacherId = @TeacherId AND Month = @Month AND Year = @Year)
                UPDATE dbo.PAYROLL
                SET SessionCount = @SessionCount, Hours = @Hours, HourlyRate = @HourlyRate, Bonus = @Bonus,
                    FinalizedAtUtc = GETUTCDATE()
                WHERE TeacherId = @TeacherId AND Month = @Month AND Year = @Year AND Status = N'Finalized';
            ELSE
                INSERT INTO dbo.PAYROLL (TeacherId, Month, Year, SessionCount, Hours, HourlyRate, Bonus)
                VALUES (@TeacherId, @Month, @Year, @SessionCount, @Hours, @HourlyRate, @Bonus);

            SET @TeacherCount += 1;
            FETCH NEXT FROM cur_Teacher INTO @TeacherId, @HourlyRate, @SessionCount, @Hours;
        END;

        CLOSE cur_Teacher;
        DEALLOCATE cur_Teacher;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT py.TeacherId, te.FullName AS TeacherName, py.SessionCount, py.Hours, py.HourlyRate, py.Bonus,
           py.Deduction, py.TotalPay, py.Status
    FROM dbo.PAYROLL py JOIN dbo.TEACHER te ON te.TeacherId = py.TeacherId
    WHERE py.Month = @Month AND py.Year = @Year
    ORDER BY te.FullName;
END;
GO

/* =====================================================================
   G. REPORTS - STATISTICS
   ===================================================================== */

/* G1. usp_Dashboard_Stats: figures for the Dashboard screen.
       Academic staff may call it too but must NOT see revenue:
       RevenueThisMonth is NULL unless the caller is a manager/accountant. */
IF OBJECT_ID(N'dbo.usp_Dashboard_Stats', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Dashboard_Stats;
GO
CREATE PROCEDURE dbo.usp_Dashboard_Stats
    @BranchId VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Today DATE = dbo.fn_Today();
    -- This month of the center as a UTC range (receipts are stored in UTC)
    DECLARE @MonthStartUtc DATETIME = dbo.fn_CenterTimeToUtc(DATEADD(DAY, 1 - DAY(@Today), @Today));
    DECLARE @NextMonthUtc DATETIME = dbo.fn_CenterTimeToUtc(DATEADD(MONTH, 1, DATEADD(DAY, 1 - DAY(@Today), @Today)));
    DECLARE @CanSeeRevenue BIT = CASE WHEN dbo.fn_CurrentRole() IN ('MANAGER', 'ACCOUNTANT') THEN 1 ELSE 0 END;

    SELECT
        (SELECT COUNT(*) FROM dbo.STUDENT
            WHERE Status = N'Studying' AND (@BranchId IS NULL OR BranchId = @BranchId)) AS ActiveStudents,
        (SELECT COUNT(*) FROM dbo.CLASS
            WHERE Status = N'In progress' AND (@BranchId IS NULL OR BranchId = @BranchId)) AS ActiveClasses,
        (SELECT COUNT(*) FROM dbo.CLASS
            WHERE Status = N'Enrolling' AND (@BranchId IS NULL OR BranchId = @BranchId)) AS EnrollingClasses,
        CASE WHEN @CanSeeRevenue = 0 THEN NULL ELSE
        (SELECT ISNULL(SUM(rc.Amount), 0) FROM dbo.RECEIPT rc
            JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
            WHERE rc.Status = N'Valid' AND rc.PaidAtUtc >= @MonthStartUtc AND rc.PaidAtUtc < @NextMonthUtc
              AND (@BranchId IS NULL OR cl.BranchId = @BranchId)) END AS RevenueThisMonth,
        (SELECT ISNULL(SUM(Balance), 0) FROM dbo.vw_OutstandingTuition
            WHERE (@BranchId IS NULL OR BranchId = @BranchId)) AS TotalOutstanding,
        (SELECT COUNT(*) FROM dbo.CLASS_SESSION se JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
            WHERE se.SessionDate = @Today AND se.Status <> N'Cancelled'
              AND (@BranchId IS NULL OR cl.BranchId = @BranchId)) AS SessionsToday;
END;
GO

/* G2. usp_Report_Revenue: revenue per course between two dates (days of the center) */
IF OBJECT_ID(N'dbo.usp_Report_Revenue', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Report_Revenue;
GO
CREATE PROCEDURE dbo.usp_Report_Revenue
    @FromDate  DATE,
    @ToDate    DATE,
    @BranchId  VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- From the start of @FromDate to the end of @ToDate in the center, as UTC bounds
    DECLARE @FromUtc DATETIME = dbo.fn_CenterTimeToUtc(@FromDate),
            @ToUtc   DATETIME = dbo.fn_CenterTimeToUtc(DATEADD(DAY, 1, @ToDate));
    SELECT br.BranchName, pg.ProgramName, co.CourseName, COUNT(*) AS ReceiptCount, SUM(rc.Amount) AS Revenue
    FROM dbo.RECEIPT rc
    JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
    JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
    JOIN dbo.COURSE co     ON co.CourseId = cl.CourseId
    JOIN dbo.PROGRAM pg    ON pg.ProgramId = co.ProgramId
    JOIN dbo.BRANCH br     ON br.BranchId = cl.BranchId
    WHERE rc.Status = N'Valid'
      AND rc.PaidAtUtc >= @FromUtc AND rc.PaidAtUtc < @ToUtc
      AND (@BranchId IS NULL OR cl.BranchId = @BranchId)
    GROUP BY br.BranchName, pg.ProgramName, co.CourseName
    ORDER BY br.BranchName, pg.ProgramName, Revenue DESC;
END;
GO

/* G3. usp_Report_ClassResults: final results of a class */
IF OBJECT_ID(N'dbo.usp_Report_ClassResults', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Report_ClassResults;
GO
CREATE PROCEDURE dbo.usp_Report_ClassResults
    @ClassId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT lr.StudentId, lr.StudentName, lr.FinalGrade, lr.Classification, lr.AttendanceRate, lr.Result,
           ce.SerialNumber AS CertificateNumber
    FROM dbo.vw_LearningResults lr
    LEFT JOIN dbo.CERTIFICATE ce ON ce.EnrollmentId = lr.EnrollmentId
    WHERE lr.ClassId = @ClassId AND lr.Status IN (N'Studying', N'Completed')
    ORDER BY lr.FinalGrade DESC, lr.StudentName;
END;
GO

/* =====================================================================
   H. XML - XPATH/XQUERY - IMPORT/EXPORT
   ===================================================================== */

/* H1. usp_Course_FindBySkill: courses with a Unit that practices @Skill
       (XQuery .exist() with sql:variable) */
IF OBJECT_ID(N'dbo.usp_Course_FindBySkill', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Course_FindBySkill;
GO
CREATE PROCEDURE dbo.usp_Course_FindBySkill
    @Skill NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT co.CourseId, co.CourseName, co.Level,
           co.SyllabusXml.value('(/Syllabus/Textbook)[1]', 'NVARCHAR(200)') AS Textbook,
           co.SyllabusXml.value('count(/Syllabus/Unit[Skill = sql:variable("@Skill")])', 'INT') AS UnitCount
    FROM dbo.COURSE co
    WHERE co.SyllabusXml.exist('/Syllabus/Unit[Skill = sql:variable("@Skill")]') = 1;
END;
GO

/* H2. usp_Course_Syllabus: shred the XML syllabus into a relational result with .nodes() */
IF OBJECT_ID(N'dbo.usp_Course_Syllabus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Course_Syllabus;
GO
CREATE PROCEDURE dbo.usp_Course_Syllabus
    @CourseId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.value('@No', 'INT')                   AS Unit,
           u.value('(Title)[1]', 'NVARCHAR(200)')  AS Title,
           u.value('@Sessions', 'INT')             AS Sessions,
           STUFF(u.query('for $s in Skill return concat(", ", string($s))').value('.', 'NVARCHAR(200)'), 1, 2, '') AS Skills
    FROM dbo.COURSE co
    CROSS APPLY co.SyllabusXml.nodes('/Syllabus/Unit') AS T(u)
    WHERE co.CourseId = @CourseId
    ORDER BY Unit;
END;
GO

/* H3. usp_Teacher_FindByCertificate: teachers holding certificate @CertificateType with a score
       >= @MinScore (XQuery on the untyped XML profile) */
IF OBJECT_ID(N'dbo.usp_Teacher_FindByCertificate', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Teacher_FindByCertificate;
GO
CREATE PROCEDURE dbo.usp_Teacher_FindByCertificate
    @CertificateType  NVARCHAR(20),
    @MinScore         DECIMAL(4,1) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT te.TeacherId, te.FullName, te.TeacherType,
           te.ProfileXml.value('(/Profile/Certificate[@Type = sql:variable("@CertificateType")]/@Score)[1]',
                               'DECIMAL(4,1)') AS Score,
           te.ProfileXml.value('(/Profile/Experience/@Years)[1]', 'INT') AS YearsOfExperience,
           te.ProfileXml.query('/Profile/Specialty') AS Specialties
    FROM dbo.TEACHER te
    WHERE te.ProfileXml.exist('/Profile/Certificate[@Type = sql:variable("@CertificateType")
                                   and (empty(@Score) or @Score >= sql:variable("@MinScore"))]') = 1
    ORDER BY Score DESC;
END;
GO

/* H4. usp_Student_ExportXml: export students to XML (FOR XML PATH) */
IF OBJECT_ID(N'dbo.usp_Student_ExportXml', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_ExportXml;
GO
CREATE PROCEDURE dbo.usp_Student_ExportXml
    @BranchId VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (
        SELECT st.StudentId AS '@StudentId', st.BranchId AS '@BranchId',
               st.FullName, st.DateOfBirth, st.Gender, st.Phone, st.Email,
               st.GuardianName, st.GuardianPhone, st.Status
        FROM dbo.STUDENT st
        WHERE @BranchId IS NULL OR st.BranchId = @BranchId
        ORDER BY st.StudentId
        FOR XML PATH('Student'), ROOT('Students'), TYPE
    ) AS XmlData;
END;
GO

/* H5. usp_Student_ImportXml: import students from XML (same structure as the export).
       Rows with a duplicate phone/email are skipped; returns the number of imported rows. */
IF OBJECT_ID(N'dbo.usp_Student_ImportXml', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_ImportXml;
GO
CREATE PROCEDURE dbo.usp_Student_ImportXml
    @Data      XML,
    @BranchId  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Source TABLE (
        FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10), Phone VARCHAR(15),
        Email VARCHAR(100), GuardianName NVARCHAR(100), GuardianPhone VARCHAR(15));

    INSERT INTO @Source
    SELECT x.value('(FullName)[1]', 'NVARCHAR(100)'),
           x.value('(DateOfBirth)[1]', 'DATE'),
           ISNULL(x.value('(Gender)[1]', 'NVARCHAR(10)'), N'Other'),
           NULLIF(x.value('(Phone)[1]', 'VARCHAR(15)'), ''),
           NULLIF(x.value('(Email)[1]', 'VARCHAR(100)'), ''),
           NULLIF(x.value('(GuardianName)[1]', 'NVARCHAR(100)'), ''),
           NULLIF(x.value('(GuardianPhone)[1]', 'VARCHAR(15)'), '')
    FROM @Data.nodes('/Students/Student') AS T(x);

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.STUDENT (FullName, DateOfBirth, Gender, Phone, Email, GuardianName, GuardianPhone, BranchId)
        SELECT s.FullName, s.DateOfBirth, s.Gender, s.Phone, s.Email, s.GuardianName, s.GuardianPhone, @BranchId
        FROM @Source s
        WHERE s.FullName IS NOT NULL AND s.DateOfBirth IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.STUDENT x WHERE x.Phone = s.Phone OR x.Email = s.Email);
        DECLARE @RowCount INT = @@ROWCOUNT;
        COMMIT TRANSACTION;
        SELECT @RowCount AS ImportedRows, (SELECT COUNT(*) FROM @Source) - @RowCount AS SkippedRows;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =====================================================================
   I. ACCOUNTS - BACKUP (security)
   ===================================================================== */

/* I1. usp_Account_Create: create a USER with a password in the contained database + add it to a ROLE.
       EXECUTE AS OWNER: the caller only needs EXECUTE, not ALTER ANY USER; the username is
       checked character by character and QUOTENAME'd against SQL injection in dynamic SQL. */
IF OBJECT_ID(N'dbo.usp_Account_Create', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_Create;
GO
CREATE PROCEDURE dbo.usp_Account_Create
    @Username    NVARCHAR(50),
    @Password    NVARCHAR(128),
    @Role        VARCHAR(20),
    @EmployeeId  VARCHAR(10) = NULL,
    @TeacherId   VARCHAR(10) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @DbRole SYSNAME, @Sql NVARCHAR(MAX);

    IF @Username IS NULL OR @Username LIKE N'%[^a-zA-Z0-9_.]%' OR LEN(@Username) < 3
        THROW 50060, N'A username may only contain letters without diacritics, digits, dots and underscores (at least 3 characters).', 1;
    IF LEN(ISNULL(@Password, N'')) < 8
        THROW 50061, N'The password must be at least 8 characters long.', 1;
    IF DATABASE_PRINCIPAL_ID(@Username) IS NOT NULL OR EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE Username = @Username)
        THROW 50062, N'The username already exists.', 1;

    SET @DbRole = CASE @Role WHEN 'MANAGER' THEN 'rl_Manager' WHEN 'ACADEMIC_STAFF' THEN 'rl_AcademicStaff'
                             WHEN 'ACCOUNTANT' THEN 'rl_Accountant' WHEN 'TEACHER' THEN 'rl_Teacher' END;
    IF @DbRole IS NULL
        THROW 50063, N'Invalid role.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.ACCOUNT (Username, Role, EmployeeId, TeacherId) VALUES (@Username, @Role, @EmployeeId, @TeacherId);

        SET @Sql = N'CREATE USER ' + QUOTENAME(@Username)
                 + N' WITH PASSWORD = N''' + REPLACE(@Password, N'''', N'''''') + N''', DEFAULT_SCHEMA = dbo;'
                 + N' ALTER ROLE ' + QUOTENAME(@DbRole) + N' ADD MEMBER ' + QUOTENAME(@Username) + N';';
        EXEC sys.sp_executesql @Sql;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* I2. usp_Account_Lock: lock / unlock (DENY / GRANT the CONNECT permission) */
IF OBJECT_ID(N'dbo.usp_Account_Lock', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_Lock;
GO
CREATE PROCEDURE dbo.usp_Account_Lock
    @Username  NVARCHAR(50),
    @Lock      BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(400);
    IF NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE Username = @Username)
        THROW 50064, N'Account not found.', 1;
    IF @Username = ORIGINAL_LOGIN()
        THROW 50065, N'You cannot lock the account you are signed in with.', 1;

    SET @Sql = CASE WHEN @Lock = 1 THEN N'DENY CONNECT TO ' ELSE N'GRANT CONNECT TO ' END + QUOTENAME(@Username);
    EXEC sys.sp_executesql @Sql;
    UPDATE dbo.ACCOUNT SET Status = CASE WHEN @Lock = 1 THEN N'Locked' ELSE N'Active' END
    WHERE Username = @Username;
END;
GO

/* I3. usp_Account_ResetPassword: the manager resets an employee's password */
IF OBJECT_ID(N'dbo.usp_Account_ResetPassword', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_ResetPassword;
GO
CREATE PROCEDURE dbo.usp_Account_ResetPassword
    @Username     NVARCHAR(50),
    @NewPassword  NVARCHAR(128)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    IF NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE Username = @Username)
        THROW 50064, N'Account not found.', 1;
    IF LEN(ISNULL(@NewPassword, N'')) < 8
        THROW 50061, N'The password must be at least 8 characters long.', 1;

    SET @Sql = N'ALTER USER ' + QUOTENAME(@Username)
             + N' WITH PASSWORD = N''' + REPLACE(@NewPassword, N'''', N'''''') + N''';';
    EXEC sys.sp_executesql @Sql;
END;
GO

/* I4. usp_Account_ChangePassword: users change their own password (runs as the caller;
       SQL Server requires the correct current password - OLD_PASSWORD) */
IF OBJECT_ID(N'dbo.usp_Account_ChangePassword', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_ChangePassword;
GO
CREATE PROCEDURE dbo.usp_Account_ChangePassword
    @OldPassword  NVARCHAR(128),
    @NewPassword  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    IF LEN(ISNULL(@NewPassword, N'')) < 8
        THROW 50061, N'The password must be at least 8 characters long.', 1;

    SET @Sql = N'ALTER USER ' + QUOTENAME(USER_NAME())
             + N' WITH PASSWORD = N''' + REPLACE(@NewPassword, N'''', N'''''')
             + N''' OLD_PASSWORD = N''' + REPLACE(@OldPassword, N'''', N'''''') + N''';';
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        -- Turn the technical system error into a business message
        IF ERROR_NUMBER() = 15151   -- wrong OLD_PASSWORD
            THROW 50066, N'The current password is incorrect.', 1;
        IF ERROR_NUMBER() IN (15114, 15115, 15116, 15118)   -- password policy violation
            THROW 50067, N'The new password is not strong enough: it needs uppercase and lowercase letters, digits or special characters.', 1;
        THROW;
    END CATCH;
END;
GO

/* I5. usp_Account_RecordLogin: update the last sign-in time (called right after sign-in) */
IF OBJECT_ID(N'dbo.usp_Account_RecordLogin', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_RecordLogin;
GO
CREATE PROCEDURE dbo.usp_Account_RecordLogin
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ACCOUNT SET LastLoginAtUtc = GETUTCDATE() WHERE Username = USER_NAME() COLLATE DATABASE_DEFAULT;
    SELECT Username, Role, EmployeeId, TeacherId, Status, FullName, BranchId FROM dbo.vw_CurrentAccount;
END;
GO

/* I6. usp_Account_List: accounts with the role code (the application shows the localized role name and converts the
       UTC times to the user's time zone) */
IF OBJECT_ID(N'dbo.usp_Account_List', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_List;
GO
CREATE PROCEDURE dbo.usp_Account_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ac.Username, ac.Role, COALESCE(em.FullName, te.FullName) AS FullName,
           ac.Status, ac.CreatedAtUtc, ac.LastLoginAtUtc
    FROM dbo.ACCOUNT ac
    LEFT JOIN dbo.EMPLOYEE em ON em.EmployeeId = ac.EmployeeId
    LEFT JOIN dbo.TEACHER te  ON te.TeacherId = ac.TeacherId
    ORDER BY CASE ac.Role WHEN 'MANAGER' THEN 1 WHEN 'ACADEMIC_STAFF' THEN 2 WHEN 'ACCOUNTANT' THEN 3 ELSE 4 END,
             ac.Username;
END;
GO

/* I7. usp_Backup: FULL / DIFFERENTIAL / LOG backup into a folder on the SQL Server machine */
IF OBJECT_ID(N'dbo.usp_Backup', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Backup;
GO
CREATE PROCEDURE dbo.usp_Backup
    @Type      VARCHAR(10)    = 'FULL',
    @Folder    NVARCHAR(260)  = NULL,
    @FilePath  NVARCHAR(400)  = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- File names carry the center's local time, the time people at the center recognize
    DECLARE @Sql NVARCHAR(MAX), @Timestamp VARCHAR(20) =
        REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), dbo.fn_UtcToCenterTime(GETUTCDATE()), 120), '-', ''), ':', ''),
                ' ', '_');

    IF @Type NOT IN ('FULL', 'DIFF', 'LOG')
        THROW 50070, N'The backup type must be FULL, DIFF or LOG.', 1;

    -- Default: the SQL Server backup folder (Linux/Docker: /var/opt/mssql/data)
    IF @Folder IS NULL
        SET @Folder = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF @Folder IS NULL
        SET @Folder = LEFT(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)), 260);
    IF RIGHT(@Folder, 1) NOT IN ('/', '\')
        SET @Folder += CASE WHEN CHARINDEX('/', @Folder) > 0 THEN '/' ELSE '\' END;

    SET @FilePath = @Folder + N'QLTTTA_' + @Type + N'_' + @Timestamp + CASE @Type WHEN 'LOG' THEN N'.trn' ELSE N'.bak' END;
    SET @Sql = CASE @Type
                   WHEN 'FULL' THEN N'BACKUP DATABASE QLTTTA TO DISK = @f WITH INIT, NAME = N''QLTTTA Full'''
                   WHEN 'DIFF' THEN N'BACKUP DATABASE QLTTTA TO DISK = @f WITH DIFFERENTIAL, INIT, NAME = N''QLTTTA Differential'''
                   ELSE             N'BACKUP LOG QLTTTA TO DISK = @f WITH INIT, NAME = N''QLTTTA Log'''
               END;
    EXEC sys.sp_executesql @Sql, N'@f NVARCHAR(400)', @f = @FilePath;
    SELECT @FilePath AS BackupFile;
END;
GO
