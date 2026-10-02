/* =====================================================================
   File   : 05_triggers.sql - Triggers
   Triggers enforce the integrity rules that CHECK/FOREIGN KEY cannot
   express (rules spanning several tables or rows, derived attributes)
   and write the audit trail. Every trigger works on SETS of rows
   (several rows in inserted/deleted), never assuming a single row.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* T1. trg_CLASS_CheckRoom (rule across CLASS - ROOM)
       - The room must belong to the same branch as the class
       - The class capacity cannot exceed the room capacity */
IF OBJECT_ID(N'dbo.trg_CLASS_CheckRoom', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_CLASS_CheckRoom;
GO
CREATE TRIGGER dbo.trg_CLASS_CheckRoom
ON dbo.CLASS
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.ROOM rm ON rm.RoomId = i.RoomId WHERE rm.BranchId <> i.BranchId)
    BEGIN
        RAISERROR (N'The room must belong to the same branch as the class.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.ROOM rm ON rm.RoomId = i.RoomId WHERE i.MaxStudents > rm.Capacity)
    BEGIN
        RAISERROR (N'The maximum class size exceeds the capacity of the room.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

/* T2. trg_CLASS_SCHEDULE_CheckConflict (rule across rows and tables)
       Two active classes whose periods overlap, on the same weekday with overlapping
       hours, cannot share the same room or the same teacher. */
IF OBJECT_ID(N'dbo.trg_CLASS_SCHEDULE_CheckConflict', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_CLASS_SCHEDULE_CheckConflict;
GO
CREATE TRIGGER dbo.trg_CLASS_SCHEDULE_CheckConflict
ON dbo.CLASS_SCHEDULE
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Msg NVARCHAR(400);

    SELECT TOP (1) @Msg = N'Schedule conflict with class ' + c2.ClassId
           + CASE WHEN c1.RoomId = c2.RoomId THEN N' (same room ' + c1.RoomId ELSE N' (same teacher ' + c1.TeacherId END
           + N').'
    FROM inserted i
    JOIN dbo.CLASS c1           ON c1.ClassId = i.ClassId
    JOIN dbo.CLASS_SCHEDULE cs  ON cs.Weekday = i.Weekday AND cs.ClassId <> i.ClassId
                               AND cs.StartTime < i.EndTime AND i.StartTime < cs.EndTime
    JOIN dbo.CLASS c2           ON c2.ClassId = cs.ClassId
    WHERE c2.Status IN (N'Enrolling', N'In progress')
      AND (c1.RoomId = c2.RoomId OR c1.TeacherId = c2.TeacherId)
      AND c2.StartDate <= ISNULL(c1.EndDate, DATEADD(MONTH, 6, c1.StartDate))
      AND c1.StartDate <= ISNULL(c2.EndDate, DATEADD(MONTH, 6, c2.StartDate));

    IF @Msg IS NOT NULL
    BEGIN
        RAISERROR (@Msg, 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T3. trg_ENROLLMENT_CheckCapacity: the number of enrolled students never exceeds the class size */
IF OBJECT_ID(N'dbo.trg_ENROLLMENT_CheckCapacity', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_ENROLLMENT_CheckCapacity;
GO
CREATE TRIGGER dbo.trg_ENROLLMENT_CheckCapacity
ON dbo.ENROLLMENT
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(ClassId) OR UPDATE(Status)) RETURN;

    DECLARE @ClassId VARCHAR(10);
    SELECT TOP (1) @ClassId = cl.ClassId
    FROM dbo.CLASS cl
    WHERE cl.ClassId IN (SELECT ClassId FROM inserted)
      AND (SELECT COUNT(*) FROM dbo.ENROLLMENT en
           WHERE en.ClassId = cl.ClassId AND en.Status IN (N'Studying', N'Completed')) > cl.MaxStudents;

    IF @ClassId IS NOT NULL
    BEGIN
        RAISERROR (N'Class %s is full.', 16, 1, @ClassId);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T4. trg_RECEIPT_UpdateAmountPaid (derived attribute across tables)
       ENROLLMENT.AmountPaid = SUM(RECEIPT.Amount) of the valid receipts.
       A payment above the tuition due is rejected => rollback. */
IF OBJECT_ID(N'dbo.trg_RECEIPT_UpdateAmountPaid', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_RECEIPT_UpdateAmountPaid;
GO
CREATE TRIGGER dbo.trg_RECEIPT_UpdateAmountPaid
ON dbo.RECEIPT
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.ENROLLMENT en
        JOIN (SELECT EnrollmentId, SUM(Amount) AS Total FROM dbo.RECEIPT
              WHERE Status = N'Valid'
                AND EnrollmentId IN (SELECT EnrollmentId FROM inserted UNION SELECT EnrollmentId FROM deleted)
              GROUP BY EnrollmentId) t ON t.EnrollmentId = en.EnrollmentId
        WHERE t.Total > en.TuitionDue)
    BEGIN
        RAISERROR (N'The amount exceeds the tuition the student still owes.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE en
    SET AmountPaid = ISNULL((SELECT SUM(rc.Amount) FROM dbo.RECEIPT rc
                             WHERE rc.EnrollmentId = en.EnrollmentId AND rc.Status = N'Valid'), 0)
    FROM dbo.ENROLLMENT en
    WHERE en.EnrollmentId IN (SELECT EnrollmentId FROM inserted UNION SELECT EnrollmentId FROM deleted);
END;
GO

/* T5. trg_RECEIPT_PreventDelete (INSTEAD OF DELETE): financial documents are never
       physically deleted, only cancelled with usp_Receipt_Cancel. */
IF OBJECT_ID(N'dbo.trg_RECEIPT_PreventDelete', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_RECEIPT_PreventDelete;
GO
CREATE TRIGGER dbo.trg_RECEIPT_PreventDelete
ON dbo.RECEIPT
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR (N'Receipts cannot be deleted. Use the Cancel receipt function instead.', 16, 1);
END;
GO

/* T6. trg_ATTENDANCE_CheckClass: the student must belong to the class of the session */
IF OBJECT_ID(N'dbo.trg_ATTENDANCE_CheckClass', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_ATTENDANCE_CheckClass;
GO
CREATE TRIGGER dbo.trg_ATTENDANCE_CheckClass
ON dbo.ATTENDANCE
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.CLASS_SESSION se ON se.SessionId = i.SessionId
               JOIN dbo.ENROLLMENT en    ON en.EnrollmentId = i.EnrollmentId
               WHERE en.ClassId <> se.ClassId)
    BEGIN
        RAISERROR (N'The student does not belong to the class of this session.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T7. trg_GRADE_CheckComponent: the grade component must belong to the course of the enrollment's class */
IF OBJECT_ID(N'dbo.trg_GRADE_CheckComponent', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_GRADE_CheckComponent;
GO
CREATE TRIGGER dbo.trg_GRADE_CheckComponent
ON dbo.GRADE
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.ENROLLMENT en       ON en.EnrollmentId = i.EnrollmentId
               JOIN dbo.CLASS cl            ON cl.ClassId = en.ClassId
               JOIN dbo.GRADE_COMPONENT gc  ON gc.ComponentId = i.ComponentId
               WHERE gc.CourseId <> cl.CourseId)
    BEGIN
        RAISERROR (N'The grade component does not belong to the course of the class.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T8. trg_GRADE_Audit: log every grade change (old/new data as XML) */
IF OBJECT_ID(N'dbo.trg_GRADE_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_GRADE_Audit;
GO
CREATE TRIGGER dbo.trg_GRADE_Audit
ON dbo.GRADE
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AUDIT_LOG (TableName, Action, RecordKey, OldData, NewData)
    SELECT N'GRADE',
           CASE WHEN i.EnrollmentId IS NOT NULL AND d.EnrollmentId IS NOT NULL THEN 'UPDATE'
                WHEN i.EnrollmentId IS NOT NULL THEN 'INSERT' ELSE 'DELETE' END,
           COALESCE(i.EnrollmentId, d.EnrollmentId) + N'/' + CAST(COALESCE(i.ComponentId, d.ComponentId) AS NVARCHAR(10)),
           (SELECT d.Score, d.EnteredBy FOR XML PATH('Grade'), TYPE),
           (SELECT i.Score, i.EnteredBy FOR XML PATH('Grade'), TYPE)
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.EnrollmentId = i.EnrollmentId AND d.ComponentId = i.ComponentId
    WHERE i.EnrollmentId IS NULL OR d.EnrollmentId IS NULL OR i.Score <> d.Score;
END;
GO

/* T9. trg_RECEIPT_Audit: log receipts being created/cancelled */
IF OBJECT_ID(N'dbo.trg_RECEIPT_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_RECEIPT_Audit;
GO
CREATE TRIGGER dbo.trg_RECEIPT_Audit
ON dbo.RECEIPT
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AUDIT_LOG (TableName, Action, RecordKey, OldData, NewData)
    SELECT N'RECEIPT',
           CASE WHEN d.ReceiptId IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
           i.ReceiptId,
           CASE WHEN d.ReceiptId IS NULL THEN NULL
                ELSE (SELECT d.EnrollmentId, d.Amount, d.Status FOR XML PATH('Receipt'), TYPE) END,
           (SELECT i.EnrollmentId, i.Amount, i.PaymentMethod, i.Status, i.CancelReason FOR XML PATH('Receipt'), TYPE)
    FROM inserted i
    LEFT JOIN deleted d ON d.ReceiptId = i.ReceiptId;
END;
GO

/* T10. trg_AUDIT_LOG_ReadOnly (INSTEAD OF UPDATE, DELETE): the audit log is append-only */
IF OBJECT_ID(N'dbo.trg_AUDIT_LOG_ReadOnly', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_AUDIT_LOG_ReadOnly;
GO
CREATE TRIGGER dbo.trg_AUDIT_LOG_ReadOnly
ON dbo.AUDIT_LOG
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR (N'The audit log is append-only; it cannot be changed or deleted.', 16, 1);
END;
GO

/* T11. trg_PLACEMENT_TEST_Recommend: recommend a course from the overall score automatically */
IF OBJECT_ID(N'dbo.trg_PLACEMENT_TEST_Recommend', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_PLACEMENT_TEST_Recommend;
GO
CREATE TRIGGER dbo.trg_PLACEMENT_TEST_Recommend
ON dbo.PLACEMENT_TEST
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(ListeningScore) OR UPDATE(SpeakingScore) OR UPDATE(ReadingScore) OR UPDATE(WritingScore)) RETURN;

    UPDATE pl
    SET RecommendedCourseId = dbo.fn_RecommendCourse(pl.OverallScore, NULL)
    FROM dbo.PLACEMENT_TEST pl
    JOIN inserted i ON i.TestId = pl.TestId;
END;
GO

/* T12. trg_CERTIFICATE_CheckResult: certificates are only issued to enrollments that Passed */
IF OBJECT_ID(N'dbo.trg_CERTIFICATE_CheckResult', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_CERTIFICATE_CheckResult;
GO
CREATE TRIGGER dbo.trg_CERTIFICATE_CheckResult
ON dbo.CERTIFICATE
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.ENROLLMENT en ON en.EnrollmentId = i.EnrollmentId
               WHERE ISNULL(en.Result, N'') <> N'Passed')
    BEGIN
        RAISERROR (N'Certificates are only issued to students who passed.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T13. trg_CLASS_SESSION_LockTaught: a taught session cannot change its date/time/room/teacher
        (keeps payroll and attendance data correct) */
IF OBJECT_ID(N'dbo.trg_CLASS_SESSION_LockTaught', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_CLASS_SESSION_LockTaught;
GO
CREATE TRIGGER dbo.trg_CLASS_SESSION_LockTaught
ON dbo.CLASS_SESSION
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.SessionId = i.SessionId
               WHERE d.Status = N'Taught'
                 AND (i.SessionDate <> d.SessionDate OR i.StartTime <> d.StartTime OR i.EndTime <> d.EndTime
                      OR i.TeacherId <> d.TeacherId OR i.RoomId <> d.RoomId))
    BEGIN
        RAISERROR (N'The date, time, room and teacher of a taught session cannot be changed.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO
