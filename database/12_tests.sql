/* =====================================================================
   File   : 12_tests.sql - Tests of the constraints, business rules and permissions
   - Every test case runs in a transaction that is ROLLED BACK => the data never changes.
   - Permissions are tested with EXECUTE AS USER (impersonating a user) ... REVERT.
   - Run as sa / db_owner after 07_seed_data.sql. The summary table is at the end of the output.
   - A "Rejected" case only PASSES when it is rejected for the RIGHT REASON (the message matches the
     pattern in #Expected), so a procedure broken by another error cannot "pass". A case listed in
     #Expected that did not run also FAILS.
   - If any case FAILS the script ends with THROW 50099 (sqlcmd -b returns exit code 1), which
     scripts/test_all.sh uses to block changes that break the business rules.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results;
CREATE TABLE #Results (
    TestId       VARCHAR(5)     NOT NULL,
    Description  NVARCHAR(200)  NOT NULL,
    Expected     NVARCHAR(20)   NOT NULL,   -- 'Rejected' or 'Succeeded'
    Actual       NVARCHAR(20)   NULL,
    Message      NVARCHAR(400)  NULL
);

-- Specification: the cases that must run and the message pattern (LIKE) a "Rejected" case must return.
-- System errors are matched on the object/constraint name only (independent of the SQL Server message language).
IF OBJECT_ID('tempdb..#Expected') IS NOT NULL DROP TABLE #Expected;
CREATE TABLE #Expected (TestId VARCHAR(5) PRIMARY KEY, MessagePattern NVARCHAR(200) NULL);
INSERT #Expected VALUES
    ('T01', N'%CK_STUDENT_Guardian%'),          ('T02', N'%CK_STUDENT_Phone%'),
    ('T03', N'%already enrolled in this class%'), ('T04', N'%entry requirement%'),
    ('T05', N'%clashes with another class%'),   ('T06', N'%exceeds the tuition%'),
    ('T07', N'%Receipts cannot be deleted%'),   ('T08', N'%Schedule conflict%'),
    ('T09', N'%same branch%'),                  ('T10', N'%CK_GRADE_Score%'),
    ('T11', N'%append-only%'),                  ('T12', N'%students who passed%'),
    ('T13', N'%taught session%'),               ('T14', N'%same course%'),
    ('T15', NULL), ('T16', NULL), ('T17', NULL), ('T18', NULL), ('T19', NULL), ('T20', NULL),
    ('T21', N'%is full%'),                      ('T22', NULL), ('T23', NULL), ('T24', NULL),
    ('T25', N'%future month%'),                 ('T26', NULL), ('T27', N'%XML%'),
    ('P01', N'%STUDENT%'),                      ('P02', NULL),
    ('P03', N'%only enter grades%'),            ('P04', N'%usp_Enrollment_Create%'),
    ('P05', NULL),                              ('P06', N'%HourlyRate%'),
    ('P07', N'%PAYROLL%'),                      ('P08', N'%RECEIPT%'),
    ('P09', N'%usp_Account_Create%'),           ('P10', NULL), ('P11', NULL),
    ('P12', N'%current password is incorrect%');
GO

/* ---------------- A. INTEGRITY CONSTRAINTS & BUSINESS RULES ---------------- */

-- T01: a 12-year-old student without guardian details
BEGIN TRY
    BEGIN TRAN;
    DECLARE @Id VARCHAR(10);
    EXEC dbo.usp_Student_Add @FullName = N'Nguyễn Nhỏ', @DateOfBirth = '20140101', @Gender = N'Male',
         @Phone = '0909999001', @BranchId = 'BR01', @StudentId = @Id OUTPUT;
    ROLLBACK;
    INSERT #Results VALUES ('T01', N'Student under 18 without guardian details', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T01', N'Student under 18 without guardian details', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T02: a phone number containing letters
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO dbo.STUDENT (FullName, DateOfBirth, Gender, Phone, BranchId)
    VALUES (N'Trần Thử', '20000101', N'Male', '09abc12345', 'BR01');
    ROLLBACK;
    INSERT #Results VALUES ('T02', N'Invalid phone number format (domain CHECK)', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T02', N'Invalid phone number format (domain CHECK)', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T03: duplicate enrollment (the student is already enrolled in this class)
BEGIN TRY
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00001', @ClassId = 'CL0003', @EmployeeId = 'EM0002',
         @EnrollmentId = @EnrollmentId OUTPUT;
    INSERT #Results VALUES ('T03', N'Enrolling twice in the same class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T03', N'Enrolling twice in the same class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T04: enrolling without meeting the entry requirement (placement score 2.63 into IELTS 6.5)
BEGIN TRY
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00070', @ClassId = 'CL0008', @EmployeeId = 'EM0002',
         @EnrollmentId = @EnrollmentId OUTPUT;
    INSERT #Results VALUES ('T04', N'Prerequisite course / placement score not met', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T04', N'Prerequisite course / placement score not met', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T05: enrolling in a class at the same time as a class the student takes (ST00023 takes CL0003 Mon-Wed-Fri 18:00)
