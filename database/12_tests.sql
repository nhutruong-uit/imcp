/* =====================================================================
   File   : 12_tests.sql - Tests of the constraints, business rules and permissions
   - Every test case leaves the data unchanged: a case that writes runs in a transaction that is
     ROLLED BACK. A few cases that expect a rejection BEFORE anything is written (e.g. T03-T05)
     call the procedure without a transaction of their own.
   - Permissions are tested with EXECUTE AS USER (impersonating a user) ... REVERT.
   - Run as sa / db_owner after 07_seed_data.sql. The summary table is at the end of the output.
   - A "Rejected" case only PASSES when it is rejected for the RIGHT REASON (the message matches the
     pattern in #Expected), so a procedure broken by another error cannot "pass". A case listed in
     #Expected that did not run also FAILS.
   - If any case FAILS the script ends with THROW 50099 (sqlcmd -b returns exit code 1), which
     scripts/test_all.sh uses to block changes that break the business rules.

   How this test script works (read this before the cases):
   1. #Results gets one row per case: TestId, Description, Expected (what must happen: Rejected or
      Succeeded), Actual (what really happened) and Message (the error text, or for a success case
      a short summary of the computed result).
   2. #Expected is the specification: every case code that must run and, for a "Rejected" case, the
      LIKE pattern its error message must match. Business errors are matched on their English text
      (e.g. %is full%), system errors on the object/constraint name (e.g. %CK_STUDENT_Guardian%).
      NULL = no message check (success cases).
   3. Every case is its own batch ending with GO (so the DECLAREd variables of one case do not clash
      with the next one) and has the same shape:
        BEGIN TRY    the statement under test  -> it reached the end   => Actual = Succeeded
        BEGIN CATCH  an error was raised       -> Actual = Rejected, Message = ERROR_MESSAGE()
      "IF @@TRANCOUNT > 0 ROLLBACK" in both branches undoes whatever the case wrote. When a tested
      procedure has its own BEGIN TRANSACTION ... COMMIT, that COMMIT inside the test transaction
      only lowers @@TRANCOUNT (nested transaction); the outer ROLLBACK still undoes everything.
   4. A success case does not stop at "it ran": it compares the result with a value computed
      independently in the test or with a prepared scenario (section C), and sets Actual to
      "Wrong result" (or "Error") when they differ.
   5. SUMMARY: #Results FULL OUTER JOIN #Expected on TestId. Verdict = PASSED only when Actual equals
      Expected and the message matches the pattern; a case missing on either side is FAILED.
      THROW 50099 then makes the whole script fail when any Verdict is FAILED.
   Sections: A. constraints and business rules, C. functions/triggers/cursors/XML results,
   D. schema conventions (catalog views), B. permissions (EXECUTE AS USER), then the summary.
   How to run it:
   - SSMS: open this file, connect as sa (or a db_owner of QLTTTA) and press Execute (F5). Read the
     last two result grids (Verdict per case, then TotalCases / PassedCases). The run passed when it
     ends without error 50099.
   - Command line: scripts/test_all.sh (Windows: scripts\test_all.ps1) re-creates the database, runs
     this file with sqlcmd -b, counts the PASSED rows and stops the suite on error 50099. The exact
     command is in docs/SETUP.md ("Running the full test suite").
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
    Actual       NVARCHAR(20)   NULL,       -- also 'Wrong result' / 'Error' (always FAILED)
    Message      NVARCHAR(400)  NULL
);

-- Specification: the cases that must run and the message pattern (LIKE) a "Rejected" case must return.
-- System errors are matched on the object/constraint name only (independent of the SQL Server message language).
-- Keep the two-value form (code, pattern-or-NULL): tst_conventions counts these pairs for the numbers in the docs.
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
    ('T28', NULL), ('T29', NULL), ('T30', NULL), ('T31', NULL), ('T32', NULL),
    ('P01', N'%STUDENT%'),                      ('P02', NULL),
    ('P03', N'%only enter grades%'),            ('P04', N'%usp_Enrollment_Create%'),
    ('P05', NULL),                              ('P06', N'%HourlyRate%'),
    ('P07', N'%PAYROLL%'),                      ('P08', N'%RECEIPT%'),
    ('P09', N'%usp_Account_Create%'),           ('P10', NULL), ('P11', NULL),
    ('P12', N'%current password is incorrect%');
GO

/* ---------------- A. INTEGRITY CONSTRAINTS & BUSINESS RULES ---------------- */

-- T01: a 12-year-old student without guardian details
--      Proves CK_STUDENT_Guardian: a student under 18 needs a guardian name and phone. Concept: CHECK constraint
--      across several columns - it applies even though usp_Student_Add has no check of its own for it.
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
--      Proves CK_STUDENT_Phone (9-11 digits only) on a direct INSERT that bypasses every procedure.
--      Concept: domain constraint (CHECK with LIKE and a [^0-9] character class).
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
--      Proves usp_Enrollment_Create refuses a second enrollment of the same student in the same class (THROW 50022;
--      the UNIQUE constraint UQ_ENROLLMENT_StudentId_ClassId backs it up). Concept: business check in a procedure
--      before any write, so no transaction is needed here.
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
--      Proves the entry requirement of usp_Enrollment_Create: passed the prerequisite course OR a high enough
--      latest placement score (THROW 50023, message built from values). Concept: rule over several tables with
--      NOT EXISTS subqueries.
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
--      Proves usp_Enrollment_Create refuses a class whose weekly slots overlap a class the student is taking
--      (THROW 50024). Concept: interval overlap test (start1 < end2 AND start2 < end1) on the same weekday.
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
--      Proves trg_RECEIPT_UpdateAmountPaid: the valid receipts of an enrollment never add up to more than its
--      tuition due. Concept: AFTER INSERT trigger that keeps a derived attribute and rolls the statement back.
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
--      Proves trg_RECEIPT_PreventDelete: receipts are cancelled, never deleted. Concept: INSTEAD OF trigger - the
--      DELETE is replaced by the trigger body, which only raises an error. @Remaining double-checks that the row
--      is still there; without the error message the case still FAILS (the pattern needs the message).
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
--      Proves trg_CLASS_SCHEDULE_CheckConflict: two active classes with overlapping periods cannot use the same
--      room (or teacher) at overlapping hours of the same weekday. The two classes have different teachers, so
--      only the room clashes. Concept: AFTER trigger for a rule across rows and tables.
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
--      Proves trg_CLASS_CheckRoom: the room of a class belongs to the branch of the class (TD-301 is a BR02 room).
--      Concept: trigger for a rule a CHECK constraint cannot express (it needs another table).
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
--      Proves CK_GRADE_Score (0 to 10) also when the score is saved through usp_Grade_Save.
--      Concept: CHECK constraint on the domain of an attribute.
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
--      Proves trg_AUDIT_LOG_ReadOnly: the audit log is append-only. Concept: INSTEAD OF UPDATE trigger;
--      @Changed checks that the value really did not change.
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
--      Proves trg_CERTIFICATE_CheckResult: a certificate needs ENROLLMENT.Result = Passed.
--      Concept: AFTER INSERT trigger that checks a row of another table.
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
--      Proves trg_CLASS_SESSION_LockTaught: date, time, room and teacher of a taught session are frozen (payroll
--      and attendance rely on them). Concept: AFTER UPDATE trigger comparing inserted (new) with deleted (old).
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
--      Proves usp_Enrollment_TransferClass only moves a student to an open class of the SAME course
--      (THROW 50027; CL0004 is TOEIC, CL0010 is Communication). Concept: business rule checked in a procedure.
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
--      Success case: usp_Enrollment_Create with a promotion code runs to the end; Message shows the new ID from
--      the OUTPUT parameter and the tuition due. Concept: procedure with a multi-step transaction, OUTPUT parameter.
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
--      Proves fn_Classification at every boundary (each threshold and the value just below it) and NULL in =>
--      NULL out. Concept: scalar function; boundary-value testing with a VALUES table constructor.
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
--      Proves fn_FinalGrade against the same formula computed here with GROUP BY for every graded enrollment;
--      then one score is deleted (rolled back) and the function must return NULL. Concept: scalar function.
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
--      Proves fn_AttendanceRate with a prepared scenario: 2 Present + 1 Late out of N taught sessions => 3/N.
--      Concept: ROW_NUMBER() OVER (ORDER BY ...) numbers the sessions so the scenario can be built in one INSERT.
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
--      Proves fn_DiscountAmount with two temporary promotions (rolled back). Concept: scalar function with CASE.
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
--      Proves trg_RECEIPT_UpdateAmountPaid (payment added, then removed again by usp_Receipt_Cancel) and
--      trg_RECEIPT_Audit (the receipt stored as XML, found with the XQuery method .exist()).
--      Concepts: derived attribute kept by a trigger, XML audit trail built with FOR XML PATH.
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
--      Proves trg_ENROLLMENT_CheckCapacity: Studying + Completed enrollments never exceed MaxStudents. The class is
--      first made exactly full (MaxStudents = current count). Concept: AFTER INSERT trigger as the last guard.
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
--      Proves every property of the generated sessions: count, weekday/time of the schedule, SessionNo 1..n in
--      date order, start/end date. Concepts: WHILE loop in a procedure; INSERT ... EXEC stores the result set of
--      a procedure in a table; ROW_NUMBER() gives the expected numbering.
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
--      Proves the result of every student against the rule recomputed here from fn_FinalGrade/fn_AttendanceRate,
--      and that a certificate exists exactly for those who passed (with the right classification).
--      Concept: cursor (LOCAL FAST_FORWARD, FETCH NEXT, @@FETCH_STATUS) inside a transaction.
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
--      Proves sessions, hours, bonus and total pay against values aggregated here from CLASS_SESSION.
--      Concepts: cursor over the teachers; FULL OUTER JOIN also finds a missing or an extra payroll row.
BEGIN TRY
    DECLARE @Date24 DATE = DATEADD(MONTH, -1, dbo.fn_Today());
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
--      Proves usp_Payroll_Finalize checks its input first (THROW 50050) - before it starts its transaction.
BEGIN TRY
    DECLARE @Date25 DATE = DATEADD(MONTH, 1, dbo.fn_Today());
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
--      Proves usp_Student_ExportXml (one Student element per row, counted with XQuery count()) and
--      usp_Student_ImportXml (.nodes() turns each Student element into a row, .value() reads one field;
--      a row whose phone already exists is skipped). Concepts: FOR XML PATH, nodes(), value(), XQuery.
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
--      Proves COURSE.SyllabusXml is typed XML: SQL Server itself validates it against the XML SCHEMA COLLECTION
--      xsc_CourseSyllabus and refuses an element the schema does not define.
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

