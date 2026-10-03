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

   What this file does:
     One procedure per business operation of the center (enroll a student, record a payment, close the
     results of a class...). The application, the seed script 07_seed_data.sql and the tests call these
     procedures, so every rule is checked in one place, whoever calls it.
     Run order: after 01_tables.sql, 02_functions.sql and 03_views.sql (the procedures use their objects)
     and before 06_security.sql (it GRANTs EXECUTE on them); scripts/db_init runs 00-07 in this order.

   Groups (the letter starts every header below) and their THROW numbers (.claude/rules/01-sql.md):
     A. Students ........................................... 50001-50009
     B. Classes, weekly schedules, sessions ................. 50010-50019
     C. Enrollment, class transfer .......................... 50020-50029
     D. Tuition receipts .................................... 50030-50039
     E. Placement tests, attendance, grades, results ........ 50040-50049
     F. Teacher payroll ..................................... 50050-50059
     G. Reports and statistics .............................. read only, no business error
     H. XML: XPath/XQuery, export/import .................... no business error
     I. Accounts (I1-I6) .................................... 50060-50069
        Backup (I7) ......................................... 50070-50079
     50099 is reserved for the test scripts. A procedure may reuse the number and message of another
     group when it reports the same thing (C1 reuses 50012 of group B for a missing class, E4 reuses
     50026 of group C for a missing enrollment).

   Header of each procedure:
     Used by : the C++ repository / screen, the roles with EXECUTE (06_security.sql) and the scripts and
               test cases that call it (12_tests.sql T../P.., 13_server_tests.sql S.., e2e = tst_e2e_gui).
               rl_Manager may run every procedure (GRANT EXECUTE ON SCHEMA::dbo).
     Rules / Steps / Returns : what the procedure checks and does, in plain words.
     Concepts : the course topics it shows (to name at the oral defense).
     The report (docs/report) quotes B3, C1, E5, F1, H1 and I1 word for word, so their step-by-step
     explanation is in the header above the procedure, never inside the body.

   Patterns you will meet (explained once here):
     - OUTPUT parameter + OUTPUT inserted.x INTO @New: the IDs (ST00001, EN000001...) come from a
       SEQUENCE in the column DEFAULT (01_tables.sql), so the procedure only knows the new ID after the
       INSERT. OUTPUT inserted.StudentId INTO @New copies the generated value into a table variable
       while the row is inserted; the procedure then copies it into its OUTPUT parameter.
       (SCOPE_IDENTITY() would only work for an IDENTITY column.)
     - SET XACT_ABORT ON + BEGIN TRY / BEGIN TRANSACTION ... COMMIT / BEGIN CATCH ... ROLLBACK; THROW;:
       several writes that must succeed together (all or nothing). With XACT_ABORT ON any run-time error
       leaves the transaction only able to roll back, so no half-written data can be committed.
       IF @@TRANCOUNT > 0 before ROLLBACK: a trigger that rejected the change (RAISERROR + ROLLBACK) has
       already closed the transaction. THROW; with no arguments re-raises the original error to the caller.
       A single INSERT/UPDATE is atomic by itself, so such procedures need no transaction (A1).
     - THROW 5xxxx: business errors (SQL Server 2012+). THROW always uses severity 16 and takes no format
       arguments, so a message with values is first built in @Msg. The statement before THROW must end
       with a semicolon. The English message is shown in the UI language through DbMessages.cpp.
       Triggers (05_triggers.sql) use RAISERROR + ROLLBACK TRANSACTION instead.
     - Ownership chaining: the procedures, views and tables all belong to dbo, so a role with only
       EXECUTE on a procedure reads and writes the tables through it without any table permission.
     - Row-level rules that GRANT cannot express: dbo.fn_CurrentRole() / fn_CurrentTeacherId() map the
       signed-in database user (USER_NAME()) to its ACCOUNT row, so a teacher only changes the sessions,
       attendance and grades of their own classes (B5, E2-E4) and only some roles see revenue (G1).
     - IF EXISTS (...) UPDATE ... ELSE INSERT ... ("upsert", B2, E2, E4, F1): save = change the row when
       it is there, add it otherwise.
     - Cursors (E5, F1): DECLARE ... CURSOR LOCAL FAST_FORWARD, OPEN, FETCH NEXT ... INTO,
       WHILE @@FETCH_STATUS = 0, CLOSE, DEALLOCATE (explained in the E5 header).
     - XML (H1-H5): .value() reads one value, .query() returns an XML fragment, .exist() tests a path,
       .nodes() turns repeated elements into rows (with CROSS APPLY), sql:variable("@x") reads a T-SQL
       variable inside XQuery, FOR XML PATH builds XML from rows.
     - Safe dynamic SQL (I1-I4, I7): a statement whose text depends on input (CREATE/ALTER USER with a
       name, DENY/GRANT CONNECT, the BACKUP chosen by @Type) is built as text and run by sys.sp_executesql.
       Values go in as parameters where SQL Server allows it (@f in I7); names are wrapped in QUOTENAME
       ([name], an inner ] is doubled) and a password literal has its quotes doubled with REPLACE, so the
       input can never end the name/string and append its own SQL (SQL injection).
     - WITH EXECUTE AS OWNER (I1, I2, I3, I7): the procedure runs as its owner dbo, so the caller only
       needs EXECUTE, not ALTER ANY USER or BACKUP DATABASE. Ownership chaining only covers DML and
       EXECUTE on objects, not DDL, BACKUP or dynamic SQL, hence this clause. Inside, USER_NAME() is dbo;
       ORIGINAL_LOGIN() is the real caller.
     - Result sets: some write procedures also end with a SELECT (B3, E1, E5, F1, H5); the seed script and
       the tests capture such a result with INSERT INTO @t EXEC dbo.usp_... .
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =====================================================================
   A. STUDENTS
   ===================================================================== */

/* A1. usp_Student_Add: add a student, return the new ID through an OUTPUT parameter
       Reference implementation of the team: copy its layout for a new write procedure.
       Used by: Students screen - Add (SqlStudentRepository::add); roles rl_Manager, rl_AcademicStaff;
                tests T01 (12_tests.sql), S08 (13_server_tests.sql), e2e academicStaff_searchAddDeleteStudent.
       Rules:   the name must not be empty (50001); the phone (50002) and the email (50003) must not belong
                to another student. These checks give a clear message; the filtered unique indexes
                UX_STUDENT_Phone / UX_STUDENT_Email remain the real guarantee. Age, guardian and contact
                rules are CHECK constraints of STUDENT (CK_STUDENT_Guardian, CK_STUDENT_Contact), so test
                T01 (a child without guardian) is rejected by the table itself.
       Concepts: OUTPUT parameter, OUTPUT inserted.x INTO a table variable, SEQUENCE default (ST00001...),
                 THROW for business errors, a single statement is atomic (no transaction needed). */
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

    -- 1. Check the business rules first (one THROW per rule, numbers of group A)
    IF LTRIM(RTRIM(ISNULL(@FullName, N''))) = N''
        THROW 50001, N'The student''s full name must not be empty.', 1;
    IF @Phone IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Phone = @Phone)
        THROW 50002, N'The phone number is already used by another student.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Email = @Email)
        THROW 50003, N'The email is already used by another student.', 1;

    -- 2. Insert the row. NULLIF turns an empty phone/email of the form into NULL (= not given); an empty
    --    string would break CK_STUDENT_Phone. StudentId is not listed: its DEFAULT takes the next value of
    --    seq_STUDENT, and OUTPUT inserted.StudentId INTO @New catches that value during the INSERT.
    DECLARE @New TABLE (StudentId VARCHAR(10));
    INSERT INTO dbo.STUDENT (FullName, DateOfBirth, Gender, Phone, Email, Address, Occupation,
                             GuardianName, GuardianPhone, BranchId, Notes, RegisteredOn)
    OUTPUT inserted.StudentId INTO @New
    VALUES (LTRIM(RTRIM(@FullName)), @DateOfBirth, @Gender, NULLIF(@Phone, ''), NULLIF(@Email, ''), @Address,
            @Occupation, @GuardianName, NULLIF(@GuardianPhone, ''), @BranchId, @Notes,
            ISNULL(@RegisteredOn, dbo.fn_Today()));

    -- 3. Hand the new ID back to the caller through the OUTPUT parameter
    SELECT @StudentId = StudentId FROM @New;
END;
GO

/* A2. usp_Student_Update: change the profile and the status of a student
       Used by: Students screen - Edit (SqlStudentRepository::update); roles rl_Manager, rl_AcademicStaff;
                e2e academicStaff_editStudent_savesToDatabase.
       Rules:   the student must exist (50004); the phone/email must not belong to ANOTHER student
                (StudentId <> @StudentId, so keeping one's own phone is fine). The new values are checked by
                the CHECK constraints of STUDENT (status, guardian, contact).
       Concepts: the A1 pattern for an UPDATE; a single statement, so no transaction. */
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

    -- 1. Business rules (same numbers and messages as A1, so the user sees the same text)
    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentId = @StudentId)
        THROW 50004, N'Student not found.', 1;
    IF @Phone IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Phone = @Phone AND StudentId <> @StudentId)
        THROW 50002, N'The phone number is already used by another student.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.STUDENT WHERE Email = @Email AND StudentId <> @StudentId)
        THROW 50003, N'The email is already used by another student.', 1;

    -- 2. Write every field in one UPDATE (empty phone/email => NULL, as in A1)
    UPDATE dbo.STUDENT
    SET FullName = LTRIM(RTRIM(@FullName)), DateOfBirth = @DateOfBirth, Gender = @Gender,
        Phone = NULLIF(@Phone, ''), Email = NULLIF(@Email, ''), Address = @Address,
        Occupation = @Occupation, GuardianName = @GuardianName, GuardianPhone = NULLIF(@GuardianPhone, ''),
        BranchId = @BranchId, Status = @Status, Notes = @Notes
    WHERE StudentId = @StudentId;