BEGIN TRY
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00023', @ClassId = 'CL0007', @EmployeeId = 'EM0004',
         @EnrollmentId = @EnrollmentId OUTPUT;
    INSERT #Results VALUES ('T05', N'A student in 2 classes with clashing schedules', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T05', N'A student in 2 classes with clashing schedules', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T06: a payment above the tuition (EN000001 is fully paid) - derived-attribute trigger
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ReceiptId VARCHAR(10);
    EXEC dbo.usp_Receipt_Create @EnrollmentId = 'EN000001', @Amount = 1000000, @EmployeeId = 'EM0003',
         @ReceiptId = @ReceiptId OUTPUT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T06', N'Payment above the outstanding tuition', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T06', N'Payment above the outstanding tuition', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T07: deleting a receipt (INSTEAD OF DELETE)
BEGIN TRY
    BEGIN TRAN;
    DELETE FROM dbo.RECEIPT WHERE ReceiptId = 'RC000001';
    DECLARE @Remaining INT = (SELECT COUNT(*) FROM dbo.RECEIPT WHERE ReceiptId = 'RC000001');
    ROLLBACK;
    INSERT #Results VALUES ('T07', N'Physically deleting a receipt', N'Rejected',
                            CASE WHEN @Remaining = 1 THEN N'Rejected' ELSE N'Succeeded' END, NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T07', N'Physically deleting a receipt', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T08: a schedule slot in a busy room (CL0010 uses D1-102 like CL0004, on Tuesday 19:00-20:30)
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_ClassSchedule_Add @ClassId = 'CL0010', @Weekday = 2, @StartTime = '19:00', @EndTime = '20:30';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T08', N'Two classes in the same room at the same time', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T08', N'Two classes in the same room at the same time', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T09: moving a class to a room of another branch (rule across CLASS - ROOM)
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.CLASS SET RoomId = 'TD-301' WHERE ClassId = 'CL0010';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T09', N'Room of another branch than the class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T09', N'Room of another branch than the class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T10: a score of 11 (outside the 0-10 domain)
BEGIN TRY
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10) = (SELECT TOP 1 EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0006');
    DECLARE @ComponentId INT = (SELECT TOP 1 ComponentId FROM dbo.GRADE_COMPONENT WHERE CourseId = 'CM-B1');
    EXEC dbo.usp_Grade_Save @EnrollmentId = @EnrollmentId, @ComponentId = @ComponentId, @Score = 11;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T10', N'Score outside the 0-10 domain', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T10', N'Score outside the 0-10 domain', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T11: changing the audit log (INSTEAD OF UPDATE)
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.AUDIT_LOG SET PerformedBy = N'someone' WHERE LogId = 1;
    DECLARE @Changed INT = (SELECT COUNT(*) FROM dbo.AUDIT_LOG WHERE LogId = 1 AND PerformedBy = N'someone');
    ROLLBACK;
    INSERT #Results VALUES ('T11', N'Changing the audit log', N'Rejected',
                            CASE WHEN @Changed = 0 THEN N'Rejected' ELSE N'Succeeded' END, NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T11', N'Changing the audit log', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T12: issuing a certificate to a student who failed
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO dbo.CERTIFICATE (EnrollmentId, SerialNumber, FinalGrade, Classification)
    SELECT TOP 1 EnrollmentId, 'TEST-0001', 5, N'Average' FROM dbo.ENROLLMENT WHERE Result = N'Failed';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T12', N'Certificate for a student who failed', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T12', N'Certificate for a student who failed', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T13: moving the date of a taught session
BEGIN TRY
    BEGIN TRAN;
    UPDATE TOP (1) dbo.CLASS_SESSION SET SessionDate = DATEADD(DAY, 1, SessionDate) WHERE Status = N'Taught';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T13', N'Changing the time of a taught session', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T13', N'Changing the time of a taught session', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T14: transferring a student to a class of another course
BEGIN TRY
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10) = (SELECT TOP 1 EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0004');
    EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = @EnrollmentId, @NewClassId = 'CL0010';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T14', N'Transfer to a class of another course', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T14', N'Transfer to a class of another course', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T15: a valid enrollment (class without entry requirement, with a promotion), then rolled back
BEGIN TRY
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00071', @ClassId = 'CL0010', @PromotionId = 'PR-REFER',
         @EmployeeId = 'EM0002', @EnrollmentId = @EnrollmentId OUTPUT;
    DECLARE @Info NVARCHAR(200) = (SELECT N'ID ' + EnrollmentId + N', tuition due ' + FORMAT(TuitionDue, 'N0') + N' VND'
                                   FROM dbo.ENROLLMENT WHERE EnrollmentId = @EnrollmentId);
    ROLLBACK;
    INSERT #Results VALUES ('T15', N'Valid enrollment with a promotion', N'Succeeded', N'Succeeded', @Info);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T15', N'Valid enrollment with a promotion', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- C. FUNCTIONS, TRIGGERS, CURSORS, XML: CHECKING THE RESULTS ----------------
   Not only "it runs": results are compared with independently computed values or prepared scenarios. */

-- T16: fn_Classification at the grade thresholds (upper/lower bound of each class)
BEGIN TRY
    DECLARE @Wrong16 INT;
    SELECT @Wrong16 = COUNT(*)
    FROM (VALUES (CAST(10 AS DECIMAL(4,2)), N'Excellent'), (9, N'Excellent'), (8.99, N'Very good'), (8, N'Very good'),
                 (7.99, N'Good'), (6.5, N'Good'), (6.49, N'Average'), (5, N'Average'),
                 (4.99, N'Failed'), (0, N'Failed')) AS m(Grade, Expected)
    WHERE ISNULL(dbo.fn_Classification(m.Grade), N'') <> m.Expected;
    IF dbo.fn_Classification(NULL) IS NOT NULL SET @Wrong16 += 1;
    INSERT #Results VALUES ('T16', N'fn_Classification: thresholds at 9 / 8 / 6.5 / 5', N'Succeeded',
                            CASE WHEN @Wrong16 = 0 THEN N'Succeeded' ELSE N'Wrong result' END,
                            CAST(11 - @Wrong16 AS NVARCHAR(5)) + N'/11 grades (NULL included) classified correctly');
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T16', N'fn_Classification: thresholds at 9 / 8 / 6.5 / 5', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T17: fn_FinalGrade = SUM(Score x Weight) / 100; NULL when a component has no score
BEGIN TRY
    DECLARE @Count17 INT, @Mismatch17 INT, @Enrollment17 VARCHAR(10), @AfterDelete17 DECIMAL(4,2);
    SELECT @Count17 = COUNT(*), @Mismatch17 = ISNULL(SUM(CASE WHEN x.ByFunction = x.Computed THEN 0 ELSE 1 END), 0)
    FROM (SELECT gr.EnrollmentId, dbo.fn_FinalGrade(gr.EnrollmentId) AS ByFunction,
                 CAST(ROUND(CAST(SUM(gr.Score * gc.Weight) / 100 AS DECIMAL(9,4)), 2) AS DECIMAL(4,2)) AS Computed
          FROM dbo.GRADE gr JOIN dbo.GRADE_COMPONENT gc ON gc.ComponentId = gr.ComponentId
          GROUP BY gr.EnrollmentId) x
    WHERE x.ByFunction IS NOT NULL;
    SELECT TOP (1) @Enrollment17 = EnrollmentId FROM dbo.ENROLLMENT
    WHERE dbo.fn_FinalGrade(EnrollmentId) IS NOT NULL ORDER BY EnrollmentId;

    BEGIN TRAN;
    DELETE TOP (1) FROM dbo.GRADE WHERE EnrollmentId = @Enrollment17;
    SET @AfterDelete17 = dbo.fn_FinalGrade(@Enrollment17);
    ROLLBACK;

    INSERT #Results VALUES ('T17', N'fn_FinalGrade: weighted grade, NULL when a score is missing', N'Succeeded',
        CASE WHEN @Count17 > 0 AND @Mismatch17 = 0 AND @AfterDelete17 IS NULL THEN N'Succeeded' ELSE N'Wrong result' END,
        CAST(@Count17 - @Mismatch17 AS NVARCHAR(10)) + N'/' + CAST(@Count17 AS NVARCHAR(10))
        + N' enrollments match; one score of ' + ISNULL(@Enrollment17, N'?') + N' removed => '
        + ISNULL(CAST(@AfterDelete17 AS NVARCHAR(10)), N'NULL'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T17', N'fn_FinalGrade: weighted grade, NULL when a score is missing', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T18: fn_AttendanceRate: "Present" and "Late" count as present; absences (even excused) do not
BEGIN TRY
    DECLARE @Enrollment18 VARCHAR(10), @Class18 VARCHAR(10), @Taught18 INT, @Rate18 DECIMAL(5,2), @Expected18 DECIMAL(5,2);
    SELECT TOP (1) @Enrollment18 = en.EnrollmentId, @Class18 = en.ClassId
    FROM dbo.ENROLLMENT en
    WHERE (SELECT COUNT(*) FROM dbo.CLASS_SESSION se WHERE se.ClassId = en.ClassId AND se.Status = N'Taught') >= 5
    ORDER BY en.EnrollmentId;
    SELECT @Taught18 = COUNT(*) FROM dbo.CLASS_SESSION WHERE ClassId = @Class18 AND Status = N'Taught';

    BEGIN TRAN;
    DELETE FROM dbo.ATTENDANCE WHERE EnrollmentId = @Enrollment18;
    -- Prepared scenario: 2 sessions present, 1 late, 1 excused absence, the rest unexcused absences
    INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status)
    SELECT se.SessionId, @Enrollment18, CASE WHEN se.Position <= 2 THEN N'Present' WHEN se.Position = 3 THEN N'Late'
                                             WHEN se.Position = 4 THEN N'Excused absence' ELSE N'Unexcused absence' END
    FROM (SELECT SessionId, ROW_NUMBER() OVER (ORDER BY SessionDate, SessionId) AS Position
          FROM dbo.CLASS_SESSION WHERE ClassId = @Class18 AND Status = N'Taught') se;
    SET @Rate18 = dbo.fn_AttendanceRate(@Enrollment18);
    ROLLBACK;

    SET @Expected18 = CAST(100.0 * 3 / @Taught18 AS DECIMAL(5,2));
    INSERT #Results VALUES ('T18', N'fn_AttendanceRate: late counts as present, excused absence does not', N'Succeeded',
        CASE WHEN @Rate18 = @Expected18 THEN N'Succeeded' ELSE N'Wrong result' END,
        N'2 present + 1 late out of ' + CAST(@Taught18 AS NVARCHAR(10)) + N' taught sessions => '
        + ISNULL(CAST(@Rate18 AS NVARCHAR(10)), N'NULL') + N'% (expected ' + CAST(@Expected18 AS NVARCHAR(10)) + N'%)');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T18', N'fn_AttendanceRate: late counts as present, excused absence does not', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T19: fn_DiscountAmount: % discounts rounded to thousands, never above the tuition, 0 when expired
