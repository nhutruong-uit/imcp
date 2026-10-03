/* =====================================================================
   File   : 12_tests.sql - Tests of the constraints, business rules and permissions
   - Every test case leaves the data unchanged: every case that writes - or would write if the rule
     under test were broken - runs in a transaction that is ROLLED BACK, so a failing case cannot leave
     data behind for the next run. Only the read-only checks (catalog views, functions) need none.
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
    Actual       NVARCHAR(20)   NULL,       -- also 'Wrong result' / 'Wrong error' / 'Error' (always FAILED)
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
    ('T33', N'%prerequisite course first%'),    ('T34', N'%clashes with another class%'),
    ('T35', NULL),                              ('T36', N'%letters without diacritics%'),
    ('T37', N'%does not belong to the class of this session%'),
    ('T38', N'%does not belong to the course of the class%'),
    ('T39', NULL), ('T40', NULL),
    ('T41', N'%enrollment history%'),           ('T42', N'%have paid tuition%'),
    ('T43', N'%grades can no longer be changed%'),
    ('T44', N'%attendance can no longer be changed%'),
    ('T45', N'%lock or unlock%'),               ('T46', NULL),
    ('T47', N'%paid more than the tuition of the new class%'),
    ('T48', NULL), ('T49', NULL),
    ('T50', N'%on or after its date%'),         ('T51', N'%cannot change its status%'),
    ('T52', N'%clashes with another class%'),   ('T53', N'%not completed can be set%'),
    ('T54', N'%can only move from Enrolling%'), ('T55', NULL),
    ('T56', N'%finished or cancelled class cannot be changed%'),
    ('T57', N'%still has scheduled sessions%'), ('T58', NULL), ('T59', NULL),
    ('T60', N'%CK_TEACHER_Age%'),               ('T61', N'%used by an active class%'),
    ('T62', N'%who has left%'),                 ('T63', NULL), ('T64', NULL), ('T65', NULL),
    ('T66', NULL), ('T67', NULL),
    ('T68', N'%evaluated classes cannot be changed%'), ('T69', NULL),
    ('T70', N'%same course and branch%'),       ('T71', NULL),
    ('P01', N'%STUDENT%'),                      ('P02', NULL),
    ('P03', N'%only enter grades%'),            ('P04', N'%usp_Enrollment_Create%'),
    ('P05', NULL),                              ('P06', N'%HourlyRate%'),
    ('P07', N'%PAYROLL%'),                      ('P08', N'%RECEIPT%'),
    ('P09', N'%usp_Account_Create%'),           ('P10', NULL), ('P11', NULL),
    ('P12', N'%current password is incorrect%'), ('P13', N'%current password is incorrect%'),
    ('P14', N'%AUDIT_LOG%'),                    ('P15', N'%AUDIT_LOG%'),
    ('P16', N'%usp_Receipt_Create%'),           ('P17', N'%usp_Grade_Save%'),
    ('P18', N'%RECEIPT%'),                      ('P19', N'%PAYROLL%'),
    ('P20', N'%only update sessions you teach%'),
    ('P21', N'%only take attendance for sessions you teach%');
GO

/* ---------------- A. INTEGRITY CONSTRAINTS & BUSINESS RULES ---------------- */

-- T01: a 12-year-old student without guardian details
--      Proves CK_STUDENT_Guardian: a student under 18 needs a guardian name and phone. Concept: CHECK constraint
--      across several columns - it applies even though usp_Student_Add has no check of its own for it.
BEGIN TRY
    -- 12 years before today (a fixed date would stop being "under 18" a few years later)
    DECLARE @Dob DATE = DATEADD(YEAR, -12, dbo.fn_Today());
    BEGIN TRAN;
    DECLARE @Id VARCHAR(10);
    EXEC dbo.usp_Student_Add @FullName = N'Nguyễn Nhỏ', @DateOfBirth = @Dob, @Gender = N'Male',
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
--      before any write. The transaction only matters if the rule breaks: the extra enrollment is then undone.
BEGIN TRY
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00001', @ClassId = 'CL0003', @EmployeeId = 'EM0002',
         @EnrollmentId = @EnrollmentId OUTPUT;
    ROLLBACK;
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
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00070', @ClassId = 'CL0008', @EmployeeId = 'EM0002',
         @EnrollmentId = @EnrollmentId OUTPUT;
    ROLLBACK;
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
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00023', @ClassId = 'CL0007', @EmployeeId = 'EM0004',
         @EnrollmentId = @EnrollmentId OUTPUT;
    ROLLBACK;
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
--      Success case: usp_Enrollment_Create with a promotion code runs to the end. The stored BaseTuition,
--      DiscountAmount and TuitionDue are compared with the class tuition and the discount computed here from the
--      PROMOTION row (AMOUNT = the value, PERCENT = rounded to thousands, never above the tuition); Message shows
--      the new ID from the OUTPUT parameter and the tuition due. Concept: multi-step transaction, OUTPUT parameter.
BEGIN TRY
    DECLARE @Tuition15 DECIMAL(12,0) = (SELECT Tuition FROM dbo.CLASS WHERE ClassId = 'CL0010');
    DECLARE @ExpectedDiscount15 DECIMAL(12,0) =
        (SELECT CASE DiscountType WHEN 'AMOUNT' THEN DiscountValue ELSE ROUND(@Tuition15 * DiscountValue / 100, -3) END
         FROM dbo.PROMOTION WHERE PromotionId = 'PR-REFER');
    IF @ExpectedDiscount15 > @Tuition15 SET @ExpectedDiscount15 = @Tuition15;
    DECLARE @Base15 DECIMAL(12,0), @Discount15 DECIMAL(12,0), @Due15 DECIMAL(12,0);
    BEGIN TRAN;
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00071', @ClassId = 'CL0010', @PromotionId = 'PR-REFER',
         @EmployeeId = 'EM0002', @EnrollmentId = @EnrollmentId OUTPUT;
    SELECT @Base15 = BaseTuition, @Discount15 = DiscountAmount, @Due15 = TuitionDue
    FROM dbo.ENROLLMENT WHERE EnrollmentId = @EnrollmentId;
    DECLARE @Info NVARCHAR(200) = N'ID ' + ISNULL(@EnrollmentId, N'?') + N', tuition due '
                                  + ISNULL(FORMAT(@Due15, 'N0'), N'?') + N' VND (expected '
                                  + FORMAT(@Tuition15 - @ExpectedDiscount15, 'N0') + N')';
    ROLLBACK;
    INSERT #Results VALUES ('T15', N'Valid enrollment with a promotion', N'Succeeded',
        CASE WHEN @Base15 = @Tuition15 AND @Discount15 = @ExpectedDiscount15 AND @Due15 = @Tuition15 - @ExpectedDiscount15
             THEN N'Succeeded' ELSE N'Wrong result' END, @Info);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T15', N'Valid enrollment with a promotion', N'Succeeded', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T33: entering a course that has a prerequisite course but no minimum placement score
--      Proves the entry requirement of usp_Enrollment_Create: without a minimum score a placement test is no way
--      in, only the prerequisite course is (before the fix any placement test was enough). Scenario, rolled
--      back: IE-65 loses its minimum score; ST00070 (placement 2.63, has not passed IE-55) asks for CL0008.
--      Concept: a comparison with NULL is UNKNOWN, so the placement branch finds no row.
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.COURSE SET MinPlacementScore = NULL WHERE CourseId = 'IE-65';
    DECLARE @EnrollmentId VARCHAR(10);
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00070', @ClassId = 'CL0008', @EmployeeId = 'EM0002',
         @EnrollmentId = @EnrollmentId OUTPUT;
    ROLLBACK;
    INSERT #Results VALUES ('T33', N'Prerequisite course required when no minimum score is set', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T33', N'Prerequisite course required when no minimum score is set', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T34: transferring a student to a class that clashes with another class they take
--      Proves usp_Enrollment_TransferClass runs the same schedule check as usp_Enrollment_Create (THROW 50024).
--      Scenario, rolled back: ST00071 studies in CL0003 (Mon/Wed/Fri 18:00-20:00) and in CL0010 (course CM-A1);
--      a new CM-A1 class meets on Monday 18:00-19:00 while CL0003 runs; moving the CL0010 enrollment there must
--      be refused. Concept: interval overlap test, one rule kept in two procedures.
BEGIN TRY
    DECLARE @E34 TABLE (EnrollmentId VARCHAR(10));
    DECLARE @C34 TABLE (ClassId VARCHAR(10));
    DECLARE @Enrollment34 VARCHAR(10), @Class34 VARCHAR(10), @Start34 DATE;
    BEGIN TRAN;
    INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, BaseTuition) VALUES ('ST00071', 'CL0003', 1000000);
    INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, BaseTuition) OUTPUT inserted.EnrollmentId INTO @E34
    VALUES ('ST00071', 'CL0010', 1000000);
    SELECT @Enrollment34 = EnrollmentId FROM @E34;
    SELECT @Start34 = StartDate FROM dbo.CLASS WHERE ClassId = 'CL0003';
    -- Room D1-LAB (capacity 16) and teacher TE0003 are free on Monday evenings
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @C34
    VALUES (N'T34 transfer target', 'CM-A1', 'BR01', 'TE0003', 'D1-LAB', @Start34, 16, 1000000);
    SELECT @Class34 = ClassId FROM @C34;
    INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime) VALUES (@Class34, 1, '18:00', '19:00');
    EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = @Enrollment34, @NewClassId = @Class34;
    ROLLBACK;
    INSERT #Results VALUES ('T34', N'Transfer into a class that clashes with another class of the student', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T34', N'Transfer into a class that clashes with another class of the student', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T36: a username with Vietnamese diacritics
--      Proves usp_Account_Create accepts only letters without diacritics, digits, dots and underscores (THROW
--      50060). The LIKE pattern is compared in a binary collation: under Vietnamese_CI_AS the range a-z also
--      contains accented letters. Rolled back in any case. Concept: the collation of a comparison (COLLATE).
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_Account_Create N'tuấn_test', N'Test@12345', 'ACADEMIC_STAFF', 'EM0006', NULL;
    ROLLBACK;
    INSERT #Results VALUES ('T36', N'Username with diacritics', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T36', N'Username with diacritics', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T37: attendance of a student who is not in the class of the session