END;
GO

/* A3. usp_Student_Delete: only a student who never enrolled can be deleted
       Used by: Students screen - Delete (SqlStudentRepository::remove); roles rl_Manager, rl_AcademicStaff;
                e2e academicStaff_searchAddDeleteStudent; test T41 (a student with an enrollment history).
       Rules:   a student with any enrollment keeps the history (enrollments, receipts, grades point to it),
                so the message (50005) suggests the status Dropped out instead. The placement tests go first
                because FK_PLACEMENT_TEST_STUDENT (no ON DELETE CASCADE) would block deleting the student.
                Both deletes run in one transaction: if the student row cannot be deleted (an enrollment added
                meanwhile), the placement tests are not lost either.
       Concepts: FOREIGN KEY without cascade (children first), @@ROWCOUNT to detect "not found", multi-step
                 transaction (SET XACT_ABORT ON + TRY/CATCH). */
IF OBJECT_ID(N'dbo.usp_Student_Delete', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Delete;
GO
CREATE PROCEDURE dbo.usp_Student_Delete
    @StudentId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- 1. Refuse when the student has an enrollment history, or when there is no such student
    IF EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE StudentId = @StudentId)
        THROW 50005, N'The student has an enrollment history and cannot be deleted. Change the status to "Dropped out" instead.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentId = @StudentId)
        THROW 50004, N'Student not found.', 1;

    -- 2. Delete the child rows, then the student, together
    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM dbo.PLACEMENT_TEST WHERE StudentId = @StudentId;
        DELETE FROM dbo.STUDENT WHERE StudentId = @StudentId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* A4. usp_Student_Search: search by ID, name or phone; filter by branch/status
       Used by: Students screen - search box and filters (SqlStudentRepository::search); roles rl_Manager,
                rl_AcademicStaff, rl_Accountant (read only); 08_demo_queries.sql; e2e student search cases.
       Rules:   an empty keyword lists everyone; a NULL filter means all branches / all statuses. The
                collation Vietnamese_CI_AS ignores case (CI) but not accents (AS): a keyword typed without
                the tone marks does not find a name written with them.
       Concepts: optional parameters (@x IS NULL OR Col = @x), LIKE with %, a procedure reading a view
                 (vw_StudentOverview adds the number of active classes and the balance due). */
IF OBJECT_ID(N'dbo.usp_Student_Search', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_Search;
GO
CREATE PROCEDURE dbo.usp_Student_Search
    @Keyword   NVARCHAR(100) = NULL,
    @BranchId  VARCHAR(10)   = NULL,
    @Status    NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- One "contains" pattern (%keyword%) for every searched column; newest students first
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

/* A5. usp_Student_Details: one student with the full profile
       Used by: Students screen - Edit fills the form with this row (SqlStudentRepository::findById);
                roles rl_Manager, rl_AcademicStaff; e2e academicStaff_editStudent_savesToDatabase.
       Concepts: a read procedure on the table STUDENT, which academic staff cannot SELECT themselves
                 (no table GRANT): ownership chaining lets them read it through the procedure. */
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

/* B1. usp_Class_Create: open a new class; the tuition defaults to the course tuition
       Used by: 07_seed_data.sql (creates the demo classes); roles rl_Manager, rl_AcademicStaff.
       Rules:   the course must be Open (50010) and the teacher still Teaching (50011). The room must belong
                to the branch of the class and hold MaxStudents (trigger trg_CLASS_CheckRoom). A new class
                starts as Enrolling (DF_CLASS_Status); its sessions are created later by B2 + B3.
       Concepts: optional parameter with a computed default (@Tuition), OUTPUT inserted.ClassId INTO @New. */
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

    -- 1. Business rules
    IF NOT EXISTS (SELECT 1 FROM dbo.COURSE WHERE CourseId = @CourseId AND Status = N'Open')
        THROW 50010, N'The course does not exist or is no longer offered.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.TEACHER WHERE TeacherId = @TeacherId AND Status = N'Teaching')
        THROW 50011, N'The teacher does not exist or is no longer teaching.', 1;

    -- 2. No tuition given => the tuition of the course (a class may also get its own price)
    IF @Tuition IS NULL
        SELECT @Tuition = Tuition FROM dbo.COURSE WHERE CourseId = @CourseId;

    -- 3. Insert and return the generated ClassId (DEFAULT from seq_CLASS), same pattern as A1
    DECLARE @New TABLE (ClassId VARCHAR(10));
    INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
    OUTPUT inserted.ClassId INTO @New
    VALUES (@ClassName, @CourseId, @BranchId, @TeacherId, @RoomId, @StartDate, @MaxStudents, @Tuition);

    SELECT @ClassId = ClassId FROM @New;
END;
GO

/* B2. usp_ClassSchedule_Add: add a weekly time slot to a class
       (trigger trg_CLASS_SCHEDULE_CheckConflict checks room/teacher clashes)
       Used by: 07_seed_data.sql; roles rl_Manager, rl_AcademicStaff; test T08 (a busy room is rejected).
       Rules:   one slot per class and weekday (primary key ClassId + Weekday). Weekday is ISO
                (1 = Monday ... 7 = Sunday) and the hours must lie between 07:00 and 22:00
                (CK_CLASS_SCHEDULE_Weekday, CK_CLASS_SCHEDULE_Time). Sessions that already exist are not
                changed: B3 rebuilds them as long as no session has been taught or cancelled.
       Concepts: upsert (IF EXISTS UPDATE ELSE INSERT), a rule across rows checked by a trigger. */
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
    -- Save = change the slot of this weekday when it exists, add it otherwise. Either way the AFTER INSERT,
    -- UPDATE trigger rolls back a clash with another active class in the same room or with the same teacher.
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SCHEDULE WHERE ClassId = @ClassId AND Weekday = @Weekday)
        UPDATE dbo.CLASS_SCHEDULE SET StartTime = @StartTime, EndTime = @EndTime
        WHERE ClassId = @ClassId AND Weekday = @Weekday;
    ELSE
        INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime)
        VALUES (@ClassId, @Weekday, @StartTime, @EndTime);
END;
GO

/* B3. usp_Class_GenerateSessions: generate SessionCount sessions from the start date
       following the weekly schedule (WHILE loop over the days), update the end date.
       Used by: 07_seed_data.sql (every demo class); roles rl_Manager, rl_AcademicStaff; test T22.
       Rules:   the class must exist (50012) and have a weekly schedule (50013). It is refused once a session
                was taught or cancelled (50014), so the real history (attendance, payroll) is never deleted.
                The sessions get the room and teacher of the class; clashes were already checked on the weekly
                schedule (B2).
       Steps:   1. One SELECT reads several values into variables: the SessionCount of the course and the
                   start date, teacher and room of the class. When the class does not exist no row is read
                   and @SessionCount stays NULL - that is how "Class not found" is detected.
                2. Check the three rules above.
                3. In one transaction: delete the old (only Scheduled) sessions, then walk day by day from the
                   start date. dbo.fn_Weekday gives the ISO weekday of @Date (independent of SET DATEFIRST).
                   When the class has a slot that weekday, the SELECT reads one row (@@ROWCOUNT = 1) and a
                   session with the next number is inserted. The loop always ends because the schedule has at
                   least one weekday, and it stops when SessionCount sessions exist.
                4. Store the date of the last session as the class EndDate and commit.
                5. Return SessionsCreated and EndDate as a result set (the seed and T22 read it with
                   INSERT ... EXEC).
       Concepts: WHILE loop, variables assigned by SELECT, @@ROWCOUNT, multi-step transaction with
                 SET XACT_ABORT ON + TRY/CATCH + THROW; (see the file header), scalar function. */
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

/* B4. usp_Class_UpdateStatus: start or cancel a class (the life cycle Enrolling -> In progress -> Finished,
       or Cancelled)
       Used by: roles rl_Manager, rl_AcademicStaff; tests T42 (cancelling a class whose students paid), T54 (an
                invalid change), T55 (cancelling sets the enrollments to Left).
       Rules:   only two moves are made here (50019): Enrolling -> In progress, and Enrolling / In progress ->
                Cancelled. Finished is set by E5 after computing the results, and a finished or cancelled class
                never reopens (its grades and attendance are final, its room and teacher may be booked again).
                A class cannot be cancelled while some of its students hold a valid receipt (50015: refund or
                transfer them first); its other enrollments become Left, so they no longer count as debt and
                accept no payment.
       Concepts: a state machine checked in a procedure (allowed transitions), a rule across tables
                 (CLASS - ENROLLMENT - RECEIPT), multi-step transaction. */