BEGIN TRY
    DECLARE @D1 DECIMAL(12,0), @D2 DECIMAL(12,0), @D3 DECIMAL(12,0);
    BEGIN TRAN;
    INSERT INTO dbo.PROMOTION (PromotionId, PromotionName, DiscountType, DiscountValue, StartDate, EndDate) VALUES
        ('PRTEST1', N'Test: 15% off', 'PERCENT', 15, '20260101', '20261231'),
        ('PRTEST2', N'Test: 5 million off', 'AMOUNT', 5000000, '20260101', '20261231');
    SET @D1 = dbo.fn_DiscountAmount('PRTEST1', 4250000, '20260615');   -- 637,500 => rounded to 638,000
    SET @D2 = dbo.fn_DiscountAmount('PRTEST2', 3000000, '20260615');   -- at most the tuition
    SET @D3 = dbo.fn_DiscountAmount('PRTEST1', 4250000, '20270101');   -- outside the promotion period
    ROLLBACK;
    INSERT #Results VALUES ('T19', N'fn_DiscountAmount: rounded to thousands, capped at the tuition, 0 when expired', N'Succeeded',
        CASE WHEN @D1 = 638000 AND @D2 = 3000000 AND @D3 = 0 THEN N'Succeeded' ELSE N'Wrong result' END,
        N'15% x 4,250,000 = ' + CAST(@D1 AS NVARCHAR(20)) + N'; 5 million off a 3 million tuition = '
        + CAST(@D2 AS NVARCHAR(20)) + N'; expired = ' + CAST(@D3 AS NVARCHAR(20)));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T19', N'fn_DiscountAmount: rounded to thousands, capped at the tuition, 0 when expired', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T20: Tuition payment: the trigger updates AmountPaid (derived attribute) and writes an XML audit row;
