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
        (B6-B8: changing a class, removing a slot) .......... 50080-50089
     C. Enrollment, class transfer .......................... 50020-50029
     D. Tuition receipts .................................... 50030-50039
     E. Placement tests, attendance, grades, results ........ 50040-50049
     F. Teacher payroll ..................................... 50050-50059
     G. Reports and statistics .............................. read only, no business error
     H. XML: XPath/XQuery, export/import .................... no business error
     I. Accounts (I1-I6) .................................... 50060-50069
        Backup (I7) ......................................... 50070-50079
     J. Catalogs: branches, rooms, programs, courses, grade
        components, employees, teachers, promotions ......... 50090-50098
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
                tests T01 (12_tests.sql), S08 (13_server_tests.sql),
                e2e academicStaff_studentsFlow_searchesAddsAndDeletes.
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
                e2e academicStaff_studentsFlow_searchesAddsAndDeletes;
                test T41 (a student with an enrollment history).
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
       Used by: Classes screen - New class (SqlClassRepository::add), 07_seed_data.sql (creates the demo
                classes); roles rl_Manager, rl_AcademicStaff; tests T122 (a suspended branch), T123 (a room under
                maintenance).
       Rules:   the course must be Open (50010), the teacher still Teaching (50011), the branch Active (50085)
                and the room not under maintenance (50084). The room must belong to the branch of the class and
                hold MaxStudents (trigger trg_CLASS_CheckRoom). A new class starts as Enrolling
                (DF_CLASS_Status); its sessions are created later by B2 + B3.
       Steps:   the checks run in a transaction that keeps the course, teacher and branch rows locked
                (UPDLOCK, HOLDLOCK) until COMMIT. J8, J15 and J2 take the same locks before they discontinue the
                course, let the teacher leave or suspend the branch, so a class can never be opened on something
                that is being closed at the same moment (each side waits for the other, then sees its result).
       Concepts: optional parameter with a computed default (@Tuition), OUTPUT inserted.ClassId INTO @New,
                 pessimistic locking (UPDLOCK, HOLDLOCK), THROW inside TRY. */
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
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- 1. Business rules, on rows locked until COMMIT
        IF NOT EXISTS (SELECT 1 FROM dbo.COURSE WITH (UPDLOCK, HOLDLOCK)
                       WHERE CourseId = @CourseId AND Status = N'Open')
            THROW 50010, N'The course does not exist or is no longer offered.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.TEACHER WITH (UPDLOCK, HOLDLOCK)
                       WHERE TeacherId = @TeacherId AND Status = N'Teaching')
            THROW 50011, N'The teacher does not exist or is no longer teaching.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.BRANCH WITH (UPDLOCK, HOLDLOCK)
                       WHERE BranchId = @BranchId AND Status = N'Active')
            THROW 50085, N'The branch does not exist or is suspended.', 1;
        IF EXISTS (SELECT 1 FROM dbo.ROOM WHERE RoomId = @RoomId AND Status = N'Maintenance')
            THROW 50084, N'The room is under maintenance; choose another room.', 1;

        -- 2. No tuition given => the tuition of the course (a class may also get its own price)
        IF @Tuition IS NULL
            SELECT @Tuition = Tuition FROM dbo.COURSE WHERE CourseId = @CourseId;

        -- 3. Insert and return the generated ClassId (DEFAULT from seq_CLASS), same pattern as A1
        DECLARE @New TABLE (ClassId VARCHAR(10));
        INSERT INTO dbo.CLASS (ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, MaxStudents, Tuition)
        OUTPUT inserted.ClassId INTO @New
        VALUES (@ClassName, @CourseId, @BranchId, @TeacherId, @RoomId, @StartDate, @MaxStudents, @Tuition);

        SELECT @ClassId = ClassId FROM @New;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* B2. usp_ClassSchedule_Add: add a weekly time slot to a class
       (trigger trg_CLASS_SCHEDULE_CheckConflict checks room/teacher clashes)
       Used by: Classes screen - Weekly schedule (SqlClassRepository::saveSlot), 07_seed_data.sql; roles
                rl_Manager, rl_AcademicStaff; tests T08 (a busy room is rejected), T75 (a finished class), T105
                (a slot that clashes with another class of an enrolled student), T124 (a class with taught
                sessions), T125 (the generated sessions are removed).
       Rules:   only a class that is Enrolling or In progress gets new slots (50080: the timetable of a
                finished or cancelled class is history). One slot per class and weekday (primary key
                ClassId + Weekday). Weekday is ISO (1 = Monday ... 7 = Sunday) and the hours must lie
                between 07:00 and 22:00 (CK_CLASS_SCHEDULE_Weekday, CK_CLASS_SCHEDULE_Time). The new slot must
                not clash with another class of a student who studies in this class (50024, the same check as
                C1 and B6). The weekly timetable is the plan the sessions are generated from, so the two always
                agree: once a session was taught or cancelled the timetable is fixed (50086), and before that a
                change removes the generated sessions (and EndDate, like B6) - the screen generates them again.
       Concepts: upsert (IF EXISTS UPDATE ELSE INSERT), a rule across rows checked by a trigger, CROSS APPLY of
                 an inline table-valued function, THROW inside TRY (the CATCH rolls back and re-raises it). */
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
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.CLASS WHERE ClassId = @ClassId AND Status IN (N'Enrolling', N'In progress'))
        THROW 50080, N'Only an enrolling or in-progress class can be changed.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId AND Status <> N'Scheduled')
        THROW 50086, N'The weekly schedule of a class with taught or cancelled sessions can no longer change.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- 1. The generated sessions (all still Scheduled) follow the old timetable: remove them with EndDate, B3
        --    generates them again. Without EndDate the checks below use the estimated period (fn_ClassPeriod).
        DELETE FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId;
        UPDATE dbo.CLASS SET EndDate = NULL WHERE ClassId = @ClassId AND EndDate IS NOT NULL;

        -- 2. Save = change the slot of this weekday when it exists, add it otherwise. Either way the AFTER INSERT,
        --    UPDATE trigger rolls back a clash with another active class in the same room or with the same teacher.
        IF EXISTS (SELECT 1 FROM dbo.CLASS_SCHEDULE WITH (UPDLOCK, HOLDLOCK)
                   WHERE ClassId = @ClassId AND Weekday = @Weekday)
            UPDATE dbo.CLASS_SCHEDULE SET StartTime = @StartTime, EndTime = @EndTime
            WHERE ClassId = @ClassId AND Weekday = @Weekday;
        ELSE
            INSERT INTO dbo.CLASS_SCHEDULE (ClassId, Weekday, StartTime, EndTime)
            VALUES (@ClassId, @Weekday, @StartTime, @EndTime);

        -- 3. The students of the class must not get a clash with their other classes (fn_StudentScheduleClash
        --    reads the slots just written, inside the same transaction)
        IF EXISTS (SELECT 1 FROM dbo.ENROLLMENT en
                   CROSS APPLY dbo.fn_StudentScheduleClash(en.StudentId, en.ClassId, en.EnrollmentId) c
                   WHERE en.ClassId = @ClassId AND en.Status = N'Studying')
            THROW 50024, N'The class schedule clashes with another class the student is taking.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* B3. usp_Class_GenerateSessions: generate SessionCount sessions from the start date
       following the weekly schedule (WHILE loop over the days), update the end date.
       Used by: Classes screen - Generate sessions (SqlClassRepository::generateSessions), 07_seed_data.sql
                (every demo class); roles rl_Manager, rl_AcademicStaff; test T22.
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
       Used by: Classes screen - Start / Cancel (SqlClassRepository::changeStatus); roles rl_Manager,
                rl_AcademicStaff; tests T42 (cancelling a class whose students paid), T54 (an
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
       Used by: Timetable & attendance and Teaching schedule screens - Update session
                (SqlSessionRepository::update); roles rl_Manager, rl_AcademicStaff, rl_Teacher; test P20 (a teacher
                updates a session of another teacher).
       Rules:   a TEACHER account may only change the sessions it teaches (CLASS_SESSION.TeacherId = the
                teacher linked to the signed-in account, 50017); the other roles may change any session.
                The sessions of a Finished or Cancelled class are final (50018, like grades and attendance).
                A NULL description keeps the old one, an empty one removes it (the screen sends the text of the
                field, so clearing the field clears the content). Status values: CK_CLASS_SESSION_Status. The
                trigger trg_CLASS_SESSION_LockTaught refuses a future session marked Taught and a Taught session
                that changes its status, date, time, room or teacher; F1 pays the Taught sessions.
                Tests: P20, T50 and T51 (trigger), T56 (a finished class), T106 (keep, change and clear the
                content).
       Concepts: a row-level permission inside a procedure (fn_CurrentRole, fn_CurrentTeacherId),
                 CASE + NULLIF to tell "keep" (NULL) from "remove" (empty text). */
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

    -- 3. Save the status and the content of the lesson: NULL keeps it, an empty text removes it
    UPDATE dbo.CLASS_SESSION
    SET Status = @Status,
        Description = CASE WHEN @Description IS NULL THEN Description
                           ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END
    WHERE SessionId = @SessionId;
END;
GO

/* B6. usp_Class_Update: change a class that is still running (name, teacher, room, start date, size, tuition)
       Used by: Classes screen - Edit (SqlClassRepository::update); roles rl_Manager, rl_AcademicStaff;
                tests T72 (a size below the enrolled students), T73 (a teacher who is busy at that time), T74 (the
                scheduled sessions follow the new teacher and room), T83 (a new start date for a class in
                progress), T101 and T102 (a new start date, also after the old end date), T111 (a new start date
                that clashes with another class of a student), T114 (a teacher who is not teaching), T116 (a past
                session that is still Scheduled keeps its teacher).
       Rules:   the class must exist (50012) and be Enrolling or In progress (50080); a new teacher must still
                be Teaching (50011); a new room is not under maintenance (50084); the start date only moves while the class is Enrolling and none of its
                sessions was taught or cancelled (50081); the maximum size never falls below the number of
                enrolled students (50082 - trg_ENROLLMENT_CheckCapacity only checks new enrollments). The room
                must belong to the branch and hold the size (trg_CLASS_CheckRoom). A new tuition only applies
                to later enrollments: an enrollment keeps the BaseTuition it was given (C1).
       Steps:   1. In one transaction, read the class with UPDLOCK, HOLDLOCK and check the rules: the class row
                   (and a new teacher's row) stays locked until COMMIT, so an enrollment (C1 takes the same lock)
                   or usp_Teacher_Update cannot change what was checked before the UPDATE.
                2. UPDATE CLASS. A new start date makes the generated sessions wrong: they
                   are all still Scheduled (rule above), so they are deleted and EndDate becomes NULL in the
                   same UPDATE (the old EndDate may lie before the new start date: CK_CLASS_Dates) - the screen
                   then generates them with B3. Otherwise the Scheduled sessions from today on take the new
                   teacher and room; a past session keeps them even while it is still Scheduled (taught but not
                   confirmed yet: its own teacher confirms it and F1 pays that teacher), and a taught session
                   keeps them anyway (trg_CLASS_SESSION_LockTaught).
                3. Every weekly slot of the class is written again unchanged (SET StartTime = StartTime): that
                   fires trg_CLASS_SCHEDULE_CheckConflict, which compares the slots with the NEW teacher, room
                   and period of the class and rolls back a clash with another class - one rule, one place.
                4. A new period may clash with another class of an enrolled student: the same check as C1
                   (fn_StudentScheduleClash, 50024) for every Studying enrollment of the class.
       Concepts: re-checking a rule by firing its trigger, multi-step transaction, pessimistic locking (UPDLOCK,
                 HOLDLOCK), CROSS APPLY of an inline table-valued function, THROW inside TRY (the CATCH rolls
                 back and re-raises it). */
IF OBJECT_ID(N'dbo.usp_Class_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Class_Update;
GO
CREATE PROCEDURE dbo.usp_Class_Update
    @ClassId      VARCHAR(10),
    @ClassName    NVARCHAR(100),
    @TeacherId    VARCHAR(10),
    @RoomId       VARCHAR(10),
    @StartDate    DATE,
    @MaxStudents  INT,
    @Tuition      DECIMAL(12,0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Status NVARCHAR(20), @OldTeacherId VARCHAR(10), @OldRoomId VARCHAR(10), @OldStartDate DATE;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- 1. The class as it is now, locked until COMMIT (UPDLOCK, HOLDLOCK, as in C1: no enrollment slips in
        --    between the size check and the UPDATE); still NULL => no such class
        SELECT @Status = Status, @OldTeacherId = TeacherId, @OldRoomId = RoomId, @OldStartDate = StartDate
        FROM dbo.CLASS WITH (UPDLOCK, HOLDLOCK) WHERE ClassId = @ClassId;
        IF @Status IS NULL
            THROW 50012, N'Class not found.', 1;
        IF @Status NOT IN (N'Enrolling', N'In progress')
            THROW 50080, N'Only an enrolling or in-progress class can be changed.', 1;
        -- A new teacher must still teach; the teacher row stays locked, so usp_Teacher_Update waits to set Left
        IF @TeacherId <> @OldTeacherId
           AND NOT EXISTS (SELECT 1 FROM dbo.TEACHER WITH (UPDLOCK, HOLDLOCK)
                           WHERE TeacherId = @TeacherId AND Status = N'Teaching')
            THROW 50011, N'The teacher does not exist or is no longer teaching.', 1;
        IF @RoomId <> @OldRoomId AND EXISTS (SELECT 1 FROM dbo.ROOM WHERE RoomId = @RoomId AND Status = N'Maintenance')
            THROW 50084, N'The room is under maintenance; choose another room.', 1;
        IF @StartDate <> @OldStartDate
           AND (@Status <> N'Enrolling'
                OR EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId AND Status <> N'Scheduled'))
            THROW 50081, N'The start date can only change while the class is enrolling and none of its sessions has been taught or cancelled.', 1;
        IF @MaxStudents < dbo.fn_EnrolledCount(@ClassId)
            THROW 50082, N'The maximum size cannot be lower than the number of students enrolled in the class.', 1;

        -- 2. The class (trg_CLASS_CheckRoom checks the room), then its sessions. A new start date clears EndDate
        --    in the same statement: CK_CLASS_Dates checks the row as it is after the UPDATE.
        UPDATE dbo.CLASS
        SET ClassName = LTRIM(RTRIM(@ClassName)), TeacherId = @TeacherId, RoomId = @RoomId, StartDate = @StartDate,
            EndDate = CASE WHEN @StartDate <> @OldStartDate THEN NULL ELSE EndDate END,
            MaxStudents = @MaxStudents, Tuition = @Tuition
        WHERE ClassId = @ClassId;

        IF @StartDate <> @OldStartDate
            DELETE FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId;
        ELSE
            UPDATE dbo.CLASS_SESSION SET TeacherId = @TeacherId, RoomId = @RoomId
            WHERE ClassId = @ClassId AND Status = N'Scheduled' AND SessionDate >= dbo.fn_Today();

        -- 3. Re-check the weekly slots against the other classes (fires trg_CLASS_SCHEDULE_CheckConflict)
        UPDATE dbo.CLASS_SCHEDULE SET StartTime = StartTime WHERE ClassId = @ClassId;

        -- 4. The students of the class must not get a clash with their other classes
        IF @StartDate <> @OldStartDate
           AND EXISTS (SELECT 1 FROM dbo.ENROLLMENT en
                       CROSS APPLY dbo.fn_StudentScheduleClash(en.StudentId, en.ClassId, en.EnrollmentId) c
                       WHERE en.ClassId = @ClassId AND en.Status = N'Studying')
            THROW 50024, N'The class schedule clashes with another class the student is taking.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* B7. usp_ClassSchedule_Remove: remove a weekly time slot of a class
       Used by: Classes screen - Weekly schedule (SqlClassRepository::removeSlot); roles rl_Manager,
                rl_AcademicStaff; tests T94 (a slot removed), T112 (a slot that does not exist).
       Rules:   only for a class that is Enrolling or In progress (50080), whose sessions were neither taught nor
                cancelled (50086, as B2: the timetable and the sessions always agree), and a slot that exists
                (50083). The generated sessions follow the old timetable, so they are removed with EndDate; the
                screen generates them again (B3).
       Concepts: DELETE on a composite key, @@ROWCOUNT to detect "not found", a multi-step transaction. */
IF OBJECT_ID(N'dbo.usp_ClassSchedule_Remove', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_ClassSchedule_Remove;
GO
CREATE PROCEDURE dbo.usp_ClassSchedule_Remove
    @ClassId  VARCHAR(10),
    @Weekday  TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.CLASS WHERE ClassId = @ClassId AND Status IN (N'Enrolling', N'In progress'))
        THROW 50080, N'Only an enrolling or in-progress class can be changed.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId AND Status <> N'Scheduled')
        THROW 50086, N'The weekly schedule of a class with taught or cancelled sessions can no longer change.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM dbo.CLASS_SCHEDULE WHERE ClassId = @ClassId AND Weekday = @Weekday;
        IF @@ROWCOUNT = 0
            THROW 50083, N'Schedule slot not found.', 1;
        DELETE FROM dbo.CLASS_SESSION WHERE ClassId = @ClassId;
        UPDATE dbo.CLASS SET EndDate = NULL WHERE ClassId = @ClassId AND EndDate IS NOT NULL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* B8. usp_ClassSchedule_ByClass: the weekly time slots of a class
       Used by: Classes screen - Weekly schedule (SqlClassRepository::schedule); roles rl_Manager,
                rl_AcademicStaff; test T94.
       Returns: one row per weekday of the class (1 = Monday ... 7 = Sunday) with its hours as hh:mi text
                (CONVERT style 108 gives hh:mi:ss, LEFT keeps hh:mi).
       Concepts: a read procedure on a table the role cannot SELECT itself (ownership chaining). */
IF OBJECT_ID(N'dbo.usp_ClassSchedule_ByClass', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_ClassSchedule_ByClass;
GO
CREATE PROCEDURE dbo.usp_ClassSchedule_ByClass
    @ClassId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Weekday, LEFT(CONVERT(VARCHAR(8), StartTime, 108), 5) AS StartTime,
           LEFT(CONVERT(VARCHAR(8), EndTime, 108), 5) AS EndTime
    FROM dbo.CLASS_SCHEDULE
    WHERE ClassId = @ClassId
    ORDER BY Weekday;
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
       Used by: Enrollments screen - New enrollment (SqlEnrollmentRepository::enroll), 07_seed_data.sql (every
                demo enrollment); roles rl_Manager, rl_AcademicStaff (DENY EXECUTE to rl_Accountant, test P04);
                tests T03 (already enrolled), T04 (entry requirement), T05 (schedule clash), T15 (valid enrollment
                with a promotion), T120 (a date in the future).
       Steps:   1. Defaults: the enrollment date is today and the employee is the signed-in one
                   (fn_CurrentEmployeeId) when the caller passes NULL. A past date is allowed (a paper form typed
                   later), a future one is not (50100): attendance counts from that day (ClassJoinedOn), so a
                   student dated in the future would have no session to count and pass on attendance.
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
                7. In one transaction: lock the class row (UPDLOCK, HOLDLOCK) and check its status again, so
                   two enrollments into the last seat run one after the other; insert the ENROLLMENT
                   (ClassJoinedOn = the enrollment date; TuitionDue = BaseTuition - DiscountAmount is a computed
                   column; the capacity trigger may roll back here), set a Prospective / On hold / Completed
                   student to Studying, commit, and return the new ID through the OUTPUT parameter.
       Concepts: multi-step transaction (SET XACT_ABORT ON + TRY/CATCH + THROW;), pessimistic locking
                 (UPDLOCK, HOLDLOCK), NOT EXISTS subqueries, TOP (1) with ORDER BY, an inline table-valued
                 function in EXISTS, scalar functions,
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
    IF @EnrolledOn > dbo.fn_Today()
        THROW 50100, N'An enrollment cannot be dated in the future.', 1;

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
        -- The class row stays locked until COMMIT (UPDLOCK = read for update, HOLDLOCK = keep the lock until the
        -- end): a second enrollment into the same class waits here, then the capacity trigger sees the seat taken
        -- ("is full" instead of a deadlock); usp_Class_Update takes the same lock before it lowers the size
        SELECT @ClassStatus = Status FROM dbo.CLASS WITH (UPDLOCK, HOLDLOCK) WHERE ClassId = @ClassId;
        IF @ClassStatus NOT IN (N'Enrolling', N'In progress')
            THROW 50021, N'The class no longer accepts enrollments.', 1;

        DECLARE @New TABLE (EnrollmentId VARCHAR(10));
        INSERT INTO dbo.ENROLLMENT (StudentId, ClassId, EnrolledOn, ClassJoinedOn, BaseTuition, PromotionId,
                                    DiscountAmount, EnrolledByEmployeeId)
        OUTPUT inserted.EnrollmentId INTO @New
        VALUES (@StudentId, @ClassId, @EnrolledOn, @EnrolledOn, @Tuition, @PromotionId, @Discount, @EmployeeId);

        UPDATE dbo.STUDENT SET Status = N'Studying'
        WHERE StudentId = @StudentId AND Status IN (N'Prospective', N'On hold', N'Completed');

        COMMIT TRANSACTION;
        SELECT @EnrollmentId = EnrollmentId FROM @New;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* C2. usp_Enrollment_TransferClass: move a student to another class of the SAME course and branch,
       keeping the payment history (ClassId is updated in one transaction).
       Used by: Enrollments screen - Transfer (SqlEnrollmentRepository::transfer); roles rl_Manager,
                rl_AcademicStaff; tests T14 (a class of another course is rejected), T34 (a
                class that clashes with another class of the student is rejected), T46 (the tuition of the new
                class applies), T47 (a student who paid more than the new tuition cannot move), T69 (attendance
                counts from the transfer day), T70 (a class of another branch is rejected).
       Rules:   only a Studying / On hold enrollment can move (50026); the new class must be of the same course,
                at the same branch and still open, Enrolling / In progress (50027): the revenue of a receipt
                belongs to the branch of its class, so an enrollment never changes branch and past monthly
                figures never move; the student must not be in it already (50022);
                its weekly schedule must not clash with another class the student is taking (50024,
                fn_StudentScheduleClash as in usp_Enrollment_Create, leaving out the enrollment that moves).
                The tuition follows the new class: BaseTuition becomes its tuition and the promotion of the
                enrollment is applied again (fn_DiscountAmount on the enrollment date). A student who already
                paid more than the new tuition due cannot move until a receipt is cancelled (50028), because
                AmountPaid may never exceed TuitionDue (CK_ENROLLMENT_AmountPaid).
                The enrollment row is kept (same EnrollmentId), so receipts and grades stay attached to it;
                only the attendance of the old class is removed, and ClassJoinedOn becomes the transfer day
                (fn_AttendanceRate counts the new class from then on). The capacity trigger
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
    -- 2. The new class: same course and branch (self-join a = old, b = new), still open, student not there yet
    IF NOT EXISTS (SELECT 1 FROM dbo.CLASS a JOIN dbo.CLASS b ON a.CourseId = b.CourseId AND a.BranchId = b.BranchId
                   WHERE a.ClassId = @OldClassId AND b.ClassId = @NewClassId
                     AND b.Status IN (N'Enrolling', N'In progress'))
        THROW 50027, N'A student can only be transferred to an open class of the same course and branch.', 1;
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
        -- The new class row stays locked until COMMIT, like in C1: an enrollment into its last seat waits here
        DECLARE @Locked VARCHAR(10);
        SELECT @Locked = ClassId FROM dbo.CLASS WITH (UPDLOCK, HOLDLOCK) WHERE ClassId = @NewClassId;
        -- Attendance in the old class means nothing for the new class
        -- (those rows would point to sessions of another class, which trg_ATTENDANCE_CheckClass forbids)
        DELETE at FROM dbo.ATTENDANCE at JOIN dbo.CLASS_SESSION se ON se.SessionId = at.SessionId
        WHERE at.EnrollmentId = @EnrollmentId AND se.ClassId = @OldClassId;

        -- ClassJoinedOn: today, never before EnrolledOn (CK_ENROLLMENT_ClassJoinedOn)
        UPDATE dbo.ENROLLMENT
        SET ClassId = @NewClassId, Status = N'Studying', BaseTuition = @NewTuition, DiscountAmount = @NewDiscount,
            ClassJoinedOn = CASE WHEN dbo.fn_Today() > EnrolledOn THEN dbo.fn_Today() ELSE EnrolledOn END
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
       Used by: Enrollments screen - Put on hold / Resume / Leave (SqlEnrollmentRepository::changeStatus); roles
                rl_Manager, rl_AcademicStaff; tests T52 (resuming into a schedule clash), T53 (a completed
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
       Used by: Classes screen - Students (SqlClassRepository::students); roles rl_Manager, rl_AcademicStaff,
                rl_Accountant; test T108.
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

/* C5. usp_Enrollment_Search: find enrollments by keyword, class, student or status
       Used by: Enrollments screen, the profile of a student (SqlEnrollmentRepository::search); roles rl_Manager,
                rl_AcademicStaff, rl_Accountant; test T76.
       Returns: one row per enrollment, newest first: student, class, course, branch, enrollment date, tuition
                due, amount paid, balance, status, final grade and result. The keyword searches the enrollment,
                student and class IDs and the student and class names; a NULL filter means "all".
       Concepts: optional parameters (@x IS NULL OR Col = @x), LIKE, a join of five tables, a calculated column. */
IF OBJECT_ID(N'dbo.usp_Enrollment_Search', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Enrollment_Search;
GO
CREATE PROCEDURE dbo.usp_Enrollment_Search
    @Keyword    NVARCHAR(100) = NULL,
    @ClassId    VARCHAR(10)   = NULL,
    @StudentId  VARCHAR(10)   = NULL,
    @Status     NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Pattern NVARCHAR(102) = N'%' + LTRIM(RTRIM(ISNULL(@Keyword, N''))) + N'%';

    SELECT en.EnrollmentId, st.StudentId, st.FullName AS StudentName, cl.ClassId, cl.ClassName, co.CourseName,
           br.BranchName, en.EnrolledOn, en.TuitionDue, en.AmountPaid, en.TuitionDue - en.AmountPaid AS Balance,
           en.Status, en.FinalGrade, en.Result
    FROM dbo.ENROLLMENT en
    JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
    JOIN dbo.CLASS cl   ON cl.ClassId = en.ClassId
    JOIN dbo.COURSE co  ON co.CourseId = cl.CourseId
    JOIN dbo.BRANCH br  ON br.BranchId = cl.BranchId
    WHERE (en.EnrollmentId LIKE @Pattern OR st.StudentId LIKE @Pattern OR st.FullName LIKE @Pattern
           OR cl.ClassId LIKE @Pattern OR cl.ClassName LIKE @Pattern)
      AND (@ClassId IS NULL OR en.ClassId = @ClassId)
      AND (@StudentId IS NULL OR en.StudentId = @StudentId)
      AND (@Status IS NULL OR en.Status = @Status)
    ORDER BY en.EnrolledOn DESC, en.EnrollmentId DESC;
END;
GO

/* =====================================================================
   D. TUITION
   ===================================================================== */

/* D1. usp_Receipt_Create: record a receipt; a trigger updates ENROLLMENT.AmountPaid
       and blocks payments above the tuition due.
       Used by: Tuition collection screen - Collect payment (SqlTuitionRepository::collect); roles rl_Manager,
                rl_Accountant (DENY EXECUTE to rl_AcademicStaff: they cannot collect money); tests T06 (payment above
                the tuition), T20 (payment, then cancellation), P16 (academic staff are refused), T121 (a payment
                dated in the future).
       Rules:   a collecting employee is required (50030): the signed-in one (fn_CurrentEmployeeId) unless
                @EmployeeId is passed; @PaidAtUtc may be in the past (a payment typed later, the demo history) but
                not in the future (50034: revenue would show money not received yet); the enrollment must exist
                and not be Left (50031); the amount must be
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
    IF @PaidAtUtc > GETUTCDATE()
        THROW 50034, N'A payment cannot be dated in the future.', 1;
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
       Used by: Tuition collection screen - Cancel receipt (SqlTuitionRepository::cancel); roles rl_Manager,
                rl_Accountant; test T20.
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
       Used by: Tuition collection screen - Print receipt (SqlTuitionRepository::print, a PDF made by the application);
                roles rl_Manager, rl_Accountant; test T107.
       Returns: one row with the receipt, the student, class and course, the amount paid and the balance of
                the enrollment right after this payment, the employee who collected it and the branch header
                (name, address, phone). A receipt printed again later shows the same figures: AmountPaid is the
                sum of the valid receipts of the enrollment up to this one (by payment time, then ID), not
                ENROLLMENT.AmountPaid of today.
       Concepts: a chain of INNER JOINs (every linked row must exist), CROSS APPLY of a correlated subquery
                 (a running total). */
IF OBJECT_ID(N'dbo.usp_Receipt_Print', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Receipt_Print;
GO
CREATE PROCEDURE dbo.usp_Receipt_Print
    @ReceiptId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT rc.ReceiptId, rc.PaidAtUtc, rc.Amount, rc.PaymentMethod, rc.Description, rc.Status,
           st.StudentId, st.FullName AS StudentName, cl.ClassId, cl.ClassName, co.CourseName,
           en.TuitionDue, paid.AmountPaid, en.TuitionDue - paid.AmountPaid AS Balance,
           em.FullName AS CollectedBy, br.BranchName, br.Address AS BranchAddress, br.Phone AS BranchPhone
    FROM dbo.RECEIPT rc
    JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
    JOIN dbo.STUDENT st    ON st.StudentId = en.StudentId
    JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
    JOIN dbo.COURSE co     ON co.CourseId = cl.CourseId
    JOIN dbo.EMPLOYEE em   ON em.EmployeeId = rc.CollectedByEmployeeId
    JOIN dbo.BRANCH br     ON br.BranchId = cl.BranchId
    -- The valid receipts of the enrollment up to and including this one (same time: the smaller ID first)
    CROSS APPLY (SELECT ISNULL(SUM(r2.Amount), 0) AS AmountPaid
                 FROM dbo.RECEIPT r2
                 WHERE r2.EnrollmentId = rc.EnrollmentId AND r2.Status = N'Valid'
                   AND (r2.PaidAtUtc < rc.PaidAtUtc
                        OR (r2.PaidAtUtc = rc.PaidAtUtc AND r2.ReceiptId <= rc.ReceiptId))) paid
    WHERE rc.ReceiptId = @ReceiptId;
END;
GO

/* D4. usp_Receipt_Search: the receipts of a period, by keyword and status
       Used by: Tuition collection screen (SqlTuitionRepository::receipts); roles rl_Manager, rl_Accountant; test T77.
       Returns: one row per receipt paid from @FromDate to @ToDate (days of the center, both included; a NULL
                date = no limit), newest first: payment time (UTC), student, class, amount, method, status,
                who collected it, description and cancel reason. The keyword searches the receipt, student and
                class IDs and the student name.
       Concepts: a local period turned into a half-open UTC range (as G2, so IX_RECEIPT_PaidAtUtc stays usable),
                 optional parameters with OPTION (RECOMPILE) (a plan for the values of each call), a chain of
                 INNER JOINs. */
IF OBJECT_ID(N'dbo.usp_Receipt_Search', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Receipt_Search;
GO
CREATE PROCEDURE dbo.usp_Receipt_Search
    @Keyword   NVARCHAR(100) = NULL,
    @FromDate  DATE          = NULL,
    @ToDate    DATE          = NULL,
    @Status    NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- A NULL date gives a NULL bound, which the WHERE below ignores
    DECLARE @Pattern NVARCHAR(102) = N'%' + LTRIM(RTRIM(ISNULL(@Keyword, N''))) + N'%',
            @FromUtc DATETIME      = dbo.fn_CenterTimeToUtc(@FromDate),
            @ToUtc   DATETIME      = dbo.fn_CenterTimeToUtc(DATEADD(DAY, 1, @ToDate));

    SELECT rc.ReceiptId, rc.PaidAtUtc, rc.EnrollmentId, st.StudentId, st.FullName AS StudentName, cl.ClassId,
           cl.ClassName, rc.Amount, rc.PaymentMethod, rc.Status, em.FullName AS CollectedBy, rc.Description,
           rc.CancelReason
    FROM dbo.RECEIPT rc
    JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
    JOIN dbo.STUDENT st    ON st.StudentId = en.StudentId
    JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
    JOIN dbo.EMPLOYEE em   ON em.EmployeeId = rc.CollectedByEmployeeId
    WHERE (rc.ReceiptId LIKE @Pattern OR st.StudentId LIKE @Pattern OR st.FullName LIKE @Pattern
           OR cl.ClassId LIKE @Pattern)
      AND (@FromUtc IS NULL OR rc.PaidAtUtc >= @FromUtc)
      AND (@ToUtc IS NULL OR rc.PaidAtUtc < @ToUtc)
      AND (@Status IS NULL OR rc.Status = @Status)
    ORDER BY rc.PaidAtUtc DESC, rc.ReceiptId DESC
    -- A plan made for these exact values: with "NULL = no limit" filters a cached plan made for NULL dates would
    -- scan every receipt even when a period is given; RECOMPILE lets the optimizer seek IX_RECEIPT_PaidAtUtc
    OPTION (RECOMPILE);
END;
GO

/* =====================================================================
   E. ACADEMICS: PLACEMENT TESTS - ATTENDANCE - GRADES - RESULTS
   ===================================================================== */

/* E1. usp_PlacementTest_Add (a trigger recommends the matching course)
       Used by: Placement tests screen - New test (SqlPlacementRepository::add); roles rl_Manager,
                rl_AcademicStaff; test T109 (the overall score rounds like the application shows it).
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
       Used by: Timetable & attendance and Teaching schedule screens - Attendance
                (SqlSessionRepository::saveAttendance); roles rl_Manager, rl_AcademicStaff, rl_Teacher; tests P21 (a
                teacher marks a session of another teacher), T44 (a session of a finished class).
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

    -- 3. Save = update the mark when it exists, insert it otherwise. The existence check keeps its lock (UPDLOCK,
    --    HOLDLOCK) until the caller's COMMIT: the application saves every mark inside one transaction, so two
    --    saves of the same mark run one after the other instead of both trying to INSERT
    IF EXISTS (SELECT 1 FROM dbo.ATTENDANCE WITH (UPDLOCK, HOLDLOCK)
               WHERE SessionId = @SessionId AND EnrollmentId = @EnrollmentId)
        UPDATE dbo.ATTENDANCE SET Status = @Status, Notes = @Notes
        WHERE SessionId = @SessionId AND EnrollmentId = @EnrollmentId;
    ELSE
        INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status, Notes)
        VALUES (@SessionId, @EnrollmentId, @Status, @Notes);
END;
GO

/* E3. usp_Attendance_BySession: attendance list of a session (including students not marked yet)
       Used by: Timetable & attendance and Teaching schedule screens - Attendance
                (SqlSessionRepository::attendance); roles rl_Manager, rl_AcademicStaff, rl_Teacher.
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
       Used by: Grade book and My grade book screens - Save (SqlGradeRepository::save); roles rl_Manager,
                rl_AcademicStaff, rl_Teacher (DENY EXECUTE to rl_Accountant); tests T10 (a score of 11 is rejected
                by CK_GRADE_Score), P03 (a teacher grades the class of another teacher), T43 (a grade of a finished
                class), P17 (an accountant is refused).
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

    -- 3. Save = update the score (and who/when) when it exists, insert it otherwise (the DEFAULTs fill who/when).
    --    The existence check keeps its lock (UPDLOCK, HOLDLOCK) until the caller's COMMIT: the application saves
    --    every score inside one transaction, so two saves of the same score run one after the other
    IF EXISTS (SELECT 1 FROM dbo.GRADE WITH (UPDLOCK, HOLDLOCK)
               WHERE EnrollmentId = @EnrollmentId AND ComponentId = @ComponentId)
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
       Used by: Classes screen - Evaluate results (SqlClassRepository::evaluate), 07_seed_data.sql (closes the
                finished demo classes); roles rl_Manager, rl_AcademicStaff; tests T23, T35 (re-evaluation), T57
                (sessions still scheduled).
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
                5. Close the cursor; a student of the class who takes no other class any more (no Studying or On
                   hold enrollment) becomes Completed (test T71); mark the class Finished (E4 then refuses grade
                   changes), commit, and return PassedCount / FailedCount (the seed and T23 read it with
                   INSERT ... EXEC).
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

        -- Students who finished their last class are Completed (usp_Enrollment_Create makes them Studying again)
        UPDATE st SET Status = N'Completed'
        FROM dbo.STUDENT st
        WHERE st.Status = N'Studying'
          AND EXISTS (SELECT 1 FROM dbo.ENROLLMENT en
                      WHERE en.StudentId = st.StudentId AND en.ClassId = @ClassId AND en.Status = N'Completed')
          AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT x
                          WHERE x.StudentId = st.StudentId AND x.Status IN (N'Studying', N'On hold'));

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

/* E6. usp_PlacementTest_Search: placement tests with the student, the recommended course and the grader
       Used by: Placement tests screen and the profile of a student (SqlPlacementRepository::search); roles
                rl_Manager, rl_AcademicStaff; test T78.
       Returns: one row per test, newest first: date, student, the four skill scores, the overall score
                (computed column), the recommended course and the teacher who graded it - both LEFT JOINs,
                because a test may have neither (no open course matches, no grader recorded). The keyword
                searches the test and student IDs and the student name; a NULL filter means "all".
       Concepts: LEFT JOIN for optional references, a computed PERSISTED column read like any column. */
IF OBJECT_ID(N'dbo.usp_PlacementTest_Search', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_PlacementTest_Search;
GO
CREATE PROCEDURE dbo.usp_PlacementTest_Search
    @Keyword    NVARCHAR(100) = NULL,
    @StudentId  VARCHAR(10)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Pattern NVARCHAR(102) = N'%' + LTRIM(RTRIM(ISNULL(@Keyword, N''))) + N'%';

    SELECT pl.TestId, pl.TestDate, st.StudentId, st.FullName AS StudentName, pl.ListeningScore, pl.SpeakingScore,
           pl.ReadingScore, pl.WritingScore, pl.OverallScore, co.CourseName AS RecommendedCourse,
           te.FullName AS GradedBy, pl.Notes
    FROM dbo.PLACEMENT_TEST pl
    JOIN dbo.STUDENT st      ON st.StudentId = pl.StudentId
    LEFT JOIN dbo.COURSE co  ON co.CourseId = pl.RecommendedCourseId
    LEFT JOIN dbo.TEACHER te ON te.TeacherId = pl.GradedByTeacherId
    WHERE (pl.TestId LIKE @Pattern OR st.StudentId LIKE @Pattern OR st.FullName LIKE @Pattern)
      AND (@StudentId IS NULL OR pl.StudentId = @StudentId)
    ORDER BY pl.TestDate DESC, pl.TestId DESC;
END;
GO

/* E7. usp_Grade_ByClass: the grade book of a class, one row per student and grade component
       Used by: Grade book screen (SqlGradeRepository::cells); roles rl_Manager, rl_AcademicStaff; test T79.
                A teacher reads the same rows for the classes they teach through vw_Teacher_MyGrades.
       Returns: every enrollment of the class paired with every grade component of its course (JOIN), with the
                score when it exists (LEFT JOIN on both key columns: a missing score is NULL, an empty cell
                of the grade book), ordered by student name and component.
       Concepts: a JOIN that builds every pair, LEFT JOIN on a composite key to show missing values. */
IF OBJECT_ID(N'dbo.usp_Grade_ByClass', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Grade_ByClass;
GO
CREATE PROCEDURE dbo.usp_Grade_ByClass
    @ClassId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT en.EnrollmentId, cl.ClassId, st.StudentId, st.FullName AS StudentName, gc.ComponentId, gc.ComponentName,
           gc.Weight, gr.Score
    FROM dbo.ENROLLMENT en
    JOIN dbo.STUDENT st          ON st.StudentId = en.StudentId
    JOIN dbo.CLASS cl            ON cl.ClassId = en.ClassId
    JOIN dbo.GRADE_COMPONENT gc  ON gc.CourseId = cl.CourseId
    LEFT JOIN dbo.GRADE gr       ON gr.EnrollmentId = en.EnrollmentId AND gr.ComponentId = gc.ComponentId
    WHERE en.ClassId = @ClassId
    ORDER BY st.FullName, en.EnrollmentId, gc.ComponentId;
END;
GO

/* =====================================================================
   F. TEACHER PAYROLL
   ===================================================================== */

/* F1. usp_Payroll_Finalize: finalize the monthly pay of every teacher with a CURSOR.
       Pay = hours taught x hourly rate; a 500,000 VND bonus for 20 sessions or more.
       Used by: Teacher payroll screen - Finalize month (SqlPayrollRepository::finalize), 07_seed_data.sql (the
                last 2 months); roles rl_Manager, rl_Accountant; tests T24 (figures
                match the taught sessions), T25 (a future month is rejected), T58 (running it again removes a
                row that no longer has a taught session), T103 (a lower rate under a deduction is refused).
       Steps:   1. Refuse a future month (50050); the running month is allowed as a preview that the next run
                   refreshes (F3 pays a month only once it is over). DATEFROMPARTS builds the first day of that
                   month, and [@From, @To) is the month as a date range (a sargable filter on SessionDate).
                2. In one transaction a cursor reads one row per teacher who taught in that month (teachers
                   without a Taught session get no row): the number of Taught sessions, the hours
                   (SUM of DATEDIFF in minutes / 60) and the current hourly rate.
                3. Bonus 500,000 when the teacher taught 20 sessions or more.
                4. Upsert into PAYROLL (one row per teacher and month, UQ_PAYROLL_TeacherId_Month_Year): an
                   existing row is refreshed only while its status is Finalized - a Paid row is never changed;
                   otherwise a new row is inserted. A refreshed row keeps its Deduction (F2) and takes the
                   current rate; CK_PAYROLL_Deduction refuses the whole run when the pay would then fall below
                   that deduction. After the loop, a Finalized row of a teacher who no longer has a Taught
                   session that month is deleted. Running the procedure again for a month is therefore safe.
                5. Commit and return the payroll of the month. TotalPay is a computed column
                   (Hours x HourlyRate + Bonus - Deduction), never written by hand. The hourly rate is copied
                   into PAYROLL, so a later rate change does not alter a Paid payslip.
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

/* F2. usp_Payroll_Adjust: set the deduction of a payroll row (an advance, a missed duty...)
       Used by: Teacher payroll screen - Deduction (SqlPayrollRepository::adjust); roles rl_Manager, rl_Accountant;
                tests T80 (TotalPay follows), T81 (a paid row), T82 (more than the pay of the month), T113 (a row
                that does not exist).
       Rules:   the row must exist (50051) and still be Finalized (50052: a Paid row is final); the deduction is
                not negative (CK_PAYROLL_Figures) and at most the pay of the month, hours x rate + bonus (50053,
                the readable form of CK_PAYROLL_Deduction), so TotalPay never becomes negative. TotalPay is a
                computed column: SQL Server recomputes it. F1 keeps the deduction when it refreshes a Finalized
                row.
       Concepts: a computed PERSISTED column recomputed by an UPDATE, a rule across the columns of a row. */
IF OBJECT_ID(N'dbo.usp_Payroll_Adjust', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Payroll_Adjust;
GO
CREATE PROCEDURE dbo.usp_Payroll_Adjust
    @PayrollId  INT,
    @Deduction  DECIMAL(12,0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Status NVARCHAR(20), @Gross DECIMAL(14,0);

    -- 1. The row and its pay before the deduction; still NULL => no such row
    SELECT @Status = Status, @Gross = CAST(Hours * HourlyRate AS DECIMAL(14,0)) + Bonus
    FROM dbo.PAYROLL WHERE PayrollId = @PayrollId;
    IF @Status IS NULL
        THROW 50051, N'Payroll row not found.', 1;
    IF @Status <> N'Finalized'
        THROW 50052, N'A paid payroll row can no longer be changed.', 1;
    IF @Deduction > @Gross
        THROW 50053, N'The deduction cannot be larger than the pay of the month.', 1;

    -- 2. One UPDATE; TotalPay follows by itself
    UPDATE dbo.PAYROLL SET Deduction = @Deduction WHERE PayrollId = @PayrollId;
END;
GO

/* F3. usp_Payroll_MarkPaid: record that the pay of a row has been paid out
       Used by: Teacher payroll screen - Mark as paid (SqlPayrollRepository::markPaid); roles rl_Manager,
                rl_Accountant; tests T81 (the row is Paid, then F2 refuses it), T115 (a month that has not ended).
       Rules:   the row must exist (50051) and be Finalized (50052); its month must be over (50054). Paid is the
                last state: F1 and F2 never change a Paid row again, so a month paid while it is still running
                would never pay the sessions taught after that day. F1 may still finalize the running month: a
                Finalized row is a preview that the next run refreshes.
       Concepts: a one-way state change, @@ROWCOUNT, a month as a date range (DATEFROMPARTS, DATEADD). */
IF OBJECT_ID(N'dbo.usp_Payroll_MarkPaid', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Payroll_MarkPaid;
GO
CREATE PROCEDURE dbo.usp_Payroll_MarkPaid
    @PayrollId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Month TINYINT, @Year SMALLINT;
    SELECT @Month = Month, @Year = Year FROM dbo.PAYROLL WHERE PayrollId = @PayrollId;
    IF @Month IS NULL
        THROW 50051, N'Payroll row not found.', 1;
    -- The first day of the next month is still to come => the month is not over
    IF DATEADD(MONTH, 1, DATEFROMPARTS(@Year, @Month, 1)) > dbo.fn_Today()
        THROW 50054, N'A month can only be marked as paid after it has ended.', 1;
    UPDATE dbo.PAYROLL SET Status = N'Paid' WHERE PayrollId = @PayrollId AND Status = N'Finalized';
    IF @@ROWCOUNT = 0
        THROW 50052, N'A paid payroll row can no longer be changed.', 1;
END;
GO

/* =====================================================================
   G. REPORTS - STATISTICS
   ===================================================================== */

/* G1. usp_Dashboard_Stats: figures for the Dashboard screen.
       Academic staff may call it too but must NOT see revenue:
       RevenueThisMonth is NULL unless the caller is a manager/accountant.
       Used by: Dashboard screen (SqlStatisticsRepository::dashboard, with the branch chosen on the screen);
                roles rl_Manager, rl_AcademicStaff, rl_Accountant; tests P11, T67; 08_demo_queries.sql;
                docs/report/tools/export_data.py.
       Returns: one row - students with a Studying enrollment (counted on ENROLLMENT, the classes people sit in
                now, rather than on STUDENT.Status, the overall state of a person), classes In progress,
                classes Enrolling,
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
       Used by: Revenue screen - By course (SqlStatisticsRepository::revenueReport); roles rl_Manager,
                rl_Accountant; test T77.
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
       Used by: Classes screen - Results (SqlClassRepository::results); roles rl_Manager, rl_AcademicStaff;
                test T79.
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
       Used by: Courses screen - Find by skill (SqlCourseRepository::findBySkill); roles rl_Manager,
                rl_AcademicStaff; 08_demo_queries.sql; docs/report/tools/export_data.py.
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
       Used by: Courses and My classes screens - Syllabus (SqlCourseRepository::syllabus); roles rl_Manager,
                rl_AcademicStaff, rl_Teacher; 08_demo_queries.sql; docs/report/tools/export_data.py.
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
       Used by: Teachers screen - Find by certificate (SqlStaffRepository::findTeachersByCertificate); roles
                rl_Manager, rl_AcademicStaff; 08_demo_queries.sql.
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
       Used by: Students screen - Export XML (SqlStudentRepository::exportXml); roles rl_Manager,
                rl_AcademicStaff; 10_import_export.sql; test T26 (export, then import).
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
       Used by: Students screen - Import XML (SqlStudentRepository::importXml); roles rl_Manager,
                rl_AcademicStaff; 10_import_export.sql; tests T26, T59 (duplicates inside the file, an empty
                name).
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
       Used by: Accounts screen - New account (SqlAccountRepository::create); rl_Manager only (schema grant);
                07_seed_data.sql (demo accounts), 13_server_tests.sql (temporary account t_lockout); tests P09
                (academic staff are refused), P10 (the manager creates an account, rolled back).
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
       Used by: Accounts screen - Lock / Unlock (SqlAccountRepository::setLocked); rl_Manager only; tests S14-S18
                (13_server_tests.sql: real sign-ins before and after the lock,
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
       Used by: Accounts screen - Reset password (SqlAccountRepository::resetPassword); rl_Manager only; test S19
                (13_server_tests.sql: the account signs in with the new password and no longer with the old
                one).
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
       Used by: Accounts screen (SqlAccountRepository::list; a manager-only feature in Permissions);
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
       Used by: Backup screen (SqlBackupRepository::backup); rl_Manager only; tests S04 (the manager backs up: the
                file passes RESTORE VERIFYONLY and is recorded in msdb), S05 (academic staff are refused), S06
                (unknown type). The whole backup and restore chain is shown in 09_backup_restore.sql.
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

/* =====================================================================
   J. CATALOGS: BRANCHES, ROOMS, PROGRAMS, COURSES, GRADE COMPONENTS,
      EMPLOYEES, TEACHERS, PROMOTIONS
   The reference data the business procedures read. Only the manager maintains it (EXECUTE ON
   SCHEMA::dbo in 06_security.sql; the other roles only read it). Two kinds of key:
     - a code chosen by the user (BR01, D1-101, IELTS, IE-FND, PR-OPEN): _Add refuses a code in use
       (50091) and a code with other characters than letters, digits, dash and underscore (50092);
     - an ID from a SEQUENCE (EM0001, TE0001): _Add returns it through an OUTPUT parameter (as A1).
   _Update refuses a key that does not exist (50090). Column rules (formats, ranges, cross-column
   rules, uniqueness) stay the CHECK / UNIQUE constraints of 01_tables.sql; the procedures add the
   rules that need other tables (a branch, course or teacher still used by an active class...).
   ===================================================================== */

/* J1. usp_Branch_Add: open a new branch
       Used by: Branches & rooms screen - New branch (SqlCatalogRepository::addBranch); rl_Manager; test T84.
       Rules:   the code is new (50091) and only holds letters, digits, dash or underscore (50092; compared in
                the binary collation, as I1); name unique (UQ_BRANCH_BranchName); phone/email formats
                (CK_BRANCH_Phone, CK_BRANCH_Email). A new branch is Active (DF_BRANCH_Status).
       Concepts: a single INSERT (no transaction needed), NULLIF for optional text. */
IF OBJECT_ID(N'dbo.usp_Branch_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Branch_Add;
GO
CREATE PROCEDURE dbo.usp_Branch_Add
    @BranchId    VARCHAR(10),
    @BranchName  NVARCHAR(100),
    @Address     NVARCHAR(200),
    @Phone       VARCHAR(15)   = NULL,
    @Email       VARCHAR(100)  = NULL,
    @FoundedOn   DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(@BranchId, '') = '' OR @BranchId COLLATE Latin1_General_BIN LIKE '%[^A-Za-z0-9_-]%'
        THROW 50092, N'A code may only contain letters, digits, dashes and underscores.', 1;
    IF EXISTS (SELECT 1 FROM dbo.BRANCH WHERE BranchId = @BranchId)
        THROW 50091, N'This code is already used.', 1;

    INSERT INTO dbo.BRANCH (BranchId, BranchName, Address, Phone, Email, FoundedOn)
    VALUES (@BranchId, LTRIM(RTRIM(@BranchName)), @Address, NULLIF(@Phone, ''), NULLIF(@Email, ''), @FoundedOn);
END;
GO

/* J2. usp_Branch_Update: change a branch, or suspend / reactivate it
       Used by: Branches & rooms screen - Edit branch (SqlCatalogRepository::updateBranch); rl_Manager; test T85.
       Rules:   the branch must exist (50090); a branch is not Suspended while it still has an Enrolling or
                In progress class (50093) - suspended branches leave the combo boxes of the screens.
       Concepts: a rule across tables (BRANCH - CLASS) checked before a single UPDATE. */
IF OBJECT_ID(N'dbo.usp_Branch_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Branch_Update;
GO
CREATE PROCEDURE dbo.usp_Branch_Update
    @BranchId    VARCHAR(10),
    @BranchName  NVARCHAR(100),
    @Address     NVARCHAR(200),
    @Phone       VARCHAR(15)   = NULL,
    @Email       VARCHAR(100)  = NULL,
    @FoundedOn   DATE          = NULL,
    @Status      NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- The branch row stays locked until COMMIT (UPDLOCK, HOLDLOCK): usp_Class_Create takes the same lock, so no
        -- class is opened in the branch between the check below and the UPDATE
        IF NOT EXISTS (SELECT 1 FROM dbo.BRANCH WITH (UPDLOCK, HOLDLOCK) WHERE BranchId = @BranchId)
            THROW 50090, N'The record to update does not exist.', 1;
        IF @Status = N'Suspended'
           AND EXISTS (SELECT 1 FROM dbo.CLASS WHERE BranchId = @BranchId AND Status IN (N'Enrolling', N'In progress'))
            THROW 50093, N'A branch with active classes cannot be suspended.', 1;

        UPDATE dbo.BRANCH
        SET BranchName = LTRIM(RTRIM(@BranchName)), Address = @Address, Phone = NULLIF(@Phone, ''),
            Email = NULLIF(@Email, ''), FoundedOn = @FoundedOn, Status = @Status
        WHERE BranchId = @BranchId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* J3. usp_Room_Add: add a classroom to a branch
       Used by: Branches & rooms screen - New room (SqlCatalogRepository::addRoom); rl_Manager; tests T86, T95.
       Rules:   the code is new and well formed (50091, 50092); the branch exists (FK_ROOM_BRANCH); the name is
                unique inside the branch (UQ_ROOM_BranchId_RoomName); capacity 1-100 and the room type
                (CK_ROOM_Capacity, CK_ROOM_RoomType). A new room is Available (DF_ROOM_Status).
       Concepts: a single INSERT, a default value for an optional parameter. */
IF OBJECT_ID(N'dbo.usp_Room_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Room_Add;
GO
CREATE PROCEDURE dbo.usp_Room_Add
    @RoomId    VARCHAR(10),
    @BranchId  VARCHAR(10),
    @RoomName  NVARCHAR(50),
    @Capacity  INT,
    @RoomType  NVARCHAR(30) = N'Lecture'
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(@RoomId, '') = '' OR @RoomId COLLATE Latin1_General_BIN LIKE '%[^A-Za-z0-9_-]%'
        THROW 50092, N'A code may only contain letters, digits, dashes and underscores.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ROOM WHERE RoomId = @RoomId)
        THROW 50091, N'This code is already used.', 1;

    INSERT INTO dbo.ROOM (RoomId, BranchId, RoomName, Capacity, RoomType)
    VALUES (@RoomId, @BranchId, LTRIM(RTRIM(@RoomName)), @Capacity, @RoomType);
END;
GO

/* J4. usp_Room_Update: change a classroom (name, branch, capacity, type, maintenance)
       Used by: Branches & rooms screen - Edit room (SqlCatalogRepository::updateRoom); rl_Manager; test T86.
       Rules:   the room must exist (50090). A room used by an active class keeps its branch and a capacity of at
                least the class size: trg_ROOM_CheckClasses rolls the UPDATE back otherwise (test T61).
       Concepts: a rule kept by a trigger, whoever writes the table. */
IF OBJECT_ID(N'dbo.usp_Room_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Room_Update;
GO
CREATE PROCEDURE dbo.usp_Room_Update
    @RoomId    VARCHAR(10),
    @BranchId  VARCHAR(10),
    @RoomName  NVARCHAR(50),
    @Capacity  INT,
    @RoomType  NVARCHAR(30),
    @Status    NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.ROOM WHERE RoomId = @RoomId)
        THROW 50090, N'The record to update does not exist.', 1;

    UPDATE dbo.ROOM
    SET BranchId = @BranchId, RoomName = LTRIM(RTRIM(@RoomName)), Capacity = @Capacity, RoomType = @RoomType,
        Status = @Status
    WHERE RoomId = @RoomId;
END;
GO

/* J5. usp_Program_Add: add a training program
       Used by: Courses screen - Programs - New program (SqlCatalogRepository::addProgram); rl_Manager; test T87.
       Rules:   the code is new and well formed (50091, 50092); the name is unique (UQ_PROGRAM_ProgramName).
       Concepts: a single INSERT. */
IF OBJECT_ID(N'dbo.usp_Program_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Program_Add;
GO
CREATE PROCEDURE dbo.usp_Program_Add
    @ProgramId       VARCHAR(10),
    @ProgramName     NVARCHAR(100),
    @TargetLearners  NVARCHAR(100) = NULL,
    @Description     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(@ProgramId, '') = '' OR @ProgramId COLLATE Latin1_General_BIN LIKE '%[^A-Za-z0-9_-]%'
        THROW 50092, N'A code may only contain letters, digits, dashes and underscores.', 1;
    IF EXISTS (SELECT 1 FROM dbo.PROGRAM WHERE ProgramId = @ProgramId)
        THROW 50091, N'This code is already used.', 1;

    INSERT INTO dbo.PROGRAM (ProgramId, ProgramName, TargetLearners, Description)
    VALUES (@ProgramId, LTRIM(RTRIM(@ProgramName)), NULLIF(@TargetLearners, N''), NULLIF(@Description, N''));
END;
GO

/* J6. usp_Program_Update: change the name, learners or description of a program
       Used by: Courses screen - Programs - Edit (SqlCatalogRepository::updateProgram); rl_Manager; test T87.
       Rules:   the program must exist (50090); the name stays unique (UQ_PROGRAM_ProgramName).
       Concepts: a single UPDATE. */
IF OBJECT_ID(N'dbo.usp_Program_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Program_Update;
GO
CREATE PROCEDURE dbo.usp_Program_Update
    @ProgramId       VARCHAR(10),
    @ProgramName     NVARCHAR(100),
    @TargetLearners  NVARCHAR(100) = NULL,
    @Description     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.PROGRAM WHERE ProgramId = @ProgramId)
        THROW 50090, N'The record to update does not exist.', 1;

    UPDATE dbo.PROGRAM
    SET ProgramName = LTRIM(RTRIM(@ProgramName)), TargetLearners = NULLIF(@TargetLearners, N''),
        Description = NULLIF(@Description, N'')
    WHERE ProgramId = @ProgramId;
END;
GO

/* J7. usp_Course_Add: add a course to a program
       Used by: Courses screen - New course (SqlCourseRepository::add); rl_Manager; test T88.
       Rules:   the code is new and well formed (50091, 50092); program and prerequisite exist (FK_COURSE_PROGRAM,
                FK_COURSE_COURSE); level A1-C2, 1-200 sessions of 30-240 minutes, tuition >= 0, a minimum
                placement score 0-10 (CK_COURSE_*). A new course is Open (DF_COURSE_Status) and has no syllabus
                yet (J9 adds it) and no grade components (J10): the weights must add up to 100 before a class of
                the course can be evaluated (E5, vw_CourseInvalidWeights).
       Concepts: a single INSERT, a self-referencing foreign key (the prerequisite). */
IF OBJECT_ID(N'dbo.usp_Course_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Course_Add;
GO
CREATE PROCEDURE dbo.usp_Course_Add
    @CourseId              VARCHAR(10),
    @ProgramId             VARCHAR(10),
    @CourseName            NVARCHAR(100),
    @Level                 VARCHAR(2),
    @SessionCount          INT,
    @SessionMinutes        INT          = 90,
    @Tuition               DECIMAL(12,0),
    @MinPlacementScore     DECIMAL(4,2) = NULL,
    @PrerequisiteCourseId  VARCHAR(10)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(@CourseId, '') = '' OR @CourseId COLLATE Latin1_General_BIN LIKE '%[^A-Za-z0-9_-]%'
        THROW 50092, N'A code may only contain letters, digits, dashes and underscores.', 1;
    IF EXISTS (SELECT 1 FROM dbo.COURSE WHERE CourseId = @CourseId)
        THROW 50091, N'This code is already used.', 1;

    INSERT INTO dbo.COURSE (CourseId, ProgramId, CourseName, Level, SessionCount, SessionMinutes, Tuition,
                            MinPlacementScore, PrerequisiteCourseId)
    VALUES (@CourseId, @ProgramId, LTRIM(RTRIM(@CourseName)), @Level, @SessionCount, @SessionMinutes, @Tuition,
            @MinPlacementScore, NULLIF(@PrerequisiteCourseId, ''));
END;
GO

/* J8. usp_Course_Update: change a course, or stop offering it
       Used by: Courses screen - Edit course (SqlCourseRepository::update); rl_Manager; tests T88, T89, T90.
       Rules:   the course must exist (50090); it is not Discontinued while an Enrolling or In progress class
                runs it (50094); the prerequisite chain has no loop (50095). CK_COURSE_Prerequisite only stops
                a course from being its own prerequisite; a longer loop (A needs B, B needs A) would lock both
                courses forever, so the chain is walked upwards from the new prerequisite with a recursive CTE:
                reaching this course again means a loop. The depth limit stops the walk in any case.
                A new session count or tuition only applies to classes opened later (B1, B3).
       Concepts: recursive CTE (anchor member UNION ALL recursive member), a rule over a hierarchy, a rule
                 across tables (COURSE - CLASS). */
IF OBJECT_ID(N'dbo.usp_Course_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Course_Update;
GO
CREATE PROCEDURE dbo.usp_Course_Update
    @CourseId              VARCHAR(10),
    @ProgramId             VARCHAR(10),
    @CourseName            NVARCHAR(100),
    @Level                 VARCHAR(2),
    @SessionCount          INT,
    @SessionMinutes        INT,
    @Tuition               DECIMAL(12,0),
    @MinPlacementScore     DECIMAL(4,2) = NULL,
    @PrerequisiteCourseId  VARCHAR(10)  = NULL,
    @Status                NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @LoopCount INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;
        SET @PrerequisiteCourseId = NULLIF(@PrerequisiteCourseId, '');
        -- The course row stays locked until COMMIT (UPDLOCK, HOLDLOCK): usp_Class_Create takes the same lock, so no
        -- class of the course is opened between the check below and the UPDATE
        IF NOT EXISTS (SELECT 1 FROM dbo.COURSE WITH (UPDLOCK, HOLDLOCK) WHERE CourseId = @CourseId)
            THROW 50090, N'The record to update does not exist.', 1;
        IF @Status = N'Discontinued'
           AND EXISTS (SELECT 1 FROM dbo.CLASS WHERE CourseId = @CourseId AND Status IN (N'Enrolling', N'In progress'))
            THROW 50094, N'A course with active classes cannot be discontinued.', 1;

        -- Walk the prerequisite chain upwards from the new prerequisite: the anchor is that course, each recursive
        -- step adds the prerequisite of the course found before
        IF @PrerequisiteCourseId IS NOT NULL
        BEGIN
            WITH Chain (CourseId, PrerequisiteCourseId, Depth) AS (
                SELECT CourseId, PrerequisiteCourseId, 1 FROM dbo.COURSE WHERE CourseId = @PrerequisiteCourseId
                UNION ALL
                SELECT co.CourseId, co.PrerequisiteCourseId, ch.Depth + 1
                FROM dbo.COURSE co JOIN Chain ch ON co.CourseId = ch.PrerequisiteCourseId
                WHERE ch.Depth < 100
            )
            SELECT @LoopCount = COUNT(*) FROM Chain WHERE CourseId = @CourseId;
            IF @LoopCount > 0
                THROW 50095, N'The prerequisite would make a loop: a course cannot require itself, not even through other courses.', 1;
        END;

        UPDATE dbo.COURSE
        SET ProgramId = @ProgramId, CourseName = LTRIM(RTRIM(@CourseName)), Level = @Level, SessionCount = @SessionCount,
            SessionMinutes = @SessionMinutes, Tuition = @Tuition, MinPlacementScore = @MinPlacementScore,
            PrerequisiteCourseId = @PrerequisiteCourseId, Status = @Status
        WHERE CourseId = @CourseId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* J9. usp_Course_SetSyllabus: replace the XML syllabus of a course (NULL removes it)
       Used by: Courses screen - Syllabus (SqlCourseRepository::setSyllabus); rl_Manager; test T91.
       Rules:   the course must exist (50090). COURSE.SyllabusXml is TYPED XML: SQL Server validates the
                document against the schema collection xsc_CourseSyllabus while it is written. A document that
                breaks the schema raises a system error 6900-6999; the CATCH turns it into a business message
                that keeps the detail of the validation (50096). Text that is not XML at all already fails when
                the parameter is converted to xml (the application reports that error itself).
       Concepts: typed XML and XML schema collection, TRY/CATCH with ERROR_NUMBER() and ERROR_MESSAGE(), a
                 message built from values. */
IF OBJECT_ID(N'dbo.usp_Course_SetSyllabus', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Course_SetSyllabus;
GO
CREATE PROCEDURE dbo.usp_Course_SetSyllabus
    @CourseId     VARCHAR(10),
    @SyllabusXml  XML = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Msg NVARCHAR(2048);
    IF NOT EXISTS (SELECT 1 FROM dbo.COURSE WHERE CourseId = @CourseId)
        THROW 50090, N'The record to update does not exist.', 1;

    BEGIN TRY
        UPDATE dbo.COURSE SET SyllabusXml = @SyllabusXml WHERE CourseId = @CourseId;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() BETWEEN 6900 AND 6999   -- validation against the XML schema collection
        BEGIN
            SET @Msg = N'The syllabus does not follow the XML schema of the center: ' + ERROR_MESSAGE();
            THROW 50096, @Msg, 1;
        END;
        THROW;
    END CATCH;
END;
GO

/* J10. usp_GradeComponent_Save: add a grade component to a course (@ComponentId NULL) or change one
        Used by: Courses screen - Grade components (SqlCourseRepository::saveComponent); rl_Manager; tests T92, T104.
        Rules:   a changed component must exist in that course (50090): a component never moves to another
                 course, its scores belong to the classes of its own course (fn_FinalGrade would count them for
                 the old one); name unique inside the course
                 (UQ_GRADE_COMPONENT_CourseId_ComponentName); weight above 0 and at most 100
                 (CK_GRADE_COMPONENT_Weight). The components of a course with evaluated classes are frozen
                 (trg_GRADE_COMPONENT_Lock, test T68). The weights of a course need not add up to 100 after
                 every single change; vw_CourseInvalidWeights lists the courses that are not ready and E5
                 refuses to evaluate their classes.
        Concepts: upsert on an IDENTITY key (NULL = new row), a deferred rule checked through a view. */
IF OBJECT_ID(N'dbo.usp_GradeComponent_Save', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GradeComponent_Save;
GO
CREATE PROCEDURE dbo.usp_GradeComponent_Save
    @ComponentId    INT           = NULL,
    @CourseId       VARCHAR(10),
    @ComponentName  NVARCHAR(50),
    @Weight         DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF @ComponentId IS NULL
        INSERT INTO dbo.GRADE_COMPONENT (CourseId, ComponentName, Weight)
        VALUES (@CourseId, LTRIM(RTRIM(@ComponentName)), @Weight);
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.GRADE_COMPONENT WHERE ComponentId = @ComponentId AND CourseId = @CourseId)
            THROW 50090, N'The record to update does not exist.', 1;
        UPDATE dbo.GRADE_COMPONENT
        SET ComponentName = LTRIM(RTRIM(@ComponentName)), Weight = @Weight
        WHERE ComponentId = @ComponentId AND CourseId = @CourseId;
    END;
END;
GO

/* J11. usp_GradeComponent_Delete: remove a grade component that has no score yet
        Used by: Courses screen - Grade components (SqlCourseRepository::removeComponent); rl_Manager; tests T92, T93.
        Rules:   the component must exist (50090) and have no score in GRADE (50097: the scores would be lost, and
                 FK_GRADE_GRADE_COMPONENT refuses it anyway with a technical message); the components of a
                 course with evaluated classes are frozen (trg_GRADE_COMPONENT_Lock).
        Concepts: checking the child rows before a DELETE (a clear message instead of a foreign key error). */
IF OBJECT_ID(N'dbo.usp_GradeComponent_Delete', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_GradeComponent_Delete;
GO
CREATE PROCEDURE dbo.usp_GradeComponent_Delete
    @ComponentId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.GRADE_COMPONENT WHERE ComponentId = @ComponentId)
        THROW 50090, N'The record to update does not exist.', 1;
    IF EXISTS (SELECT 1 FROM dbo.GRADE WHERE ComponentId = @ComponentId)
        THROW 50097, N'A grade component that already has scores cannot be deleted.', 1;
    DELETE FROM dbo.GRADE_COMPONENT WHERE ComponentId = @ComponentId;
END;
GO

/* J12. usp_Employee_Add: hire an office employee, return the new ID
        Used by: Employees screen - New employee (SqlStaffRepository::addEmployee); rl_Manager; test T96.
        Rules:   every format and range is a constraint of EMPLOYEE: phone unique (UQ_EMPLOYEE_Phone), email
                 unique when given (UX_EMPLOYEE_Email), gender, position, salary >= 0, at least 18 years old on
                 the hire date (CK_EMPLOYEE_Age). The hire date defaults to today (fn_Today).
        Concepts: OUTPUT inserted.EmployeeId INTO @New and an OUTPUT parameter (the A1 pattern), SEQUENCE
                  default. */
IF OBJECT_ID(N'dbo.usp_Employee_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Employee_Add;
GO
CREATE PROCEDURE dbo.usp_Employee_Add
    @FullName     NVARCHAR(100),
    @DateOfBirth  DATE,
    @Gender       NVARCHAR(10),
    @Phone        VARCHAR(15),
    @Email        VARCHAR(100)  = NULL,
    @Address      NVARCHAR(200) = NULL,
    @Position     NVARCHAR(30),
    @BranchId     VARCHAR(10),
    @HireDate     DATE          = NULL,
    @BaseSalary   DECIMAL(12,0) = 0,
    @EmployeeId   VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @New TABLE (EmployeeId VARCHAR(10));
    INSERT INTO dbo.EMPLOYEE (FullName, DateOfBirth, Gender, Phone, Email, Address, Position, BranchId, HireDate,
                              BaseSalary)
    OUTPUT inserted.EmployeeId INTO @New
    VALUES (LTRIM(RTRIM(@FullName)), @DateOfBirth, @Gender, @Phone, NULLIF(@Email, ''), NULLIF(@Address, N''),
            @Position, @BranchId, ISNULL(@HireDate, dbo.fn_Today()), ISNULL(@BaseSalary, 0));
    SELECT @EmployeeId = EmployeeId FROM @New;
END;
GO

/* J13. usp_Employee_Update: change an employee, or record that they left
        Used by: Employees screen - Edit (SqlStaffRepository::updateEmployee); rl_Manager; tests T96, T110.
        Rules:   the employee must exist (50090); nobody is set to Left while their sign-in account is still
                 Active (50098: lock it first with I2, so the person can no longer sign in). The constraints of
                 EMPLOYEE check the new values (J12).
        Concepts: a rule across tables (EMPLOYEE - ACCOUNT), a single UPDATE. */
IF OBJECT_ID(N'dbo.usp_Employee_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Employee_Update;
GO
CREATE PROCEDURE dbo.usp_Employee_Update
    @EmployeeId   VARCHAR(10),
    @FullName     NVARCHAR(100),
    @DateOfBirth  DATE,
    @Gender       NVARCHAR(10),
    @Phone        VARCHAR(15),
    @Email        VARCHAR(100)  = NULL,
    @Address      NVARCHAR(200) = NULL,
    @Position     NVARCHAR(30),
    @BranchId     VARCHAR(10),
    @HireDate     DATE,
    @BaseSalary   DECIMAL(12,0),
    @Status       NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.EMPLOYEE WHERE EmployeeId = @EmployeeId)
        THROW 50090, N'The record to update does not exist.', 1;
    IF @Status = N'Left'
       AND EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE EmployeeId = @EmployeeId AND Status = N'Active')
        THROW 50098, N'An employee or teacher with an active account or an active class cannot be set to Left: lock the account and hand the classes over first.', 1;

    UPDATE dbo.EMPLOYEE
    SET FullName = LTRIM(RTRIM(@FullName)), DateOfBirth = @DateOfBirth, Gender = @Gender, Phone = @Phone,
        Email = NULLIF(@Email, ''), Address = NULLIF(@Address, N''), Position = @Position, BranchId = @BranchId,
        HireDate = @HireDate, BaseSalary = @BaseSalary, Status = @Status
    WHERE EmployeeId = @EmployeeId;
END;
GO

/* J14. usp_Teacher_Add: hire a teacher, return the new ID
        Used by: Teachers screen - New teacher (SqlStaffRepository::addTeacher); rl_Manager; test T97.
        Rules:   the constraints of TEACHER: phone and email unique, degree, teacher type, hourly rate > 0, a
                 native speaker is not of Vietnamese nationality (CK_TEACHER_Native), at least 18 years old on
                 the hire date (CK_TEACHER_Age). @ProfileXml is untyped XML (certificates, experience,
                 specialties), read by H3; NULL = no profile.
        Concepts: OUTPUT parameter (A1 pattern), an untyped XML parameter. */
IF OBJECT_ID(N'dbo.usp_Teacher_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Teacher_Add;
GO
CREATE PROCEDURE dbo.usp_Teacher_Add
    @FullName     NVARCHAR(100),
    @DateOfBirth  DATE,
    @Gender       NVARCHAR(10),
    @Nationality  NVARCHAR(50)  = N'Vietnam',
    @Phone        VARCHAR(15),
    @Email        VARCHAR(100),
    @Degree       NVARCHAR(20),
    @TeacherType  NVARCHAR(20),
    @HourlyRate   DECIMAL(12,0),
    @BranchId     VARCHAR(10),
    @HireDate     DATE          = NULL,
    @ProfileXml   XML           = NULL,
    @TeacherId    VARCHAR(10)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @New TABLE (TeacherId VARCHAR(10));
    INSERT INTO dbo.TEACHER (FullName, DateOfBirth, Gender, Nationality, Phone, Email, Degree, TeacherType,
                             HourlyRate, BranchId, HireDate, ProfileXml)
    OUTPUT inserted.TeacherId INTO @New
    VALUES (LTRIM(RTRIM(@FullName)), @DateOfBirth, @Gender, ISNULL(NULLIF(@Nationality, N''), N'Vietnam'), @Phone,
            @Email, @Degree, @TeacherType, @HourlyRate, @BranchId, ISNULL(@HireDate, dbo.fn_Today()), @ProfileXml);
    SELECT @TeacherId = TeacherId FROM @New;
END;
GO

/* J15. usp_Teacher_Update: change a teacher, put them on leave or record that they left
        Used by: Teachers screen - Edit (SqlStaffRepository::updateTeacher); rl_Manager; tests T97, T98.
        Rules:   the teacher must exist (50090); a teacher is not set to Left while they are the main teacher of
                 an Enrolling or In progress class or their account is still Active (50098: hand the classes over
                 with B6 and lock the account first). On leave is allowed: another teacher may take the class.
                 A new hourly rate applies to the months finalized, or finalized again, after it; a Paid month
                 keeps its rate (F1 copies the rate into PAYROLL).
        Concepts: rules across tables (TEACHER - CLASS - ACCOUNT), a single UPDATE. */
IF OBJECT_ID(N'dbo.usp_Teacher_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Teacher_Update;
GO
CREATE PROCEDURE dbo.usp_Teacher_Update
    @TeacherId    VARCHAR(10),
    @FullName     NVARCHAR(100),
    @DateOfBirth  DATE,
    @Gender       NVARCHAR(10),
    @Nationality  NVARCHAR(50),
    @Phone        VARCHAR(15),
    @Email        VARCHAR(100),
    @Degree       NVARCHAR(20),
    @TeacherType  NVARCHAR(20),
    @HourlyRate   DECIMAL(12,0),
    @BranchId     VARCHAR(10),
    @HireDate     DATE,
    @ProfileXml   XML           = NULL,
    @Status       NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- The teacher row stays locked until COMMIT (UPDLOCK, HOLDLOCK): usp_Class_Create and usp_Class_Update take
        -- the same lock, so no class is given to the teacher between the check below and the UPDATE
        IF NOT EXISTS (SELECT 1 FROM dbo.TEACHER WITH (UPDLOCK, HOLDLOCK) WHERE TeacherId = @TeacherId)
            THROW 50090, N'The record to update does not exist.', 1;
        IF @Status = N'Left'
           AND (EXISTS (SELECT 1 FROM dbo.CLASS WHERE TeacherId = @TeacherId AND Status IN (N'Enrolling', N'In progress'))
                OR EXISTS (SELECT 1 FROM dbo.ACCOUNT WHERE TeacherId = @TeacherId AND Status = N'Active'))
            THROW 50098, N'An employee or teacher with an active account or an active class cannot be set to Left: lock the account and hand the classes over first.', 1;

        UPDATE dbo.TEACHER
        SET FullName = LTRIM(RTRIM(@FullName)), DateOfBirth = @DateOfBirth, Gender = @Gender, Nationality = @Nationality,
            Phone = @Phone, Email = @Email, Degree = @Degree, TeacherType = @TeacherType, HourlyRate = @HourlyRate,
            BranchId = @BranchId, HireDate = @HireDate, ProfileXml = @ProfileXml, Status = @Status
        WHERE TeacherId = @TeacherId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* J16. usp_Promotion_Add: create a tuition promotion
        Used by: Promotions screen - New promotion (SqlCatalogRepository::addPromotion); rl_Manager; test T99.
        Rules:   the code is new and well formed (50091, 50092); PERCENT or AMOUNT (CK_PROMOTION_DiscountType); a
                 positive value, at most 50 for a percentage (CK_PROMOTION_DiscountValue); the end date is not
                 before the start date (CK_PROMOTION_Dates).
        Concepts: a single INSERT, cross-column CHECK constraints. */
IF OBJECT_ID(N'dbo.usp_Promotion_Add', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Promotion_Add;
GO
CREATE PROCEDURE dbo.usp_Promotion_Add
    @PromotionId    VARCHAR(10),
    @PromotionName  NVARCHAR(100),
    @DiscountType   VARCHAR(10),
    @DiscountValue  DECIMAL(12,2),
    @StartDate      DATE,
    @EndDate        DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(@PromotionId, '') = '' OR @PromotionId COLLATE Latin1_General_BIN LIKE '%[^A-Za-z0-9_-]%'
        THROW 50092, N'A code may only contain letters, digits, dashes and underscores.', 1;
    IF EXISTS (SELECT 1 FROM dbo.PROMOTION WHERE PromotionId = @PromotionId)
        THROW 50091, N'This code is already used.', 1;

    INSERT INTO dbo.PROMOTION (PromotionId, PromotionName, DiscountType, DiscountValue, StartDate, EndDate)
    VALUES (@PromotionId, LTRIM(RTRIM(@PromotionName)), @DiscountType, @DiscountValue, @StartDate, @EndDate);
END;
GO

/* J17. usp_Promotion_Update: change a promotion (for example end it early)
        Used by: Promotions screen - Edit (SqlCatalogRepository::updatePromotion); rl_Manager; tests T99, T100,
                 T117 (a used promotion gets another discount), T118 (it ends before its last use), T119 (it is
                 renamed and ended on the day of its last use).
        Rules:   the promotion must exist (50090); the CHECK constraints of J16 apply. Enrollments keep the
                 DiscountAmount they were given (C1 stores the amount), but a class transfer (C2) applies the
                 promotion again on the tuition of the new class with fn_DiscountAmount on EnrolledOn. So once an
                 enrollment uses the promotion, its rule is frozen: the discount type, value and start date no
                 longer change (50110) and the end date never moves before the last enrollment that used it
                 (50111). The name can always change, and the promotion can still be ended early.
        Concepts: a rule that depends on other rows (COUNT / MAX over ENROLLMENT), a stored amount next to a rule
                  that is applied again later. */
IF OBJECT_ID(N'dbo.usp_Promotion_Update', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_Promotion_Update;
GO
CREATE PROCEDURE dbo.usp_Promotion_Update
    @PromotionId    VARCHAR(10),
    @PromotionName  NVARCHAR(100),
    @DiscountType   VARCHAR(10),
    @DiscountValue  DECIMAL(12,2),
    @StartDate      DATE,
    @EndDate        DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Uses INT, @LastUse DATE;
    IF NOT EXISTS (SELECT 1 FROM dbo.PROMOTION WHERE PromotionId = @PromotionId)
        THROW 50090, N'The record to update does not exist.', 1;

    -- A promotion in use keeps its rule: C2 applies it again when a student changes class
    SELECT @Uses = COUNT(*), @LastUse = MAX(EnrolledOn) FROM dbo.ENROLLMENT WHERE PromotionId = @PromotionId;
    IF @Uses > 0 AND EXISTS (SELECT 1 FROM dbo.PROMOTION
                             WHERE PromotionId = @PromotionId
                               AND (DiscountType <> @DiscountType OR DiscountValue <> @DiscountValue
                                    OR StartDate <> @StartDate))
        THROW 50110, N'A promotion already used by enrollments keeps its discount and start date; only its name and end date can change.', 1;
    IF @EndDate < @LastUse
        THROW 50111, N'The end date cannot be before the last enrollment that used the promotion.', 1;

    UPDATE dbo.PROMOTION
    SET PromotionName = LTRIM(RTRIM(@PromotionName)), DiscountType = @DiscountType, DiscountValue = @DiscountValue,
        StartDate = @StartDate, EndDate = @EndDate
    WHERE PromotionId = @PromotionId;
END;
GO