IF OBJECT_ID(N'dbo.usp_Class_UpdateStatus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Class_UpdateStatus;
GO
CREATE PROCEDURE dbo.usp_Class_UpdateStatus
    @ClassId  VARCHAR(10),
    @Status   NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OldStatus NVARCHAR(20);

    -- 1. The class must exist and the move must be one of the two allowed ones
    SELECT @OldStatus = Status FROM dbo.CLASS WHERE ClassId = @ClassId;
    IF @OldStatus IS NULL
        THROW 50012, N'Class not found.', 1;
    IF NOT ((@OldStatus = N'Enrolling' AND @Status = N'In progress')
            OR (@OldStatus IN (N'Enrolling', N'In progress') AND @Status = N'Cancelled'))
        THROW 50019, N'A class can only move from Enrolling to In progress, or from Enrolling or In progress to Cancelled.', 1;

    -- 2. Cancelling is refused while money was collected for the class (valid receipts of its enrollments)
    IF @Status = N'Cancelled' AND EXISTS (SELECT 1 FROM dbo.RECEIPT rc
                                          JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
                                          WHERE en.ClassId = @ClassId AND rc.Status = N'Valid')
        THROW 50015, N'Some students of this class have paid tuition; refund or transfer them before cancelling the class.', 1;

    -- 3. Change the status; a cancelled class closes its open enrollments
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.CLASS SET Status = @Status WHERE ClassId = @ClassId;
        IF @Status = N'Cancelled'
            UPDATE dbo.ENROLLMENT SET Status = N'Left'
            WHERE ClassId = @ClassId AND Status IN (N'Studying', N'On hold');
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* B5. usp_Session_Update: the teacher confirms a session was taught / records its content
       Used by: roles rl_Manager, rl_AcademicStaff, rl_Teacher; test P20 (a teacher updates a session of
                another teacher).
       Rules:   a TEACHER account may only change the sessions it teaches (CLASS_SESSION.TeacherId = the
                teacher linked to the signed-in account, 50017); the other roles may change any session.
                The sessions of a Finished or Cancelled class are final (50018, like grades and attendance).
                A NULL description keeps the old one. Status values: CK_CLASS_SESSION_Status. The trigger
                trg_CLASS_SESSION_LockTaught refuses a future session marked Taught and a Taught session that
                changes its status, date, time, room or teacher; F1 pays the Taught sessions.
                Tests: P20, T50 and T51 (trigger), T56 (a finished class).
       Concepts: a row-level permission inside a procedure (fn_CurrentRole, fn_CurrentTeacherId),
                 ISNULL to keep the current value. */
IF OBJECT_ID(N'dbo.usp_Session_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Session_Update;
GO
CREATE PROCEDURE dbo.usp_Session_Update
    @SessionId    INT,
    @Status       NVARCHAR(20),
    @Description  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Read the teacher and the class status of the session; still NULL => the session does not exist
    DECLARE @SessionTeacherId VARCHAR(10), @ClassStatus NVARCHAR(20);
    SELECT @SessionTeacherId = se.TeacherId, @ClassStatus = cl.Status
    FROM dbo.CLASS_SESSION se JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
    WHERE se.SessionId = @SessionId;

    IF @SessionTeacherId IS NULL
        THROW 50016, N'Session not found.', 1;
    -- 2. A rule GRANT cannot express (it depends on the row): a teacher only updates their own sessions
    IF dbo.fn_CurrentRole() = 'TEACHER' AND @SessionTeacherId <> dbo.fn_CurrentTeacherId()
        THROW 50017, N'You can only update sessions you teach.', 1;
    IF @ClassStatus IN (N'Finished', N'Cancelled')
        THROW 50018, N'The sessions of a finished or cancelled class cannot be changed.', 1;

    -- 3. Save the status and, when given, the content of the lesson
    UPDATE dbo.CLASS_SESSION
    SET Status = @Status, Description = ISNULL(@Description, Description)
    WHERE SessionId = @SessionId;
END;
GO

/* =====================================================================
   C. ENROLLMENT
   ===================================================================== */

/* C1. usp_Enrollment_Create: enroll a student in a class (multi-step transaction)
       - The class must be enrolling/in progress and have free seats (the seats are checked by the trigger
         trg_ENROLLMENT_CheckCapacity during the INSERT, not by this procedure)
       - Entry requirement: passed the prerequisite course OR a high enough placement score
       - No schedule clash with another class the student is taking
       - Discount from the promotion
       Used by: 07_seed_data.sql (every demo enrollment); roles rl_Manager, rl_AcademicStaff (DENY EXECUTE to
                rl_Accountant, test P04); tests T03 (already enrolled), T04 (entry requirement), T05 (schedule
                clash), T15 (valid enrollment with a promotion).
       Steps:   1. Defaults: the enrollment date is today and the employee is the signed-in one
                   (fn_CurrentEmployeeId) when the caller passes NULL.
                2. The student must exist and not be Dropped out (50020).
                3. One SELECT reads the class and its course: tuition, status, prerequisite and minimum
                   placement score. Then: the class exists (50012), still accepts enrollments (50021), the
                   student is not in it yet (50022).
                4. Entry requirement (50023), only when the course has a prerequisite or a minimum score. It is
                   met when EITHER a Passed enrollment in a class of the prerequisite course exists OR the
                   LATEST placement test (TOP (1) ... ORDER BY TestDate DESC) reaches the minimum score. The
                   placement test only counts when the course sets a minimum score: with a prerequisite and no
                   minimum score, the prerequisite course is the only way in (test T33). The message contains
                   values, so it is built in @Msg first (THROW takes no format arguments); it only mentions the
                   placement score when the course has one.
                5. Schedule clash (50024): fn_StudentScheduleClash lists the Studying enrollments of the
                   student in an active class on the same weekday with overlapping hours and overlapping
                   periods (the same check as C2 and C3).
                6. A promotion code must exist and be valid on the enrollment date (50025); the discount comes
                   from fn_DiscountAmount (0 on a free class is a valid discount).
                7. In one transaction: insert the ENROLLMENT (TuitionDue = BaseTuition - DiscountAmount is a
                   computed column; the capacity trigger may roll back here), set a Prospective / On hold
                   student to Studying, commit, and return the new ID through the OUTPUT parameter.
       Concepts: multi-step transaction (SET XACT_ABORT ON + TRY/CATCH + THROW;), NOT EXISTS subqueries,
                 TOP (1) with ORDER BY, an inline table-valued function in EXISTS, scalar functions,
                 OUTPUT inserted.x INTO @New, a business rule that a CHECK constraint cannot express (it needs
                 other tables). */
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
            @Prerequisite VARCHAR(10), @MinScore DECIMAL(4,2), @Discount DECIMAL(12,0), @Msg NVARCHAR(2048);

    SET @EnrolledOn = ISNULL(@EnrolledOn, dbo.fn_Today());
    SET @EmployeeId = COALESCE(@EmployeeId, dbo.fn_CurrentEmployeeId());

    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentId = @StudentId AND Status <> N'Dropped out')
        THROW 50020, N'The student does not exist or has dropped out.', 1;

    SELECT @CourseId = cl.CourseId, @Tuition = cl.Tuition, @ClassStatus = cl.Status,
           @Prerequisite = co.PrerequisiteCourseId, @MinScore = co.MinPlacementScore
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
            WHERE pl.OverallScore >= @MinScore)
    BEGIN
        SET @Msg = N'The student does not meet the entry requirement of course ' + @CourseId
                 + CASE WHEN @MinScore IS NULL THEN N' (complete the prerequisite course first).'
                        ELSE N' (complete the prerequisite course or score at least '
                             + CAST(@MinScore AS NVARCHAR(10)) + N' in the placement test).' END;
        THROW 50023, @Msg, 1;
    END;

    -- No schedule clash with another class the student is taking
    IF EXISTS (SELECT 1 FROM dbo.fn_StudentScheduleClash(@StudentId, @ClassId, NULL))
        THROW 50024, N'The class schedule clashes with another class the student is taking.', 1;

    IF @PromotionId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.PROMOTION
                       WHERE PromotionId = @PromotionId AND @EnrolledOn BETWEEN StartDate AND EndDate)
        THROW 50025, N'The promotion code does not exist or has expired.', 1;
    SET @Discount = CASE WHEN @PromotionId IS NULL THEN 0
                         ELSE dbo.fn_DiscountAmount(@PromotionId, @Tuition, @EnrolledOn) END;

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
       keeping the payment history (ClassId is updated in one transaction).
       Used by: roles rl_Manager, rl_AcademicStaff; tests T14 (a class of another course is rejected), T34 (a
                class that clashes with another class of the student is rejected), T46 (the tuition of the new
                class applies), T47 (a student who paid more than the new tuition cannot move).
       Rules:   only a Studying / On hold enrollment can move (50026); the new class must be of the same course
                and still open, Enrolling / In progress (50027); the student must not be in it already (50022);
                its weekly schedule must not clash with another class the student is taking (50024,
                fn_StudentScheduleClash as in usp_Enrollment_Create, leaving out the enrollment that moves).
                The tuition follows the new class: BaseTuition becomes its tuition and the promotion of the
                enrollment is applied again (fn_DiscountAmount on the enrollment date). A student who already
                paid more than the new tuition due cannot move until a receipt is cancelled (50028), because
                AmountPaid may never exceed TuitionDue (CK_ENROLLMENT_AmountPaid).
                The enrollment row is kept (same EnrollmentId), so receipts and grades stay attached to it;
                only the attendance of the old class is removed. The capacity trigger
                (trg_ENROLLMENT_CheckCapacity) checks the new class because ClassId changes. An enrollment
                that was On hold becomes Studying, and so does the student.
       Concepts: UPDATE of a foreign key instead of delete + insert, DELETE with a JOIN, self-join of CLASS
                 (a = old class, b = new class), multi-step transaction. */
IF OBJECT_ID(N'dbo.usp_Enrollment_TransferClass', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_TransferClass;
GO
CREATE PROCEDURE dbo.usp_Enrollment_TransferClass
    @EnrollmentId  VARCHAR(10),
    @NewClassId    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OldClassId VARCHAR(10), @StudentId VARCHAR(10), @PromotionId VARCHAR(10), @EnrolledOn DATE,
            @AmountPaid DECIMAL(12,0), @NewTuition DECIMAL(12,0), @NewDiscount DECIMAL(12,0);

    -- 1. Read the active enrollment (old class, student, promotion, payments); still NULL => none
    SELECT @OldClassId = ClassId, @StudentId = StudentId, @PromotionId = PromotionId, @EnrolledOn = EnrolledOn,
           @AmountPaid = AmountPaid
    FROM dbo.ENROLLMENT
    WHERE EnrollmentId = @EnrollmentId AND Status IN (N'Studying', N'On hold');
    IF @OldClassId IS NULL
        THROW 50026, N'Active enrollment not found.', 1;
    -- 2. The new class: same course (self-join a = old, b = new), still open, student not enrolled there yet
    IF NOT EXISTS (SELECT 1 FROM dbo.CLASS a JOIN dbo.CLASS b ON a.CourseId = b.CourseId
                   WHERE a.ClassId = @OldClassId AND b.ClassId = @NewClassId
                     AND b.Status IN (N'Enrolling', N'In progress'))
        THROW 50027, N'A student can only be transferred to an open class of the same course.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE StudentId = @StudentId AND ClassId = @NewClassId)
        THROW 50022, N'The student is already enrolled in this class.', 1;

    -- 3. No schedule clash with the other classes of the student (same test as usp_Enrollment_Create; the
    --    enrollment that moves is left out, its old class no longer counts)
    IF EXISTS (SELECT 1 FROM dbo.fn_StudentScheduleClash(@StudentId, @NewClassId, @EnrollmentId))
        THROW 50024, N'The class schedule clashes with another class the student is taking.', 1;

    -- 4. The tuition of the new class, with the promotion of the enrollment applied again
    SELECT @NewTuition = Tuition FROM dbo.CLASS WHERE ClassId = @NewClassId;
    SET @NewDiscount = CASE WHEN @PromotionId IS NULL THEN 0
                            ELSE dbo.fn_DiscountAmount(@PromotionId, @NewTuition, @EnrolledOn) END;
    IF @AmountPaid > @NewTuition - @NewDiscount
        THROW 50028, N'The student has paid more than the tuition of the new class; cancel a receipt before the transfer.', 1;

    -- 5. Two writes that must succeed together (SET XACT_ABORT ON + TRY/CATCH, see the file header)
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Attendance in the old class means nothing for the new class
        -- (those rows would point to sessions of another class, which trg_ATTENDANCE_CheckClass forbids)
        DELETE at FROM dbo.ATTENDANCE at JOIN dbo.CLASS_SESSION se ON se.SessionId = at.SessionId
        WHERE at.EnrollmentId = @EnrollmentId AND se.ClassId = @OldClassId;

        UPDATE dbo.ENROLLMENT
        SET ClassId = @NewClassId, Status = N'Studying', BaseTuition = @NewTuition, DiscountAmount = @NewDiscount
        WHERE EnrollmentId = @EnrollmentId;

        UPDATE dbo.STUDENT SET Status = N'Studying' WHERE StudentId = @StudentId AND Status = N'On hold';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C3. usp_Enrollment_UpdateStatus: put on hold / leave / resume
       Used by: roles rl_Manager, rl_AcademicStaff; tests T52 (resuming into a schedule clash), T53 (a completed
                enrollment).
       Rules:   only Studying, On hold and Left are set here, and only on an enrollment that is not Completed
                (50029): Completed comes from usp_Class_EvaluateResults with the final grade. Resuming
                (Studying) checks the schedule clash like an enrollment (50024; the capacity trigger checks the
                free seats) and makes the student Studying again. When the enrollment becomes On hold or Left and
                the student has no other Studying enrollment, the student status follows: On hold => On hold,
                Left => Dropped out.
       Concepts: a state check before the write, NOT EXISTS, CASE inside SET, an inline table-valued function,
                 multi-step transaction. */
IF OBJECT_ID(N'dbo.usp_Enrollment_UpdateStatus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_UpdateStatus;
GO
CREATE PROCEDURE dbo.usp_Enrollment_UpdateStatus
    @EnrollmentId  VARCHAR(10),
    @Status        NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OldStatus NVARCHAR(20), @StudentId VARCHAR(10), @ClassId VARCHAR(10);

    -- 1. Read the enrollment; still NULL => wrong ID. Then the allowed change and, to resume, no clash
    SELECT @OldStatus = Status, @StudentId = StudentId, @ClassId = ClassId
    FROM dbo.ENROLLMENT WHERE EnrollmentId = @EnrollmentId;
    IF @OldStatus IS NULL
        THROW 50026, N'Enrollment not found.', 1;
    IF @OldStatus = N'Completed' OR @Status IS NULL OR @Status NOT IN (N'Studying', N'On hold', N'Left')
        THROW 50029, N'Only an enrollment that is not completed can be set to Studying, On hold or Left.', 1;
    IF @Status = N'Studying' AND @OldStatus <> N'Studying'
       AND EXISTS (SELECT 1 FROM dbo.fn_StudentScheduleClash(@StudentId, @ClassId, @EnrollmentId))
        THROW 50024, N'The class schedule clashes with another class the student is taking.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- 2. Change the enrollment
        UPDATE dbo.ENROLLMENT SET Status = @Status WHERE EnrollmentId = @EnrollmentId;

        -- 3. The student follows: Studying again on resume; On hold / Dropped out when no class is in
        --    progress any more (step 2 already ran, so this enrollment no longer counts in the NOT EXISTS)
        IF @Status = N'Studying'
            UPDATE dbo.STUDENT SET Status = N'Studying' WHERE StudentId = @StudentId AND Status <> N'Studying';
        ELSE
            UPDATE dbo.STUDENT SET Status = CASE @Status WHEN N'On hold' THEN N'On hold' ELSE N'Dropped out' END
            WHERE StudentId = @StudentId
              AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT x WHERE x.StudentId = @StudentId AND x.Status = N'Studying');
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C4. usp_Enrollment_ByClass: students of a class
       Used by: roles rl_Manager, rl_AcademicStaff, rl_Accountant.
       Returns: one row per enrollment of the class (every status) with a contact phone (the student's,
                else the guardian's), tuition due, amount paid, balance, status, final grade and result.
                TuitionDue is a computed column; AmountPaid is kept up to date by trg_RECEIPT_UpdateAmountPaid.
       Concepts: COALESCE (first non-NULL value), a calculated column in the SELECT list. */
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
       and blocks payments above the tuition due.
       Used by: roles rl_Manager, rl_Accountant (DENY EXECUTE to rl_AcademicStaff: they cannot collect money);
                tests T06 (payment above the tuition), T20 (payment, then cancellation), P16 (academic staff
                are refused).
       Rules:   a collecting employee is required (50030): the signed-in one (fn_CurrentEmployeeId) unless
                @EmployeeId is passed; the enrollment must exist and not be Left (50031); the amount must be
                > 0 (CK_RECEIPT_Amount). After the INSERT, trg_RECEIPT_UpdateAmountPaid recomputes AmountPaid
                and rolls back a payment above the tuition due; trg_RECEIPT_Audit writes an XML audit row.
       Concepts: a derived attribute kept by a trigger, OUTPUT inserted.ReceiptId INTO @New, default values. */
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
    -- 1. Who collects the money: the signed-in employee unless the caller names one; then the rules
    SET @EmployeeId = COALESCE(@EmployeeId, dbo.fn_CurrentEmployeeId());

    IF @EmployeeId IS NULL
        THROW 50030, N'The current account is not linked to an employee who can collect payments.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT WHERE EnrollmentId = @EnrollmentId AND Status <> N'Left')
        THROW 50031, N'Valid enrollment not found.', 1;

    -- 2. Insert with defaults (now, a standard description); the triggers then check and update the money
    DECLARE @New TABLE (ReceiptId VARCHAR(10));
    INSERT INTO dbo.RECEIPT (EnrollmentId, PaidAtUtc, Amount, PaymentMethod, CollectedByEmployeeId, Description)
    OUTPUT inserted.ReceiptId INTO @New
    VALUES (@EnrollmentId, ISNULL(@PaidAtUtc, GETUTCDATE()), @Amount, @PaymentMethod, @EmployeeId,
            ISNULL(@Description, N'Tuition payment'));

    SELECT @ReceiptId = ReceiptId FROM @New;
END;
GO

/* D2. usp_Receipt_Cancel: cancel a receipt (no physical delete - keeps the audit trail)
       Used by: roles rl_Manager, rl_Accountant; test T20.
       Rules:   a reason is required (50032, also CK_RECEIPT_CancelReason); only a Valid receipt can be
                cancelled (50033). The UPDATE fires trg_RECEIPT_UpdateAmountPaid (AmountPaid goes down again)
                and trg_RECEIPT_Audit. Deleting is impossible: trg_RECEIPT_PreventDelete (INSTEAD OF DELETE)
                and DENY DELETE ON RECEIPT to rl_Manager (06_security.sql).
       Concepts: logical delete (a status) instead of DELETE, @@ROWCOUNT. */
IF OBJECT_ID(N'dbo.usp_Receipt_Cancel', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Receipt_Cancel;
GO
CREATE PROCEDURE dbo.usp_Receipt_Cancel
    @ReceiptId  VARCHAR(10),
    @Reason     NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. A cancellation must say why
    IF LTRIM(RTRIM(ISNULL(@Reason, N''))) = N''
        THROW 50032, N'A reason is required to cancel a receipt.', 1;

    -- 2. Cancel only a Valid receipt; 0 rows => unknown ID or already cancelled
    UPDATE dbo.RECEIPT SET Status = N'Cancelled', CancelReason = @Reason
    WHERE ReceiptId = @ReceiptId AND Status = N'Valid';
    IF @@ROWCOUNT = 0
        THROW 50033, N'No valid receipt found to cancel.', 1;
END;
GO

/* D3. usp_Receipt_Print: data for printing a receipt
       Used by: roles rl_Manager, rl_Accountant.
       Returns: one row with the receipt, the student, class and course, the current balance of the
                enrollment, the employee who collected it and the branch header (name, address, phone).
       Concepts: a chain of INNER JOINs (every linked row must exist). */
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

/* E1. usp_PlacementTest_Add (a trigger recommends the matching course)
       Used by: roles rl_Manager, rl_AcademicStaff.
       Steps:   1. Insert the four skill scores (0-10, CK_PLACEMENT_TEST_Scores). OverallScore is a computed
                   column (the average of the four); trg_PLACEMENT_TEST_Recommend then fills
                   RecommendedCourseId with fn_RecommendCourse.
                2. Return the new TestId (OUTPUT parameter) and one row with the overall score and the
                   recommended course. C1 later compares the latest test with the course minimum.
       Concepts: computed PERSISTED column, AFTER INSERT trigger, OUTPUT inserted.TestId INTO @New,
                 LEFT JOIN (RecommendedCourseId stays NULL when no open course matches). */
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
    -- 1. Insert; the trigger sets RecommendedCourseId while this statement runs
    DECLARE @New TABLE (TestId VARCHAR(10));
    INSERT INTO dbo.PLACEMENT_TEST (StudentId, TestDate, ListeningScore, SpeakingScore, ReadingScore, WritingScore,
                                    GradedByTeacherId, Notes)
    OUTPUT inserted.TestId INTO @New
    VALUES (@StudentId, ISNULL(@TestDate, dbo.fn_Today()), @ListeningScore, @SpeakingScore, @ReadingScore,
            @WritingScore, @TeacherId, @Notes);

    -- 2. Return the ID, then read the row back to show what the trigger recommended
    SELECT @TestId = TestId FROM @New;
    SELECT pl.TestId, pl.OverallScore, pl.RecommendedCourseId, co.CourseName AS RecommendedCourse
    FROM dbo.PLACEMENT_TEST pl LEFT JOIN dbo.COURSE co ON co.CourseId = pl.RecommendedCourseId
    WHERE pl.TestId = @TestId;
END;
GO

/* E2. usp_Attendance_Save: save the attendance of one student at one session
       (a teacher only takes attendance for the sessions they teach)
       Used by: roles rl_Manager, rl_AcademicStaff, rl_Teacher; tests P21 (a teacher marks a session of another
                teacher), T44 (a session of a finished class).
       Rules:   a TEACHER account only marks the sessions it teaches (50040). The attendance of a Finished class
                is final, like its grades (50046): the results and certificates were computed from it (E5).
                The student must belong to the class of the session (trigger trg_ATTENDANCE_CheckClass);
                status values: CK_ATTENDANCE_Status.
                Only Present and Late count as present in fn_AttendanceRate (E5 needs 80%).
       Concepts: a row-level permission inside a procedure, upsert on a composite key (SessionId, EnrollmentId). */
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
    -- 1. A teacher may only mark the sessions they teach (a rule GRANT cannot express)
    IF dbo.fn_CurrentRole() = 'TEACHER'
       AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE SessionId = @SessionId
                                                         AND TeacherId = dbo.fn_CurrentTeacherId())
        THROW 50040, N'You can only take attendance for sessions you teach.', 1;
    -- 2. A finished class is closed: its results were computed from this attendance (same rule as grades, E4)
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SESSION se JOIN dbo.CLASS cl ON cl.ClassId = se.ClassId
               WHERE se.SessionId = @SessionId AND cl.Status = N'Finished')
        THROW 50046, N'The class has finished and its results are final; attendance can no longer be changed.', 1;

    -- 3. Save = update the mark when it exists, insert it otherwise
    IF EXISTS (SELECT 1 FROM dbo.ATTENDANCE WHERE SessionId = @SessionId AND EnrollmentId = @EnrollmentId)
        UPDATE dbo.ATTENDANCE SET Status = @Status, Notes = @Notes
        WHERE SessionId = @SessionId AND EnrollmentId = @EnrollmentId;
    ELSE
        INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status, Notes)
        VALUES (@SessionId, @EnrollmentId, @Status, @Notes);