--      cancelling the receipt lowers AmountPaid again
BEGIN TRY
    DECLARE @Enrollment20 VARCHAR(10), @Before20 DECIMAL(12,0), @AfterPay20 DECIMAL(12,0), @AfterCancel20 DECIMAL(12,0),
            @Receipt20 VARCHAR(10), @AuditRows20 INT;
    SELECT TOP (1) @Enrollment20 = EnrollmentId, @Before20 = AmountPaid FROM dbo.ENROLLMENT
    WHERE Status <> N'Left' AND TuitionDue - AmountPaid >= 100000 ORDER BY EnrollmentId;

    BEGIN TRAN;
    EXEC dbo.usp_Receipt_Create @EnrollmentId = @Enrollment20, @Amount = 100000, @EmployeeId = 'EM0003',
         @ReceiptId = @Receipt20 OUTPUT;
    SELECT @AfterPay20 = AmountPaid FROM dbo.ENROLLMENT WHERE EnrollmentId = @Enrollment20;
    SELECT @AuditRows20 = COUNT(*) FROM dbo.AUDIT_LOG
    WHERE TableName = N'RECEIPT' AND Action = 'INSERT' AND RecordKey = @Receipt20
      AND NewData.exist('/Receipt[Amount = 100000]') = 1;
    EXEC dbo.usp_Receipt_Cancel @ReceiptId = @Receipt20, @Reason = N'Test cancellation';
    SELECT @AfterCancel20 = AmountPaid FROM dbo.ENROLLMENT WHERE EnrollmentId = @Enrollment20;
    ROLLBACK;

    INSERT #Results VALUES ('T20', N'Payment then cancellation: AmountPaid updated, XML audit row', N'Succeeded',
        CASE WHEN @AfterPay20 = @Before20 + 100000 AND @AuditRows20 = 1 AND @AfterCancel20 = @Before20
             THEN N'Succeeded' ELSE N'Wrong result' END,
        @Enrollment20 + N': paid ' + CAST(@Before20 AS NVARCHAR(20)) + N' -> ' + CAST(@AfterPay20 AS NVARCHAR(20))
        + N' (paid 100,000) -> ' + CAST(@AfterCancel20 AS NVARCHAR(20)) + N' (cancelled); audit: '
        + CAST(@AuditRows20 AS NVARCHAR(5)) + N' row(s)');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T20', N'Payment then cancellation: AmountPaid updated, XML audit row', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T21: a full class accepts no more students, even through a direct INSERT that bypasses the procedure (trigger)
BEGIN TRY
    DECLARE @Class21 VARCHAR(10), @Student21 VARCHAR(10);
    SELECT TOP (1) @Class21 = ClassId FROM dbo.CLASS
    WHERE Status = N'Enrolling' AND dbo.fn_EnrolledCount(ClassId) >= 1 ORDER BY ClassId;
    SELECT TOP (1) @Student21 = st.StudentId FROM dbo.STUDENT st
    WHERE NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.StudentId = st.StudentId AND en.ClassId = @Class21)
    ORDER BY st.StudentId;

    BEGIN TRAN;
    UPDATE dbo.CLASS SET MaxStudents = dbo.fn_EnrolledCount(@Class21) WHERE ClassId = @Class21;   -- exactly full
    INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, BaseTuition) VALUES (@Student21, @Class21, 1000000);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T21', N'Enrolling in a full class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T21', N'Enrolling in a full class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T22: usp_Class_GenerateSessions: the course's number of sessions, on the weekdays/times of the weekly