--      Proves trg_ATTENDANCE_CheckClass on a direct INSERT: the session (CL0003) and the enrollment (CL0004)
--      must belong to the same class. Concept: rule across tables in an AFTER trigger (join with inserted).
BEGIN TRY
    DECLARE @Session37 INT = (SELECT TOP (1) SessionId FROM dbo.CLASS_SESSION WHERE ClassId = 'CL0003' ORDER BY SessionId);
    DECLARE @Enrollment37 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0004'
                                         ORDER BY EnrollmentId);
    BEGIN TRAN;
    INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status) VALUES (@Session37, @Enrollment37, N'Present');
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T37', N'Attendance for a session of another class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T37', N'Attendance for a session of another class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T38: a grade for a component of another course
--      Proves trg_GRADE_CheckComponent on a direct INSERT: an enrollment of CL0004 (course TO-450) cannot get a
--      score for a grade component of IE-55. Concept: rule across tables in an AFTER trigger.
BEGIN TRY
    DECLARE @Enrollment38 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0004'
                                         ORDER BY EnrollmentId);
    DECLARE @Component38 INT = (SELECT TOP (1) ComponentId FROM dbo.GRADE_COMPONENT WHERE CourseId = 'IE-55'
                                ORDER BY ComponentId);
    BEGIN TRAN;
    INSERT INTO dbo.GRADE (EnrollmentId, ComponentId, Score) VALUES (@Enrollment38, @Component38, 7);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T38', N'Grade for a component of another course', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T38', N'Grade for a component of another course', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T41: deleting a student who has an enrollment history
--      Proves usp_Student_Delete keeps the history: a student with enrollments cannot be deleted (THROW 50005,
--      the message suggests the status Dropped out). Concept: business check before a DELETE.
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_Student_Delete @StudentId = 'ST00001';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T41', N'Deleting a student who has an enrollment history', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T41', N'Deleting a student who has an enrollment history', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T42: cancelling a class whose students have paid tuition
--      Proves usp_Class_UpdateStatus refuses Cancelled while the class has valid receipts (THROW 50015): the
--      money must be refunded or the students transferred first. Concept: rule across CLASS - ENROLLMENT -
--      RECEIPT in a procedure.
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_Class_UpdateStatus @ClassId = 'CL0003', @Status = N'Cancelled';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T42', N'Cancelling a class whose students have paid', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T42', N'Cancelling a class whose students have paid', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T43: changing a grade of a finished class
--      Proves usp_Grade_Save: once usp_Class_EvaluateResults has closed a class (Finished), its grades are final
--      (THROW 50042). CL0001 is a finished class of the seed data.
BEGIN TRY
    DECLARE @Enrollment43 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0001'
                                         ORDER BY EnrollmentId);
    DECLARE @Component43 INT = (SELECT TOP (1) ComponentId FROM dbo.GRADE_COMPONENT WHERE CourseId = 'IE-FND'
                                ORDER BY ComponentId);
    BEGIN TRAN;
    EXEC dbo.usp_Grade_Save @EnrollmentId = @Enrollment43, @ComponentId = @Component43, @Score = 9;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T43', N'Changing a grade of a finished class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T43', N'Changing a grade of a finished class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T44: changing the attendance of a finished class
--      Proves usp_Attendance_Save: the attendance of a Finished class is final like its grades (THROW 50046),
--      because the results and certificates were computed from it. Concept: the same closing rule in two
--      procedures.
BEGIN TRY
    DECLARE @Session44 INT = (SELECT TOP (1) SessionId FROM dbo.CLASS_SESSION WHERE ClassId = 'CL0001'
                              ORDER BY SessionId);
    DECLARE @Enrollment44 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0001'
                                         ORDER BY EnrollmentId);
    BEGIN TRAN;
    EXEC dbo.usp_Attendance_Save @SessionId = @Session44, @EnrollmentId = @Enrollment44, @Status = N'Present';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T44', N'Changing the attendance of a finished class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T44', N'Changing the attendance of a finished class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T45: locking an account without saying lock or unlock (@Lock NULL)
--      Proves usp_Account_Lock refuses NULL (THROW 50068); before, NULL took the "unlock" branch (GRANT CONNECT,
--      status Active). Rolled back in any case. Concept: validating a BIT parameter (it can also be NULL).
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_Account_Lock @Username = N'gvu_ha', @Lock = NULL;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T45', N'Locking an account without saying lock or unlock', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T45', N'Locking an account without saying lock or unlock', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T46: a transfer applies the tuition of the new class
--      Proves usp_Enrollment_TransferClass: BaseTuition becomes the tuition of the new class and the promotion of
--      the enrollment is applied again; compared with the discount computed here from the PROMOTION row.
--      Scenario, rolled back: ST00071 in CL0010 (CM-A1, 3,800,000) with PR-REFER moves to a new CM-A1 class
--      that costs 4,200,000. Concept: a derived amount recomputed in a multi-step transaction.
BEGIN TRY
    DECLARE @E46 TABLE (EnrollmentId VARCHAR(10));
    DECLARE @C46 TABLE (ClassId VARCHAR(10));
    DECLARE @Enrollment46 VARCHAR(10), @Class46 VARCHAR(10), @Base46 DECIMAL(12,0), @Discount46 DECIMAL(12,0),
            @Due46 DECIMAL(12,0);
    DECLARE @ExpectedDiscount46 DECIMAL(12,0) =
        (SELECT CASE DiscountType WHEN 'AMOUNT' THEN DiscountValue ELSE ROUND(4200000 * DiscountValue / 100, -3) END
         FROM dbo.PROMOTION WHERE PromotionId = 'PR-REFER');
    BEGIN TRAN;
    INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, BaseTuition, PromotionId, DiscountAmount)
    OUTPUT inserted.EnrollmentId INTO @E46
    VALUES ('ST00071', 'CL0010', 3800000, 'PR-REFER', 500000);
    SELECT @Enrollment46 = EnrollmentId FROM @E46;
    -- Room D1-LAB (capacity 16) and teacher TE0003 are free on Monday evenings
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @C46
    VALUES (N'T46 transfer target', 'CM-A1', 'BR01', 'TE0003', 'D1-LAB', dbo.fn_Today(), 16, 4200000);
    SELECT @Class46 = ClassId FROM @C46;
    INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime) VALUES (@Class46, 1, '18:00', '19:00');
    EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = @Enrollment46, @NewClassId = @Class46;
    SELECT @Base46 = BaseTuition, @Discount46 = DiscountAmount, @Due46 = TuitionDue
    FROM dbo.ENROLLMENT WHERE EnrollmentId = @Enrollment46;
    ROLLBACK;
    INSERT #Results VALUES ('T46', N'Transfer: the tuition of the new class applies', N'Succeeded',
        CASE WHEN @Base46 = 4200000 AND @Discount46 = @ExpectedDiscount46 AND @Due46 = 4200000 - @ExpectedDiscount46
             THEN N'Succeeded' ELSE N'Wrong result' END,
        N'BaseTuition ' + ISNULL(FORMAT(@Base46, 'N0'), N'?') + N', discount ' + ISNULL(FORMAT(@Discount46, 'N0'), N'?')
        + N', due ' + ISNULL(FORMAT(@Due46, 'N0'), N'?') + N' (expected 4,200,000 / '
        + FORMAT(@ExpectedDiscount46, 'N0') + N')');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T46', N'Transfer: the tuition of the new class applies', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T47: transferring a student who paid more than the tuition of the new class
--      Proves usp_Enrollment_TransferClass refuses the move (THROW 50028): AmountPaid may never exceed the new
--      TuitionDue (CK_ENROLLMENT_AmountPaid), so a receipt must be cancelled first. Scenario, rolled back:
--      ST00071 paid 3,800,000 in full for CL0010 and asks for a CM-A1 class that costs 3,000,000.
BEGIN TRY
    DECLARE @E47 TABLE (EnrollmentId VARCHAR(10));
    DECLARE @C47 TABLE (ClassId VARCHAR(10));
    DECLARE @Enrollment47 VARCHAR(10), @Class47 VARCHAR(10);
    BEGIN TRAN;
    INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, BaseTuition) OUTPUT inserted.EnrollmentId INTO @E47
    VALUES ('ST00071', 'CL0010', 3800000);
    SELECT @Enrollment47 = EnrollmentId FROM @E47;
    -- Paid in full: trg_RECEIPT_UpdateAmountPaid sets AmountPaid = 3,800,000
    INSERT INTO dbo.RECEIPT (EnrollmentId, Amount, PaymentMethod, CollectedByEmployeeId)
    VALUES (@Enrollment47, 3800000, N'Cash', 'EM0003');
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @C47
    VALUES (N'T47 transfer target', 'CM-A1', 'BR01', 'TE0003', 'D1-LAB', dbo.fn_Today(), 16, 3000000);
    SELECT @Class47 = ClassId FROM @C47;
    INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime) VALUES (@Class47, 1, '18:00', '19:00');
    EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = @Enrollment47, @NewClassId = @Class47;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T47', N'Transfer when more was paid than the new tuition', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T47', N'Transfer when more was paid than the new tuition', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T50: marking a future session as taught
--      Proves trg_CLASS_SESSION_LockTaught: a session becomes Taught only on or after its date (dbo.fn_Today), so a
--      teacher cannot be paid in advance by usp_Payroll_Finalize. A Scheduled session of a class in progress
--      that lies after today is used. Concept: transition rule (old vs new row) in an AFTER UPDATE trigger.
BEGIN TRY
    DECLARE @Session50 INT = (SELECT TOP (1) se.SessionId
                              FROM dbo.CLASS_SESSION se JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
                              WHERE cl.Status = N'In progress' AND se.Status = N'Scheduled'
                                AND se.SessionDate > dbo.fn_Today()
                              ORDER BY se.SessionDate, se.SessionId);
    BEGIN TRAN;
    EXEC dbo.usp_Session_Update @SessionId = @Session50, @Status = N'Taught';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T50', N'Marking a future session as taught', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T50', N'Marking a future session as taught', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T51: setting a taught session back to Scheduled
--      Proves trg_CLASS_SESSION_LockTaught keeps a Taught session taught: otherwise its date/teacher could change
--      again (T13) and usp_Class_GenerateSessions could delete it together with its attendance.
BEGIN TRY
    DECLARE @Session51 INT = (SELECT TOP (1) se.SessionId
                              FROM dbo.CLASS_SESSION se JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
                              WHERE cl.Status = N'In progress' AND se.Status = N'Taught'
                              ORDER BY se.SessionId);
    BEGIN TRAN;
    EXEC dbo.usp_Session_Update @SessionId = @Session51, @Status = N'Scheduled';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T51', N'Setting a taught session back to Scheduled', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T51', N'Setting a taught session back to Scheduled', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T52: resuming an enrollment whose class clashes with another class of the student