END;
GO

/* E3. usp_Attendance_BySession: attendance list of a session (including students not marked yet)
       Used by: roles rl_Manager, rl_AcademicStaff, rl_Teacher.
       Returns: every Studying / Completed student of the class of the session; a student without a saved
                mark shows the default Present with IsSaved = 0.
       Concepts: LEFT JOIN keeps the students without a mark, ISNULL default, CASE for a 0/1 flag,
                 the same row-level rule as E2 (50040) for reading. */
IF OBJECT_ID(N'dbo.usp_Attendance_BySession', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Attendance_BySession;
GO
CREATE PROCEDURE dbo.usp_Attendance_BySession
    @SessionId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. A teacher only sees the attendance of their own sessions
    IF dbo.fn_CurrentRole() = 'TEACHER'
       AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE SessionId = @SessionId
                                                         AND TeacherId = dbo.fn_CurrentTeacherId())
        THROW 50040, N'You can only view the attendance of sessions you teach.', 1;

    -- 2. All students of the class (JOIN ENROLLMENT), with their mark when one exists (LEFT JOIN ATTENDANCE)
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
       (a teacher only grades their own classes; no changes after the class finished)
       Used by: roles rl_Manager, rl_AcademicStaff, rl_Teacher (DENY EXECUTE to rl_Accountant);
                tests T10 (a score of 11 is rejected by CK_GRADE_Score), P03 (a teacher grades the class
                of another teacher), T43 (a grade of a finished class), P17 (an accountant is refused).
       Rules:   the enrollment must exist (50026, the message of group C); a TEACHER only grades the classes
                whose CLASS.TeacherId is their own (50041); the grades of a Finished class are final (50042).
                The component must belong to the course of the class (trigger trg_GRADE_CheckComponent) and
                every change is logged as XML in AUDIT_LOG (trigger trg_GRADE_Audit).
       Concepts: a row-level permission, upsert, ORIGINAL_LOGIN() records who entered the score (it is also
                 the DEFAULT of GRADE.EnteredBy), audit trigger. */
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

    -- 1. Read the class of the enrollment (its teacher and status); still NULL => no such enrollment
    SELECT @ClassTeacherId = cl.TeacherId, @ClassStatus = cl.Status
    FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
    WHERE en.EnrollmentId = @EnrollmentId;

    IF @ClassTeacherId IS NULL
        THROW 50026, N'Enrollment not found.', 1;
    -- 2. A teacher only grades their own classes; nobody changes a grade once the results are final
    IF dbo.fn_CurrentRole() = 'TEACHER' AND @ClassTeacherId <> dbo.fn_CurrentTeacherId()
        THROW 50041, N'You can only enter grades for classes you teach.', 1;
    IF @ClassStatus = N'Finished'
        THROW 50042, N'The class has finished and its results are final; grades can no longer be changed.', 1;

    -- 3. Save = update the score (and who/when) when it exists, insert it otherwise (the DEFAULTs fill who/when)
    IF EXISTS (SELECT 1 FROM dbo.GRADE WHERE EnrollmentId = @EnrollmentId AND ComponentId = @ComponentId)
        UPDATE dbo.GRADE SET Score = @Score, EnteredAtUtc = GETUTCDATE(), EnteredBy = ORIGINAL_LOGIN()
        WHERE EnrollmentId = @EnrollmentId AND ComponentId = @ComponentId;
    ELSE
        INSERT INTO dbo.GRADE (EnrollmentId, ComponentId, Score) VALUES (@EnrollmentId, @ComponentId, @Score);
END;
GO