--      schedule, end date = last session
BEGIN TRY
    DECLARE @Class22 VARCHAR(10), @CourseSessions22 INT, @Sessions22 INT, @WrongSlot22 INT, @WrongNo22 INT,
            @EndDateOk22 BIT, @Reported22 INT;
    SELECT TOP (1) @Class22 = cl.ClassId, @CourseSessions22 = co.SessionCount
    FROM dbo.CLASS cl JOIN dbo.COURSE co ON co.CourseId = cl.CourseId
    WHERE EXISTS (SELECT 1 FROM dbo.CLASS_SCHEDULE cs WHERE cs.ClassId = cl.ClassId)
      AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION se WHERE se.ClassId = cl.ClassId AND se.Status <> N'Scheduled')
    ORDER BY cl.ClassId;

    IF OBJECT_ID('tempdb..#R22') IS NOT NULL DROP TABLE #R22;
    CREATE TABLE #R22 (SessionsCreated INT, EndDate DATE);
    BEGIN TRAN;
    INSERT #R22 EXEC dbo.usp_Class_GenerateSessions @ClassId = @Class22;
    SELECT @Reported22 = SessionsCreated FROM #R22;
    SELECT @Sessions22 = COUNT(*) FROM dbo.CLASS_SESSION WHERE ClassId = @Class22;
    SELECT @WrongSlot22 = COUNT(*) FROM dbo.CLASS_SESSION se
    WHERE se.ClassId = @Class22
      AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SCHEDULE cs
                      WHERE cs.ClassId = se.ClassId AND cs.Weekday = dbo.fn_Weekday(se.SessionDate)
                        AND cs.StartTime = se.StartTime AND cs.EndTime = se.EndTime);
    SELECT @WrongNo22 = COUNT(*)
    FROM (SELECT SessionNo, ROW_NUMBER() OVER (ORDER BY SessionDate) AS Position
          FROM dbo.CLASS_SESSION WHERE ClassId = @Class22) x
    WHERE x.SessionNo <> x.Position;
    SELECT @EndDateOk22 = CASE WHEN cl.EndDate = (SELECT MAX(SessionDate) FROM dbo.CLASS_SESSION WHERE ClassId = @Class22)
                                AND (SELECT MIN(SessionDate) FROM dbo.CLASS_SESSION WHERE ClassId = @Class22) >= cl.StartDate
                               THEN 1 ELSE 0 END
    FROM dbo.CLASS cl WHERE cl.ClassId = @Class22;
    ROLLBACK;

    INSERT #Results VALUES ('T22', N'usp_Class_GenerateSessions: sessions follow the weekly schedule', N'Succeeded',
        CASE WHEN @Sessions22 = @CourseSessions22 AND @Reported22 = @CourseSessions22 AND @WrongSlot22 = 0
                  AND @WrongNo22 = 0 AND @EndDateOk22 = 1 THEN N'Succeeded' ELSE N'Wrong result' END,
        @Class22 + N': ' + CAST(@Sessions22 AS NVARCHAR(10)) + N'/' + CAST(@CourseSessions22 AS NVARCHAR(10))
        + N' sessions, ' + CAST(@WrongSlot22 AS NVARCHAR(10)) + N' on a wrong weekday/time, end date '
        + CASE WHEN @EndDateOk22 = 1 THEN N'correct' ELSE N'wrong' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T22', N'usp_Class_GenerateSessions: sessions follow the weekly schedule', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T23: usp_Class_EvaluateResults (cursor): Passed when grade >= 5 AND attendance >= 80%;
--      only students who passed get a certificate
BEGIN TRY
    DECLARE @Class23 VARCHAR(10), @Count23 INT, @Wrong23 INT, @WrongCert23 INT, @LowAttendance23 INT,
            @Passed23 INT, @Failed23 INT;
    SELECT TOP (1) @Class23 = cl.ClassId FROM dbo.CLASS cl
    WHERE cl.Status IN (N'In progress', N'Finished')
      AND EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.ClassId = cl.ClassId)
      AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en
                      WHERE en.ClassId = cl.ClassId AND en.Status IN (N'Studying', N'Completed')
                        AND dbo.fn_FinalGrade(en.EnrollmentId) IS NULL)
    ORDER BY cl.ClassId;

    IF OBJECT_ID('tempdb..#R23') IS NOT NULL DROP TABLE #R23;
    CREATE TABLE #R23 (PassedCount INT, FailedCount INT);
    BEGIN TRAN;
    -- Remove the previous results to evaluate from scratch
    DELETE ce FROM dbo.CERTIFICATE ce JOIN dbo.ENROLLMENT en ON en.EnrollmentId = ce.EnrollmentId WHERE en.ClassId = @Class23;
    UPDATE dbo.ENROLLMENT SET Result = NULL, FinalGrade = NULL WHERE ClassId = @Class23;
    INSERT #R23 EXEC dbo.usp_Class_EvaluateResults @ClassId = @Class23;
    SELECT @Passed23 = PassedCount, @Failed23 = FailedCount FROM #R23;

    SELECT @Count23 = COUNT(*),
           @Wrong23 = SUM(CASE WHEN en.Result = CASE WHEN dbo.fn_FinalGrade(en.EnrollmentId) >= 5
                                                          AND ISNULL(dbo.fn_AttendanceRate(en.EnrollmentId), 100) >= 80
                                                     THEN N'Passed' ELSE N'Failed' END
                               THEN 0 ELSE 1 END),
           -- a student with a passing grade but attendance below 80% must fail
           @LowAttendance23 = SUM(CASE WHEN en.FinalGrade >= 5 AND dbo.fn_AttendanceRate(en.EnrollmentId) < 80
                                            AND en.Result = N'Failed' THEN 1 ELSE 0 END)
    FROM dbo.ENROLLMENT en WHERE en.ClassId = @Class23 AND en.Status = N'Completed';
    SELECT @WrongCert23 = COUNT(*)
    FROM dbo.ENROLLMENT en LEFT JOIN dbo.CERTIFICATE ce ON ce.EnrollmentId = en.EnrollmentId
    WHERE en.ClassId = @Class23 AND en.Status = N'Completed'
      AND ((en.Result = N'Passed' AND (ce.CertificateId IS NULL OR ce.Classification <> dbo.fn_Classification(en.FinalGrade)))
        OR (en.Result = N'Failed' AND ce.CertificateId IS NOT NULL));
    ROLLBACK;

    INSERT #Results VALUES ('T23', N'usp_Class_EvaluateResults: pass on grade and attendance, certificates', N'Succeeded',
        CASE WHEN @Count23 > 0 AND @Wrong23 = 0 AND @WrongCert23 = 0 AND @Passed23 + @Failed23 = @Count23
             THEN N'Succeeded' ELSE N'Wrong result' END,
        @Class23 + N': ' + CAST(@Passed23 AS NVARCHAR(10)) + N' passed, ' + CAST(@Failed23 AS NVARCHAR(10))
        + N' failed (' + CAST(@LowAttendance23 AS NVARCHAR(10)) + N' with a passing grade but attendance < 80%); '
        + CAST(@WrongCert23 AS NVARCHAR(10)) + N' certificate mismatch(es)');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T23', N'usp_Class_EvaluateResults: pass on grade and attendance, certificates', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T24: usp_Payroll_Finalize (cursor): last month's pay matches the taught sessions; 500,000 bonus at >= 20 sessions
BEGIN TRY
    DECLARE @Date24 DATE = DATEADD(MONTH, -1, GETDATE());
    DECLARE @Month24 TINYINT = MONTH(@Date24), @Year24 SMALLINT = YEAR(@Date24), @Teachers24 INT, @Wrong24 INT;

    IF OBJECT_ID('tempdb..#R24') IS NOT NULL DROP TABLE #R24;
    CREATE TABLE #R24 (TeacherId VARCHAR(10), TeacherName NVARCHAR(100), SessionCount INT, Hours DECIMAL(6,2),
                       HourlyRate DECIMAL(12,0), Bonus DECIMAL(12,0), Deduction DECIMAL(12,0), TotalPay DECIMAL(14,0),
                       Status NVARCHAR(20));
    BEGIN TRAN;
    DELETE FROM dbo.PAYROLL WHERE Month = @Month24 AND Year = @Year24;
    INSERT #R24 EXEC dbo.usp_Payroll_Finalize @Month = @Month24, @Year = @Year24;
    SELECT @Teachers24 = COUNT(*) FROM #R24;
    SELECT @Wrong24 = COUNT(*)
    FROM (SELECT se.TeacherId, COUNT(*) AS SessionCount,
                 CAST(SUM(DATEDIFF(MINUTE, se.StartTime, se.EndTime)) / 60.0 AS DECIMAL(6,2)) AS Hours
          FROM dbo.CLASS_SESSION se
          WHERE se.Status = N'Taught' AND MONTH(se.SessionDate) = @Month24 AND YEAR(se.SessionDate) = @Year24
          GROUP BY se.TeacherId) t
    JOIN dbo.TEACHER te ON te.TeacherId = t.TeacherId
    FULL OUTER JOIN (SELECT * FROM dbo.PAYROLL WHERE Month = @Month24 AND Year = @Year24) py ON py.TeacherId = t.TeacherId
    WHERE py.PayrollId IS NULL OR t.TeacherId IS NULL OR py.SessionCount <> t.SessionCount OR py.Hours <> t.Hours
       OR py.Bonus <> CASE WHEN t.SessionCount >= 20 THEN 500000 ELSE 0 END
       OR py.TotalPay <> CAST(t.Hours * te.HourlyRate AS DECIMAL(14,0)) + py.Bonus - py.Deduction;
    ROLLBACK;

    INSERT #Results VALUES ('T24', N'usp_Payroll_Finalize: sessions, hours, bonus, total pay', N'Succeeded',
        CASE WHEN @Teachers24 > 0 AND @Wrong24 = 0 THEN N'Succeeded' ELSE N'Wrong result' END,
        N'Month ' + CAST(@Month24 AS NVARCHAR(2)) + N'/' + CAST(@Year24 AS NVARCHAR(4)) + N': '
        + CAST(@Teachers24 AS NVARCHAR(10)) + N' teachers, ' + CAST(@Wrong24 AS NVARCHAR(10))
        + N' row(s) differing from CLASS_SESSION');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T24', N'usp_Payroll_Finalize: sessions, hours, bonus, total pay', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T25: finalizing the payroll of a future month
BEGIN TRY
    DECLARE @Date25 DATE = DATEADD(MONTH, 1, GETDATE());
    DECLARE @Month25 TINYINT = MONTH(@Date25), @Year25 SMALLINT = YEAR(@Date25);
    EXEC dbo.usp_Payroll_Finalize @Month = @Month25, @Year = @Year25;
    INSERT #Results VALUES ('T25', N'Finalizing the payroll of a future month', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T25', N'Finalizing the payroll of a future month', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T26: XML: export the students (FOR XML PATH) and import them back (nodes/value); a duplicate phone is skipped
BEGIN TRY
    DECLARE @Xml26 XML, @Nodes26 INT, @Students26 INT, @Imported26 INT, @Skipped26 INT, @NewFound26 INT,
            @ExistingPhone26 VARCHAR(15);
    IF OBJECT_ID('tempdb..#X26') IS NOT NULL DROP TABLE #X26;
    IF OBJECT_ID('tempdb..#I26') IS NOT NULL DROP TABLE #I26;
    CREATE TABLE #X26 (XmlData XML);
    CREATE TABLE #I26 (ImportedRows INT, SkippedRows INT);

    INSERT #X26 EXEC dbo.usp_Student_ExportXml;
    SELECT @Xml26 = XmlData FROM #X26;
    SET @Nodes26 = @Xml26.value('count(/Students/Student)', 'INT');
    SELECT @Students26 = COUNT(*) FROM dbo.STUDENT;
    SELECT TOP (1) @ExistingPhone26 = Phone FROM dbo.STUDENT WHERE Phone IS NOT NULL ORDER BY StudentId;

    SET @Xml26 = N'<Students>'
        + N'<Student><FullName>XML Import New</FullName><DateOfBirth>2000-01-01</DateOfBirth><Gender>Male</Gender>'
        + N'<Phone>0988777666</Phone></Student>'
        + N'<Student><FullName>XML Import Duplicate</FullName><DateOfBirth>2000-01-01</DateOfBirth><Gender>Female</Gender>'
        + N'<Phone>' + @ExistingPhone26 + N'</Phone></Student></Students>';
    BEGIN TRAN;
    INSERT #I26 EXEC dbo.usp_Student_ImportXml @Data = @Xml26, @BranchId = 'BR01';
    SELECT @Imported26 = ImportedRows, @Skipped26 = SkippedRows FROM #I26;
    SELECT @NewFound26 = COUNT(*) FROM dbo.STUDENT WHERE Phone = '0988777666' AND FullName = N'XML Import New';
    ROLLBACK;

    INSERT #Results VALUES ('T26', N'Student XML export/import, duplicates skipped', N'Succeeded',
        CASE WHEN @Nodes26 = @Students26 AND @Imported26 = 1 AND @Skipped26 = 1 AND @NewFound26 = 1
             THEN N'Succeeded' ELSE N'Wrong result' END,
        N'Exported ' + CAST(@Nodes26 AS NVARCHAR(10)) + N'/' + CAST(@Students26 AS NVARCHAR(10)) + N' students; imported '
        + CAST(@Imported26 AS NVARCHAR(10)) + N' row(s), skipped ' + CAST(@Skipped26 AS NVARCHAR(10))
        + N' duplicate phone row(s)');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T26', N'Student XML export/import, duplicates skipped', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T27: a course syllabus that does not follow the XML schema (typed XML xsc_CourseSyllabus)
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.COURSE SET SyllabusXml = N'<Syllabus><ElementNotInSchema/></Syllabus>'
    WHERE CourseId = (SELECT MIN(CourseId) FROM dbo.COURSE);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T27', N'Course syllabus that violates the XML schema', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T27', N'Course syllabus that violates the XML schema', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- B. PERMISSIONS (EXECUTE AS USER) ---------------- */

-- P01: a teacher reads the STUDENT table
BEGIN TRY
    EXECUTE AS USER = N'gv_john';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.STUDENT);
    REVERT;
    INSERT #Results VALUES ('P01', N'Teacher SELECTs the STUDENT table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P01', N'Teacher SELECTs the STUDENT table', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P02: a teacher reads the views of their own classes (ownership chaining + USER_NAME() filter)
BEGIN TRY
    EXECUTE AS USER = N'gv_john';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.vw_Teacher_MyClasses);
    DECLARE @st INT = (SELECT COUNT(*) FROM dbo.vw_Teacher_MyStudents);
    REVERT;
    INSERT #Results VALUES ('P02', N'Teacher SELECTs the views of their classes/students', N'Succeeded', N'Succeeded',
                            CAST(@n AS NVARCHAR(10)) + N' classes, ' + CAST(@st AS NVARCHAR(10))
                            + N' students (only the classes of TE0001)');
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P02', N'Teacher SELECTs the views of their classes/students', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P03: a teacher enters a grade in a class they do not teach
BEGIN TRY
    DECLARE @EnrollmentId VARCHAR(10) = (SELECT TOP 1 EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0004');
    DECLARE @ComponentId INT = (SELECT TOP 1 ComponentId FROM dbo.GRADE_COMPONENT WHERE CourseId = 'TO-450');
    EXECUTE AS USER = N'gv_john';
    EXEC dbo.usp_Grade_Save @EnrollmentId = @EnrollmentId, @ComponentId = @ComponentId, @Score = 9;
    REVERT;
    INSERT #Results VALUES ('P03', N'Teacher grades a class of another teacher', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P03', N'Teacher grades a class of another teacher', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P04: an accountant enrolls a student (DENY EXECUTE)
BEGIN TRY
    DECLARE @EnrollmentId VARCHAR(10);
    EXECUTE AS USER = N'kt_minh';
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00071', @ClassId = 'CL0010', @EnrollmentId = @EnrollmentId OUTPUT;
    REVERT;
    INSERT #Results VALUES ('P04', N'Accountant enrolls a student', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P04', N'Accountant enrolls a student', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P05: an accountant reads the teachers' hourly rate (column-level GRANT)
BEGIN TRY
    EXECUTE AS USER = N'kt_minh';
    DECLARE @Rate DECIMAL(12,0) = (SELECT TOP 1 HourlyRate FROM dbo.TEACHER ORDER BY TeacherId);
    REVERT;
    INSERT #Results VALUES ('P05', N'Accountant SELECTs the TEACHER.HourlyRate column', N'Succeeded', N'Succeeded',
                            N'Read hourly rate ' + FORMAT(@Rate, 'N0'));
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P05', N'Accountant SELECTs the TEACHER.HourlyRate column', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P06: academic staff read the teachers' hourly rate (that column is not GRANTed)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    DECLARE @Rate DECIMAL(12,0) = (SELECT TOP 1 HourlyRate FROM dbo.TEACHER ORDER BY TeacherId);
    REVERT;
    INSERT #Results VALUES ('P06', N'Academic staff SELECT the TEACHER.HourlyRate column', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P06', N'Academic staff SELECT the TEACHER.HourlyRate column', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P07: academic staff read the payroll (DENY SELECT)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.PAYROLL);
    REVERT;
    INSERT #Results VALUES ('P07', N'Academic staff SELECT the PAYROLL table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P07', N'Academic staff SELECT the PAYROLL table', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P08: the manager deletes a receipt (DENY DELETE - even for the manager)
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'ql_quan';
    DELETE FROM dbo.RECEIPT WHERE ReceiptId = 'RC000001';
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P08', N'Manager DELETEs from the RECEIPT table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P08', N'Manager DELETEs from the RECEIPT table', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P09: academic staff create an account (no GRANT EXECUTE)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Account_Create N'test_user', N'Test@12345', 'ACADEMIC_STAFF', 'EM0006', NULL;
    REVERT;
    INSERT #Results VALUES ('P09', N'Academic staff create a sign-in account', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P09', N'Academic staff create a sign-in account', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P10: the manager creates a new account (EXECUTE AS OWNER), then rolls it back
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'ql_quan';
    EXEC dbo.usp_Account_Create N'tuvan_mai', N'TuVan@2026', 'ACADEMIC_STAFF', 'EM0006', NULL;
    REVERT;
    DECLARE @UserExists INT = CASE WHEN DATABASE_PRINCIPAL_ID(N'tuvan_mai') IS NOT NULL THEN 1 ELSE 0 END;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P10', N'Manager creates an account (user + role)', N'Succeeded',
                            CASE WHEN @UserExists = 1 THEN N'Succeeded' ELSE N'Rejected' END,
                            N'Created the contained user tuvan_mai in rl_AcademicStaff (rolled back)');
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P10', N'Manager creates an account (user + role)', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P11: academic staff may open the Dashboard but not see the revenue (the procedure returns NULL)
BEGIN TRY
    IF OBJECT_ID('tempdb..#Dashboard') IS NOT NULL DROP TABLE #Dashboard;
    CREATE TABLE #Dashboard (ActiveStudents INT, ActiveClasses INT, EnrollingClasses INT, RevenueThisMonth BIGINT,
                             TotalOutstanding BIGINT, SessionsToday INT);
    EXECUTE AS USER = N'gvu_lan';
    INSERT #Dashboard EXEC dbo.usp_Dashboard_Stats;
    REVERT;
    INSERT #Results SELECT 'P11', N'Academic staff see the monthly revenue on the Dashboard', N'Rejected',
                           CASE WHEN RevenueThisMonth IS NULL THEN N'Rejected' ELSE N'Succeeded' END,
                           N'usp_Dashboard_Stats returns RevenueThisMonth = NULL for the ACADEMIC_STAFF role'
                    FROM #Dashboard;
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P11', N'Academic staff see the monthly revenue on the Dashboard', N'Rejected', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- P12: changing one's own password with a wrong current password (ALTER USER ... OLD_PASSWORD)
BEGIN TRY
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Account_ChangePassword N'wrong-password', N'NewPassword@1';
    REVERT;
    INSERT #Results VALUES ('P12', N'Password change with a wrong current password', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT #Results VALUES ('P12', N'Password change with a wrong current password', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- SUMMARY ---------------- */
IF OBJECT_ID('tempdb..#Summary') IS NOT NULL DROP TABLE #Summary;
SELECT COALESCE(r.TestId, e.TestId) AS TestId,
       ISNULL(r.Description, N'(test case did not run)') AS Description, r.Expected, r.Actual,
       CASE WHEN r.TestId IS NOT NULL AND e.TestId IS NOT NULL AND r.Expected = r.Actual
                 AND (e.MessagePattern IS NULL OR r.Message LIKE e.MessagePattern)
            THEN N'PASSED' ELSE N'FAILED' END AS Verdict,
       r.Message
INTO #Summary
FROM #Results r
FULL OUTER JOIN #Expected e ON e.TestId = r.TestId;

SELECT TestId, Description, Expected, Actual, Verdict, Message FROM #Summary ORDER BY TestId;
SELECT COUNT(*) AS TotalCases, SUM(CASE WHEN Verdict = N'PASSED' THEN 1 ELSE 0 END) AS PassedCases FROM #Summary;

IF EXISTS (SELECT 1 FROM #Summary WHERE Verdict <> N'PASSED')
    THROW 50099, N'Some database test cases FAILED (see the summary table above).', 1;
GO