--      Proves usp_Enrollment_UpdateStatus checks fn_StudentScheduleClash when an enrollment becomes Studying again
--      (THROW 50024). Scenario, rolled back: ST00001 studies in CL0003 (Mon/Wed/Fri 18:00-20:00) and has an
--      enrollment On hold in CL0007, which meets at the same hours; resuming it must be refused.
BEGIN TRY
    DECLARE @E52 TABLE (EnrollmentId VARCHAR(10));
    DECLARE @Enrollment52 VARCHAR(10);
    BEGIN TRAN;
    INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, BaseTuition, Status) OUTPUT inserted.EnrollmentId INTO @E52
    VALUES ('ST00001', 'CL0007', 6500000, N'On hold');
    SELECT @Enrollment52 = EnrollmentId FROM @E52;
    EXEC dbo.usp_Enrollment_UpdateStatus @EnrollmentId = @Enrollment52, @Status = N'Studying';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T52', N'Resuming an enrollment that clashes with another class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T52', N'Resuming an enrollment that clashes with another class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T53: changing the status of a completed enrollment
--      Proves usp_Enrollment_UpdateStatus refuses a Completed enrollment (THROW 50029): Completed, FinalGrade and
--      Result come from usp_Class_EvaluateResults and must stay together.
BEGIN TRY
    DECLARE @Enrollment53 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT
                                         WHERE Status = N'Completed' ORDER BY EnrollmentId);
    BEGIN TRAN;
    EXEC dbo.usp_Enrollment_UpdateStatus @EnrollmentId = @Enrollment53, @Status = N'Studying';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T53', N'Changing the status of a completed enrollment', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T53', N'Changing the status of a completed enrollment', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T54: reopening a finished class
--      Proves the life cycle of usp_Class_UpdateStatus (THROW 50019): a Finished class never goes back to
--      In progress (its grades, attendance and certificates are final).
BEGIN TRY
    DECLARE @Class54 VARCHAR(10) = (SELECT TOP (1) ClassId FROM dbo.CLASS WHERE Status = N'Finished' ORDER BY ClassId);
    BEGIN TRAN;
    EXEC dbo.usp_Class_UpdateStatus @ClassId = @Class54, @Status = N'In progress';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T54', N'Reopening a finished class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T54', N'Reopening a finished class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T56: changing a session of a finished class
--      Proves usp_Session_Update refuses the sessions of a Finished class (THROW 50018), like grades (T43) and
--      attendance (T44).
BEGIN TRY
    DECLARE @Session56 INT = (SELECT TOP (1) se.SessionId
                              FROM dbo.CLASS_SESSION se JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
                              WHERE cl.Status = N'Finished' ORDER BY se.SessionId);
    BEGIN TRAN;
    EXEC dbo.usp_Session_Update @SessionId = @Session56, @Status = N'Taught', @Description = N'T56 correction';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T56', N'Changing a session of a finished class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T56', N'Changing a session of a finished class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T57: evaluating a class that still has scheduled sessions
--      Proves usp_Class_EvaluateResults refuses to close a class while sessions are still Scheduled (THROW 50047):
--      the attendance rate would leave them out, and they could be taught and paid after the class is closed.
BEGIN TRY
    DECLARE @Class57 VARCHAR(10) = (SELECT TOP (1) cl.ClassId FROM dbo.CLASS cl
                                    WHERE cl.Status = N'In progress'
                                      AND EXISTS (SELECT 1 FROM dbo.CLASS_SESSION se
                                                  WHERE se.ClassId = cl.ClassId AND se.Status = N'Scheduled')
                                    ORDER BY cl.ClassId);
    BEGIN TRAN;
    EXEC dbo.usp_Class_EvaluateResults @ClassId = @Class57;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T57', N'Evaluating a class with sessions still scheduled', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T57', N'Evaluating a class with sessions still scheduled', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T60: a teacher younger than 18 on the hire date
--      Proves CK_TEACHER_Age, the same cross-column CHECK as CK_EMPLOYEE_Age.
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.TEACHER SET DateOfBirth = DATEADD(YEAR, -17, HireDate) WHERE TeacherId = 'TE0001';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T60', N'Teacher younger than 18 when hired', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T60', N'Teacher younger than 18 when hired', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T61: lowering the capacity of a room below the size of a class in progress
--      Proves trg_ROOM_CheckClasses: rule 2 (the class size fits the room) also holds when ROOM changes, which
--      managers may update directly. CL0003 (20 students at most) uses room D1-201.
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.ROOM SET Capacity = 10 WHERE RoomId = (SELECT RoomId FROM dbo.CLASS WHERE ClassId = 'CL0003');
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T61', N'Room capacity below the size of an active class', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T61', N'Room capacity below the size of an active class', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T62: creating an account for an employee who has left
--      Proves usp_Account_Create checks the person (THROW 50069) before it creates the database user. Scenario,
--      rolled back: the consultant EM0006 (no account) leaves the center.
BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.EMPLOYEE SET Status = N'Left' WHERE EmployeeId = 'EM0006';
    EXEC dbo.usp_Account_Create @Username = N't_left_employee', @Password = N'T62-test-only', @Role = 'ACADEMIC_STAFF',
                                @EmployeeId = 'EM0006';
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T62', N'Account for an employee who has left', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T62', N'Account for an employee who has left', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T68: changing a grade weight of a course whose classes have been evaluated
--      Proves trg_GRADE_COMPONENT_Lock: the manager may maintain GRADE_COMPONENT directly (06_security.sql), but the
--      components of an evaluated course are frozen - a new weight would change the final grades recomputed next
--      to the stored results and certificates. Concept: trigger on INSERT, UPDATE and DELETE (inserted UNION deleted).
BEGIN TRY
    DECLARE @Component68 INT = (SELECT TOP (1) gc.ComponentId FROM dbo.GRADE_COMPONENT gc
                                WHERE EXISTS (SELECT 1 FROM dbo.CLASS cl JOIN dbo.ENROLLMENT en ON en.ClassId = cl.ClassId
                                              WHERE cl.CourseId = gc.CourseId AND en.Result IS NOT NULL)
                                ORDER BY gc.ComponentId);
    BEGIN TRAN;
    UPDATE dbo.GRADE_COMPONENT SET Weight = Weight - 5 WHERE ComponentId = @Component68;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T68', N'New grade weight for a course with evaluated classes', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T68', N'New grade weight for a course with evaluated classes', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- T70: transferring a student to a class of the same course at another branch
--      Proves usp_Enrollment_TransferClass keeps an enrollment in its branch (THROW 50027): the revenue of a receipt
--      belongs to the branch of its class, so a cross-branch move would change past monthly figures. Scenario,
--      rolled back: a TO-450 class opens at BR02 and a student of CL0004 (TO-450, BR01) asks to move there.
BEGIN TRY
    DECLARE @C70 TABLE (ClassId VARCHAR(10));
    DECLARE @Class70 VARCHAR(10), @Enrollment70 VARCHAR(10);
    SELECT TOP (1) @Enrollment70 = EnrollmentId FROM dbo.ENROLLMENT
    WHERE ClassId = 'CL0004' AND Status = N'Studying' ORDER BY EnrollmentId;
    BEGIN TRAN;
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @C70
    SELECT N'T70 other branch', CourseId, 'BR02', TeacherId, 'TD-301', dbo.fn_Today(), 20, Tuition
    FROM dbo.CLASS WHERE ClassId = 'CL0004';
    SELECT @Class70 = ClassId FROM @C70;
    EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = @Enrollment70, @NewClassId = @Class70;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T70', N'Transfer to a class of another branch', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T70', N'Transfer to a class of another branch', N'Rejected', N'Rejected', ERROR_MESSAGE());
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