/* E5. usp_Class_EvaluateResults: end-of-course results for the whole class with a CURSOR.
       For each student: final grade + attendance rate; Passed when grade >= 5 and
       attendance >= 80%; a certificate is issued to students who passed.
       Running it again on a Finished class (after a correction) keeps the certificates in line with the new
       results: a student who now fails loses the certificate, a student who still passes gets the new grade.
       Used by: 07_seed_data.sql (closes the finished demo classes); roles rl_Manager, rl_AcademicStaff;
                tests T23, T35 (re-evaluation), T57 (sessions still scheduled).
       Steps:   1. The class must be In progress or Finished (50043), the weights of its course must add up
                   to 100% (view vw_CourseInvalidWeights, 50044) and no session may still be Scheduled (50047:
                   the attendance rate would leave them out and they could still be taught and paid after the
                   class is closed). Certificates are dated with the class EndDate, else today.
                2. Check first, write later: count the Studying / Completed students whose fn_FinalGrade is
                   still NULL (a grade component without a score) and stop with 50045; the message contains
                   the count, so it is built in @Msg.
                3. In one transaction a cursor walks the Studying / Completed enrollments one by one:
                   grade = fn_FinalGrade, attendance = fn_AttendanceRate (NULL while no session was taught,
                   then counted as 100), Passed when grade >= 5 AND attendance >= 80, else Failed. The
                   enrollment stores FinalGrade and Result and gets the status Completed.
                4. A student who passed and has no certificate yet gets one: serial EC<year>-<EnrollmentId>,
                   classification from fn_Classification; trg_CERTIFICATE_CheckResult checks Passed again.
                   A student who passed and already has one (re-evaluation) gets its grade and classification
                   updated; a student who failed loses an earlier certificate (only a Passed enrollment may
                   hold one - the trigger only checks new or changed certificates, not this case).
                5. Close the cursor, mark the class Finished (E4 then refuses grade changes), commit, and return
                   PassedCount / FailedCount (the seed and T23 read it with INSERT ... EXEC).
       Cursor:  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR <query>; OPEN cur; FETCH NEXT FROM cur INTO @var;
                WHILE @@FETCH_STATUS = 0 (0 = a row was read) BEGIN ...; FETCH NEXT ... END; CLOSE; DEALLOCATE.
                LOCAL: only this procedure sees the cursor; FAST_FORWARD: read-only and forward-only, the
                cheapest kind. Why a cursor: it shows the cursor topic of the syllabus, and each student goes
                through several steps; a set-based UPDATE + INSERT ... SELECT could give the same result.
       Concepts: cursor, multi-step transaction, scalar functions, a view used as a deferred check (SQL Server
                 has no deferred constraints), a trigger as a second safety net. */
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
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId AND Status = N'Scheduled')
        THROW 50047, N'The class still has scheduled sessions; mark them as taught or cancelled first.', 1;

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
                ELSE
                    UPDATE dbo.CERTIFICATE SET FinalGrade = @Grade, Classification = dbo.fn_Classification(@Grade)
                    WHERE EnrollmentId = @EnrollmentId AND FinalGrade <> @Grade;
            END
            ELSE
            BEGIN
                SET @FailedCount += 1;
                -- Failed after a re-evaluation: an earlier certificate is withdrawn
                DELETE FROM dbo.CERTIFICATE WHERE EnrollmentId = @EnrollmentId;
            END;

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
       Pay = hours taught x hourly rate; a 500,000 VND bonus for 20 sessions or more.
       Used by: 07_seed_data.sql (the last 2 months); roles rl_Manager, rl_Accountant; tests T24 (figures
                match the taught sessions), T25 (a future month is rejected), T58 (running it again removes a
                row that no longer has a taught session).
       Steps:   1. Refuse a future month (50050); DATEFROMPARTS builds the first day of that month, and
                   [@From, @To) is the month as a date range (a sargable filter on SessionDate).
                2. In one transaction a cursor reads one row per teacher who taught in that month (teachers
                   without a Taught session get no row): the number of Taught sessions, the hours
                   (SUM of DATEDIFF in minutes / 60) and the current hourly rate.
                3. Bonus 500,000 when the teacher taught 20 sessions or more.
                4. Upsert into PAYROLL (one row per teacher and month, UQ_PAYROLL_TeacherId_Month_Year): an
                   existing row is refreshed only while its status is Finalized - a Paid row is never changed;
                   otherwise a new row is inserted. After the loop, a Finalized row of a teacher who no longer
                   has a Taught session that month is deleted. Running the procedure again for a month is
                   therefore safe.
                5. Commit and return the payroll of the month. TotalPay is a computed column
                   (Hours x HourlyRate + Bonus - Deduction), never written by hand. The hourly rate is copied
                   into PAYROLL, so a later rate change does not alter old payslips.
       Concepts: cursor (explained in the E5 header) over a GROUP BY query, upsert, computed PERSISTED column,
                 multi-step transaction. */
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
            @Bonus DECIMAL(12,0), @TeacherCount INT = 0, @From DATE, @To DATE;

    SET @From = DATEFROMPARTS(@Year, @Month, 1);
    SET @To = DATEADD(MONTH, 1, @From);
    IF @From > dbo.fn_Today()
        THROW 50050, N'Payroll cannot be finalized for a future month.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE cur_Teacher CURSOR LOCAL FAST_FORWARD FOR
            SELECT te.TeacherId, te.HourlyRate, COUNT(se.SessionId),
                   CAST(SUM(DATEDIFF(MINUTE, se.StartTime, se.EndTime)) / 60.0 AS DECIMAL(6,2))
            FROM dbo.TEACHER te
            JOIN dbo.CLASS_SESSION se ON se.TeacherId = te.TeacherId
            WHERE se.Status = N'Taught' AND se.SessionDate >= @From AND se.SessionDate < @To
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

        -- A row finalized earlier whose sessions are no longer Taught (e.g. cancelled) must not stay
        DELETE py FROM dbo.PAYROLL py
        WHERE py.Month = @Month AND py.Year = @Year AND py.Status = N'Finalized'
          AND NOT EXISTS (SELECT 1 FROM dbo.CLASS_SESSION se
                          WHERE se.TeacherId = py.TeacherId AND se.Status = N'Taught'
                            AND se.SessionDate >= @From AND se.SessionDate < @To);

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
       RevenueThisMonth is NULL unless the caller is a manager/accountant.
       Used by: Dashboard screen (SqlStatisticsRepository, called without @BranchId); roles rl_Manager,
                rl_AcademicStaff, rl_Accountant; test P11; 08_demo_queries.sql; docs/report/tools/export_data.py.
       Returns: one row - students with a Studying enrollment (STUDENT.Status stays Studying after the last
                course is completed, so the enrollments are counted), classes In progress, classes Enrolling,
                revenue of this month
                (valid receipts paid between the start of this month and the start of next month in the
                center, as a UTC range), outstanding tuition (vw_OutstandingTuition) and today's sessions (not
                cancelled; "today" = fn_Today, the center's date); @BranchId NULL = the whole center.
       Concepts: scalar subqueries in one SELECT, optional filter (@BranchId IS NULL OR ...), hiding a value
                 by role with CASE (fn_CurrentRole: db_owner / sysadmin without an ACCOUNT row = MANAGER). */
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
    -- 1. Revenue is shown only to these two roles (role of the signed-in account, see fn_CurrentRole)
    DECLARE @CanSeeRevenue BIT = CASE WHEN dbo.fn_CurrentRole() IN ('MANAGER', 'ACCOUNTANT') THEN 1 ELSE 0 END;

    -- 2. One row of independent figures: each column is its own scalar subquery
    SELECT
        (SELECT COUNT(DISTINCT en.StudentId) FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
            WHERE en.Status = N'Studying' AND (@BranchId IS NULL OR st.BranchId = @BranchId)) AS ActiveStudents,
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

/* G2. usp_Report_Revenue: revenue per course between two dates (days of the center)
       Used by: roles rl_Manager, rl_Accountant.
       Returns: per branch, program and course the number of valid receipts and their total; both dates are
                included (whole days of the center); @BranchId NULL = all branches.
       Concepts: GROUP BY over a chain of joins, half-open range of UTC instants (>= start, < end) built from
                 local dates with fn_CenterTimeToUtc. */
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
    -- (the end bound is the start of the day AFTER @ToDate, used with "<", so a receipt paid late on @ToDate
    -- still counts while nothing of the next day does)
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

/* G3. usp_Report_ClassResults: final results of a class
       Used by: roles rl_Manager, rl_AcademicStaff.
       Returns: the Studying / Completed students with grade, classification, attendance, result and the
                certificate number, best grade first; the LEFT JOIN keeps the students without a certificate.
       Concepts: a procedure reading a view built on scalar functions (vw_LearningResults), LEFT JOIN. */
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
       (XQuery .exist() with sql:variable)
       Used by: roles rl_Manager, rl_AcademicStaff; 08_demo_queries.sql; docs/report/tools/export_data.py.
       Steps:   1. WHERE SyllabusXml.exist('/Syllabus/Unit[Skill = sql:variable("@Skill")]') = 1 keeps the
                   courses whose syllabus has at least one Unit with a Skill element equal to @Skill.
                   sql:variable lets the XQuery read the T-SQL parameter, so the value is never pasted into
                   the query text.
                2. .value('(/Syllabus/Textbook)[1]', 'NVARCHAR(200)') reads the first textbook; the [1] is
                   needed because .value() must return a single value.
                3. .value('count(...)', 'INT') counts the matching units with the XPath function count().
       Concepts: typed XML column (validated by the XML schema collection xsc_CourseSyllabus), XPath
                 predicate [ ], .exist(), .value(), sql:variable. */
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

/* H2. usp_Course_Syllabus: shred the XML syllabus into a relational result with .nodes()
       Used by: roles rl_Manager, rl_AcademicStaff, rl_Teacher; 08_demo_queries.sql;
                docs/report/tools/export_data.py.
       Returns: one row per Unit of the course: number, title, sessions and the skills as one text.
       Concepts: .nodes() + CROSS APPLY (shredding XML into rows), .value() of an attribute and of an element,
                 .query() with a FLWOR expression (for ... return ...), STUFF. */
