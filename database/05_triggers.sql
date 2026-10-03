/* =====================================================================
   File   : 05_triggers.sql - Triggers
   Triggers enforce the integrity rules that CHECK/FOREIGN KEY cannot
   express (rules spanning several tables or rows, derived attributes)
   and write the audit trail. Every trigger works on SETS of rows
   (several rows in inserted/deleted), never assuming a single row.

   Run order: scripts/db_init runs this file after 04_procedures.sql (it needs the tables of 01 and
   fn_RecommendCourse / fn_ClassPeriod of 02). Each trigger is dropped and created again, so the file can be re-run.
   A trigger fires for EVERY write to its table: from the procedures of 04, the seed data of 07, the
   test cases of 12_tests.sql, even a direct INSERT/UPDATE by dbo. That is why the rules live here and
   not only in the procedures.

   Key ideas for the oral defense:
     - inserted / deleted: two virtual tables with the new rows (INSERT, UPDATE) and the old rows
       (UPDATE, DELETE) of ONE statement. An UPDATE of 100 rows fires the trigger once with 100 rows,
       so every check joins inserted with the other tables (never SELECT @x = Col FROM inserted,
       which reads a single row).
     - AFTER trigger: runs after the change and after the constraints, sees the final data and can undo
       the whole statement with ROLLBACK TRANSACTION. INSTEAD OF trigger: runs in place of the
       statement, so the change never happens unless the trigger does it itself (T5, T10).
     - RAISERROR with severity 16 = a user error the application shows (the English message is
       translated through DbMessages); ROLLBACK TRANSACTION undoes the statement and the caller's
       transaction.
     - UPDATE(Col) is TRUE when the column is in the SET list of the UPDATE (always TRUE for an INSERT);
       it lets a trigger skip the work when the related columns did not change (T3, T11).
     - Why not a CHECK constraint: a CHECK only sees the columns of ONE row of ONE table. Rules that read
       other rows (capacity, schedule clashes), other tables (room branch, enrollment result) or the old
       values of a row (taught session) need a trigger.
   Each trigger header names the test cases of 12_tests.sql that prove its rule (test Tnn, Pnn);
   T1-T14 without the word test are the triggers of this file.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* T1. trg_CLASS_CheckRoom (rule across CLASS - ROOM)
       - The room must belong to the same branch as the class
       - The class capacity cannot exceed the room capacity
       Fired by: every INSERT/UPDATE of CLASS (usp_Class_Create, usp_Class_UpdateStatus, the EndDate
       written by usp_Class_GenerateSessions); tested by test T09 (a room of another branch).
       Why a trigger: BranchId and Capacity of the room are in another table (ROOM).
       How: AFTER INSERT, UPDATE; inserted (every new/changed class) is joined with ROOM, so a statement
       that changes many classes is checked as a whole. Two checks give two precise messages.
       The ROOM side (a smaller Capacity, another branch) is checked by T14 trg_ROOM_CheckClasses.
       Concepts: inter-table constraint, AFTER trigger, join with inserted, RAISERROR + ROLLBACK. */
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
       hours, cannot share the same room or the same teacher.
       Fired by: usp_ClassSchedule_Add (a weekly time slot); tested by test T08 (a busy room).
       Why a trigger: the new slot is compared with the slots of OTHER classes (other rows of
       CLASS_SCHEDULE), and room, teacher and dates come from CLASS.
       How it works (AFTER INSERT, UPDATE; set-based):
         - i = the new/changed slots, c1 = their class, cs = every slot of another class on the same
           weekday, c2 = that other class.
         - Two time ranges overlap when each one starts before the other ends
           (cs.StartTime < i.EndTime AND i.StartTime < cs.EndTime); 18:00-20:00 and 20:00-21:30 do not.
         - The other class must be active (Enrolling or In progress) and the two class periods must
           overlap; fn_ClassPeriod gives the period (a class without EndDate yet, set by
           usp_Class_GenerateSessions, is estimated as SessionCount weeks long - never too short).
         - SELECT TOP (1) @Msg = ... looks at ALL rows of inserted and keeps the first conflict only to
           build a readable message (which class, which room or teacher).
       Concepts: constraint across rows and tables, interval overlap, AFTER trigger, message built from
       values (a template with %1/%2 in DbMessages). */
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
    CROSS APPLY dbo.fn_ClassPeriod(c1.ClassId) p1
    CROSS APPLY dbo.fn_ClassPeriod(c2.ClassId) p2
    WHERE c2.Status IN (N'Enrolling', N'In progress')
      AND (c1.RoomId = c2.RoomId OR c1.TeacherId = c2.TeacherId)
      AND p2.StartDate <= p1.EndDate
      AND p1.StartDate <= p2.EndDate;

    IF @Msg IS NOT NULL
    BEGIN
        RAISERROR (@Msg, 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T3. trg_ENROLLMENT_CheckCapacity: the number of enrolled students never exceeds the class size
       Fired by: usp_Enrollment_Create (which has no seat check of its own and relies on this trigger),
       usp_Enrollment_TransferClass (new ClassId), usp_Enrollment_UpdateStatus (a student who resumes);
       tested by test T21 (a direct INSERT into a full class that bypasses the procedure).
       Why a trigger: the rule counts OTHER rows of ENROLLMENT and reads CLASS.MaxStudents.
       How: UPDATE(ClassId) OR UPDATE(Status) - only these columns change the head count, so an UPDATE of
       e.g. FinalGrade returns at once (both are TRUE for an INSERT). The count runs AFTER the change for
       every class found in inserted, with the statuses Studying and Completed (as fn_EnrolledCount);
       @ClassId only carries the first full class into the message.
       Not covered: lowering CLASS.MaxStudents below the current count is not checked.
       Concepts: aggregate constraint, UPDATE(col), AFTER trigger, correlated subquery. */
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
       A payment above the tuition due is rejected => rollback.
       Fired by: usp_Receipt_Create (new receipt), usp_Receipt_Cancel (Status Valid -> Cancelled lowers
       the total) and the seed receipts of 07; tested by tests T06 (overpayment) and T20 (pay, cancel).
       Why a trigger: AmountPaid is a DERIVED attribute stored in another table (ENROLLMENT). Storing it
       makes balances cheap to read in views and reports; the trigger keeps it equal to the receipts,
       whoever writes RECEIPT.
       How it works (AFTER INSERT, UPDATE; set-based):
         1. Affected enrollments = EnrollmentId of inserted UNION deleted (deleted = the old rows of an
            UPDATE, so a receipt moved to another enrollment updates both).
         2. If the new total of valid receipts of any of them is above TuitionDue => RAISERROR + ROLLBACK
            (CK_ENROLLMENT_AmountPaid would also fail, but with a technical message).
         3. Otherwise AmountPaid is recomputed from scratch (SUM, 0 when no valid receipt is left)
            instead of adding the new amount, so it can never drift away from the receipts.
       No DELETE event: receipts cannot be deleted (T5 trg_RECEIPT_PreventDelete).
       Concepts: derived attribute, inserted/deleted, set-based UPDATE ... FROM, AFTER trigger. */
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
       physically deleted, only cancelled with usp_Receipt_Cancel.
       Tested by test T07 (DELETE as dbo); test P08 shows the second layer, the DENY DELETE of 06_security.sql.
       Why INSTEAD OF: the trigger runs in place of the DELETE, so no row is ever removed; raising the
       error is enough (no ROLLBACK needed, nothing changed). Unlike a DENY it also stops dbo and
       sysadmin, who skip permission checks.
       Concepts: INSTEAD OF trigger, soft delete (Status Cancelled + CancelReason), defense in depth. */
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

/* T6. trg_ATTENDANCE_CheckClass: the student must belong to the class of the session
       Fired by: usp_Attendance_Save and the attendance rows of 07_seed_data.sql.
       Why a trigger: ATTENDANCE stores SessionId and EnrollmentId but no ClassId, so no foreign key can
       say "same class"; the rule compares ENROLLMENT.ClassId with CLASS_SESSION.ClassId.
       How: AFTER INSERT, UPDATE; every row of inserted is joined with its session and its enrollment.
       Concepts: inter-table constraint (two foreign-key paths must meet), join with inserted. */
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

/* T7. trg_GRADE_CheckComponent: the grade component must belong to the course of the enrollment's class
       Fired by: usp_Grade_Save and the grade rows of 07_seed_data.sql.
       Why a trigger: the paths GRADE -> ENROLLMENT -> CLASS -> COURSE and GRADE -> GRADE_COMPONENT ->
       COURSE must end at the same course; a foreign key only checks that the referenced row exists.
       How: AFTER INSERT, UPDATE; inserted is joined with three tables and the statement is rejected when
       any row points to a component of another course.
       Concepts: inter-table constraint, multi-table join with inserted. */
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

/* T8. trg_GRADE_Audit: log every grade change (old/new data as XML)
       Fired by: usp_Grade_Save (new or changed score), the seed grades of 07 and any DELETE of GRADE;
       query X9 of 08_demo_queries.sql reads the log back.
       How it works (ONE trigger for INSERT, UPDATE and DELETE):
         - FULL OUTER JOIN of inserted and deleted on the key (EnrollmentId, ComponentId) pairs the rows:
           both sides = UPDATE, only inserted = INSERT, only deleted = DELETE.
         - The WHERE skips an UPDATE that kept the same score (Score is NOT NULL, so <> is safe).
         - (SELECT ... FOR XML PATH('Grade'), TYPE) turns the old (d) or new (i) values into a small XML
           document <Grade><Score>..</Score><EnteredBy>..</EnteredBy></Grade>; NULL columns are left
           out, so the missing side of an INSERT/DELETE becomes an empty <Grade/>.
         - LoggedAtUtc and PerformedBy come from the defaults of AUDIT_LOG (GETUTCDATE(), ORIGINAL_LOGIN()).
       The log cannot be changed afterwards (T10 trg_AUDIT_LOG_ReadOnly + DENY in 06_security.sql).
       Concepts: audit trail, FULL OUTER JOIN of inserted/deleted, FOR XML PATH, XML column. */
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

/* T9. trg_RECEIPT_Audit: log receipts being created/cancelled
       Fired by: usp_Receipt_Create (INSERT row) and usp_Receipt_Cancel (UPDATE row); tested by test T20,
       which finds the new row with NewData.exist(...).
       How: AFTER INSERT, UPDATE; LEFT JOIN deleted on ReceiptId - no old row = INSERT (OldData stays
       NULL), an old row = UPDATE. No DELETE branch: T5 makes deleting impossible.
       Unlike T8, every UPDATE is logged, even one that changes nothing.
       Concepts: audit trail, LEFT JOIN of inserted/deleted, FOR XML PATH. */
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

/* T10. trg_AUDIT_LOG_ReadOnly (INSTEAD OF UPDATE, DELETE): the audit log is append-only
        Tested by test T11 (UPDATE as dbo). INSERT stays allowed: the audit triggers T8 and T9 add rows.
        Why INSTEAD OF: the UPDATE/DELETE is replaced by the error, so no row changes, even for dbo and
        sysadmin, who are not stopped by the DENY UPDATE, DELETE of 06_security.sql. TRUNCATE TABLE fires
        no trigger, but it needs ALTER permission on the table, which no business role has.
        Concepts: INSTEAD OF trigger, append-only log, defense in depth (trigger + DENY). */
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

/* T11. trg_PLACEMENT_TEST_Recommend: recommend a course from the overall score automatically
        Fired by: usp_PlacementTest_Add (which then returns the recommendation) and the seed placement
        tests of 07_seed_data.sql.
        Why a trigger: OverallScore is a computed column (average of the 4 skills) and the recommendation
        depends on the COURSE table (fn_RecommendCourse: the open course with the highest minimum score
        the student reached), so it is recomputed whenever a skill score is written.
        How: UPDATE(col) returns at once unless a skill score is in the statement (all TRUE for an
        INSERT); the UPDATE ... FROM joins PLACEMENT_TEST with inserted, so every new/changed test gets
        its course. That UPDATE does not fire the trigger again (the RECURSIVE_TRIGGERS database option
        is OFF), and it would return at once anyway since it writes no skill score.
        Concepts: derived value, UPDATE(col), scalar function in a set-based UPDATE ... FROM. */
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

/* T12. trg_CERTIFICATE_CheckResult: certificates are only issued to enrollments that Passed
        Fired by: usp_Class_EvaluateResults, which issues the certificates; tested by test T12 (a direct
        INSERT for a student who failed).
        Why a trigger: the result is stored in ENROLLMENT, not in CERTIFICATE.
        How: AFTER INSERT, UPDATE; inserted joined with ENROLLMENT. ISNULL(Result, '') also rejects an
        enrollment without a result yet (NULL <> 'Passed' is UNKNOWN, which would not count as a violation).
        Concepts: inter-table constraint, NULL handling (three-valued logic). */
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

/* T13. trg_CLASS_SESSION_LockTaught: a taught session stays taught and cannot change its
        date/time/room/teacher; a session is marked taught only once its day has come
        (keeps payroll and attendance data correct: usp_Payroll_Finalize pays the Taught sessions)
        Tested by tests T13 (moving the date of a taught session), T50 (marking a future session taught)
        and T51 (setting a taught session back to Scheduled).
        Why a trigger: the rules compare the OLD values (deleted) with the NEW values (inserted) of the
        same row; a CHECK constraint only sees the new values. They hold for every writer, also a direct
        UPDATE by a manager.
        How: AFTER UPDATE only; inserted and deleted are joined on SessionId, and the old status
        (d.Status) decides whether the session was already taught. Three checks, three messages:
          1. a Taught session keeps its date, time, room and teacher;
          2. a Taught session keeps its status (setting it back to Scheduled would unlock rule 1 and let
             usp_Class_GenerateSessions delete it together with its attendance);
          3. a session becomes Taught only on or after its date (dbo.fn_Today: the center's day), so a
             future session is not paid in advance. The Description may still change.
        Concepts: transition constraint (old vs new values), join of inserted with deleted. */
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
        RETURN;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.SessionId = i.SessionId
               WHERE d.Status = N'Taught' AND i.Status <> N'Taught')
    BEGIN
        RAISERROR (N'A taught session cannot change its status.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.SessionId = i.SessionId
               WHERE i.Status = N'Taught' AND d.Status <> N'Taught' AND i.SessionDate > dbo.fn_Today())
    BEGIN
        RAISERROR (N'A session can only be marked as taught on or after its date.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

/* T14. trg_ROOM_CheckClasses (rule across ROOM - CLASS, seen from the room)
        A room used by an active class (Enrolling / In progress) stays in the branch of that class and keeps a
        capacity of at least the class size: rule 2 of docs/DATABASE.md, which T1 checks when a CLASS row changes.
        Fired by: a direct UPDATE of ROOM (managers hold UPDATE on the catalog tables, 06_security.sql);
        tested by test T61 (a capacity below the size of a class in progress).
        Why a trigger: the rule reads the CLASS rows that use the room.
        How: AFTER UPDATE; it returns at once unless BranchId or Capacity is in the SET list, then joins
        inserted (every changed room) with the active classes of those rooms. A finished class keeps its
        history: a later, smaller capacity does not concern it.
        Concepts: the same inter-table rule guarded from both tables, UPDATE(col), join with inserted. */
IF OBJECT_ID(N'dbo.trg_ROOM_CheckClasses', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_ROOM_CheckClasses;
GO
CREATE TRIGGER dbo.trg_ROOM_CheckClasses
ON dbo.ROOM
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(BranchId) OR UPDATE(Capacity)) RETURN;

    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.CLASS cl ON cl.RoomId = i.RoomId
               WHERE cl.Status IN (N'Enrolling', N'In progress')
                 AND (cl.BranchId <> i.BranchId OR cl.MaxStudents > i.Capacity))
    BEGIN
        RAISERROR (N'The room is used by an active class: it must stay in the branch of the class and hold its maximum size.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO
