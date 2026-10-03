/* =====================================================================
   File   : 01_tables.sql - Sequences, XML schema, tables and constraints
   Naming : tables in UPPER_SNAKE_CASE; columns in PascalCase; constraints
            PK_<TABLE>, FK_<CHILD>_<PARENT>, UQ_<TABLE>_<Column>,
            CK_<TABLE>_<Column>, DF_<TABLE>_<Column>
   Time   : instants are UTC - DATETIME columns named ...Utc, DEFAULT
            (GETUTCDATE()); the application converts them to the user's
            time zone. Business dates (DATE) are calendar days of the
            center (UTC+07:00): their DEFAULTs repeat the offset of
            dbo.fn_CenterUtcOffset, because a DEFAULT cannot call a function
            that 02_functions.sql creates later and drops when re-run (T32
            checks that the offsets match).
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   1. SEQUENCES that generate the IDs (SQL Server 2012+)
   --------------------------------------------------------------------- */
CREATE SEQUENCE dbo.seq_EMPLOYEE       AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_TEACHER        AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_STUDENT        AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_CLASS          AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_ENROLLMENT     AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_RECEIPT        AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_PLACEMENT_TEST AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.seq_CERTIFICATE    AS INT START WITH 1 INCREMENT BY 1;
GO

/* ---------------------------------------------------------------------
   2. XML SCHEMA COLLECTION for course syllabuses (typed XML)
   --------------------------------------------------------------------- */
CREATE XML SCHEMA COLLECTION dbo.xsc_CourseSyllabus AS N'
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
  <xs:element name="Syllabus">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="Textbook" maxOccurs="unbounded">
          <xs:complexType>
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="Author" type="xs:string" use="optional"/>
                <xs:attribute name="Year" type="xs:int" use="optional"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        </xs:element>
        <xs:element name="Objective" type="xs:string"/>
        <xs:element name="Unit" maxOccurs="unbounded">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Title" type="xs:string"/>
              <xs:element name="Skill" type="xs:string" maxOccurs="unbounded"/>
            </xs:sequence>
            <xs:attribute name="No" type="xs:int" use="required"/>
            <xs:attribute name="Sessions" type="xs:int" use="required"/>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

/* ---------------------------------------------------------------------
   3. BRANCH - Branches of the center
   --------------------------------------------------------------------- */
CREATE TABLE dbo.BRANCH (
    BranchId    VARCHAR(10)    NOT NULL,
    BranchName  NVARCHAR(100)  NOT NULL,
    Address     NVARCHAR(200)  NOT NULL,
    Phone       VARCHAR(15)    NULL,
    Email       VARCHAR(100)   NULL,
    FoundedOn   DATE           NULL,
    Status      NVARCHAR(20)   NOT NULL CONSTRAINT DF_BRANCH_Status DEFAULT (N'Active'),
    CONSTRAINT PK_BRANCH PRIMARY KEY (BranchId),
    CONSTRAINT UQ_BRANCH_BranchName UNIQUE (BranchName),
    CONSTRAINT CK_BRANCH_Phone CHECK (Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) BETWEEN 9 AND 11),
    CONSTRAINT CK_BRANCH_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_BRANCH_Status CHECK (Status IN (N'Active', N'Suspended'))
);
GO

/* ---------------------------------------------------------------------
   4. ROOM - Classrooms of a branch
   --------------------------------------------------------------------- */
CREATE TABLE dbo.ROOM (
    RoomId    VARCHAR(10)   NOT NULL,
    BranchId  VARCHAR(10)   NOT NULL,
    RoomName  NVARCHAR(50)  NOT NULL,
    Capacity  INT           NOT NULL,
    RoomType  NVARCHAR(30)  NOT NULL CONSTRAINT DF_ROOM_RoomType DEFAULT (N'Lecture'),
    Status    NVARCHAR(20)  NOT NULL CONSTRAINT DF_ROOM_Status DEFAULT (N'Available'),
    CONSTRAINT PK_ROOM PRIMARY KEY (RoomId),
    CONSTRAINT FK_ROOM_BRANCH FOREIGN KEY (BranchId) REFERENCES dbo.BRANCH (BranchId),
    CONSTRAINT UQ_ROOM_BranchId_RoomName UNIQUE (BranchId, RoomName),
    CONSTRAINT CK_ROOM_Capacity CHECK (Capacity BETWEEN 1 AND 100),
    CONSTRAINT CK_ROOM_RoomType CHECK (RoomType IN (N'Lecture', N'Lab', N'Multi-purpose')),
    CONSTRAINT CK_ROOM_Status CHECK (Status IN (N'Available', N'Maintenance'))
);
GO

/* ---------------------------------------------------------------------
   5. EMPLOYEE - Office staff (manager, academic staff, accountant, consultant)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.EMPLOYEE (
    EmployeeId   VARCHAR(10)    NOT NULL CONSTRAINT DF_EMPLOYEE_EmployeeId
                     DEFAULT ('EM' + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_EMPLOYEE AS VARCHAR(10)), 4)),
    FullName     NVARCHAR(100)  NOT NULL,
    DateOfBirth  DATE           NOT NULL,
    Gender       NVARCHAR(10)   NOT NULL,
    Phone        VARCHAR(15)    NOT NULL,
    Email        VARCHAR(100)   NULL,
    Address      NVARCHAR(200)  NULL,
    Position     NVARCHAR(30)   NOT NULL,
    BranchId     VARCHAR(10)    NOT NULL,
    HireDate     DATE           NOT NULL CONSTRAINT DF_EMPLOYEE_HireDate
                     DEFAULT (CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00') AS DATE)),
    BaseSalary   DECIMAL(12,0)  NOT NULL CONSTRAINT DF_EMPLOYEE_BaseSalary DEFAULT (0),
    Status       NVARCHAR(20)   NOT NULL CONSTRAINT DF_EMPLOYEE_Status DEFAULT (N'Working'),
    CONSTRAINT PK_EMPLOYEE PRIMARY KEY (EmployeeId),
    CONSTRAINT FK_EMPLOYEE_BRANCH FOREIGN KEY (BranchId) REFERENCES dbo.BRANCH (BranchId),
    CONSTRAINT UQ_EMPLOYEE_Phone UNIQUE (Phone),
    CONSTRAINT CK_EMPLOYEE_Gender CHECK (Gender IN (N'Male', N'Female', N'Other')),
    CONSTRAINT CK_EMPLOYEE_Phone CHECK (Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) BETWEEN 9 AND 11),
    CONSTRAINT CK_EMPLOYEE_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_EMPLOYEE_Position CHECK (Position IN (N'Manager', N'Academic staff', N'Accountant', N'Consultant')),
    CONSTRAINT CK_EMPLOYEE_BaseSalary CHECK (BaseSalary >= 0),
    -- Cross-column constraint: an employee must be at least 18 years old when hired
    CONSTRAINT CK_EMPLOYEE_Age CHECK (DATEADD(YEAR, 18, DateOfBirth) <= HireDate),
    CONSTRAINT CK_EMPLOYEE_Status CHECK (Status IN (N'Working', N'Left'))
);
GO
-- UNIQUE on a nullable column: a filtered index (several NULL rows remain valid)
CREATE UNIQUE INDEX UX_EMPLOYEE_Email ON dbo.EMPLOYEE (Email) WHERE Email IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   6. TEACHER - Teachers (Vietnamese / native speakers), XML profile
   --------------------------------------------------------------------- */
CREATE TABLE dbo.TEACHER (
    TeacherId    VARCHAR(10)    NOT NULL CONSTRAINT DF_TEACHER_TeacherId
                     DEFAULT ('TE' + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_TEACHER AS VARCHAR(10)), 4)),
    FullName     NVARCHAR(100)  NOT NULL,
    DateOfBirth  DATE           NOT NULL,
    Gender       NVARCHAR(10)   NOT NULL,
    Nationality  NVARCHAR(50)   NOT NULL CONSTRAINT DF_TEACHER_Nationality DEFAULT (N'Vietnam'),
    Phone        VARCHAR(15)    NOT NULL,
    Email        VARCHAR(100)   NOT NULL,
    Degree       NVARCHAR(20)   NOT NULL,
    TeacherType  NVARCHAR(20)   NOT NULL,
    HourlyRate   DECIMAL(12,0)  NOT NULL,
    ProfileXml   XML            NULL,
    BranchId     VARCHAR(10)    NOT NULL,
    HireDate     DATE           NOT NULL CONSTRAINT DF_TEACHER_HireDate
                     DEFAULT (CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00') AS DATE)),
    Status       NVARCHAR(20)   NOT NULL CONSTRAINT DF_TEACHER_Status DEFAULT (N'Teaching'),
    CONSTRAINT PK_TEACHER PRIMARY KEY (TeacherId),
    CONSTRAINT FK_TEACHER_BRANCH FOREIGN KEY (BranchId) REFERENCES dbo.BRANCH (BranchId),
    CONSTRAINT UQ_TEACHER_Phone UNIQUE (Phone),
    CONSTRAINT UQ_TEACHER_Email UNIQUE (Email),
    CONSTRAINT CK_TEACHER_Gender CHECK (Gender IN (N'Male', N'Female', N'Other')),
    CONSTRAINT CK_TEACHER_Phone CHECK (Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) BETWEEN 9 AND 11),
    CONSTRAINT CK_TEACHER_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_TEACHER_Degree CHECK (Degree IN (N'Bachelor', N'Master', N'PhD')),
    CONSTRAINT CK_TEACHER_TeacherType CHECK (TeacherType IN (N'Vietnamese', N'Native')),
    CONSTRAINT CK_TEACHER_HourlyRate CHECK (HourlyRate > 0),
    -- Cross-column constraint: a native-speaker teacher cannot have Vietnamese nationality
    CONSTRAINT CK_TEACHER_Native CHECK (TeacherType = N'Vietnamese' OR Nationality <> N'Vietnam'),
    CONSTRAINT CK_TEACHER_Status CHECK (Status IN (N'Teaching', N'On leave', N'Left'))
);
GO

/* ---------------------------------------------------------------------
   7. ACCOUNT - Application sign-in accounts.
      Username equals the name of the (contained) database USER;
      passwords are managed by SQL Server (never stored in a table).
   --------------------------------------------------------------------- */