IF OBJECT_ID(N'dbo.usp_Course_Syllabus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Course_Syllabus;
GO
CREATE PROCEDURE dbo.usp_Course_Syllabus
    @CourseId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    -- CROSS APPLY ... .nodes('/Syllabus/Unit') AS T(u) gives one row per Unit element; u is that element,
    -- so u.value('@No', ...) reads its attribute No and (Title)[1] its first Title child.
    -- Skills: the FLWOR loop returns one ", <skill>" string per Skill child; SQL Server joins the strings with
    -- a space (", Listening , Reading") and STUFF(..., 1, 2, '') removes the first 2 characters (", ").
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
       >= @MinScore (XQuery on the untyped XML profile)
       Used by: roles rl_Manager, rl_AcademicStaff; 08_demo_queries.sql.
       Rules:   a certificate of that type without a Score attribute also matches (empty(@Score) or ...).
       Concepts: untyped XML (no XML schema, unlike COURSE.SyllabusXml), .exist() with two sql:variable values
                 and the operators "and" / "or" in the predicate, .value() of an attribute, .query() returning
                 XML (the Specialty elements). */
IF OBJECT_ID(N'dbo.usp_Teacher_FindByCertificate', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Teacher_FindByCertificate;
GO
CREATE PROCEDURE dbo.usp_Teacher_FindByCertificate
    @CertificateType  NVARCHAR(20),
    @MinScore         DECIMAL(4,1) = 0
AS
BEGIN
    SET NOCOUNT ON;
    -- Inside the XQuery strings, @Type and @Score are XML attributes of <Certificate>; the T-SQL parameters
    -- are only reached through sql:variable("@CertificateType") / sql:variable("@MinScore").
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

/* H4. usp_Student_ExportXml: export students to XML (FOR XML PATH)
       Used by: roles rl_Manager, rl_AcademicStaff; 10_import_export.sql; test T26 (export, then import).
       Returns: one XML value <Students><Student StudentId=".." BranchId=".."><FullName>..</FullName>...
                </Student>...</Students>; @BranchId NULL = every branch.
       Concepts: FOR XML PATH('Student') = one element per row, ROOT('Students') = the outer element,
                 TYPE = the result is of type xml (not text); an alias starting with @ becomes an attribute,
                 the other columns child elements, and a NULL column produces no element. */
IF OBJECT_ID(N'dbo.usp_Student_ExportXml', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_ExportXml;
GO
CREATE PROCEDURE dbo.usp_Student_ExportXml
    @BranchId VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- The inner SELECT builds the whole document; the outer SELECT returns it as one column XmlData
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
       Rows with a duplicate phone/email are skipped; returns the number of imported rows.
       Used by: roles rl_Manager, rl_AcademicStaff; 10_import_export.sql; tests T26, T59 (duplicates inside the
                file, an empty name).
       Steps:   1. Shred the XML into the table variable @Source with .nodes('/Students/Student') and .value();
                   an empty FullName / Phone / Email / GuardianName / GuardianPhone becomes NULL (NULLIF; the
                   name is trimmed first), a missing Gender element becomes Other, a missing FullName or
                   DateOfBirth element gives NULL. RowNo numbers the elements, so one row per phone/email is kept.
                2. One INSERT ... SELECT in a transaction adds every row that has a name and a birth date,
                   whose phone/email no existing student uses and no row with a smaller RowNo uses either (the
                   first one wins; a filtered unique index would otherwise reject the whole statement). The
                   StudentId/BranchId attributes of the file are ignored: new IDs come from the sequence and
                   every row goes to @BranchId.
                3. Return ImportedRows and SkippedRows.
                The INSERT is one statement, so a row that breaks a constraint (for example a minor without
                guardian, CK_STUDENT_Guardian) makes the whole import fail and nothing is imported.
       Concepts: XML shredding (.nodes + .value), table variable, ROW_NUMBER() to keep the file order,
                 set-based INSERT ... SELECT with NOT EXISTS, @@ROWCOUNT, transaction. */
IF OBJECT_ID(N'dbo.usp_Student_ImportXml', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Student_ImportXml;
GO
CREATE PROCEDURE dbo.usp_Student_ImportXml
    @Data      XML,
    @BranchId  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Shred the XML: one row of @Source per <Student> element (x = that element)
    DECLARE @Source TABLE (
        RowNo INT, FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10), Phone VARCHAR(15),
        Email VARCHAR(100), GuardianName NVARCHAR(100), GuardianPhone VARCHAR(15));

    INSERT INTO @Source (RowNo, FullName, DateOfBirth, Gender, Phone, Email, GuardianName, GuardianPhone)
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
           NULLIF(LTRIM(RTRIM(x.value('(FullName)[1]', 'NVARCHAR(100)'))), N''),
           x.value('(DateOfBirth)[1]', 'DATE'),
           ISNULL(x.value('(Gender)[1]', 'NVARCHAR(10)'), N'Other'),
           NULLIF(x.value('(Phone)[1]', 'VARCHAR(15)'), ''),
           NULLIF(x.value('(Email)[1]', 'VARCHAR(100)'), ''),
           NULLIF(x.value('(GuardianName)[1]', 'NVARCHAR(100)'), ''),
           NULLIF(x.value('(GuardianPhone)[1]', 'VARCHAR(15)'), '')
    FROM @Data.nodes('/Students/Student') AS T(x);

    -- 2. Insert the valid rows in one set-based statement (no loop)
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.STUDENT (FullName, DateOfBirth, Gender, Phone, Email, GuardianName, GuardianPhone, BranchId)
        SELECT s.FullName, s.DateOfBirth, s.Gender, s.Phone, s.Email, s.GuardianName, s.GuardianPhone, @BranchId
        FROM @Source s
        WHERE s.FullName IS NOT NULL AND s.DateOfBirth IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.STUDENT x WHERE x.Phone = s.Phone OR x.Email = s.Email)
          AND NOT EXISTS (SELECT 1 FROM @Source e WHERE e.RowNo < s.RowNo AND (e.Phone = s.Phone OR e.Email = s.Email));
        -- 3. @@ROWCOUNT = rows inserted by the statement just above; read it at once (the next statement
        --    resets it), then report imported and skipped rows
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
       checked character by character and QUOTENAME'd against SQL injection in dynamic SQL.
       Used by: rl_Manager only (schema grant); 07_seed_data.sql (demo accounts), 13_server_tests.sql
                (temporary account t_lockout); tests P09 (academic staff are refused), P10 (the manager creates
                an account, rolled back).
       Steps:   1. Validate: the username matches the LIKE pattern (only letters a-z/A-Z without diacritics,
                   digits, dot and underscore) and has at least 3 characters (50060); the password has at
                   least 8 characters (50061); the name is neither a database principal (user or role) nor an
                   ACCOUNT row yet (50062); the employee or teacher has not left the center (50069, test T62).
                   The pattern is compared with the binary collation Latin1_General_BIN: under the database
                   collation Vietnamese_CI_AS the range a-z would also accept letters such as "ấ" or "đ"
                   (test T36).
                2. Map the role code stored in ACCOUNT.Role to its database role (CASE; NULL = unknown, 50063).
                3. In one transaction: insert the ACCOUNT row (CK_ACCOUNT_Owner: a TEACHER account needs
                   @TeacherId, the other roles @EmployeeId), then build and run with sys.sp_executesql:
                     CREATE USER [name] WITH PASSWORD = '...', DEFAULT_SCHEMA = dbo;
                     ALTER ROLE [role] ADD MEMBER [name];
                   CREATE USER cannot take the password as a parameter, so the literal is built with its quotes
                   doubled (REPLACE) and the names are wrapped in QUOTENAME. CREATE USER is transactional:
                   an error rolls back the new user and the ACCOUNT row together.
       Concepts: contained database user (password hashed by SQL Server, no server login), database roles,
                 EXECUTE AS OWNER, safe dynamic SQL (sp_executesql + QUOTENAME), a transaction around DDL. */
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

    IF @Username IS NULL OR @Username COLLATE Latin1_General_BIN LIKE N'%[^a-zA-Z0-9_.]%' OR LEN(@Username) < 3
        THROW 50060, N'A username may only contain letters without diacritics, digits, dots and underscores (at least 3 characters).', 1;
    IF LEN(ISNULL(@Password, N'')) < 8
        THROW 50061, N'The password must be at least 8 characters long.', 1;
    IF DATABASE_PRINCIPAL_ID(@Username) IS NOT NULL OR EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE Username = @Username)
        THROW 50062, N'The username already exists.', 1;
    IF EXISTS (SELECT 1 FROM dbo.EMPLOYEE WHERE EmployeeId = @EmployeeId AND Status = N'Left')
       OR EXISTS (SELECT 1 FROM dbo.TEACHER WHERE TeacherId = @TeacherId AND Status = N'Left')
        THROW 50069, N'An account cannot be created for an employee or teacher who has left.', 1;

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

/* I2. usp_Account_Lock: lock / unlock (DENY / GRANT the CONNECT permission)
       Used by: rl_Manager only; tests S14-S18 (13_server_tests.sql: real sign-ins before and after the lock,
                a manager cannot lock their own account, academic staff are refused).
       Rules:   @Lock must say lock (1) or unlock (0) - NULL is refused instead of meaning "unlock" (50068,
                test T45); the account must exist (50064); nobody locks the account they are signed in with
                (50065). Inside EXECUTE AS OWNER, USER_NAME() is dbo, so ORIGINAL_LOGIN() tells who really called.
                DENY CONNECT stops the user from signing in at all (DENY wins over GRANT); ACCOUNT.Status
                keeps the state for the Accounts list (I6). Both are written in one transaction (DENY/GRANT
                can be rolled back), so the permission and the status never disagree.
       Concepts: DENY / GRANT CONNECT, EXECUTE AS OWNER, ORIGINAL_LOGIN(), QUOTENAME in dynamic SQL. */
IF OBJECT_ID(N'dbo.usp_Account_Lock', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_Lock;
GO
CREATE PROCEDURE dbo.usp_Account_Lock
    @Username  NVARCHAR(50),
    @Lock      BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Sql NVARCHAR(400);
    -- 1. Rules
    IF @Lock IS NULL
        THROW 50068, N'Choose whether to lock or unlock the account.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE Username = @Username)
        THROW 50064, N'Account not found.', 1;
    IF @Username = ORIGINAL_LOGIN()
        THROW 50065, N'You cannot lock the account you are signed in with.', 1;

    -- 2. DENY / GRANT take no variable for the user name, hence dynamic SQL with QUOTENAME; then the status,
    --    both in one transaction
    SET @Sql = CASE WHEN @Lock = 1 THEN N'DENY CONNECT TO ' ELSE N'GRANT CONNECT TO ' END + QUOTENAME(@Username);
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sys.sp_executesql @Sql;
        UPDATE dbo.ACCOUNT SET Status = CASE WHEN @Lock = 1 THEN N'Locked' ELSE N'Active' END
        WHERE Username = @Username;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* I3. usp_Account_ResetPassword: the manager resets an employee's password
       Used by: rl_Manager only; test S19 (13_server_tests.sql: the account signs in with the new password and no
                longer with the old one).
       Rules:   the account must exist (50064); the new password has at least 8 characters (50061). Running as
                the owner, ALTER USER needs no OLD_PASSWORD (compare I4, which runs as the caller).
       Concepts: EXECUTE AS OWNER, ALTER USER ... WITH PASSWORD, quotes doubled in the password literal. */
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
    -- 1. Rules
    IF NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE Username = @Username)
        THROW 50064, N'Account not found.', 1;
    IF LEN(ISNULL(@NewPassword, N'')) < 8
        THROW 50061, N'The password must be at least 8 characters long.', 1;

    -- 2. ALTER USER takes no variable for the password: build the literal with doubled quotes and run it
    SET @Sql = N'ALTER USER ' + QUOTENAME(@Username)
             + N' WITH PASSWORD = N''' + REPLACE(@NewPassword, N'''', N'''''') + N''';';
    EXEC sys.sp_executesql @Sql;
END;
GO

/* I4. usp_Account_ChangePassword: users change their own password (runs as the caller;
       SQL Server requires the correct current password - OLD_PASSWORD)
       Used by: Change password dialog (SqlAuthGateway::changePassword); all four roles; tests P12, P13,
                e2e changePassword_wrongCurrentPassword_showsError.
       Rules:   no EXECUTE AS here: USER_NAME() must be the caller, and every user may change their own
                password when they give the current one. System errors become business messages:
                15151 (returned for a wrong OLD_PASSWORD) => 50066; 15114, 15115, 15116, 15118 (password
                policy) => 50067; any other error is re-raised unchanged by THROW;.
       Concepts: ALTER USER ... WITH PASSWORD ... OLD_PASSWORD, TRY/CATCH with ERROR_NUMBER(), THROW; (rethrow). */
IF OBJECT_ID(N'dbo.usp_Account_ChangePassword', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_ChangePassword;
GO
CREATE PROCEDURE dbo.usp_Account_ChangePassword
    @OldPassword  NVARCHAR(128),
    @NewPassword  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    -- 1. Length check here (clear message); SQL Server checks the old password and its policy in step 2
    IF LEN(ISNULL(@NewPassword, N'')) < 8
        THROW 50061, N'The password must be at least 8 characters long.', 1;
    -- A NULL current password would make the whole statement text NULL, and sp_executesql runs a NULL
    -- statement without any error - the call would "succeed" without changing anything (test P13)
    IF @OldPassword IS NULL
        THROW 50066, N'The current password is incorrect.', 1;

    -- 2. ALTER USER for the caller; both passwords become literals with doubled quotes
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

/* I5. usp_Account_RecordLogin: update the last sign-in time (called right after sign-in)
       Used by: Login dialog (SqlAuthGateway::login, right after the connection opens); all four roles.
       Returns: the row of vw_CurrentAccount (username, role code, employee/teacher, status, name, branch);
                the application builds its menu from the role. There is no row for an administrator without
                an ACCOUNT row (sa / db_owner); the application then checks db_owner itself.
       Concepts: USER_NAME() = the signed-in contained user. COLLATE DATABASE_DEFAULT: in a contained database
                 USER_NAME() returns text in the catalog collation (Latin1_General_100_CI_AS_KS_WS_SC), and
                 comparing it with a Vietnamese_CI_AS column without COLLATE fails with a collation conflict. */
IF OBJECT_ID(N'dbo.usp_Account_RecordLogin', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Account_RecordLogin;
GO
CREATE PROCEDURE dbo.usp_Account_RecordLogin
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Stamp the sign-in time (UTC), 2. return the account of the caller
    UPDATE dbo.ACCOUNT SET LastLoginAtUtc = GETUTCDATE() WHERE Username = USER_NAME() COLLATE DATABASE_DEFAULT;
    SELECT Username, Role, EmployeeId, TeacherId, Status, FullName, BranchId FROM dbo.vw_CurrentAccount;
END;
GO

/* I6. usp_Account_List: accounts with the role code (the application shows the localized role name and converts the
       UTC times to the user's time zone)
       Used by: Accounts screen (SqlListRepository, ListKind::Accounts; a manager-only feature in Permissions);
                rl_Manager only.
       Returns: every account with the name of its employee or teacher (two LEFT JOINs + COALESCE: an account
                belongs to exactly one of them), ordered by role (manager first), then by username.
       Concepts: LEFT JOIN, COALESCE, ORDER BY CASE for a custom order. */
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

/* I7. usp_Backup: FULL / DIFFERENTIAL / LOG backup into a folder on the SQL Server machine
       Used by: rl_Manager only; tests S04 (the manager backs up: the file passes RESTORE VERIFYONLY and is
                recorded in msdb), S05 (academic staff are refused), S06 (unknown type). The whole backup and
                restore chain is shown in 09_backup_restore.sql.
       Rules:   @Type is FULL, DIFF or LOG (50070; NULL is refused too, test S20). The current database is
                backed up (DB_NAME(), so a restored copy under another name backs up itself). The folder
                defaults to the server backup folder, else the data folder; the file is named
                <database>_<type>_<yyyymmdd_hhmmssmmm>.bak (.trn for LOG; the milliseconds keep two backups of
                the same second apart, WITH INIT would overwrite the first) and returned in @FilePath and as a
                result set. A LOG backup needs the FULL recovery model (00_create_database.sql) and an earlier
                FULL backup.
       Concepts: FULL / DIFFERENTIAL / LOG backups, EXECUTE AS OWNER (the caller needs no BACKUP DATABASE
                 permission), sp_executesql with a parameter (@f) for the file path, OUTPUT parameter. */
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
    -- File names carry the center's local time, the time people at the center recognize.
    -- Timestamp yyyymmdd_hhmmssmmm: style 121 gives yyyy-mm-dd hh:mi:ss.mmm, then - : . are removed and the
    -- space becomes _
    DECLARE @Sql NVARCHAR(MAX), @Database SYSNAME = DB_NAME(), @Timestamp VARCHAR(30) =
        REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(23), dbo.fn_UtcToCenterTime(GETUTCDATE()), 121),
                                        '-', ''), ':', ''), '.', ''), ' ', '_');

    -- 1. Only the three backup types (NOT IN is UNKNOWN for NULL, so NULL is tested on its own)
    IF @Type IS NULL OR @Type NOT IN ('FULL', 'DIFF', 'LOG')
        THROW 50070, N'The backup type must be FULL, DIFF or LOG.', 1;

    -- 2. Choose the folder (InstanceDefaultBackupPath may be NULL, then the data folder is used) and end it
    --    with the separator of the server: / on Linux, a backslash on Windows
    -- Default: the SQL Server backup folder (Linux/Docker: /var/opt/mssql/data)
    IF @Folder IS NULL
        SET @Folder = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF @Folder IS NULL
        SET @Folder = LEFT(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)), 260);
    IF RIGHT(@Folder, 1) NOT IN ('/', '\')
        SET @Folder += CASE WHEN CHARINDEX('/', @Folder) > 0 THEN '/' ELSE '\' END;

    -- 3. File name, then the BACKUP statement for the type; the path goes in as the parameter @f, not as text
    SET @FilePath = @Folder + @Database + N'_' + @Type + N'_' + @Timestamp
                  + CASE @Type WHEN 'LOG' THEN N'.trn' ELSE N'.bak' END;
    -- The database name is an identifier (QUOTENAME), the file path a parameter
    SET @Sql = CASE @Type
                   WHEN 'FULL' THEN N'BACKUP DATABASE ' + QUOTENAME(@Database) + N' TO DISK = @f WITH INIT, NAME = N''QLTTTA Full'''
                   WHEN 'DIFF' THEN N'BACKUP DATABASE ' + QUOTENAME(@Database) + N' TO DISK = @f WITH DIFFERENTIAL, INIT, NAME = N''QLTTTA Differential'''
                   ELSE             N'BACKUP LOG ' + QUOTENAME(@Database) + N' TO DISK = @f WITH INIT, NAME = N''QLTTTA Log'''
               END;
    EXEC sys.sp_executesql @Sql, N'@f NVARCHAR(400)', @f = @FilePath;
    SELECT @FilePath AS BackupFile;
END;
GO