-- T17: fn_FinalGrade = SUM(Score x Weight) / 100 rounded once to 2 decimals; NULL when a component has no score
--      Proves fn_FinalGrade against the same formula computed here with GROUP BY for every graded enrollment
--      (T63 adds a hand-computed case where rounding twice would turn a fail into a pass);
--      then one score is deleted (rolled back) and the function must return NULL. Concept: scalar function.
BEGIN TRY
    DECLARE @Count17 INT, @Mismatch17 INT, @Enrollment17 VARCHAR(10), @AfterDelete17 DECIMAL(4,2);
    SELECT @Count17 = COUNT(*), @Mismatch17 = ISNULL(SUM(CASE WHEN x.ByFunction = x.Computed THEN 0 ELSE 1 END), 0)
    FROM (SELECT gr.EnrollmentId, dbo.fn_FinalGrade(gr.EnrollmentId) AS ByFunction,
                 CAST(ROUND(SUM(gr.Score * gc.Weight) / 100, 2) AS DECIMAL(4,2)) AS Computed
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
    BEGIN TRAN;
    EXEC dbo.usp_Payroll_Finalize @Month = @Month25, @Year = @Year25;
    ROLLBACK;
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

-- T35: re-evaluating a finished class keeps the certificates in line with the new results
--      Proves usp_Class_EvaluateResults run again on a Finished class after a correction: a student whose scores
--      become 0 now fails and loses the certificate; a student whose scores become 10 keeps it with the new grade.
--      Every enrollment of the class is then compared with its certificate (Failed = none; Passed = one with the
--      same grade and classification). The scores are changed directly by dbo (usp_Grade_Save refuses a finished
--      class). Rolled back. Concept: cursor, keeping two tables consistent after a correction.
BEGIN TRY
    DECLARE @Class35 VARCHAR(10), @Fail35 VARCHAR(10), @Raise35 VARCHAR(10), @Wrong35 INT, @Passed35 INT,
            @Certs35 INT, @FailOk35 BIT, @RaiseOk35 BIT;
    SELECT TOP (1) @Class35 = cl.ClassId FROM dbo.CLASS cl
    WHERE cl.Status = N'Finished'
      AND (SELECT COUNT(*) FROM dbo.CERTIFICATE ce JOIN dbo.ENROLLMENT en ON en.EnrollmentId = ce.EnrollmentId
           WHERE en.ClassId = cl.ClassId) >= 2
    ORDER BY cl.ClassId;
    SELECT TOP (1) @Fail35 = en.EnrollmentId
    FROM dbo.ENROLLMENT en JOIN dbo.CERTIFICATE ce ON ce.EnrollmentId = en.EnrollmentId
    WHERE en.ClassId = @Class35 ORDER BY en.EnrollmentId;
    SELECT TOP (1) @Raise35 = en.EnrollmentId
    FROM dbo.ENROLLMENT en JOIN dbo.CERTIFICATE ce ON ce.EnrollmentId = en.EnrollmentId
    WHERE en.ClassId = @Class35 AND en.EnrollmentId <> @Fail35 AND ce.FinalGrade < 10 ORDER BY en.EnrollmentId;

    IF OBJECT_ID('tempdb..#R35') IS NOT NULL DROP TABLE #R35;
    CREATE TABLE #R35 (PassedCount INT, FailedCount INT);
    BEGIN TRAN;
    UPDATE dbo.GRADE SET Score = 0 WHERE EnrollmentId = @Fail35;
    UPDATE dbo.GRADE SET Score = 10 WHERE EnrollmentId = @Raise35;
    INSERT #R35 EXEC dbo.usp_Class_EvaluateResults @ClassId = @Class35;
    SELECT @Passed35 = COUNT(*) FROM dbo.ENROLLMENT WHERE ClassId = @Class35 AND Result = N'Passed';
    SELECT @Certs35 = COUNT(*)
    FROM dbo.CERTIFICATE ce JOIN dbo.ENROLLMENT en ON en.EnrollmentId = ce.EnrollmentId WHERE en.ClassId = @Class35;
    SELECT @Wrong35 = COUNT(*)
    FROM dbo.ENROLLMENT en LEFT JOIN dbo.CERTIFICATE ce ON ce.EnrollmentId = en.EnrollmentId
    WHERE en.ClassId = @Class35 AND en.Status = N'Completed'
      AND ((en.Result = N'Failed' AND ce.CertificateId IS NOT NULL)
        OR (en.Result = N'Passed' AND (ce.CertificateId IS NULL OR ce.FinalGrade <> en.FinalGrade
                                       OR ce.Classification <> dbo.fn_Classification(en.FinalGrade))));
    SET @FailOk35 = CASE WHEN EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE EnrollmentId = @Fail35 AND Result = N'Failed')
                          AND NOT EXISTS (SELECT 1 FROM dbo.CERTIFICATE WHERE EnrollmentId = @Fail35)
                         THEN 1 ELSE 0 END;
    SET @RaiseOk35 = CASE WHEN EXISTS (SELECT 1 FROM dbo.CERTIFICATE WHERE EnrollmentId = @Raise35 AND FinalGrade = 10)
                          THEN 1 ELSE 0 END;
    ROLLBACK;

    INSERT #Results VALUES ('T35', N'Re-evaluation: certificates follow the corrected results', N'Succeeded',
        CASE WHEN @Wrong35 = 0 AND @FailOk35 = 1 AND @RaiseOk35 = 1 AND @Certs35 = @Passed35
             THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Class35, N'?') + N': ' + ISNULL(@Fail35, N'?') + N' failed and lost the certificate = '
        + CAST(@FailOk35 AS NVARCHAR(1)) + N', ' + ISNULL(@Raise35, N'?') + N' re-graded 10 = '
        + CAST(@RaiseOk35 AS NVARCHAR(1)) + N'; ' + CAST(@Certs35 AS NVARCHAR(10)) + N' certificates for '
        + CAST(@Passed35 AS NVARCHAR(10)) + N' passed; ' + CAST(@Wrong35 AS NVARCHAR(10)) + N' mismatch(es)');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T35', N'Re-evaluation: certificates follow the corrected results', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T39: every changed score is written to the audit log as XML (trg_GRADE_Audit)
--      Proves trg_GRADE_Audit: an UPDATE that keeps the same score adds nothing; changing the score adds exactly
--      one AUDIT_LOG row with Action UPDATE, the key EnrollmentId/ComponentId and the old and new score in
--      OldData/NewData (read back with .value()). Rolled back. Concept: AFTER trigger on inserted/deleted,
--      FOR XML PATH, XML column.
BEGIN TRY
    DECLARE @Enrollment39 VARCHAR(10), @Component39 INT, @Old39 DECIMAL(4,2), @New39 DECIMAL(4,2), @Before39 BIGINT,
            @Same39 INT, @Rows39 INT, @Action39 VARCHAR(10), @Key39 NVARCHAR(100), @OldLogged39 DECIMAL(4,2),
            @NewLogged39 DECIMAL(4,2);
    SELECT TOP (1) @Enrollment39 = EnrollmentId, @Component39 = ComponentId, @Old39 = Score
    FROM dbo.GRADE ORDER BY EnrollmentId, ComponentId;
    SET @New39 = CASE WHEN @Old39 >= 9 THEN @Old39 - 1 ELSE @Old39 + 1 END;
    BEGIN TRAN;
    SELECT @Before39 = ISNULL(MAX(LogId), 0) FROM dbo.AUDIT_LOG;
    UPDATE dbo.GRADE SET Score = @Old39 WHERE EnrollmentId = @Enrollment39 AND ComponentId = @Component39;
    SELECT @Same39 = COUNT(*) FROM dbo.AUDIT_LOG WHERE LogId > @Before39;
    UPDATE dbo.GRADE SET Score = @New39 WHERE EnrollmentId = @Enrollment39 AND ComponentId = @Component39;
    SELECT @Rows39 = COUNT(*) FROM dbo.AUDIT_LOG WHERE LogId > @Before39;
    SELECT TOP (1) @Action39 = Action, @Key39 = RecordKey,
           @OldLogged39 = OldData.value('(/Grade/Score)[1]', 'DECIMAL(4,2)'),
           @NewLogged39 = NewData.value('(/Grade/Score)[1]', 'DECIMAL(4,2)')
    FROM dbo.AUDIT_LOG WHERE LogId > @Before39 ORDER BY LogId DESC;
    ROLLBACK;

    INSERT #Results VALUES ('T39', N'trg_GRADE_Audit: one XML audit row per changed score', N'Succeeded',
        CASE WHEN @Same39 = 0 AND @Rows39 = 1 AND @Action39 = 'UPDATE'
                  AND @Key39 = @Enrollment39 + N'/' + CAST(@Component39 AS NVARCHAR(10))
                  AND @OldLogged39 = @Old39 AND @NewLogged39 = @New39
             THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Key39, N'?') + N': ' + ISNULL(CAST(@OldLogged39 AS NVARCHAR(10)), N'NULL') + N' -> '
        + ISNULL(CAST(@NewLogged39 AS NVARCHAR(10)), N'NULL') + N' logged (' + CAST(@Rows39 AS NVARCHAR(10))
        + N' row(s); unchanged score: ' + CAST(@Same39 AS NVARCHAR(10)) + N')');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T39', N'trg_GRADE_Audit: one XML audit row per changed score', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T40: a placement test recommends a course by itself (trg_PLACEMENT_TEST_Recommend)
--      Proves the trigger after an INSERT and after an UPDATE of the scores: RecommendedCourseId is the open course
--      with the highest minimum score that the overall score reaches (the cheaper one first; a course that only its
--      prerequisite opens is left out, T49), recomputed here from COURSE. Rolled back. Concept: AFTER trigger that
--      completes the rows just written, UPDATE(col).
BEGIN TRY
    DECLARE @T40 TABLE (TestId VARCHAR(10));
    DECLARE @Test40 VARCHAR(10), @Overall40 DECIMAL(4,2), @Got40 VARCHAR(10), @Expected40 VARCHAR(10),
            @OverallLater40 DECIMAL(4,2), @GotLater40 VARCHAR(10), @ExpectedLater40 VARCHAR(10);
    BEGIN TRAN;
    INSERT INTO dbo.PLACEMENT_TEST (StudentId, ListeningScore, SpeakingScore, ReadingScore, WritingScore, GradedByTeacherId)
    OUTPUT inserted.TestId INTO @T40
    VALUES ('ST00071', 6, 5.5, 6, 5.5, 'TE0001');
    SELECT @Test40 = TestId FROM @T40;
    SELECT @Overall40 = OverallScore, @Got40 = RecommendedCourseId FROM dbo.PLACEMENT_TEST WHERE TestId = @Test40;
    SELECT TOP (1) @Expected40 = CourseId FROM dbo.COURSE
    WHERE Status = N'Open' AND ISNULL(MinPlacementScore, 0) <= @Overall40
      AND (PrerequisiteCourseId IS NULL OR MinPlacementScore IS NOT NULL)
    ORDER BY ISNULL(MinPlacementScore, 0) DESC, Tuition ASC;

    UPDATE dbo.PLACEMENT_TEST SET ListeningScore = 3, SpeakingScore = 3, ReadingScore = 3, WritingScore = 3
    WHERE TestId = @Test40;
    SELECT @OverallLater40 = OverallScore, @GotLater40 = RecommendedCourseId FROM dbo.PLACEMENT_TEST WHERE TestId = @Test40;
    SELECT TOP (1) @ExpectedLater40 = CourseId FROM dbo.COURSE
    WHERE Status = N'Open' AND ISNULL(MinPlacementScore, 0) <= @OverallLater40
      AND (PrerequisiteCourseId IS NULL OR MinPlacementScore IS NOT NULL)
    ORDER BY ISNULL(MinPlacementScore, 0) DESC, Tuition ASC;
    ROLLBACK;

    INSERT #Results VALUES ('T40', N'trg_PLACEMENT_TEST_Recommend: course recommended from the score', N'Succeeded',
        CASE WHEN @Got40 = @Expected40 AND @GotLater40 = @ExpectedLater40 AND @Got40 <> @GotLater40
             THEN N'Succeeded' ELSE N'Wrong result' END,
        CAST(@Overall40 AS NVARCHAR(10)) + N' => ' + ISNULL(@Got40, N'NULL') + N' (expected ' + ISNULL(@Expected40, N'NULL')
        + N'), then ' + CAST(@OverallLater40 AS NVARCHAR(10)) + N' => ' + ISNULL(@GotLater40, N'NULL') + N' (expected '
        + ISNULL(@ExpectedLater40, N'NULL') + N')');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T40', N'trg_PLACEMENT_TEST_Recommend: course recommended from the score', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T48: the attendance rate of a student who joined a class in progress
--      Proves fn_AttendanceRate counts only the sessions taught since the student joined the class
--      (ENROLLMENT.ClassJoinedOn). Scenario, rolled back: a student of CL0004 enrolls on the day of its 4th taught
--      session and attends every session from then on; the rate must be 100% (counting the 3 earlier sessions
--      would give less and fail the 80% rule).
BEGIN TRY
    DECLARE @Enrollment48 VARCHAR(10), @Joined48 DATE, @Rate48 DECIMAL(5,2), @Sessions48 INT;
    SELECT TOP (1) @Enrollment48 = EnrollmentId FROM dbo.ENROLLMENT
    WHERE ClassId = 'CL0004' AND Status = N'Studying' ORDER BY EnrollmentId;
    SELECT @Joined48 = SessionDate
    FROM (SELECT SessionDate, ROW_NUMBER() OVER (ORDER BY SessionDate) AS n
          FROM dbo.CLASS_SESSION WHERE ClassId = 'CL0004' AND Status = N'Taught') s
    WHERE n = 4;
    BEGIN TRAN;
    UPDATE dbo.ENROLLMENT SET EnrolledOn = @Joined48, ClassJoinedOn = @Joined48 WHERE EnrollmentId = @Enrollment48;
    DELETE at FROM dbo.ATTENDANCE at JOIN dbo.CLASS_SESSION se ON se.SessionId = at.SessionId
    WHERE at.EnrollmentId = @Enrollment48 AND se.SessionDate < @Joined48;
    UPDATE dbo.ATTENDANCE SET Status = N'Present' WHERE EnrollmentId = @Enrollment48;
    INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status)
    SELECT se.SessionId, @Enrollment48, N'Present' FROM dbo.CLASS_SESSION se
    WHERE se.ClassId = 'CL0004' AND se.Status = N'Taught' AND se.SessionDate >= @Joined48
      AND NOT EXISTS (SELECT 1 FROM dbo.ATTENDANCE a WHERE a.SessionId = se.SessionId AND a.EnrollmentId = @Enrollment48);
    SELECT @Sessions48 = COUNT(*) FROM dbo.ATTENDANCE WHERE EnrollmentId = @Enrollment48;
    SET @Rate48 = dbo.fn_AttendanceRate(@Enrollment48);
    ROLLBACK;

    INSERT #Results VALUES ('T48', N'fn_AttendanceRate: only sessions since the student joined the class count', N'Succeeded',
        CASE WHEN @Joined48 IS NOT NULL AND @Sessions48 > 0 AND @Rate48 = 100 THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Enrollment48, N'?') + N' joined on ' + ISNULL(CONVERT(NVARCHAR(10), @Joined48, 23), N'?') + N', present at '
        + CAST(ISNULL(@Sessions48, 0) AS NVARCHAR(10)) + N' sessions => ' + ISNULL(CAST(@Rate48 AS NVARCHAR(10)), N'NULL') + N'%');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T48', N'fn_AttendanceRate: only sessions since the student joined the class count', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T49: fn_RecommendCourse never recommends a course that only the prerequisite course opens
--      Proves the rule shared with usp_Enrollment_Create (T33). Scenario, rolled back: IE-55 (prerequisite IE-FND)
--      loses its minimum score and becomes free, so it would be the cheapest course "open to everybody"; the
--      recommendation for a low score must be another course, the one computed here from COURSE.
BEGIN TRY
    DECLARE @Got49 VARCHAR(10), @Expected49 VARCHAR(10);
    BEGIN TRAN;
    UPDATE dbo.COURSE SET MinPlacementScore = NULL, Tuition = 0 WHERE CourseId = 'IE-55';
    SET @Got49 = dbo.fn_RecommendCourse(0.5, NULL);
    SELECT TOP (1) @Expected49 = CourseId FROM dbo.COURSE
    WHERE Status = N'Open' AND ISNULL(MinPlacementScore, 0) <= 0.5 AND PrerequisiteCourseId IS NULL
    ORDER BY ISNULL(MinPlacementScore, 0) DESC, Tuition ASC;
    ROLLBACK;

    INSERT #Results VALUES ('T49', N'fn_RecommendCourse: no course that needs its prerequisite', N'Succeeded',
        CASE WHEN @Got49 = @Expected49 AND @Got49 <> 'IE-55' THEN N'Succeeded' ELSE N'Wrong result' END,
        N'score 0.5 => ' + ISNULL(@Got49, N'NULL') + N' (expected ' + ISNULL(@Expected49, N'NULL') + N')');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T49', N'fn_RecommendCourse: no course that needs its prerequisite', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T55: cancelling a class closes its enrollments
--      Proves usp_Class_UpdateStatus sets the open enrollments of a cancelled class to Left, so they no longer
--      count as outstanding tuition and accept no receipt. Scenario, rolled back: the deposits of an Enrolling
--      class are refunded (cancelled), then the class is cancelled.
BEGIN TRY
    DECLARE @Class55 VARCHAR(10), @Open55 INT, @Left55 INT, @StillOpen55 INT, @Status55 NVARCHAR(20);
    SELECT TOP (1) @Class55 = cl.ClassId FROM dbo.CLASS cl
    WHERE cl.Status = N'Enrolling' AND EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.ClassId = cl.ClassId)
    ORDER BY cl.ClassId;
    SELECT @Open55 = COUNT(*) FROM dbo.ENROLLMENT WHERE ClassId = @Class55 AND Status IN (N'Studying', N'On hold');
    BEGIN TRAN;
    UPDATE rc SET Status = N'Cancelled', CancelReason = N'T55: refunded before the class is cancelled'
    FROM dbo.RECEIPT rc JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
    WHERE en.ClassId = @Class55 AND rc.Status = N'Valid';
    EXEC dbo.usp_Class_UpdateStatus @ClassId = @Class55, @Status = N'Cancelled';
    SELECT @Status55 = Status FROM dbo.CLASS WHERE ClassId = @Class55;
    SELECT @Left55 = SUM(CASE WHEN Status = N'Left' THEN 1 ELSE 0 END),
           @StillOpen55 = SUM(CASE WHEN Status IN (N'Studying', N'On hold') THEN 1 ELSE 0 END)
    FROM dbo.ENROLLMENT WHERE ClassId = @Class55;
    ROLLBACK;

    INSERT #Results VALUES ('T55', N'usp_Class_UpdateStatus: a cancelled class closes its enrollments', N'Succeeded',
        CASE WHEN @Status55 = N'Cancelled' AND @Open55 > 0 AND @Left55 >= @Open55 AND @StillOpen55 = 0
             THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Class55, N'?') + N' => ' + ISNULL(@Status55, N'?') + N', ' + CAST(ISNULL(@Left55, 0) AS NVARCHAR(10))
        + N' Left, ' + CAST(ISNULL(@StillOpen55, 0) AS NVARCHAR(10)) + N' still open');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T55', N'usp_Class_UpdateStatus: a cancelled class closes its enrollments', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T58: running usp_Payroll_Finalize again removes a row that has no taught session any more
--      Scenario, rolled back: a Finalized row of last month is added for a teacher who taught nothing that month
--      (as if the sessions had been cancelled after a first run); the next run must delete it.
BEGIN TRY
    DECLARE @Date58 DATE = DATEADD(MONTH, -1, dbo.fn_Today());
    DECLARE @Month58 TINYINT = MONTH(@Date58), @Year58 SMALLINT = YEAR(@Date58), @Teacher58 VARCHAR(10),
            @Left58 INT, @Returned58 INT;
    SELECT TOP (1) @Teacher58 = te.TeacherId FROM dbo.TEACHER te
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION se
                      WHERE se.TeacherId = te.TeacherId AND se.Status = N'Taught'
                        AND MONTH(se.SessionDate) = @Month58 AND YEAR(se.SessionDate) = @Year58)
      AND NOT EXISTS (SELECT 1 FROM dbo.PAYROLL py
                      WHERE py.TeacherId = te.TeacherId AND py.Month = @Month58 AND py.Year = @Year58)
    ORDER BY te.TeacherId;

    IF OBJECT_ID('tempdb..#R58') IS NOT NULL DROP TABLE #R58;
    CREATE TABLE #R58 (TeacherId VARCHAR(10), TeacherName NVARCHAR(100), SessionCount INT, Hours DECIMAL(6,2),
                       HourlyRate DECIMAL(12,0), Bonus DECIMAL(12,0), Deduction DECIMAL(12,0), TotalPay DECIMAL(14,0),
                       Status NVARCHAR(20));
    BEGIN TRAN;
    INSERT INTO dbo.PAYROLL (TeacherId, Month, Year, SessionCount, Hours, HourlyRate)
    SELECT TeacherId, @Month58, @Year58, 3, 6, HourlyRate FROM dbo.TEACHER WHERE TeacherId = @Teacher58;
    INSERT #R58 EXEC dbo.usp_Payroll_Finalize @Month = @Month58, @Year = @Year58;
    SELECT @Left58 = COUNT(*) FROM dbo.PAYROLL WHERE TeacherId = @Teacher58 AND Month = @Month58 AND Year = @Year58;
    SELECT @Returned58 = COUNT(*) FROM #R58 WHERE TeacherId = @Teacher58;
    ROLLBACK;

    INSERT #Results VALUES ('T58', N'usp_Payroll_Finalize: a row without taught sessions is removed', N'Succeeded',
        CASE WHEN @Teacher58 IS NOT NULL AND @Left58 = 0 AND @Returned58 = 0 THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Teacher58, N'?') + N': ' + CAST(ISNULL(@Left58, -1) AS NVARCHAR(10)) + N' row(s) left for month '
        + CAST(@Month58 AS NVARCHAR(2)) + N'/' + CAST(@Year58 AS NVARCHAR(4)));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T58', N'usp_Payroll_Finalize: a row without taught sessions is removed', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T59: XML import with the same new phone twice in the file and an empty name
--      Proves usp_Student_ImportXml keeps the first of two rows with the same phone (instead of failing the whole
--      import on UX_STUDENT_Phone) and skips a name made of spaces. Rolled back.
BEGIN TRY
    DECLARE @Dob59 NVARCHAR(10) = CONVERT(NVARCHAR(10), DATEADD(YEAR, -25, dbo.fn_Today()), 23);
    DECLARE @Xml59 XML = CAST(N'<Students>'
        + N'<Student><FullName>T59 First</FullName><DateOfBirth>' + @Dob59
        + N'</DateOfBirth><Gender>Male</Gender><Phone>0999590001</Phone></Student>'
        + N'<Student><FullName>T59 Same phone</FullName><DateOfBirth>' + @Dob59
        + N'</DateOfBirth><Gender>Female</Gender><Phone>0999590001</Phone></Student>'
        + N'<Student><FullName>   </FullName><DateOfBirth>' + @Dob59
        + N'</DateOfBirth><Gender>Male</Gender><Phone>0999590002</Phone></Student>'
        + N'</Students>' AS XML);
    DECLARE @Imported59 INT, @Skipped59 INT, @Phone1Rows59 INT, @Phone2Rows59 INT, @Name59 NVARCHAR(100);
    IF OBJECT_ID('tempdb..#R59') IS NOT NULL DROP TABLE #R59;
    CREATE TABLE #R59 (ImportedRows INT, SkippedRows INT);
    BEGIN TRAN;
    INSERT #R59 EXEC dbo.usp_Student_ImportXml @Data = @Xml59, @BranchId = 'BR01';
    SELECT @Imported59 = ImportedRows, @Skipped59 = SkippedRows FROM #R59;
    SELECT @Phone1Rows59 = COUNT(*), @Name59 = MAX(FullName) FROM dbo.STUDENT WHERE Phone = '0999590001';
    SELECT @Phone2Rows59 = COUNT(*) FROM dbo.STUDENT WHERE Phone = '0999590002';
    ROLLBACK;

    INSERT #Results VALUES ('T59', N'usp_Student_ImportXml: duplicates inside the file, empty name', N'Succeeded',
        CASE WHEN @Imported59 = 1 AND @Skipped59 = 2 AND @Phone1Rows59 = 1 AND @Name59 = N'T59 First' AND @Phone2Rows59 = 0
             THEN N'Succeeded' ELSE N'Wrong result' END,
        CAST(ISNULL(@Imported59, -1) AS NVARCHAR(10)) + N' imported, ' + CAST(ISNULL(@Skipped59, -1) AS NVARCHAR(10))
        + N' skipped; kept: ' + ISNULL(@Name59, N'none'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T59', N'usp_Student_ImportXml: duplicates inside the file, empty name', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T63: fn_FinalGrade rounds once, at the end
--      Hand-computed case, rolled back: weights 6.22 / 18.61 / 75.17 and scores 4.75 / 5.42 / 4.91 give
--      (4.75 x 6.22 + 5.42 x 18.61 + 4.91 x 75.17) / 100 = 4.994959 => 4.99 (failed). Rounding to 4 decimals first
--      would give 4.9950 and then 5.00 (a pass). The components of a course without evaluated classes are changed
--      (trg_GRADE_COMPONENT_Lock freezes the others, T68), in ComponentId order, and one of its students gets the
--      three scores.
BEGIN TRY
    DECLARE @Enrollment63 VARCHAR(10), @Course63 VARCHAR(10), @Grade63 DECIMAL(4,2);
    SELECT TOP (1) @Enrollment63 = en.EnrollmentId, @Course63 = cl.CourseId
    FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
    WHERE en.Status = N'Studying'
      AND (SELECT COUNT(*) FROM dbo.GRADE_COMPONENT gc WHERE gc.CourseId = cl.CourseId) = 3
      AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT x JOIN dbo.CLASS c2 ON c2.ClassId = x.ClassId
                      WHERE c2.CourseId = cl.CourseId AND x.Result IS NOT NULL)
    ORDER BY en.EnrollmentId;
    BEGIN TRAN;
    ;WITH c AS (SELECT ComponentId, ROW_NUMBER() OVER (ORDER BY ComponentId) AS n
                FROM dbo.GRADE_COMPONENT WHERE CourseId = @Course63)
    UPDATE gc SET Weight = CASE c.n WHEN 1 THEN 6.22 WHEN 2 THEN 18.61 ELSE 75.17 END
    FROM dbo.GRADE_COMPONENT gc JOIN c ON c.ComponentId = gc.ComponentId;
    DELETE FROM dbo.GRADE WHERE EnrollmentId = @Enrollment63;
    INSERT INTO dbo.GRADE (EnrollmentId, ComponentId, Score, EnteredBy)
    SELECT @Enrollment63, c.ComponentId, CASE c.n WHEN 1 THEN 4.75 WHEN 2 THEN 5.42 ELSE 4.91 END, N'T63'
    FROM (SELECT ComponentId, ROW_NUMBER() OVER (ORDER BY ComponentId) AS n
          FROM dbo.GRADE_COMPONENT WHERE CourseId = @Course63) c;
    SET @Grade63 = dbo.fn_FinalGrade(@Enrollment63);
    ROLLBACK;

    INSERT #Results VALUES ('T63', N'fn_FinalGrade: one rounding at the end (4.994959 => 4.99)', N'Succeeded',
        CASE WHEN @Grade63 = 4.99 THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Enrollment63, N'?') + N' => ' + ISNULL(CAST(@Grade63 AS NVARCHAR(10)), N'NULL'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T63', N'fn_FinalGrade: one rounding at the end (4.994959 => 4.99)', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T64: a valid promotion code on a free class
--      Proves usp_Enrollment_Create checks the code itself: a valid code whose discount is 0 (the class is free) is
--      accepted instead of being reported as unknown or expired. Scenario, rolled back: a free CM-A1 class.
BEGIN TRY
    DECLARE @Class64 VARCHAR(10), @Enrollment64 VARCHAR(10), @Student64 VARCHAR(10), @Due64 DECIMAL(12,0),
            @Promotion64 VARCHAR(10);
    SELECT TOP (1) @Student64 = st.StudentId FROM dbo.STUDENT st
    WHERE st.Status <> N'Dropped out' AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.StudentId = st.StudentId)
    ORDER BY st.StudentId;
    BEGIN TRAN;
    DECLARE @StartDate64 DATE = DATEADD(MONTH, 1, dbo.fn_Today());
    EXEC dbo.usp_Class_Create @ClassName = N'T64 free class', @CourseId = 'CM-A1', @BranchId = 'BR01',
                              @TeacherId = 'TE0003', @RoomId = 'D1-102', @StartDate = @StartDate64,
                              @MaxStudents = 10, @Tuition = 0, @ClassId = @Class64 OUTPUT;
    EXEC dbo.usp_Enrollment_Create @StudentId = @Student64, @ClassId = @Class64, @PromotionId = 'PR-REFER',
                                   @EmployeeId = 'EM0002', @EnrollmentId = @Enrollment64 OUTPUT;
    SELECT @Due64 = TuitionDue, @Promotion64 = PromotionId FROM dbo.ENROLLMENT WHERE EnrollmentId = @Enrollment64;
    ROLLBACK;

    INSERT #Results VALUES ('T64', N'usp_Enrollment_Create: a valid promotion code on a free class', N'Succeeded',
        CASE WHEN @Enrollment64 IS NOT NULL AND @Due64 = 0 AND @Promotion64 = 'PR-REFER' THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Student64, N'?') + N' => ' + ISNULL(@Enrollment64, N'no enrollment') + N', tuition due '
        + ISNULL(CAST(@Due64 AS NVARCHAR(20)), N'?'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T64', N'usp_Enrollment_Create: a valid promotion code on a free class', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T65: the two ways to meet an entry requirement (T04 and T33 only test refusals)
--      CL0003 is a class of IE-55 (prerequisite IE-FND, minimum placement score 5.5). Scenario, rolled back:
--      (a) a student who never enrolled scores 6.0 in a new placement test => admitted on the score;
--      (b) a student who passed IE-FND gets a new placement test of 1.0 (so the score cannot help) => admitted on
--      the prerequisite. Both enrollments must exist afterwards.
BEGIN TRY
    DECLARE @ByScore65 VARCHAR(10), @ByCourse65 VARCHAR(10), @EnrollA65 VARCHAR(10), @EnrollB65 VARCHAR(10), @Rows65 INT;
    SELECT TOP (1) @ByScore65 = st.StudentId FROM dbo.STUDENT st
    WHERE st.Status <> N'Dropped out' AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.StudentId = st.StudentId)
    ORDER BY st.StudentId;
    SELECT TOP (1) @ByCourse65 = en.StudentId
    FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
    WHERE cl.CourseId = 'IE-FND' AND en.Result = N'Passed' AND st.Status <> N'Dropped out'
      AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT x WHERE x.StudentId = en.StudentId AND x.ClassId = 'CL0003')
      AND NOT EXISTS (SELECT 1 FROM dbo.fn_StudentScheduleClash(en.StudentId, 'CL0003', NULL))
    ORDER BY en.StudentId;
    BEGIN TRAN;
    INSERT INTO dbo.PLACEMENT_TEST (StudentId, ListeningScore, SpeakingScore, ReadingScore, WritingScore)
    VALUES (@ByScore65, 6, 6, 6, 6), (@ByCourse65, 1, 1, 1, 1);
    EXEC dbo.usp_Enrollment_Create @StudentId = @ByScore65, @ClassId = 'CL0003', @EmployeeId = 'EM0002',
                                   @EnrollmentId = @EnrollA65 OUTPUT;
    EXEC dbo.usp_Enrollment_Create @StudentId = @ByCourse65, @ClassId = 'CL0003', @EmployeeId = 'EM0002',
                                   @EnrollmentId = @EnrollB65 OUTPUT;
    SELECT @Rows65 = COUNT(*) FROM dbo.ENROLLMENT WHERE EnrollmentId IN (@EnrollA65, @EnrollB65) AND ClassId = 'CL0003';
    ROLLBACK;

    INSERT #Results VALUES ('T65', N'usp_Enrollment_Create: admitted on the score or on the prerequisite', N'Succeeded',
        CASE WHEN @Rows65 = 2 THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@ByScore65, N'?') + N' (score 6.0) => ' + ISNULL(@EnrollA65, N'none') + N'; ' + ISNULL(@ByCourse65, N'?')
        + N' (passed IE-FND, score 1.0) => ' + ISNULL(@EnrollB65, N'none'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T65', N'usp_Enrollment_Create: admitted on the score or on the prerequisite', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T67: the Dashboard counts the students who are taking a class
--      Proves usp_Dashboard_Stats.ActiveStudents = the students with a Studying enrollment, counted here. The
--      status of the STUDENT row is not used: it stays Studying after the last course is completed.
BEGIN TRY
    DECLARE @Active67 INT, @Expected67 INT, @ByStatus67 INT;
    IF OBJECT_ID('tempdb..#R67') IS NOT NULL DROP TABLE #R67;
    CREATE TABLE #R67 (ActiveStudents INT, ActiveClasses INT, EnrollingClasses INT, RevenueThisMonth DECIMAL(14,0),
                       TotalOutstanding DECIMAL(14,0), SessionsToday INT);
    INSERT #R67 EXEC dbo.usp_Dashboard_Stats;
    SELECT @Active67 = ActiveStudents FROM #R67;
    SELECT @Expected67 = COUNT(DISTINCT StudentId) FROM dbo.ENROLLMENT WHERE Status = N'Studying';
    SELECT @ByStatus67 = COUNT(*) FROM dbo.STUDENT WHERE Status = N'Studying';

    INSERT #Results VALUES ('T67', N'usp_Dashboard_Stats: students with a Studying enrollment', N'Succeeded',
        CASE WHEN @Active67 = @Expected67 THEN N'Succeeded' ELSE N'Wrong result' END,
        CAST(@Active67 AS NVARCHAR(10)) + N' active students (expected ' + CAST(@Expected67 AS NVARCHAR(10))
        + N'; STUDENT rows with status Studying: ' + CAST(@ByStatus67 AS NVARCHAR(10)) + N')');
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T67', N'usp_Dashboard_Stats: students with a Studying enrollment', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T69: after a transfer, the attendance of the new class counts from the transfer day
--      Proves usp_Enrollment_TransferClass sets ENROLLMENT.ClassJoinedOn to today and fn_AttendanceRate counts the
--      new class from then on. Scenario, rolled back: a second TO-450 class of BR01 started four weeks ago (Sundays
--      07:00-08:00) and taught its past sessions; a student of CL0004 moves to it today. No session of the new class
--      counts yet (NULL) - counting from EnrolledOn would mark all of them as absences.
BEGIN TRY
    DECLARE @C69 TABLE (ClassId VARCHAR(10));
    DECLARE @R69 TABLE (SessionsCreated INT, EndDate DATE);
    DECLARE @Class69 VARCHAR(10), @Enrollment69 VARCHAR(10), @Joined69 DATE, @Rate69 DECIMAL(5,2), @Taught69 INT;
    SELECT TOP (1) @Enrollment69 = EnrollmentId FROM dbo.ENROLLMENT
    WHERE ClassId = 'CL0004' AND Status = N'Studying' ORDER BY EnrollmentId DESC;
    BEGIN TRAN;
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @C69
    SELECT N'T69 transfer target', CourseId, BranchId, TeacherId, RoomId, DATEADD(WEEK, -4, dbo.fn_Today()),
           MaxStudents, Tuition
    FROM dbo.CLASS WHERE ClassId = 'CL0004';
    SELECT @Class69 = ClassId FROM @C69;
    INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime) VALUES (@Class69, 7, '07:00', '08:00');
    INSERT @R69 EXEC dbo.usp_Class_GenerateSessions @ClassId = @Class69;
    UPDATE dbo.CLASS_SESSION SET Status = N'Taught' WHERE ClassId = @Class69 AND SessionDate < dbo.fn_Today();
    UPDATE dbo.CLASS SET Status = N'In progress' WHERE ClassId = @Class69;
    SELECT @Taught69 = COUNT(*) FROM dbo.CLASS_SESSION WHERE ClassId = @Class69 AND Status = N'Taught';
    EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = @Enrollment69, @NewClassId = @Class69;
    SELECT @Joined69 = ClassJoinedOn FROM dbo.ENROLLMENT WHERE EnrollmentId = @Enrollment69;
    SET @Rate69 = dbo.fn_AttendanceRate(@Enrollment69);
    ROLLBACK;

    INSERT #Results VALUES ('T69', N'Transfer: attendance of the new class counts from the transfer day', N'Succeeded',
        CASE WHEN @Taught69 > 0 AND @Joined69 = dbo.fn_Today() AND @Rate69 IS NULL THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Enrollment69, N'?') + N' joined on ' + ISNULL(CONVERT(NVARCHAR(10), @Joined69, 23), N'?') + N' after '
        + CAST(ISNULL(@Taught69, 0) AS NVARCHAR(10)) + N' taught sessions => '
        + ISNULL(CAST(@Rate69 AS NVARCHAR(10)) + N'%', N'NULL (nothing to count yet)'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T69', N'Transfer: attendance of the new class counts from the transfer day', N'Succeeded', N'Error', ERROR_MESSAGE());
END CATCH;
GO

-- T71: evaluating a class makes the students who take no other class Completed
--      Proves the last step of usp_Class_EvaluateResults. Scenario, rolled back: the students of a finished class are
--      set back to Studying and the class is evaluated again. A student with no other Studying / On hold
--      enrollment must be Completed, the others (already in their next class) must stay Studying.
BEGIN TRY
    DECLARE @Class71 VARCHAR(10) = (SELECT TOP (1) ClassId FROM dbo.CLASS WHERE Status = N'Finished' ORDER BY ClassId);
    DECLARE @R71 TABLE (PassedCount INT, FailedCount INT);
    DECLARE @Wrong71 INT, @Completed71 INT, @Studying71 INT;
    BEGIN TRAN;
    UPDATE st SET Status = N'Studying' FROM dbo.STUDENT st
    WHERE EXISTS (SELECT 1 FROM dbo.ENROLLMENT en
                  WHERE en.StudentId = st.StudentId AND en.ClassId = @Class71 AND en.Status = N'Completed');
    INSERT @R71 EXEC dbo.usp_Class_EvaluateResults @ClassId = @Class71;
    SELECT @Wrong71 = SUM(CASE WHEN st.Status = x.Expected THEN 0 ELSE 1 END),
           @Completed71 = SUM(CASE WHEN st.Status = N'Completed' THEN 1 ELSE 0 END),
           @Studying71 = SUM(CASE WHEN st.Status = N'Studying' THEN 1 ELSE 0 END)
    FROM dbo.STUDENT st
    CROSS APPLY (SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.ENROLLMENT o
                                          WHERE o.StudentId = st.StudentId AND o.Status IN (N'Studying', N'On hold'))
                             THEN N'Studying' ELSE N'Completed' END AS Expected) x
    WHERE EXISTS (SELECT 1 FROM dbo.ENROLLMENT en
                  WHERE en.StudentId = st.StudentId AND en.ClassId = @Class71 AND en.Status = N'Completed');
    ROLLBACK;

    INSERT #Results VALUES ('T71', N'usp_Class_EvaluateResults: students without another class become Completed', N'Succeeded',
        CASE WHEN @Wrong71 = 0 AND @Completed71 > 0 AND @Studying71 > 0 THEN N'Succeeded' ELSE N'Wrong result' END,
        ISNULL(@Class71, N'?') + N': ' + CAST(ISNULL(@Completed71, 0) AS NVARCHAR(10)) + N' Completed, '
        + CAST(ISNULL(@Studying71, 0) AS NVARCHAR(10)) + N' still Studying, ' + CAST(ISNULL(@Wrong71, -1) AS NVARCHAR(10))
        + N' wrong');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('T71', N'usp_Class_EvaluateResults: students without another class become Completed', N'Succeeded', N'Error', ERROR_MESSAGE());
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