CREATE TABLE dbo.ACCOUNT (
    Username        NVARCHAR(50)  NOT NULL,
    Role            VARCHAR(20)   NOT NULL,
    EmployeeId      VARCHAR(10)   NULL,
    TeacherId       VARCHAR(10)   NULL,
    Status          NVARCHAR(20)  NOT NULL CONSTRAINT DF_ACCOUNT_Status DEFAULT (N'Active'),
    CreatedAtUtc    DATETIME      NOT NULL CONSTRAINT DF_ACCOUNT_CreatedAtUtc DEFAULT (GETUTCDATE()),
    LastLoginAtUtc  DATETIME      NULL,
    CONSTRAINT PK_ACCOUNT PRIMARY KEY (Username),
    CONSTRAINT FK_ACCOUNT_EMPLOYEE FOREIGN KEY (EmployeeId) REFERENCES dbo.EMPLOYEE (EmployeeId),
    CONSTRAINT FK_ACCOUNT_TEACHER FOREIGN KEY (TeacherId) REFERENCES dbo.TEACHER (TeacherId),
    CONSTRAINT CK_ACCOUNT_Role CHECK (Role IN ('MANAGER', 'ACADEMIC_STAFF', 'ACCOUNTANT', 'TEACHER')),
    CONSTRAINT CK_ACCOUNT_Status CHECK (Status IN (N'Active', N'Locked')),
    -- A teacher account belongs to a TEACHER, every other role to an EMPLOYEE
    CONSTRAINT CK_ACCOUNT_Owner CHECK (
        (Role = 'TEACHER' AND TeacherId IS NOT NULL AND EmployeeId IS NULL) OR
        (Role <> 'TEACHER' AND EmployeeId IS NOT NULL AND TeacherId IS NULL))
);
GO
CREATE UNIQUE INDEX UX_ACCOUNT_EmployeeId ON dbo.ACCOUNT (EmployeeId) WHERE EmployeeId IS NOT NULL;
CREATE UNIQUE INDEX UX_ACCOUNT_TeacherId ON dbo.ACCOUNT (TeacherId) WHERE TeacherId IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   8. STUDENT - Students
   --------------------------------------------------------------------- */
CREATE TABLE dbo.STUDENT (
    StudentId      VARCHAR(10)    NOT NULL CONSTRAINT DF_STUDENT_StudentId
                       DEFAULT ('ST' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_STUDENT AS VARCHAR(10)), 5)),
    FullName       NVARCHAR(100)  NOT NULL,
    DateOfBirth    DATE           NOT NULL,
    Gender         NVARCHAR(10)   NOT NULL,
    Phone          VARCHAR(15)    NULL,
    Email          VARCHAR(100)   NULL,
    Address        NVARCHAR(200)  NULL,
    Occupation     NVARCHAR(50)   NULL,
    GuardianName   NVARCHAR(100)  NULL,
    GuardianPhone  VARCHAR(15)    NULL,
    BranchId       VARCHAR(10)    NOT NULL,
    RegisteredOn   DATE           NOT NULL CONSTRAINT DF_STUDENT_RegisteredOn
                       DEFAULT (CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00') AS DATE)),
    Status         NVARCHAR(20)   NOT NULL CONSTRAINT DF_STUDENT_Status DEFAULT (N'Prospective'),
    Notes          NVARCHAR(500)  NULL,
    CONSTRAINT PK_STUDENT PRIMARY KEY (StudentId),
    CONSTRAINT FK_STUDENT_BRANCH FOREIGN KEY (BranchId) REFERENCES dbo.BRANCH (BranchId),
    CONSTRAINT CK_STUDENT_Gender CHECK (Gender IN (N'Male', N'Female', N'Other')),
    CONSTRAINT CK_STUDENT_Phone CHECK (Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) BETWEEN 9 AND 11),
    CONSTRAINT CK_STUDENT_GuardianPhone CHECK (GuardianPhone NOT LIKE '%[^0-9]%' AND LEN(GuardianPhone) BETWEEN 9 AND 11),
    CONSTRAINT CK_STUDENT_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_STUDENT_DateOfBirth CHECK (DateOfBirth > '19300101' AND DATEADD(YEAR, 4, DateOfBirth) <= RegisteredOn),
    -- Cross-column constraint: a student under 18 must have guardian details
    CONSTRAINT CK_STUDENT_Guardian CHECK (
        DATEADD(YEAR, 18, DateOfBirth) <= RegisteredOn
        OR (GuardianName IS NOT NULL AND GuardianPhone IS NOT NULL)),
    -- Must be reachable: the student's phone or the guardian's phone
    CONSTRAINT CK_STUDENT_Contact CHECK (Phone IS NOT NULL OR GuardianPhone IS NOT NULL),
    CONSTRAINT CK_STUDENT_Status CHECK (Status IN (N'Prospective', N'Studying', N'On hold', N'Dropped out'))
);
GO
CREATE UNIQUE INDEX UX_STUDENT_Phone ON dbo.STUDENT (Phone) WHERE Phone IS NOT NULL;
CREATE UNIQUE INDEX UX_STUDENT_Email ON dbo.STUDENT (Email) WHERE Email IS NOT NULL;
CREATE INDEX IX_STUDENT_FullName ON dbo.STUDENT (FullName);
GO