-- T31: instants in UTC, days of the center: a receipt paid at 17:30 UTC on 31 January (00:30 on 1 February in the
--      center, UTC+07:00) is stored unchanged and counts in February in fn_MonthlyRevenue, vw_MonthlyRevenue and
--      usp_Report_Revenue (two years back: the seed data has no receipts then)
BEGIN TRY
    DECLARE @Year31 INT = YEAR(dbo.fn_Today()) - 2;
    DECLARE @Jan31 DATE = DATEFROMPARTS(@Year31, 1, 31), @Feb31 DATE = DATEFROMPARTS(@Year31, 2, 1);
    DECLARE @PaidUtc31 DATETIME = DATEADD(MINUTE, 17 * 60 + 30, CAST(@Jan31 AS DATETIME)),
            @Enrollment31 VARCHAR(10), @Receipt31 VARCHAR(10), @Stored31 DATETIME, @FnJan31 INT, @FnFeb31 INT,
            @ViewFeb31 INT, @ReportJan31 INT, @ReportFeb31 DECIMAL(14,0);
    IF OBJECT_ID('tempdb..#R31') IS NOT NULL DROP TABLE #R31;
    CREATE TABLE #R31 (BranchName NVARCHAR(100), ProgramName NVARCHAR(100), CourseName NVARCHAR(150),
                       ReceiptCount INT, Revenue DECIMAL(14,0));
    SELECT TOP (1) @Enrollment31 = EnrollmentId FROM dbo.ENROLLMENT
    WHERE Status <> N'Left' AND TuitionDue - AmountPaid >= 100000 ORDER BY EnrollmentId;

    BEGIN TRAN;
    EXEC dbo.usp_Receipt_Create @EnrollmentId = @Enrollment31, @Amount = 100000, @EmployeeId = 'EM0003',
         @PaidAtUtc = @PaidUtc31, @ReceiptId = @Receipt31 OUTPUT;
    SELECT @Stored31 = PaidAtUtc FROM dbo.RECEIPT WHERE ReceiptId = @Receipt31;
    SELECT @FnJan31 = SUM(CASE WHEN Month = 1 THEN ReceiptCount END),
           @FnFeb31 = SUM(CASE WHEN Month = 2 THEN ReceiptCount END)
    FROM dbo.fn_MonthlyRevenue(@Year31, NULL);
    SELECT @ViewFeb31 = ISNULL(SUM(ReceiptCount), 0) FROM dbo.vw_MonthlyRevenue WHERE Year = @Year31 AND Month = 2;
    INSERT #R31 EXEC dbo.usp_Report_Revenue @FromDate = @Jan31, @ToDate = @Jan31;
    SELECT @ReportJan31 = COUNT(*) FROM #R31;
    DELETE FROM #R31;
    INSERT #R31 EXEC dbo.usp_Report_Revenue @FromDate = @Feb31, @ToDate = @Feb31;
    SELECT @ReportFeb31 = ISNULL(SUM(Revenue), 0) FROM #R31;
    ROLLBACK;

    INSERT #Results VALUES ('T31', N'Receipt at 00:30 center time counts in the center''s day and month', N'Succeeded',
        CASE WHEN @Stored31 = @PaidUtc31 AND @FnJan31 = 0 AND @FnFeb31 = 1 AND @ViewFeb31 = 1
                  AND @ReportJan31 = 0 AND @ReportFeb31 = 100000
             THEN N'Succeeded' ELSE N'Wrong result' END,
        CONCAT(N'paid ', CONVERT(NVARCHAR(16), @PaidUtc31, 120), N' UTC: fn_MonthlyRevenue Jan/Feb = ', @FnJan31, N'/',
               @FnFeb31, N', vw_MonthlyRevenue Feb = ', @ViewFeb31, N', usp_Report_Revenue rows on 31 Jan = ',
               @ReportJan31, N', revenue on 1 Feb = ', @ReportFeb31));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T31', N'Receipt at 00:30 center time counts in the center''s day and month', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- D. SCHEMA CONVENTIONS (catalog views, nothing to roll back) ---------------- */

-- T28: naming conventions of 01-sql.md: tables UPPER_SNAKE_CASE, columns PascalCase, prefixes usp_/fn_/vw_/seq_,
--      trg_<TABLE>_, PK_<TABLE>, FK_<CHILD>_<PARENT>, CK_/UQ_/DF_<TABLE>_, IX_/UX_<TABLE>_ (case-sensitive)
--      Concepts: catalog views (sys.tables, sys.columns, sys.objects, sys.foreign_keys, sys.indexes);
--      COLLATE Latin1_General_BIN makes LIKE case-sensitive; FOR XML PATH + STUFF joins the bad names into one
--      message (the 2012-compatible way to concatenate rows). A non-empty list = Actual Rejected = FAILED.
BEGIN TRY
    DECLARE @Bad TABLE (Name NVARCHAR(300));
    INSERT @Bad
    SELECT N'table ' + name FROM sys.tables WHERE is_ms_shipped = 0 AND name COLLATE Latin1_General_BIN LIKE N'%[^A-Z0-9_]%'
    UNION ALL
    SELECT N'column ' + t.name + N'.' + c.name
    FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.is_ms_shipped = 0
      AND (c.name COLLATE Latin1_General_BIN NOT LIKE N'[A-Z]%' OR c.name COLLATE Latin1_General_BIN LIKE N'%[^A-Za-z0-9]%')
    UNION ALL
    SELECT o.type_desc + N' ' + o.name
    FROM sys.objects o
    WHERE o.is_ms_shipped = 0 AND o.type IN ('P', 'FN', 'IF', 'TF', 'V', 'SO')
      AND o.name COLLATE Latin1_General_BIN NOT LIKE CASE o.type WHEN 'P' THEN N'usp[_]%' WHEN 'V' THEN N'vw[_]%'
                                                                 WHEN 'SO' THEN N'seq[_]%' ELSE N'fn[_]%' END
    UNION ALL
    -- constraints and triggers of the tables (the system-named key of a function's return table is not one)
    SELECT o.type_desc + N' ' + o.name
    FROM sys.objects o JOIN sys.tables t ON t.object_id = o.parent_object_id
    WHERE o.type IN ('PK', 'C', 'UQ', 'D', 'TR')
      AND o.name COLLATE Latin1_General_BIN NOT LIKE
          CASE o.type WHEN 'PK' THEN N'PK[_]' WHEN 'C' THEN N'CK[_]' WHEN 'UQ' THEN N'UQ[_]' WHEN 'D' THEN N'DF[_]'
                      ELSE N'trg[_]' END + t.name + CASE o.type WHEN 'PK' THEN N'' ELSE N'[_]%' END
    UNION ALL
    SELECT N'foreign key ' + fk.name
    FROM sys.foreign_keys fk
    WHERE fk.name COLLATE Latin1_General_BIN NOT LIKE
          N'FK[_]' + OBJECT_NAME(fk.parent_object_id) + N'[_]' + OBJECT_NAME(fk.referenced_object_id) + N'%'
    UNION ALL
    SELECT N'index ' + i.name
    FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
    WHERE t.is_ms_shipped = 0 AND i.name IS NOT NULL AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
      AND i.name COLLATE Latin1_General_BIN NOT LIKE CASE WHEN i.is_unique = 1 THEN N'UX[_]' ELSE N'IX[_]' END + t.name + N'[_]%';
    DECLARE @BadCount INT = (SELECT COUNT(*) FROM @Bad);
    INSERT #Results VALUES ('T28', N'Naming conventions of tables, columns, objects, constraints and indexes', N'Succeeded',
                            CASE WHEN @BadCount = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CASE WHEN @BadCount = 0 THEN N'Every name follows the conventions'
                                 ELSE LEFT(CONCAT(@BadCount, N' names break the conventions: ',
                                                  STUFF((SELECT N', ' + Name FROM @Bad FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')), 400) END);
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T28', N'Naming conventions of tables, columns, objects, constraints and indexes', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T29: least privilege - the table permissions of the business roles are EXACTLY those of 06_security.sql
--      (column grants count as the table; DENY only narrows rights). A new GRANT must be added here on purpose.
--      @Spec = the expected matrix, @Actual = what sys.database_permissions (state G = GRANT, W = WITH GRANT OPTION)
--      and sys.database_role_members really hold; EXCEPT in both directions lists the extra and missing rights.
--      Only table rights, schema rights and role memberships are compared - EXECUTE/SELECT on procedures, views
--      and functions and the DENYs are not (P01, P04, P07 and P08 test some DENYs by impersonation).
BEGIN TRY
    DECLARE @Spec TABLE (RoleName SYSNAME, Permission NVARCHAR(60), Target SYSNAME);
    INSERT @Spec VALUES
        (N'rl_Manager', N'MEMBER OF', N'db_datareader'), (N'rl_Manager', N'EXECUTE', N'SCHEMA::dbo'),
        (N'rl_Manager', N'SELECT', N'BRANCH'), (N'rl_Manager', N'SELECT', N'PROGRAM'),
        (N'rl_Manager', N'SELECT', N'COURSE'), (N'rl_Manager', N'SELECT', N'ROOM'),
        (N'rl_Manager', N'INSERT', N'BRANCH'), (N'rl_Manager', N'UPDATE', N'BRANCH'),
        (N'rl_Manager', N'INSERT', N'ROOM'), (N'rl_Manager', N'UPDATE', N'ROOM'),
        (N'rl_Manager', N'INSERT', N'PROGRAM'), (N'rl_Manager', N'UPDATE', N'PROGRAM'),
        (N'rl_Manager', N'INSERT', N'COURSE'), (N'rl_Manager', N'UPDATE', N'COURSE'),
        (N'rl_Manager', N'INSERT', N'GRADE_COMPONENT'), (N'rl_Manager', N'UPDATE', N'GRADE_COMPONENT'),
        (N'rl_Manager', N'DELETE', N'GRADE_COMPONENT'),
        (N'rl_Manager', N'INSERT', N'EMPLOYEE'), (N'rl_Manager', N'UPDATE', N'EMPLOYEE'),
        (N'rl_Manager', N'INSERT', N'TEACHER'), (N'rl_Manager', N'UPDATE', N'TEACHER'),
        (N'rl_Manager', N'INSERT', N'PROMOTION'), (N'rl_Manager', N'UPDATE', N'PROMOTION'),
        (N'rl_AcademicStaff', N'SELECT', N'BRANCH'), (N'rl_AcademicStaff', N'SELECT', N'PROGRAM'),
        (N'rl_AcademicStaff', N'SELECT', N'COURSE'), (N'rl_AcademicStaff', N'SELECT', N'ROOM'),
        (N'rl_AcademicStaff', N'SELECT', N'GRADE_COMPONENT'), (N'rl_AcademicStaff', N'SELECT', N'PLACEMENT_TEST'),
        (N'rl_AcademicStaff', N'SELECT', N'PROMOTION'), (N'rl_AcademicStaff', N'SELECT', N'TEACHER'),
        (N'rl_Accountant', N'SELECT', N'BRANCH'), (N'rl_Accountant', N'SELECT', N'PROGRAM'),
        (N'rl_Accountant', N'SELECT', N'COURSE'), (N'rl_Accountant', N'SELECT', N'PAYROLL'),
        (N'rl_Accountant', N'SELECT', N'PROMOTION'), (N'rl_Accountant', N'SELECT', N'RECEIPT'),
        (N'rl_Accountant', N'SELECT', N'TEACHER'),
        (N'rl_Teacher', N'SELECT', N'BRANCH'), (N'rl_Teacher', N'SELECT', N'PROGRAM'),
        (N'rl_Teacher', N'SELECT', N'COURSE'), (N'rl_Teacher', N'SELECT', N'ROOM');
    DECLARE @Actual TABLE (RoleName SYSNAME, Permission NVARCHAR(60), Target SYSNAME);
    INSERT @Actual
    SELECT DISTINCT r.name, p.permission_name,
           CASE p.class WHEN 1 THEN OBJECT_NAME(p.major_id) WHEN 3 THEN N'SCHEMA::' + SCHEMA_NAME(p.major_id) ELSE N'DATABASE' END
    FROM sys.database_permissions p
    JOIN sys.database_principals r ON r.principal_id = p.grantee_principal_id
    LEFT JOIN sys.objects o ON p.class = 1 AND o.object_id = p.major_id
    WHERE r.name LIKE N'rl[_]%' AND p.state IN ('G', 'W') AND (p.class <> 1 OR o.type = 'U')
    UNION
    SELECT m.name, N'MEMBER OF', r.name
    FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE m.name LIKE N'rl[_]%';
    DECLARE @Diff TABLE (Item NVARCHAR(300));
    INSERT @Diff
    SELECT N'extra ' + RoleName + N' ' + Permission + N' ' + Target
    FROM (SELECT RoleName, Permission, Target FROM @Actual EXCEPT SELECT RoleName, Permission, Target FROM @Spec) x
    UNION ALL
    SELECT N'missing ' + RoleName + N' ' + Permission + N' ' + Target
    FROM (SELECT RoleName, Permission, Target FROM @Spec EXCEPT SELECT RoleName, Permission, Target FROM @Actual) y;
    DECLARE @DiffCount INT = (SELECT COUNT(*) FROM @Diff);
    INSERT #Results VALUES ('T29', N'Least privilege: table permissions of the roles = 06_security.sql', N'Succeeded',
                            CASE WHEN @DiffCount = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CASE WHEN @DiffCount = 0 THEN CONCAT((SELECT COUNT(*) FROM @Spec), N' expected permissions, no extra and none missing')
                                 ELSE LEFT(CONCAT(@DiffCount, N' differences: ',
                                                  STUFF((SELECT N', ' + Item FROM @Diff FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')), 400) END);
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T29', N'Least privilege: table permissions of the roles = 06_security.sql', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T30: code conventions of 01-sql.md: every procedure and trigger sets NOCOUNT ON; no SELECT * in procedures,
--      views or functions
--      Concept: sys.sql_modules.definition holds the source text of every procedure, trigger, view and function.
--      SET NOCOUNT ON stops the extra "rows affected" messages; SELECT * would silently change a result when a
--      column is added.
BEGIN TRY
    DECLARE @Bad TABLE (Name NVARCHAR(300));
    INSERT @Bad
    SELECT o.type_desc + N' ' + o.name + N' without SET NOCOUNT ON'
    FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
    WHERE o.type IN ('P', 'TR') AND m.definition NOT LIKE N'%SET NOCOUNT ON%'
    UNION ALL
    SELECT o.type_desc + N' ' + o.name + N' uses SELECT *'
    FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
    WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF') AND m.definition LIKE N'%SELECT *%';
    DECLARE @BadCount INT = (SELECT COUNT(*) FROM @Bad);
    INSERT #Results VALUES ('T30', N'Procedures/triggers set NOCOUNT ON, no SELECT * in modules', N'Succeeded',
                            CASE WHEN @BadCount = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CASE WHEN @BadCount = 0 THEN CONCAT((SELECT COUNT(*) FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
                                                                 WHERE o.type IN ('P', 'TR', 'V', 'FN', 'IF', 'TF')), N' modules checked, all follow the conventions')
                                 ELSE LEFT(STUFF((SELECT N', ' + Name FROM @Bad FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''), 400) END);
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T30', N'Procedures/triggers set NOCOUNT ON, no SELECT * in modules', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T32: time conventions of 01-sql.md: instants are DATETIME columns named ...Utc; no module or default reads the
--      server's local clock (GETDATE, SYSDATETIME, CURRENT_TIMESTAMP); a DATE default that reads the clock converts
--      it to the center's offset (dbo.fn_CenterUtcOffset), never to the UTC day
BEGIN TRY
    DECLARE @Offset VARCHAR(6) = dbo.fn_CenterUtcOffset();
    DECLARE @Bad TABLE (Name NVARCHAR(300));
    INSERT @Bad
    SELECT N'column ' + t.name + N'.' + c.name + N' must be DATETIME named ...Utc'
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE t.is_ms_shipped = 0 AND ty.name IN ('datetime', 'datetime2', 'smalldatetime', 'datetimeoffset')
      AND (ty.name <> 'datetime' OR c.name COLLATE Latin1_General_BIN NOT LIKE N'%Utc')
    UNION ALL
    SELECT o.type_desc + N' ' + o.name + N' reads the server''s local clock'
    FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
    WHERE m.definition LIKE N'%GETDATE[(]%' OR m.definition LIKE N'%SYSDATETIME[(]%'
       OR m.definition LIKE N'%CURRENT[_]TIMESTAMP%'
    UNION ALL
    SELECT N'default ' + dc.name + N' ' + dc.definition
    FROM sys.default_constraints dc
    JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
    JOIN sys.types ty  ON ty.user_type_id = c.user_type_id
    WHERE dc.definition LIKE N'%GETDATE[(]%' OR dc.definition LIKE N'%SYSDATETIME[(]%'
       OR (ty.name = 'date' AND dc.definition LIKE N'%getutcdate()%')
       OR (ty.name = 'date' AND dc.definition LIKE N'%sysdatetimeoffset()%'
           AND dc.definition NOT LIKE N'%switchoffset(sysdatetimeoffset(),''' + @Offset + N''')%');
    DECLARE @BadCount INT = (SELECT COUNT(*) FROM @Bad);
    INSERT #Results VALUES ('T32', N'Instants in UTC (...Utc), no server-local clock, DATE defaults in center time', N'Succeeded',
                            CASE WHEN @BadCount = 0 THEN N'Succeeded' ELSE N'Rejected' END,
                            CASE WHEN @BadCount = 0 THEN CONCAT((SELECT COUNT(*) FROM sys.sql_modules), N' modules and ',
                                                                (SELECT COUNT(*) FROM sys.default_constraints), N' defaults checked; center offset ',
                                                                @Offset)
                                 ELSE LEFT(STUFF((SELECT N', ' + Name FROM @Bad FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''), 400) END);
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T32', N'Instants in UTC (...Utc), no server-local clock, DATE defaults in center time', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

/* ---------------- B. PERMISSIONS (EXECUTE AS USER) ---------------- */
-- Each case impersonates a demo user (EXECUTE AS USER), so the statement runs with the rights of that user only;
-- REVERT returns to sa/dbo. REVERT is in the CATCH block too: an error must not leave the next cases running as
-- that user.

-- P01: a teacher reads the STUDENT table
--      Proves DENY SELECT ON STUDENT TO rl_Teacher. Concepts: EXECUTE AS USER switches the security context to
--      gv_john until REVERT; DENY wins over any GRANT.
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
--      gv_john has SELECT on the views only, not on CLASS/STUDENT: because the views and the tables have the same
--      owner (dbo), SQL Server does not check the tables again (ownership chaining). fn_CurrentTeacherId() maps
--      USER_NAME() to the teacher, so the views return only the rows of TE0001.
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
--      Proves the row-level rule of usp_Grade_Save: role TEACHER may only grade classes they teach (THROW 50041;
--      CL0004 belongs to TE0005). Concept: rule based on the signed-in user (fn_CurrentRole/fn_CurrentTeacherId).
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
--      Proves DENY EXECUTE ON usp_Enrollment_Create TO rl_Accountant; the permission error names the procedure.
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
--      Proves the column list of GRANT SELECT ON TEACHER (...) TO rl_Accountant includes HourlyRate (payroll work).
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
--      Proves the column-level GRANT of rl_AcademicStaff leaves HourlyRate out (the other TEACHER columns are
--      granted), so reading it is refused. Concept: permission on single columns.
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
--      Proves DENY SELECT ON PAYROLL TO rl_AcademicStaff: academic staff never see the pay of the teachers.
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
--      Proves DENY DELETE ON RECEIPT TO rl_Manager: the permission check comes before the INSTEAD OF trigger of
--      T07, so this error is a permission error. Concept: DENY as an explicit block that a later GRANT cannot open.
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
--      Proves usp_Account_Create is not available to rl_AcademicStaff: only rl_Manager has EXECUTE (through
--      GRANT EXECUTE ON SCHEMA::dbo). Concept: no GRANT = no access.
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
--      The manager has no right to create users; usp_Account_Create runs WITH EXECUTE AS OWNER, so CREATE USER and
--      ALTER ROLE run as the owner (dbo). Concepts: EXECUTE AS OWNER, contained database user (user + password
--      stored in the database itself). The ROLLBACK also removes the new user.
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
--      Proves usp_Dashboard_Stats hides the revenue: RevenueThisMonth is NULL unless fn_CurrentRole() is MANAGER
--      or ACCOUNTANT. Concept: hiding a value inside a procedure, based on the role of the signed-in user.
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
--      SQL Server checks the current password itself (error 15151); the CATCH block of usp_Account_ChangePassword
--      turns that into the business message THROW 50066. Concept: TRY/CATCH translating a system error.
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
-- FULL OUTER JOIN: a case that ran but is not registered, or is registered but did not run, has a NULL side and is
-- FAILED. "r.Message LIKE e.MessagePattern" checks the reason of a rejection (NULL pattern = no check).
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

-- Makes the run fail: sqlcmd -b returns exit code 1 (scripts/test_all stops), SSMS shows error 50099
IF EXISTS (SELECT 1 FROM #Summary WHERE Verdict <> N'PASSED')
    THROW 50099, N'Some database test cases FAILED (see the summary table above).', 1;
GO