-- T66: every ID sequence stops at the largest number its code can hold
--      The DEFAULT of an ID pads the number to a fixed width (RIGHT('0000' + ..., 4) => EM0001), so the sequence
--      must end at 10^width - 1 (MAXVALUE 9999): the next number then fails instead of being cut to a code that
--      already exists. The width is read from the zeros of the DEFAULT definition (sys.default_constraints) and
--      compared as text (REPLICATE: no arithmetic overflow on rows the join has not filtered yet).
BEGIN TRY
    DECLARE @Bad66 TABLE (Name NVARCHAR(400));
    INSERT @Bad66
    SELECT sq.name + N' has MAXVALUE ' + CAST(sq.maximum_value AS NVARCHAR(20)) + N' for a code of '
           + CAST(w.Width AS NVARCHAR(5)) + N' digits'
    FROM sys.sequences sq
    JOIN sys.default_constraints dc
        ON CHARINDEX(N'[dbo].[' + sq.name COLLATE DATABASE_DEFAULT + N']', dc.definition COLLATE DATABASE_DEFAULT) > 0
    CROSS APPLY (SELECT dc.definition COLLATE DATABASE_DEFAULT AS Def) d   -- catalog text, database collation
    CROSS APPLY (SELECT CHARINDEX(N'right(''', d.Def) + 7 AS Start) s
    CROSS APPLY (SELECT CHARINDEX(N'''', d.Def, s.Start) - s.Start AS Width) w
    WHERE CAST(sq.maximum_value AS VARCHAR(20)) <> REPLICATE('9', w.Width)   -- 10^width - 1 = width nines
    UNION ALL
    SELECT sq.name + N' is not used by an ID default' FROM sys.sequences sq
    WHERE NOT EXISTS (SELECT 1 FROM sys.default_constraints dc
                      WHERE CHARINDEX(N'[dbo].[' + sq.name COLLATE DATABASE_DEFAULT + N']',
                                      dc.definition COLLATE DATABASE_DEFAULT) > 0);
    DECLARE @BadCount66 INT = (SELECT COUNT(*) FROM @Bad66);
    INSERT #Results VALUES ('T66', N'ID sequences end at the largest number their code can hold', N'Succeeded',
                            CASE WHEN @BadCount66 = 0 THEN N'Succeeded' ELSE N'Wrong result' END,
                            CASE WHEN @BadCount66 = 0
                                 THEN CAST((SELECT COUNT(*) FROM sys.sequences) AS NVARCHAR(10)) + N' sequences checked'
                                 ELSE LEFT(STUFF((SELECT N', ' + Name FROM @Bad66 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''), 400) END);
END TRY
BEGIN CATCH
    INSERT #Results VALUES ('T66', N'ID sequences end at the largest number their code can hold', N'Succeeded', N'Error', ERROR_MESSAGE());
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
--      USER_NAME() to the teacher, so the views return only the rows of TE0001. The counts are compared with
--      the classes and enrollments of that teacher counted by dbo in the base tables, and must be fewer than all
--      classes: a broken filter (no row, or every row) fails the case.
BEGIN TRY
    DECLARE @Teacher02 VARCHAR(10) = (SELECT TeacherId FROM dbo.ACCOUNT WHERE Username = N'gv_john');
    DECLARE @ExpectedClasses02 INT = (SELECT COUNT(*) FROM dbo.CLASS WHERE TeacherId = @Teacher02);
    DECLARE @ExpectedStudents02 INT = (SELECT COUNT(*) FROM dbo.ENROLLMENT en
                                       JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId WHERE cl.TeacherId = @Teacher02);
    DECLARE @AllClasses02 INT = (SELECT COUNT(*) FROM dbo.CLASS);
    EXECUTE AS USER = N'gv_john';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.vw_Teacher_MyClasses);
    DECLARE @st INT = (SELECT COUNT(*) FROM dbo.vw_Teacher_MyStudents);
    REVERT;
    INSERT #Results VALUES ('P02', N'Teacher SELECTs the views of their classes/students', N'Succeeded',
        CASE WHEN @n = @ExpectedClasses02 AND @st = @ExpectedStudents02 AND @n > 0 AND @n < @AllClasses02
             THEN N'Succeeded' ELSE N'Wrong result' END,
        CAST(@n AS NVARCHAR(10)) + N' classes, ' + CAST(@st AS NVARCHAR(10)) + N' students of '
        + ISNULL(@Teacher02, N'?') + N' (expected ' + CAST(@ExpectedClasses02 AS NVARCHAR(10)) + N' / '
        + CAST(@ExpectedStudents02 AS NVARCHAR(10)) + N')');
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
    BEGIN TRAN;
    EXECUTE AS USER = N'gv_john';
    EXEC dbo.usp_Grade_Save @EnrollmentId = @EnrollmentId, @ComponentId = @ComponentId, @Score = 9;
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P03', N'Teacher grades a class of another teacher', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P03', N'Teacher grades a class of another teacher', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P04: an accountant enrolls a student (DENY EXECUTE)
--      Proves DENY EXECUTE ON usp_Enrollment_Create TO rl_Accountant; the permission error names the procedure.
BEGIN TRY
    DECLARE @EnrollmentId VARCHAR(10);
    BEGIN TRAN;
    EXECUTE AS USER = N'kt_minh';
    EXEC dbo.usp_Enrollment_Create @StudentId = 'ST00071', @ClassId = 'CL0010', @EnrollmentId = @EnrollmentId OUTPUT;
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P04', N'Accountant enrolls a student', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
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
--      T07, so this error is a permission error. The case checks the error number 229 (permission denied): the
--      pattern %RECEIPT% alone would also match the message of that trigger. Concept: DENY as an explicit block
--      that a later GRANT cannot open.
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
    INSERT #Results VALUES ('P08', N'Manager DELETEs from the RECEIPT table', N'Rejected',
        CASE WHEN ERROR_NUMBER() = 229 THEN N'Rejected' ELSE N'Wrong error' END, ERROR_MESSAGE());
END CATCH;
GO

-- P09: academic staff create an account (no GRANT EXECUTE)
--      Proves usp_Account_Create is not available to rl_AcademicStaff: only rl_Manager has EXECUTE (through
--      GRANT EXECUTE ON SCHEMA::dbo). Concept: no GRANT = no access.
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Account_Create N'test_user', N'Test@12345', 'ACADEMIC_STAFF', 'EM0006', NULL;
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P09', N'Academic staff create a sign-in account', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
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
    BEGIN TRAN;
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Account_ChangePassword N'wrong-password', N'NewPassword@1';
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P12', N'Password change with a wrong current password', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P12', N'Password change with a wrong current password', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P13: changing one's own password without the current password (NULL)
--      Proves usp_Account_ChangePassword refuses a NULL current password (THROW 50066). Before this check the
--      NULL turned the whole ALTER USER text into NULL, sp_executesql ran nothing and the call reported success.
--      Rolled back in any case. Concept: NULL propagation in string concatenation (text + NULL = NULL).
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Account_ChangePassword NULL, N'NewPassword@1';
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P13', N'Password change without the current password', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P13', N'Password change without the current password', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P14: the manager changes the audit log (DENY UPDATE - even for the manager)
--      Proves DENY UPDATE ON AUDIT_LOG TO rl_Manager: the permission check (error 229) comes before the
--      INSTEAD OF trigger of T11, so the audit log has two independent guards. Concept: DENY on a table.
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'ql_quan';
    UPDATE dbo.AUDIT_LOG SET PerformedBy = N'someone else' WHERE LogId = (SELECT MIN(LogId) FROM dbo.AUDIT_LOG);
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P14', N'Manager UPDATEs the AUDIT_LOG table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P14', N'Manager UPDATEs the AUDIT_LOG table', N'Rejected',
        CASE WHEN ERROR_NUMBER() = 229 THEN N'Rejected' ELSE N'Wrong error' END, ERROR_MESSAGE());
END CATCH;
GO

-- P15: the manager deletes from the audit log (DENY DELETE - even for the manager)
--      Proves DENY DELETE ON AUDIT_LOG TO rl_Manager (error 229, before the INSTEAD OF trigger).
BEGIN TRY
    BEGIN TRAN;
    EXECUTE AS USER = N'ql_quan';
    DELETE FROM dbo.AUDIT_LOG WHERE LogId = (SELECT MIN(LogId) FROM dbo.AUDIT_LOG);
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P15', N'Manager DELETEs from the AUDIT_LOG table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P15', N'Manager DELETEs from the AUDIT_LOG table', N'Rejected',
        CASE WHEN ERROR_NUMBER() = 229 THEN N'Rejected' ELSE N'Wrong error' END, ERROR_MESSAGE());
END CATCH;
GO

-- P16: academic staff collect a payment (DENY EXECUTE)
--      Proves DENY EXECUTE ON usp_Receipt_Create TO rl_AcademicStaff; the permission error names the procedure.
BEGIN TRY
    DECLARE @Receipt16 VARCHAR(10);
    BEGIN TRAN;
    EXECUTE AS USER = N'gvu_lan';
    EXEC dbo.usp_Receipt_Create @EnrollmentId = 'EN000001', @Amount = 100000, @ReceiptId = @Receipt16 OUTPUT;
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P16', N'Academic staff collect a payment', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P16', N'Academic staff collect a payment', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P17: an accountant enters a grade (DENY EXECUTE)
--      Proves DENY EXECUTE ON usp_Grade_Save TO rl_Accountant; the permission error names the procedure.
BEGIN TRY
    DECLARE @Enrollment17 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0003'
                                         ORDER BY EnrollmentId);
    DECLARE @Component17 INT = (SELECT TOP (1) ComponentId FROM dbo.GRADE_COMPONENT WHERE CourseId = 'IE-55'
                                ORDER BY ComponentId);
    BEGIN TRAN;
    EXECUTE AS USER = N'kt_minh';
    EXEC dbo.usp_Grade_Save @EnrollmentId = @Enrollment17, @ComponentId = @Component17, @Score = 9;
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P17', N'Accountant enters a grade', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P17', N'Accountant enters a grade', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P18: a teacher reads the receipts (DENY SELECT)
--      Proves DENY SELECT ON RECEIPT TO rl_Teacher (error 229): teachers never see payments.
BEGIN TRY
    DECLARE @Count18 INT;
    BEGIN TRAN;
    EXECUTE AS USER = N'gv_john';
    SET @Count18 = (SELECT COUNT(*) FROM dbo.RECEIPT);
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P18', N'Teacher SELECTs the RECEIPT table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P18', N'Teacher SELECTs the RECEIPT table', N'Rejected',
        CASE WHEN ERROR_NUMBER() = 229 THEN N'Rejected' ELSE N'Wrong error' END, ERROR_MESSAGE());
END CATCH;
GO

-- P19: a teacher reads the payroll table (DENY SELECT)
--      Proves DENY SELECT ON PAYROLL TO rl_Teacher (error 229): a teacher sees only their own pay, through the
--      view vw_Teacher_MyPay. Concept: DENY on the table + a filtered view (ownership chaining).
BEGIN TRY
    DECLARE @Count19 INT;
    BEGIN TRAN;
    EXECUTE AS USER = N'gv_john';
    SET @Count19 = (SELECT COUNT(*) FROM dbo.PAYROLL);
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P19', N'Teacher SELECTs the PAYROLL table', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P19', N'Teacher SELECTs the PAYROLL table', N'Rejected',
        CASE WHEN ERROR_NUMBER() = 229 THEN N'Rejected' ELSE N'Wrong error' END, ERROR_MESSAGE());
END CATCH;
GO

-- P20: a teacher updates a session taught by another teacher
--      Proves the row-level rule of usp_Session_Update (THROW 50017): GRANT EXECUTE lets every teacher call it,
--      but the procedure compares the teacher of the session with fn_CurrentTeacherId().
BEGIN TRY
    DECLARE @Session20 INT = (SELECT TOP (1) SessionId FROM dbo.CLASS_SESSION
                              WHERE TeacherId <> (SELECT TeacherId FROM dbo.ACCOUNT WHERE Username = N'gv_john')
                              ORDER BY SessionId);
    BEGIN TRAN;
    EXECUTE AS USER = N'gv_john';
    EXEC dbo.usp_Session_Update @SessionId = @Session20, @Status = N'Taught';
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P20', N'Teacher updates a session of another teacher', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P20', N'Teacher updates a session of another teacher', N'Rejected', N'Rejected', ERROR_MESSAGE());
END CATCH;
GO

-- P21: a teacher takes attendance for a session of another teacher
--      Proves the row-level rule of usp_Attendance_Save (THROW 50040), with a session and an enrollment of CL0004
--      (in progress, taught by TE0005).
BEGIN TRY
    DECLARE @Session21 INT = (SELECT TOP (1) SessionId FROM dbo.CLASS_SESSION WHERE ClassId = 'CL0004'
                              ORDER BY SessionId);
    DECLARE @Enrollment21 VARCHAR(10) = (SELECT TOP (1) EnrollmentId FROM dbo.ENROLLMENT WHERE ClassId = 'CL0004'
                                         ORDER BY EnrollmentId);
    BEGIN TRAN;
    EXECUTE AS USER = N'gv_john';
    EXEC dbo.usp_Attendance_Save @SessionId = @Session21, @EnrollmentId = @Enrollment21, @Status = N'Present';
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P21', N'Teacher takes attendance for a session of another teacher', N'Rejected', N'Succeeded', NULL);
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Results VALUES ('P21', N'Teacher takes attendance for a session of another teacher', N'Rejected', N'Rejected', ERROR_MESSAGE());
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