/* ---------------------------------------------------------------------
   9. PROGRAM - Training programs (IELTS, TOEIC, Communication, Kids)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.PROGRAM (
    ProgramId       VARCHAR(10)    NOT NULL,
    ProgramName     NVARCHAR(100)  NOT NULL,
    TargetLearners  NVARCHAR(100)  NULL,
    Description     NVARCHAR(500)  NULL,
    CONSTRAINT PK_PROGRAM PRIMARY KEY (ProgramId),
    CONSTRAINT UQ_PROGRAM_ProgramName UNIQUE (ProgramName)
);
GO

/* ---------------------------------------------------------------------
   10. COURSE - Courses (CEFR level), self-reference to the prerequisite
   --------------------------------------------------------------------- */
CREATE TABLE dbo.COURSE (
    CourseId              VARCHAR(10)    NOT NULL,
    ProgramId             VARCHAR(10)    NOT NULL,
    CourseName            NVARCHAR(100)  NOT NULL,
    Level                 VARCHAR(2)     NOT NULL,
    SessionCount          INT            NOT NULL,
    SessionMinutes        INT            NOT NULL CONSTRAINT DF_COURSE_SessionMinutes DEFAULT (90),
    Tuition               DECIMAL(12,0)  NOT NULL,
    MinPlacementScore     DECIMAL(4,2)   NULL,
    PrerequisiteCourseId  VARCHAR(10)    NULL,
    SyllabusXml           XML (CONTENT dbo.xsc_CourseSyllabus) NULL,
    Status                NVARCHAR(20)   NOT NULL CONSTRAINT DF_COURSE_Status DEFAULT (N'Open'),
    CONSTRAINT PK_COURSE PRIMARY KEY (CourseId),
    CONSTRAINT FK_COURSE_PROGRAM FOREIGN KEY (ProgramId) REFERENCES dbo.PROGRAM (ProgramId),
    CONSTRAINT FK_COURSE_COURSE FOREIGN KEY (PrerequisiteCourseId) REFERENCES dbo.COURSE (CourseId),
    CONSTRAINT UQ_COURSE_CourseName UNIQUE (CourseName),
    CONSTRAINT CK_COURSE_Level CHECK (Level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
    CONSTRAINT CK_COURSE_SessionCount CHECK (SessionCount BETWEEN 1 AND 200),
    CONSTRAINT CK_COURSE_SessionMinutes CHECK (SessionMinutes BETWEEN 30 AND 240),
    CONSTRAINT CK_COURSE_Tuition CHECK (Tuition >= 0),
    CONSTRAINT CK_COURSE_MinPlacementScore CHECK (MinPlacementScore BETWEEN 0 AND 10),
    CONSTRAINT CK_COURSE_Prerequisite CHECK (PrerequisiteCourseId <> CourseId),
    CONSTRAINT CK_COURSE_Status CHECK (Status IN (N'Open', N'Discontinued'))
);
GO

/* ---------------------------------------------------------------------
   11. GRADE_COMPONENT - Grade components and their weights per course
   --------------------------------------------------------------------- */
CREATE TABLE dbo.GRADE_COMPONENT (
    ComponentId    INT IDENTITY(1,1)  NOT NULL,
    CourseId       VARCHAR(10)        NOT NULL,
    ComponentName  NVARCHAR(50)       NOT NULL,
    Weight         DECIMAL(5,2)       NOT NULL,
    CONSTRAINT PK_GRADE_COMPONENT PRIMARY KEY (ComponentId),
    CONSTRAINT FK_GRADE_COMPONENT_COURSE FOREIGN KEY (CourseId) REFERENCES dbo.COURSE (CourseId),
    CONSTRAINT UQ_GRADE_COMPONENT_CourseId_ComponentName UNIQUE (CourseId, ComponentName),
    CONSTRAINT CK_GRADE_COMPONENT_Weight CHECK (Weight > 0 AND Weight <= 100)
);
GO

/* ---------------------------------------------------------------------
   12. CLASS - Classes (one run of a course at a branch)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CLASS (
    ClassId      VARCHAR(10)    NOT NULL CONSTRAINT DF_CLASS_ClassId
                     DEFAULT ('CL' + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_CLASS AS VARCHAR(10)), 4)),
    ClassName    NVARCHAR(100)  NOT NULL,
    CourseId     VARCHAR(10)    NOT NULL,
    BranchId     VARCHAR(10)    NOT NULL,
    TeacherId    VARCHAR(10)    NOT NULL,
    RoomId       VARCHAR(10)    NOT NULL,
    StartDate    DATE           NOT NULL,
    EndDate      DATE           NULL,
    MaxStudents  INT            NOT NULL CONSTRAINT DF_CLASS_MaxStudents DEFAULT (20),
    Tuition      DECIMAL(12,0)  NOT NULL,
    Status       NVARCHAR(20)   NOT NULL CONSTRAINT DF_CLASS_Status DEFAULT (N'Enrolling'),
    CONSTRAINT PK_CLASS PRIMARY KEY (ClassId),
    CONSTRAINT FK_CLASS_COURSE FOREIGN KEY (CourseId) REFERENCES dbo.COURSE (CourseId),
    CONSTRAINT FK_CLASS_BRANCH FOREIGN KEY (BranchId) REFERENCES dbo.BRANCH (BranchId),
    CONSTRAINT FK_CLASS_TEACHER FOREIGN KEY (TeacherId) REFERENCES dbo.TEACHER (TeacherId),
    CONSTRAINT FK_CLASS_ROOM FOREIGN KEY (RoomId) REFERENCES dbo.ROOM (RoomId),
    CONSTRAINT CK_CLASS_MaxStudents CHECK (MaxStudents BETWEEN 1 AND 50),
    CONSTRAINT CK_CLASS_Tuition CHECK (Tuition >= 0),
    CONSTRAINT CK_CLASS_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate),
    CONSTRAINT CK_CLASS_Status CHECK (Status IN (N'Enrolling', N'In progress', N'Finished', N'Cancelled'))
);
GO
CREATE INDEX IX_CLASS_CourseId ON dbo.CLASS (CourseId);
CREATE INDEX IX_CLASS_TeacherId ON dbo.CLASS (TeacherId);
GO

/* ---------------------------------------------------------------------
   13. CLASS_SCHEDULE - Fixed weekly timetable of a class
       (Weekday: ISO 8601, 1 = Monday ... 7 = Sunday)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CLASS_SCHEDULE (
    ClassId    VARCHAR(10)  NOT NULL,
    Weekday    TINYINT      NOT NULL,
    StartTime  TIME(0)      NOT NULL,
    EndTime    TIME(0)      NOT NULL,
    CONSTRAINT PK_CLASS_SCHEDULE PRIMARY KEY (ClassId, Weekday),
    CONSTRAINT FK_CLASS_SCHEDULE_CLASS FOREIGN KEY (ClassId) REFERENCES dbo.CLASS (ClassId) ON DELETE CASCADE,
    CONSTRAINT CK_CLASS_SCHEDULE_Weekday CHECK (Weekday BETWEEN 1 AND 7),
    CONSTRAINT CK_CLASS_SCHEDULE_Time CHECK (EndTime > StartTime AND StartTime >= '07:00' AND EndTime <= '22:00')
);
GO

/* ---------------------------------------------------------------------
   14. CLASS_SESSION - Individual sessions (generated from CLASS_SCHEDULE)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CLASS_SESSION (
    SessionId    INT IDENTITY(1,1)  NOT NULL,
    ClassId      VARCHAR(10)        NOT NULL,
    SessionNo    INT                NOT NULL,
    SessionDate  DATE               NOT NULL,
    StartTime    TIME(0)            NOT NULL,
    EndTime      TIME(0)            NOT NULL,
    RoomId       VARCHAR(10)        NOT NULL,
    TeacherId    VARCHAR(10)        NOT NULL,
    Description  NVARCHAR(200)      NULL,
    Status       NVARCHAR(20)       NOT NULL CONSTRAINT DF_CLASS_SESSION_Status DEFAULT (N'Scheduled'),
    CONSTRAINT PK_CLASS_SESSION PRIMARY KEY (SessionId),
    CONSTRAINT FK_CLASS_SESSION_CLASS FOREIGN KEY (ClassId) REFERENCES dbo.CLASS (ClassId) ON DELETE CASCADE,
    CONSTRAINT FK_CLASS_SESSION_ROOM FOREIGN KEY (RoomId) REFERENCES dbo.ROOM (RoomId),
    CONSTRAINT FK_CLASS_SESSION_TEACHER FOREIGN KEY (TeacherId) REFERENCES dbo.TEACHER (TeacherId),
    CONSTRAINT UQ_CLASS_SESSION_ClassId_SessionNo UNIQUE (ClassId, SessionNo),
    CONSTRAINT CK_CLASS_SESSION_SessionNo CHECK (SessionNo >= 1),
    CONSTRAINT CK_CLASS_SESSION_Time CHECK (EndTime > StartTime),
    CONSTRAINT CK_CLASS_SESSION_Status CHECK (Status IN (N'Scheduled', N'Taught', N'Cancelled'))
);
GO
CREATE INDEX IX_CLASS_SESSION_SessionDate ON dbo.CLASS_SESSION (SessionDate)
    INCLUDE (ClassId, TeacherId, RoomId, StartTime, EndTime);
GO

/* ---------------------------------------------------------------------
   15. PROMOTION - Tuition promotions
   --------------------------------------------------------------------- */
CREATE TABLE dbo.PROMOTION (
    PromotionId    VARCHAR(10)    NOT NULL,
    PromotionName  NVARCHAR(100)  NOT NULL,
    DiscountType   VARCHAR(10)    NOT NULL,
    DiscountValue  DECIMAL(12,2)  NOT NULL,
    StartDate      DATE           NOT NULL,
    EndDate        DATE           NOT NULL,
    CONSTRAINT PK_PROMOTION PRIMARY KEY (PromotionId),
    CONSTRAINT CK_PROMOTION_DiscountType CHECK (DiscountType IN ('PERCENT', 'AMOUNT')),
    CONSTRAINT CK_PROMOTION_DiscountValue CHECK (DiscountValue > 0 AND (DiscountType <> 'PERCENT' OR DiscountValue <= 50)),
    CONSTRAINT CK_PROMOTION_Dates CHECK (EndDate >= StartDate)
);
GO

/* ---------------------------------------------------------------------
   16. ENROLLMENT - A student enrolled in a class (n-n STUDENT - CLASS)
       AmountPaid is a derived attribute = SUM(RECEIPT.Amount), kept by a trigger.
   --------------------------------------------------------------------- */
CREATE TABLE dbo.ENROLLMENT (
    EnrollmentId          VARCHAR(10)    NOT NULL CONSTRAINT DF_ENROLLMENT_EnrollmentId
                              DEFAULT ('EN' + RIGHT('000000' + CAST(NEXT VALUE FOR dbo.seq_ENROLLMENT AS VARCHAR(10)), 6)),
    StudentId             VARCHAR(10)    NOT NULL,
    ClassId               VARCHAR(10)    NOT NULL,
    EnrolledOn            DATE           NOT NULL CONSTRAINT DF_ENROLLMENT_EnrolledOn
                              DEFAULT (CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00') AS DATE)),
    BaseTuition           DECIMAL(12,0)  NOT NULL,
    PromotionId           VARCHAR(10)    NULL,
    DiscountAmount        DECIMAL(12,0)  NOT NULL CONSTRAINT DF_ENROLLMENT_DiscountAmount DEFAULT (0),
    TuitionDue            AS (BaseTuition - DiscountAmount) PERSISTED,
    AmountPaid            DECIMAL(12,0)  NOT NULL CONSTRAINT DF_ENROLLMENT_AmountPaid DEFAULT (0),
    Status                NVARCHAR(20)   NOT NULL CONSTRAINT DF_ENROLLMENT_Status DEFAULT (N'Studying'),
    FinalGrade            DECIMAL(4,2)   NULL,
    Result                NVARCHAR(20)   NULL,
    EnrolledByEmployeeId  VARCHAR(10)    NULL,
    CONSTRAINT PK_ENROLLMENT PRIMARY KEY (EnrollmentId),
    CONSTRAINT FK_ENROLLMENT_STUDENT FOREIGN KEY (StudentId) REFERENCES dbo.STUDENT (StudentId),
    CONSTRAINT FK_ENROLLMENT_CLASS FOREIGN KEY (ClassId) REFERENCES dbo.CLASS (ClassId),
    CONSTRAINT FK_ENROLLMENT_PROMOTION FOREIGN KEY (PromotionId) REFERENCES dbo.PROMOTION (PromotionId),
    CONSTRAINT FK_ENROLLMENT_EMPLOYEE FOREIGN KEY (EnrolledByEmployeeId) REFERENCES dbo.EMPLOYEE (EmployeeId),
    CONSTRAINT UQ_ENROLLMENT_StudentId_ClassId UNIQUE (StudentId, ClassId),
    CONSTRAINT CK_ENROLLMENT_BaseTuition CHECK (BaseTuition >= 0),
    CONSTRAINT CK_ENROLLMENT_DiscountAmount CHECK (DiscountAmount >= 0 AND DiscountAmount <= BaseTuition),
    -- Cross-column constraint: the amount paid never exceeds the tuition due
    CONSTRAINT CK_ENROLLMENT_AmountPaid CHECK (AmountPaid >= 0 AND AmountPaid <= BaseTuition - DiscountAmount),
    CONSTRAINT CK_ENROLLMENT_Status CHECK (Status IN (N'Studying', N'On hold', N'Left', N'Completed')),
    CONSTRAINT CK_ENROLLMENT_FinalGrade CHECK (FinalGrade BETWEEN 0 AND 10),
    CONSTRAINT CK_ENROLLMENT_Result CHECK (Result IN (N'Passed', N'Failed'))
);
GO
CREATE INDEX IX_ENROLLMENT_ClassId ON dbo.ENROLLMENT (ClassId) INCLUDE (StudentId, Status);
GO

/* ---------------------------------------------------------------------
   17. RECEIPT - Tuition receipts (one enrollment may be paid in installments)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.RECEIPT (
    ReceiptId              VARCHAR(10)    NOT NULL CONSTRAINT DF_RECEIPT_ReceiptId
                               DEFAULT ('RC' + RIGHT('000000' + CAST(NEXT VALUE FOR dbo.seq_RECEIPT AS VARCHAR(10)), 6)),
    EnrollmentId           VARCHAR(10)    NOT NULL,
    PaidAtUtc              DATETIME       NOT NULL CONSTRAINT DF_RECEIPT_PaidAtUtc DEFAULT (GETUTCDATE()),
    Amount                 DECIMAL(12,0)  NOT NULL,
    PaymentMethod          NVARCHAR(20)   NOT NULL CONSTRAINT DF_RECEIPT_PaymentMethod DEFAULT (N'Cash'),
    CollectedByEmployeeId  VARCHAR(10)    NOT NULL,
    Description            NVARCHAR(200)  NULL,
    Status                 NVARCHAR(20)   NOT NULL CONSTRAINT DF_RECEIPT_Status DEFAULT (N'Valid'),
    CancelReason           NVARCHAR(200)  NULL,
    CONSTRAINT PK_RECEIPT PRIMARY KEY (ReceiptId),
    CONSTRAINT FK_RECEIPT_ENROLLMENT FOREIGN KEY (EnrollmentId) REFERENCES dbo.ENROLLMENT (EnrollmentId),
    CONSTRAINT FK_RECEIPT_EMPLOYEE FOREIGN KEY (CollectedByEmployeeId) REFERENCES dbo.EMPLOYEE (EmployeeId),
    CONSTRAINT CK_RECEIPT_Amount CHECK (Amount > 0),
    CONSTRAINT CK_RECEIPT_PaymentMethod CHECK (PaymentMethod IN (N'Cash', N'Bank transfer', N'Card')),
    CONSTRAINT CK_RECEIPT_Status CHECK (Status IN (N'Valid', N'Cancelled')),
    CONSTRAINT CK_RECEIPT_CancelReason CHECK (Status = N'Valid' OR CancelReason IS NOT NULL)
);
GO
CREATE INDEX IX_RECEIPT_EnrollmentId ON dbo.RECEIPT (EnrollmentId) INCLUDE (Amount, Status);
CREATE INDEX IX_RECEIPT_PaidAtUtc ON dbo.RECEIPT (PaidAtUtc) INCLUDE (Amount, Status, EnrollmentId);
GO

/* ---------------------------------------------------------------------
   18. ATTENDANCE - Attendance of a student at a session
   --------------------------------------------------------------------- */
CREATE TABLE dbo.ATTENDANCE (
    SessionId     INT            NOT NULL,
    EnrollmentId  VARCHAR(10)    NOT NULL,
    Status        NVARCHAR(20)   NOT NULL CONSTRAINT DF_ATTENDANCE_Status DEFAULT (N'Present'),
    Notes         NVARCHAR(200)  NULL,
    CONSTRAINT PK_ATTENDANCE PRIMARY KEY (SessionId, EnrollmentId),
    CONSTRAINT FK_ATTENDANCE_CLASS_SESSION FOREIGN KEY (SessionId) REFERENCES dbo.CLASS_SESSION (SessionId) ON DELETE CASCADE,
    CONSTRAINT FK_ATTENDANCE_ENROLLMENT FOREIGN KEY (EnrollmentId) REFERENCES dbo.ENROLLMENT (EnrollmentId),
    CONSTRAINT CK_ATTENDANCE_Status CHECK (Status IN (N'Present', N'Late', N'Excused absence', N'Unexcused absence'))
);
GO

/* ---------------------------------------------------------------------
   19. GRADE - Score of a student for each grade component of a class
   --------------------------------------------------------------------- */
CREATE TABLE dbo.GRADE (
    EnrollmentId  VARCHAR(10)    NOT NULL,
    ComponentId   INT            NOT NULL,
    Score         DECIMAL(4,2)   NOT NULL,
    EnteredAtUtc  DATETIME       NOT NULL CONSTRAINT DF_GRADE_EnteredAtUtc DEFAULT (GETUTCDATE()),
    EnteredBy     NVARCHAR(128)  NOT NULL CONSTRAINT DF_GRADE_EnteredBy DEFAULT (ORIGINAL_LOGIN()),
    CONSTRAINT PK_GRADE PRIMARY KEY (EnrollmentId, ComponentId),
    CONSTRAINT FK_GRADE_ENROLLMENT FOREIGN KEY (EnrollmentId) REFERENCES dbo.ENROLLMENT (EnrollmentId),
    CONSTRAINT FK_GRADE_GRADE_COMPONENT FOREIGN KEY (ComponentId) REFERENCES dbo.GRADE_COMPONENT (ComponentId),
    CONSTRAINT CK_GRADE_Score CHECK (Score BETWEEN 0 AND 10)
);
GO

/* ---------------------------------------------------------------------
   20. PLACEMENT_TEST - Placement test before enrolling (4 skills)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.PLACEMENT_TEST (
    TestId               VARCHAR(10)    NOT NULL CONSTRAINT DF_PLACEMENT_TEST_TestId
                             DEFAULT ('PT' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_PLACEMENT_TEST AS VARCHAR(10)), 5)),
    StudentId            VARCHAR(10)    NOT NULL,
    TestDate             DATE           NOT NULL CONSTRAINT DF_PLACEMENT_TEST_TestDate
                             DEFAULT (CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00') AS DATE)),
    ListeningScore       DECIMAL(4,2)   NOT NULL,
    SpeakingScore        DECIMAL(4,2)   NOT NULL,
    ReadingScore         DECIMAL(4,2)   NOT NULL,
    WritingScore         DECIMAL(4,2)   NOT NULL,
    OverallScore         AS CAST((ListeningScore + SpeakingScore + ReadingScore + WritingScore) / 4 AS DECIMAL(4,2)) PERSISTED,
    RecommendedCourseId  VARCHAR(10)    NULL,
    GradedByTeacherId    VARCHAR(10)    NULL,
    Notes                NVARCHAR(200)  NULL,
    CONSTRAINT PK_PLACEMENT_TEST PRIMARY KEY (TestId),
    CONSTRAINT FK_PLACEMENT_TEST_STUDENT FOREIGN KEY (StudentId) REFERENCES dbo.STUDENT (StudentId),
    CONSTRAINT FK_PLACEMENT_TEST_COURSE FOREIGN KEY (RecommendedCourseId) REFERENCES dbo.COURSE (CourseId),
    CONSTRAINT FK_PLACEMENT_TEST_TEACHER FOREIGN KEY (GradedByTeacherId) REFERENCES dbo.TEACHER (TeacherId),
    CONSTRAINT CK_PLACEMENT_TEST_Scores CHECK (
        ListeningScore BETWEEN 0 AND 10 AND SpeakingScore BETWEEN 0 AND 10 AND
        ReadingScore   BETWEEN 0 AND 10 AND WritingScore  BETWEEN 0 AND 10)
);
GO

/* ---------------------------------------------------------------------
   21. CERTIFICATE - Course completion certificates issued by the center
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CERTIFICATE (
    CertificateId   VARCHAR(10)   NOT NULL CONSTRAINT DF_CERTIFICATE_CertificateId
                        DEFAULT ('CE' + RIGHT('00000' + CAST(NEXT VALUE FOR dbo.seq_CERTIFICATE AS VARCHAR(10)), 5)),
    EnrollmentId    VARCHAR(10)   NOT NULL,
    SerialNumber    VARCHAR(20)   NOT NULL,
    IssuedOn        DATE          NOT NULL CONSTRAINT DF_CERTIFICATE_IssuedOn
                        DEFAULT (CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00') AS DATE)),
    FinalGrade      DECIMAL(4,2)  NOT NULL,
    Classification  NVARCHAR(20)  NOT NULL,
    CONSTRAINT PK_CERTIFICATE PRIMARY KEY (CertificateId),
    CONSTRAINT FK_CERTIFICATE_ENROLLMENT FOREIGN KEY (EnrollmentId) REFERENCES dbo.ENROLLMENT (EnrollmentId),
    CONSTRAINT UQ_CERTIFICATE_EnrollmentId UNIQUE (EnrollmentId),
    CONSTRAINT UQ_CERTIFICATE_SerialNumber UNIQUE (SerialNumber),
    CONSTRAINT CK_CERTIFICATE_FinalGrade CHECK (FinalGrade BETWEEN 5 AND 10),
    CONSTRAINT CK_CERTIFICATE_Classification CHECK (Classification IN (N'Excellent', N'Very good', N'Good', N'Average'))
);
GO

/* ---------------------------------------------------------------------
   22. PAYROLL - Monthly teacher payroll (finalized with a cursor)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.PAYROLL (
    PayrollId       INT IDENTITY(1,1)  NOT NULL,
    TeacherId       VARCHAR(10)        NOT NULL,
    Month           TINYINT            NOT NULL,
    Year            SMALLINT           NOT NULL,
    SessionCount    INT                NOT NULL,
    Hours           DECIMAL(6,2)       NOT NULL,
    HourlyRate      DECIMAL(12,0)      NOT NULL,
    Bonus           DECIMAL(12,0)      NOT NULL CONSTRAINT DF_PAYROLL_Bonus DEFAULT (0),
    Deduction       DECIMAL(12,0)      NOT NULL CONSTRAINT DF_PAYROLL_Deduction DEFAULT (0),
    TotalPay        AS (CAST(Hours * HourlyRate AS DECIMAL(14,0)) + Bonus - Deduction) PERSISTED,
    FinalizedAtUtc  DATETIME           NOT NULL CONSTRAINT DF_PAYROLL_FinalizedAtUtc DEFAULT (GETUTCDATE()),
    Status          NVARCHAR(20)       NOT NULL CONSTRAINT DF_PAYROLL_Status DEFAULT (N'Finalized'),
    CONSTRAINT PK_PAYROLL PRIMARY KEY (PayrollId),
    CONSTRAINT FK_PAYROLL_TEACHER FOREIGN KEY (TeacherId) REFERENCES dbo.TEACHER (TeacherId),
    CONSTRAINT UQ_PAYROLL_TeacherId_Month_Year UNIQUE (TeacherId, Month, Year),
    CONSTRAINT CK_PAYROLL_Month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_PAYROLL_Year CHECK (Year >= 2020),
    CONSTRAINT CK_PAYROLL_Figures CHECK (SessionCount >= 0 AND Hours >= 0 AND Bonus >= 0 AND Deduction >= 0),
    CONSTRAINT CK_PAYROLL_Status CHECK (Status IN (N'Finalized', N'Paid'))
);
GO

/* ---------------------------------------------------------------------
   23. AUDIT_LOG - Audit trail, written by triggers
   --------------------------------------------------------------------- */
CREATE TABLE dbo.AUDIT_LOG (
    LogId        BIGINT IDENTITY(1,1)  NOT NULL,
    LoggedAtUtc  DATETIME              NOT NULL CONSTRAINT DF_AUDIT_LOG_LoggedAtUtc DEFAULT (GETUTCDATE()),
    PerformedBy  NVARCHAR(128)         NOT NULL CONSTRAINT DF_AUDIT_LOG_PerformedBy DEFAULT (ORIGINAL_LOGIN()),
    TableName    NVARCHAR(50)          NOT NULL,
    Action       VARCHAR(10)           NOT NULL,
    RecordKey    NVARCHAR(100)         NOT NULL,
    OldData      XML                   NULL,
    NewData      XML                   NULL,
    CONSTRAINT PK_AUDIT_LOG PRIMARY KEY (LogId),
    CONSTRAINT CK_AUDIT_LOG_Action CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO
