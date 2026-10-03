/* =====================================================================
   File   : 07_seed_data.sql - Demo data
   - Dates are RELATIVE to the day the script runs (@Today), so running
     it on any day gives: finished classes, classes in progress, classes
     about to start, revenue for the current month...
   - Business data is loaded THROUGH PROCEDURES (usp_Enrollment_Create,
     usp_Class_GenerateSessions, usp_Class_EvaluateResults,
     usp_Payroll_Finalize, usp_Account_Create) => triggers, functions and
     cursors are exercised at the same time.
   - All data is fictitious, not real personal information.

   When: the last script of scripts/db_init (after 06, so procedures, triggers and roles exist). It
   expects the EMPTY database created by 00; a second run fails on duplicate keys.
   Why relative dates: @Today = the day db_init runs, @Monday = Monday of that week; every date
   (registrations, class starts, promotions, receipts, payroll months) is an offset from them, so
   the screens, the demos and the tests always find data in every state. Each class starts a fixed
   number of days after a Monday that matches its weekly days, so its first session is its start date.
   How IDs are generated:
     - Catalogs, staff and students get explicit IDs (BR01, EM0001, TE0001, ST00001...) because the
       rest of the script and the tests refer to them; ALTER SEQUENCE ... RESTART then moves the
       sequence past the last explicit ID, so the next DEFAULT value is not a duplicate.
     - Classes, enrollments, receipts, placement tests and certificates take their ID from a DEFAULT
       constraint with NEXT VALUE FOR seq_<TABLE> (CL0001, EN000001, RC000001...); usp_Class_Create
       and usp_Enrollment_Create return it through an OUTPUT parameter.
     - Classes and enrollments are created one at a time in a fixed order (WHILE loop, cursor with
       ORDER BY), so they get the same IDs on every run; 12_tests.sql relies on them (CL0004, EN000001).
   Repeatable "random" values: ABS(CHECKSUM(...)) % n turns IDs into a number from 0 to n-1, so
   attendance, scores and dates differ between students but the same IDs always give the same value.
   Demo accounts (section 9): contained users for the four roles; their shared password is test data
   documented in docs/SETUP.md, never a real password.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Monday DATE = DATEADD(DAY, 1 - dbo.fn_Weekday(@Today), @Today);   -- Monday of this week

/* ---------------------------------------------------------------------
   1. Catalogs: branches, rooms, programs, courses, grade components, promotions
   --------------------------------------------------------------------- */
INSERT INTO dbo.BRANCH (BranchId, BranchName, Address, Phone, Email, FoundedOn) VALUES
('BR01', N'District 1 Branch', N'12 Nguyễn Thị Minh Khai, P. Đa Kao, Quận 1, TP.HCM',  '02838221234', 'q1@englishcenter.edu.vn', '20180315'),
('BR02', N'Thu Duc Branch',    N'45 Võ Văn Ngân, P. Linh Chiểu, TP. Thủ Đức, TP.HCM', '02837225678', 'td@englishcenter.edu.vn', '20210901');

INSERT INTO dbo.ROOM (RoomId, BranchId, RoomName, Capacity, RoomType) VALUES
('D1-101', 'BR01', N'Room 101',      25, N'Lecture'),
('D1-102', 'BR01', N'Room 102',      20, N'Lecture'),
('D1-201', 'BR01', N'Room 201',      30, N'Multi-purpose'),
('D1-LAB', 'BR01', N'Listening Lab', 16, N'Lab'),
('TD-301', 'BR02', N'Room 301',      25, N'Lecture'),
('TD-302', 'BR02', N'Room 302',      20, N'Lecture'),
('TD-303', 'BR02', N'Room 303',      18, N'Multi-purpose'),
('TD-LAB', 'BR02', N'Listening Lab', 16, N'Lab');

INSERT INTO dbo.PROGRAM (ProgramId, ProgramName, TargetLearners, Description) VALUES
('IELTS', N'IELTS Preparation',        N'High-school students, university students, working adults', N'Path: Foundation -> 5.5 -> 6.5+'),
('TOEIC', N'TOEIC Preparation',        N'University students, working adults',                        N'Graduation requirements and career advancement'),
('COMM',  N'English for Communication', N'Working adults',                                            N'Listening and speaking reflexes for work and daily life'),
('KIDS',  N'English for Kids',         N'Children aged 6 - 11',                                       N'Based on the Cambridge Young Learners framework');

-- SyllabusXml is typed XML: SQL Server validates every document against xsc_CourseSyllabus (01_tables.sql)
-- while inserting it; a course without a syllabus keeps NULL. PrerequisiteCourseId builds the course path
-- read by the recursive query Q8 of 08_demo_queries.sql.
INSERT INTO dbo.COURSE (CourseId, ProgramId, CourseName, Level, SessionCount, SessionMinutes, Tuition, MinPlacementScore,
                        PrerequisiteCourseId, SyllabusXml) VALUES
('IE-FND', 'IELTS', N'IELTS Foundation',       'A2', 24, 120,  6500000, 4.0, NULL, N'
<Syllabus>
  <Textbook Author="Cambridge University Press" Year="2021">Complete IELTS Foundation</Textbook>
  <Objective>Build a foundation in the 4 skills, get used to the test format, target band 4.5</Objective>
  <Unit No="1" Sessions="6"><Title>Getting to know the IELTS test</Title><Skill>Listening</Skill><Skill>Reading</Skill></Unit>
  <Unit No="2" Sessions="6"><Title>Topic vocabulary: Education - Work</Title><Skill>Vocabulary</Skill><Skill>Speaking</Skill></Unit>
  <Unit No="3" Sessions="6"><Title>Complex sentences</Title><Skill>Grammar</Skill><Skill>Writing</Skill></Unit>
  <Unit No="4" Sessions="6"><Title>Full practice tests</Title><Skill>Listening</Skill><Skill>Reading</Skill><Skill>Writing</Skill><Skill>Speaking</Skill></Unit>
</Syllabus>'),
('IE-55', 'IELTS', N'IELTS 5.5 Intensive',    'B1', 30, 120,  8500000, 5.5, 'IE-FND', N'
<Syllabus>
  <Textbook Author="Cambridge University Press" Year="2023">Cambridge IELTS 18</Textbook>
  <Textbook Author="Pauline Cullen" Year="2021">The Official Cambridge Guide to IELTS</Textbook>
  <Objective>Reach band 5.5 - 6.0 and master the strategy for every question type</Objective>
  <Unit No="1" Sessions="6"><Title>Listening Section 1-4</Title><Skill>Listening</Skill></Unit>
  <Unit No="2" Sessions="6"><Title>Reading: True/False/Not Given, Matching</Title><Skill>Reading</Skill></Unit>
  <Unit No="3" Sessions="6"><Title>Writing Task 1: Charts</Title><Skill>Writing</Skill></Unit>
  <Unit No="4" Sessions="6"><Title>Writing Task 2: Argumentative essays</Title><Skill>Writing</Skill><Skill>Grammar</Skill></Unit>
  <Unit No="5" Sessions="6"><Title>Speaking Part 1-3</Title><Skill>Speaking</Skill></Unit>
</Syllabus>'),
('IE-65', 'IELTS', N'IELTS 6.5 Advanced',     'B2', 30, 120, 10500000, 6.5, 'IE-55', NULL),
('TO-450', 'TOEIC', N'TOEIC 450+',            'A2', 20,  90,  4500000, 3.0, NULL, N'
<Syllabus>
  <Textbook Author="ETS" Year="2022">ETS TOEIC Test 2022</Textbook>
  <Objective>Score 450+ in TOEIC Listening &amp; Reading</Objective>
  <Unit No="1" Sessions="5"><Title>Part 1-2: Photographs, Question-Response</Title><Skill>Listening</Skill></Unit>
  <Unit No="2" Sessions="5"><Title>Part 3-4: Conversations, Talks</Title><Skill>Listening</Skill></Unit>
  <Unit No="3" Sessions="5"><Title>Part 5-6: Incomplete Sentences</Title><Skill>Grammar</Skill><Skill>Reading</Skill></Unit>
  <Unit No="4" Sessions="5"><Title>Part 7: Reading Comprehension</Title><Skill>Reading</Skill></Unit>
</Syllabus>'),
('TO-750', 'TOEIC', N'TOEIC 750+',            'B1', 24,  90,  6000000, 5.0, 'TO-450', NULL),
('CM-A1', 'COMM',  N'Communication Elementary',   'A1', 20,  90,  3800000, NULL, NULL, N'
<Syllabus>
  <Textbook Author="Oxford University Press" Year="2019">English File Beginner</Textbook>
  <Objective>Introduce yourself with confidence and handle everyday situations</Objective>
  <Unit No="1" Sessions="5"><Title>Greetings and Introductions</Title><Skill>Speaking</Skill><Skill>Pronunciation</Skill></Unit>
  <Unit No="2" Sessions="5"><Title>Daily Routines</Title><Skill>Speaking</Skill><Skill>Listening</Skill></Unit>
  <Unit No="3" Sessions="5"><Title>Shopping and Eating Out</Title><Skill>Speaking</Skill><Skill>Vocabulary</Skill></Unit>
  <Unit No="4" Sessions="5"><Title>Travel and Directions</Title><Skill>Listening</Skill><Skill>Speaking</Skill></Unit>
</Syllabus>'),
('CM-B1', 'COMM',  N'Communication Intermediate', 'B1', 24,  90,  4800000, 4.5, 'CM-A1', NULL),
('KD-STA', 'KIDS', N'Kids Starters',          'A1', 32,  90,  5200000, NULL, NULL, N'
<Syllabus>
  <Textbook Author="Cambridge University Press" Year="2018">Fun for Starters</Textbook>
  <Objective>Accurate pronunciation, a 400-word vocabulary, ready for Cambridge Starters</Objective>
  <Unit No="1" Sessions="8"><Title>Phonics</Title><Skill>Phonics</Skill><Skill>Pronunciation</Skill></Unit>
  <Unit No="2" Sessions="8"><Title>Colors and Numbers</Title><Skill>Vocabulary</Skill><Skill>Listening</Skill></Unit>
  <Unit No="3" Sessions="8"><Title>My Family</Title><Skill>Speaking</Skill><Skill>Vocabulary</Skill></Unit>
  <Unit No="4" Sessions="8"><Title>Animals</Title><Skill>Listening</Skill><Skill>Speaking</Skill></Unit>
</Syllabus>'),
('KD-MOV', 'KIDS', N'Kids Movers',            'A2', 32,  90,  5600000, 4.0, 'KD-STA', NULL);

-- One set of grade components per program (weights add up to 100), copied to every course of the program
-- by joining COURSE with a VALUES table constructor
INSERT INTO dbo.GRADE_COMPONENT (CourseId, ComponentName, Weight)
SELECT co.CourseId, gc.ComponentName, gc.Weight
FROM dbo.COURSE co
JOIN (VALUES ('IELTS', N'Homework', 20),      ('IELTS', N'Midterm', 30),      ('IELTS', N'Final exam', 50),
             ('TOEIC', N'Participation', 10), ('TOEIC', N'Midterm', 30),      ('TOEIC', N'Final exam', 60),
             ('COMM',  N'Participation', 20), ('COMM',  N'Presentation', 30), ('COMM',  N'Final exam', 50),
             ('KIDS',  N'Participation', 20), ('KIDS',  N'Midterm', 30),      ('KIDS',  N'Final exam', 50)
     ) AS gc (ProgramId, ComponentName, Weight) ON gc.ProgramId = co.ProgramId;

-- PR-SUMMER is already over (it covers the enrollments of the finished classes), PR-REFER and PR-OPEN are valid today
INSERT INTO dbo.PROMOTION (PromotionId, PromotionName, DiscountType, DiscountValue, StartDate, EndDate) VALUES
('PR-SUMMER', N'Summer offer: 10% off',              'PERCENT', 10,     DATEADD(WEEK, -26, @Monday), DATEADD(WEEK, -12, @Monday)),
('PR-REFER',  N'Refer a friend: 500,000 VND off',    'AMOUNT',  500000, DATEADD(YEAR, -1, @Today),   DATEADD(YEAR, 1, @Today)),
('PR-OPEN',   N'New class opening: 15% off',         'PERCENT', 15,     DATEADD(WEEK, -4, @Monday),  DATEADD(WEEK, 6, @Monday));

/* ---------------------------------------------------------------------
   2. Staff: employees and teachers (explicit IDs, then restart the sequences)
   --------------------------------------------------------------------- */
INSERT INTO dbo.EMPLOYEE (EmployeeId, FullName, DateOfBirth, Gender, Phone, Email, Address, Position, BranchId, HireDate, BaseSalary) VALUES
('EM0001', N'Trần Minh Quân',  '19850412', N'Male',   '0903111001', 'quan.tm@englishcenter.edu.vn',  N'Quận 3, TP.HCM',      N'Manager',        'BR01', '20180315', 25000000),
('EM0002', N'Lê Thị Lan',      '19930820', N'Female', '0903111002', 'lan.lt@englishcenter.edu.vn',   N'Quận 1, TP.HCM',      N'Academic staff', 'BR01', '20190601', 11000000),
('EM0003', N'Phạm Văn Minh',   '19900105', N'Male',   '0903111003', 'minh.pv@englishcenter.edu.vn',  N'Quận 10, TP.HCM',     N'Accountant',     'BR01', '20180401', 13000000),
('EM0004', N'Nguyễn Thu Hà',   '19960314', N'Female', '0903111004', 'ha.nt@englishcenter.edu.vn',    N'TP. Thủ Đức, TP.HCM', N'Academic staff', 'BR02', '20210901', 10500000),
('EM0005', N'Võ Thanh Tùng',   '19920709', N'Male',   '0903111005', 'tung.vt@englishcenter.edu.vn',  N'Bình Thạnh, TP.HCM',  N'Accountant',     'BR02', '20210901', 12500000),
('EM0006', N'Đặng Ngọc Mai',   '19980228', N'Female', '0903111006', 'mai.dn@englishcenter.edu.vn',   N'Quận 5, TP.HCM',      N'Consultant',     'BR01', '20220110',  9000000);
-- Continue the numbering after the explicit IDs (DF_EMPLOYEE_EmployeeId uses NEXT VALUE FOR seq_EMPLOYEE)
ALTER SEQUENCE dbo.seq_EMPLOYEE RESTART WITH 7;

-- ProfileXml (untyped XML): certificates, experience and specialties, read by usp_Teacher_FindByCertificate
-- and the XQuery demos X3/X4 of 08_demo_queries.sql

INSERT INTO dbo.TEACHER (TeacherId, FullName, DateOfBirth, Gender, Nationality, Phone, Email, Degree, TeacherType, HourlyRate,
                         BranchId, HireDate, ProfileXml) VALUES
('TE0001', N'John Smith',       '19860611', N'Male',   N'United Kingdom', '0908222001', 'john.smith@englishcenter.edu.vn', N'Master',   N'Native',     450000, 'BR01', '20180315',
 N'<Profile><Certificate Type="CELTA" Year="2014"/><Certificate Type="IELTS Examiner" Year="2019"/><Experience Years="10"><Workplace From="2014" To="2018">British Council</Workplace></Experience><Specialty>IELTS Speaking</Specialty><Specialty>IELTS Writing</Specialty></Profile>'),
('TE0002', N'Nguyễn Hoàng Anh', '19900923', N'Male',   N'Vietnam',        '0908222002', 'anh.nh@englishcenter.edu.vn',     N'Master',   N'Vietnamese', 300000, 'BR01', '20190110',
 N'<Profile><Certificate Type="IELTS" Score="8.5" Year="2023"/><Certificate Type="TESOL" Year="2019"/><Experience Years="8"><Workplace From="2016" To="2019">ILA Vietnam</Workplace></Experience><Specialty>IELTS Reading</Specialty><Specialty>IELTS Listening</Specialty></Profile>'),
('TE0003', N'Trần Thị Hoa',     '19950517', N'Female', N'Vietnam',        '0908222003', 'hoa.tt@englishcenter.edu.vn',     N'Bachelor', N'Vietnamese', 250000, 'BR01', '20210301',
 N'<Profile><Certificate Type="IELTS" Score="8.0" Year="2022"/><Certificate Type="TESOL" Year="2021"/><Experience Years="5"/><Specialty>Communication</Specialty></Profile>'),
('TE0004', N'Emily Johnson',    '19920302', N'Female', N'United States',  '0908222004', 'emily.j@englishcenter.edu.vn',    N'Bachelor', N'Native',     420000, 'BR02', '20210901',
 N'<Profile><Certificate Type="TESOL" Year="2017"/><Experience Years="7"/><Specialty>Communication</Specialty><Specialty>Pronunciation</Specialty></Profile>'),
('TE0005', N'Lê Quốc Bảo',      '19910830', N'Male',   N'Vietnam',        '0908222005', 'bao.lq@englishcenter.edu.vn',     N'Master',   N'Vietnamese', 260000, 'BR01', '20200615',
 N'<Profile><Certificate Type="TOEIC" Score="990" Year="2021"/><Certificate Type="IELTS" Score="7.5" Year="2020"/><Experience Years="6"/><Specialty>TOEIC</Specialty></Profile>'),
('TE0006', N'Phạm Ngọc Diệp',   '19970124', N'Female', N'Vietnam',        '0908222006', 'diep.pn@englishcenter.edu.vn',    N'Bachelor', N'Vietnamese', 220000, 'BR01', '20220801',
 N'<Profile><Certificate Type="IELTS" Score="7.5" Year="2022"/><Certificate Type="TKT" Year="2023"/><Experience Years="4"/><Specialty>Young learners</Specialty></Profile>'),
('TE0007', N'David Brown',      '19830719', N'Male',   N'Australia',      '0908222007', 'david.b@englishcenter.edu.vn',    N'Bachelor', N'Native',     400000, 'BR02', '20210901',
 N'<Profile><Certificate Type="CELTA" Year="2012"/><Experience Years="12"/><Specialty>Communication</Specialty></Profile>'),
('TE0008', N'Huỳnh Minh Thư',   '19940411', N'Female', N'Vietnam',        '0908222008', 'thu.hm@englishcenter.edu.vn',     N'Master',   N'Vietnamese', 280000, 'BR02', '20220215',
 N'<Profile><Certificate Type="IELTS" Score="8.0" Year="2024"/><Experience Years="5"/><Specialty>IELTS Writing</Specialty></Profile>');
ALTER SEQUENCE dbo.seq_TEACHER RESTART WITH 9;

/* ---------------------------------------------------------------------
   3. Students (DaysAgo = registration date as a number of days before today)
   --------------------------------------------------------------------- */
DECLARE @Students TABLE (StudentId VARCHAR(10), FullName NVARCHAR(100), DateOfBirth DATE, Gender NVARCHAR(10),
                         Phone VARCHAR(15), Email VARCHAR(100), Occupation NVARCHAR(50),
                         GuardianName NVARCHAR(100), GuardianPhone VARCHAR(15), BranchId VARCHAR(10), DaysAgo INT);
-- The table variable is filled once and reused below for STUDENT, the placement tests and the enrollment list.
-- Pupils under 18 have a guardian name and phone (CK_STUDENT_Guardian).
INSERT INTO @Students VALUES
('ST00001', N'Nguyễn Văn An',        '20040312', N'Male',   '0901000001', 'an.nv04@gmail.com',      N'University student', NULL, NULL, 'BR01', 175),
('ST00002', N'Trần Thị Bích Ngọc',   '20030725', N'Female', '0901000002', 'ngoc.ttb@gmail.com',     N'University student', NULL, NULL, 'BR01', 175),
('ST00003', N'Lê Hoàng Phúc',        '20051102', N'Male',   '0901000003', 'phuc.lh@gmail.com',      N'University student', NULL, NULL, 'BR01', 174),
('ST00004', N'Phạm Minh Châu',       '20020118', N'Female', '0901000004', 'chau.pm@gmail.com',      N'University student', NULL, NULL, 'BR01', 174),
('ST00005', N'Hoàng Gia Huy',        '20090509', N'Male',   '0901000005', NULL,                     N'Pupil',  N'Hoàng Văn Hải', '0911000005', 'BR01', 173),
('ST00006', N'Vũ Thảo Nguyên',       '20010930', N'Female', '0901000006', 'nguyen.vt@gmail.com',    N'Office worker', NULL, NULL, 'BR01', 173),
('ST00007', N'Đặng Quốc Khánh',      '19980214', N'Male',   '0901000007', 'khanh.dq@gmail.com',     N'Software engineer', NULL, NULL, 'BR01', 172),
('ST00008', N'Bùi Ngọc Ánh',         '20041201', N'Female', '0901000008', NULL,                     N'University student', NULL, NULL, 'BR01', 172),
('ST00009', N'Đỗ Thành Đạt',         '20030621', N'Male',   '0901000009', 'dat.dt@gmail.com',       N'University student', NULL, NULL, 'BR01', 171),
('ST00010', N'Ngô Khánh Linh',       '20100815', N'Female', NULL,         NULL,                     N'Pupil',  N'Ngô Văn Tâm', '0911000010', 'BR01', 171),
('ST00011', N'Dương Tuấn Kiệt',      '20000404', N'Male',   '0901000011', 'kiet.dt@gmail.com',      N'Sales executive', NULL, NULL, 'BR01', 170),
('ST00012', N'Lý Mỹ Duyên',          '20021010', N'Female', '0901000012', 'duyen.lm@gmail.com',     N'University student', NULL, NULL, 'BR01', 170),
('ST00013', N'Phan Văn Lợi',         '19900303', N'Male',   '0901000013', 'loi.pv@gmail.com',       N'Civil engineer', NULL, NULL, 'BR02', 130),
('ST00014', N'Trịnh Thu Trang',      '19950505', N'Female', '0901000014', 'trang.tt@gmail.com',     N'Accountant', NULL, NULL, 'BR02', 130),
('ST00015', N'Mai Đức Thắng',        '19881212', N'Male',   '0901000015', NULL,                     N'Self-employed', NULL, NULL, 'BR02', 129),
('ST00016', N'Hồ Thị Thanh Tâm',     '19930707', N'Female', '0901000016', 'tam.htt@gmail.com',      N'Primary school teacher', NULL, NULL, 'BR02', 129),
('ST00017', N'Tạ Minh Nhật',         '19990909', N'Male',   '0901000017', 'nhat.tm@gmail.com',      N'IT staff', NULL, NULL, 'BR02', 128),
('ST00018', N'Châu Ngọc Hân',        '19970121', N'Female', '0901000018', 'han.cn@gmail.com',       N'Pharmacist', NULL, NULL, 'BR02', 128),
('ST00019', N'Lâm Chí Thanh',        '19851111', N'Male',   '0901000019', NULL,                     N'Driver', NULL, NULL, 'BR02', 127),
('ST00020', N'Quách Bảo Trân',       '20000229', N'Female', '0901000020', 'tran.qb@gmail.com',      N'Bank clerk', NULL, NULL, 'BR02', 127),
('ST00021', N'Võ Hoài Nam',          '19920616', N'Male',   '0901000021', 'nam.vh@gmail.com',       N'Technician', NULL, NULL, 'BR02', 126),
('ST00022', N'Kiều Diễm My',         '19960808', N'Female', '0901000022', 'my.kd@gmail.com',        N'Graphic designer', NULL, NULL, 'BR02', 126),
('ST00023', N'Nguyễn Thanh Tùng',    '20010327', N'Male',   '0901000023', 'tung.nt@gmail.com',      N'University student', NULL, NULL, 'BR01', 72),
('ST00024', N'Lê Phương Thảo',       '20020519', N'Female', '0901000024', 'thao.lp@gmail.com',      N'University student', NULL, NULL, 'BR01', 71),
('ST00025', N'Trần Đức Anh',         '19991030', N'Male',   '0901000025', 'anh.td@gmail.com',       N'Marketing executive', NULL, NULL, 'BR01', 71),
('ST00026', N'Phạm Thùy Dương',      '20030414', N'Female', '0901000026', NULL,                     N'University student', NULL, NULL, 'BR01', 70),
('ST00027', N'Hoàng Văn Thái',       '19970717', N'Male',   '0901000027', 'thai.hv@gmail.com',      N'Office worker', NULL, NULL, 'BR01', 55),
('ST00028', N'Nguyễn Thị Hồng Nhung','20020202', N'Female', '0901000028', 'nhung.nth@gmail.com',    N'University student', NULL, NULL, 'BR01', 55),
('ST00029', N'Trương Minh Trí',      '20011225', N'Male',   '0901000029', 'tri.tm@gmail.com',       N'University student', NULL, NULL, 'BR01', 54),
('ST00030', N'Lương Thị Kim Oanh',   '19980308', N'Female', '0901000030', NULL,                     N'Administrative staff', NULL, NULL, 'BR01', 54),
('ST00031', N'Đinh Công Danh',       '20000902', N'Male',   '0901000031', 'danh.dc@gmail.com',      N'Technician', NULL, NULL, 'BR01', 53),
('ST00032', N'Huỳnh Thị Mỹ Lệ',      '20031120', N'Female', '0901000032', 'le.htm@gmail.com',       N'University student', NULL, NULL, 'BR01', 53),
('ST00033', N'Tôn Thất Bảo Long',    '19960601', N'Male',   '0901000033', 'long.ttb@gmail.com',     N'HR specialist', NULL, NULL, 'BR01', 52),
('ST00034', N'Cao Ngọc Quỳnh',       '20040101', N'Female', '0901000034', NULL,                     N'University student', NULL, NULL, 'BR01', 52),
('ST00035', N'La Văn Hùng',          '19940430', N'Male',   '0901000035', 'hung.lv@gmail.com',      N'Warehouse manager', NULL, NULL, 'BR01', 51),
('ST00036', N'Từ Thị Diệu Hiền',     '20020819', N'Female', '0901000036', 'hien.ttd@gmail.com',     N'University student', NULL, NULL, 'BR01', 51),
('ST00037', N'Thái Minh Hiếu',       '20010515', N'Male',   '0901000037', 'hieu.tm@gmail.com',      N'University student', NULL, NULL, 'BR01', 50),
('ST00038', N'Âu Dương Phong',       '19991231', N'Male',   '0901000038', NULL,                     N'Sales assistant', NULL, NULL, 'BR01', 50),
('ST00039', N'Nguyễn Gia Bảo',       '20170210', N'Male',   NULL, NULL, N'Pupil', N'Nguyễn Văn Hòa',  '0912000039', 'BR01', 95),
('ST00040', N'Trần Khánh Vy',        '20160606', N'Female', NULL, NULL, N'Pupil', N'Trần Thị Mai',    '0912000040', 'BR01', 95),
('ST00041', N'Lê Minh Khang',        '20180120', N'Male',   NULL, NULL, N'Pupil', N'Lê Văn Đức',      '0912000041', 'BR01', 94),
('ST00042', N'Phạm Bảo Ngọc',        '20170909', N'Female', NULL, NULL, N'Pupil', N'Phạm Quang Vinh', '0912000042', 'BR01', 94),
('ST00043', N'Hoàng Anh Thư',        '20161111', N'Female', NULL, NULL, N'Pupil', N'Hoàng Thị Lan',   '0912000043', 'BR01', 93),
('ST00044', N'Vũ Đức Minh',          '20170303', N'Male',   NULL, NULL, N'Pupil', N'Vũ Văn Sơn',      '0912000044', 'BR01', 93),
('ST00045', N'Đặng Tuệ Nhi',         '20180505', N'Female', NULL, NULL, N'Pupil', N'Đặng Thị Hạnh',   '0912000045', 'BR01', 92),
('ST00046', N'Bùi Quang Huy',        '20160808', N'Male',   NULL, NULL, N'Pupil', N'Bùi Văn Lực',     '0912000046', 'BR01', 92),
('ST00047', N'Đỗ Ngọc Hân',          '20171212', N'Female', NULL, NULL, N'Pupil', N'Đỗ Thị Thu',      '0912000047', 'BR01', 91),
('ST00048', N'Ngô Thiên Ân',         '20180707', N'Male',   NULL, NULL, N'Pupil', N'Ngô Văn Phát',    '0912000048', 'BR01', 91),
('ST00049', N'Dương Minh Anh',       '20160404', N'Female', NULL, NULL, N'Pupil', N'Dương Thị Yến',   '0912000049', 'BR01', 90),
('ST00050', N'Lý Hoàng Nam',         '20171010', N'Male',   NULL, NULL, N'Pupil', N'Lý Văn Tài',      '0912000050', 'BR01', 90),
('ST00051', N'Phan Thị Ngọc Trâm',   '19940222', N'Female', '0901000051', 'tram.ptn@gmail.com',     N'Import-export officer', NULL, NULL, 'BR02', 33),
('ST00052', N'Trịnh Quốc Bảo',       '19910919', N'Male',   '0901000052', 'bao.tq@gmail.com',       N'Electrical engineer', NULL, NULL, 'BR02', 33),
('ST00053', N'Mai Thanh Hương',      '20050315', N'Female', '0901000053', 'huong.mt@gmail.com',     N'University student', NULL, NULL, 'BR02', 26),
('ST00054', N'Hồ Minh Quân',         '20040626', N'Male',   '0901000054', 'quan.hm@gmail.com',      N'University student', NULL, NULL, 'BR02', 26),
('ST00055', N'Tạ Thị Ngọc Mai',      '20030812', N'Female', '0901000055', NULL,                     N'University student', NULL, NULL, 'BR02', 25),
('ST00056', N'Châu Gia Kiệt',        '20091001', N'Male',   '0901000056', NULL,                     N'Pupil', N'Châu Văn Lộc', '0911000056', 'BR02', 25),
('ST00057', N'Lâm Bảo Anh',          '20021205', N'Female', '0901000057', 'anh.lb@gmail.com',       N'University student', NULL, NULL, 'BR02', 24),
('ST00058', N'Quách Thành Danh',     '20010117', N'Male',   '0901000058', 'danh.qt@gmail.com',      N'IT staff', NULL, NULL, 'BR02', 24),
('ST00059', N'Võ Ngọc Bích',         '20040424', N'Female', '0901000059', 'bich.vn@gmail.com',      N'University student', NULL, NULL, 'BR02', 23),
('ST00060', N'Kiều Minh Tuấn',       '20000729', N'Male',   '0901000060', 'tuan.km@gmail.com',      N'Sales executive', NULL, NULL, 'BR02', 23),
('ST00061', N'Nguyễn Hải Đăng',      '19980520', N'Male',   '0901000061', 'dang.nh@gmail.com',      N'Study-abroad consultant', NULL, NULL, 'BR01', 6),
('ST00062', N'Trần Mai Anh',         '20001130', N'Female', '0901000062', 'anh.tm@gmail.com',       N'Bank clerk', NULL, NULL, 'BR01', 4),
('ST00063', N'Lê Quang Vinh',        '19950312', N'Male',   '0901000063', 'vinh.lq@gmail.com',      N'Mechanical engineer', NULL, NULL, 'BR02', 8),
('ST00064', N'Phạm Thị Thu Hà',      '19970618', N'Female', '0901000064', 'ha.ptt@gmail.com',       N'Accounting clerk', NULL, NULL, 'BR02', 7),
('ST00065', N'Hoàng Minh Đức',       '19930927', N'Male',   '0901000065', NULL,                     N'Technical staff', NULL, NULL, 'BR02', 5),
('ST00066', N'Vũ Thị Hồng Gấm',      '19870214', N'Female', '0901000066', 'gam.vth@gmail.com',      N'Shop owner', NULL, NULL, 'BR01', 6),
('ST00067', N'Đặng Văn Toàn',        '19790808', N'Male',   '0901000067', NULL,                     N'Ride-hailing driver', NULL, NULL, 'BR01', 5),
('ST00068', N'Bùi Thị Hoa',          '19991020', N'Female', '0901000068', 'hoa.bt@gmail.com',       N'Receptionist', NULL, NULL, 'BR01', 3),
('ST00069', N'Đỗ Hữu Nghĩa',         '20061212', N'Male',   '0901000069', 'nghia.dh@gmail.com',     N'University student', NULL, NULL, 'BR01', 2),
('ST00070', N'Ngô Bảo Châu',         '20070505', N'Female', '0901000070', NULL,                     N'University student', NULL, NULL, 'BR02', 2),
('ST00071', N'Dương Văn Khoa',       '20010101', N'Male',   '0901000071', 'khoa.dv@gmail.com',      N'Office worker', NULL, NULL, 'BR02', 1),
('ST00072', N'Lý Thị Kim Ngân',      '20110303', N'Female', NULL,         NULL,                     N'Pupil', N'Lý Văn Quý', '0911000072', 'BR01', 0);

INSERT INTO dbo.STUDENT (StudentId, FullName, DateOfBirth, Gender, Phone, Email, Occupation, GuardianName, GuardianPhone,
                         BranchId, RegisteredOn, Address)
SELECT StudentId, FullName, DateOfBirth, Gender, Phone, Email, Occupation, GuardianName, GuardianPhone, BranchId,
       DATEADD(DAY, -DaysAgo, @Today),
       CASE BranchId WHEN 'BR01' THEN N'TP.HCM' ELSE N'TP. Thủ Đức, TP.HCM' END
FROM @Students;
ALTER SEQUENCE dbo.seq_STUDENT RESTART WITH 73;

/* Placement tests (a trigger recommends the course) */
-- Taken 3 days before registration; OverallScore is a computed column and trg_PLACEMENT_TEST_Recommend
-- fills RecommendedCourseId. The scores decide who may enter a course with a minimum placement score.
INSERT INTO dbo.PLACEMENT_TEST (StudentId, TestDate, ListeningScore, SpeakingScore, ReadingScore, WritingScore, GradedByTeacherId)
SELECT s.StudentId, DATEADD(DAY, -s.DaysAgo - 3, @Today), p.Listening, p.Speaking, p.Reading, p.Writing, p.TeacherId
FROM @Students s
JOIN (VALUES
    ('ST00001', 4.5, 4.0, 4.5, 4.0, 'TE0002'), ('ST00002', 5.0, 4.5, 4.5, 4.0, 'TE0002'),
    ('ST00003', 4.0, 4.0, 4.5, 4.0, 'TE0002'), ('ST00004', 5.0, 5.0, 5.5, 4.5, 'TE0002'),
    ('ST00005', 4.5, 4.0, 4.0, 4.0, 'TE0002'), ('ST00006', 5.5, 5.0, 5.0, 4.5, 'TE0002'),
    ('ST00007', 5.0, 4.5, 5.0, 4.5, 'TE0002'), ('ST00008', 4.0, 4.5, 4.0, 4.0, 'TE0002'),
    ('ST00009', 4.5, 4.5, 5.0, 4.0, 'TE0002'), ('ST00010', 4.5, 4.0, 4.5, 4.0, 'TE0002'),
    ('ST00011', 4.0, 4.0, 4.0, 4.0, 'TE0002'), ('ST00012', 5.0, 4.5, 5.0, 4.5, 'TE0002'),
    ('ST00023', 6.0, 5.5, 6.0, 5.5, 'TE0001'), ('ST00024', 6.5, 5.5, 6.0, 5.5, 'TE0001'),
    ('ST00025', 5.5, 6.0, 5.5, 5.5, 'TE0001'), ('ST00026', 6.0, 5.5, 5.5, 5.5, 'TE0001'),
    ('ST00027', 4.0, 3.5, 4.5, 3.5, 'TE0005'), ('ST00028', 3.5, 3.0, 4.0, 3.0, 'TE0005'),
    ('ST00029', 4.5, 4.0, 4.5, 4.0, 'TE0005'), ('ST00030', 3.5, 3.5, 3.5, 3.0, 'TE0005'),
    ('ST00031', 4.0, 3.0, 4.0, 3.5, 'TE0005'), ('ST00032', 3.5, 3.0, 3.5, 3.0, 'TE0005'),
    ('ST00033', 5.0, 4.0, 4.5, 4.0, 'TE0005'), ('ST00034', 3.0, 3.0, 3.5, 3.0, 'TE0005'),
    ('ST00035', 4.0, 3.5, 4.0, 3.5, 'TE0005'), ('ST00036', 3.5, 3.5, 4.0, 3.0, 'TE0005'),
    ('ST00037', 4.5, 3.5, 4.5, 3.5, 'TE0005'), ('ST00038', 3.5, 3.0, 3.5, 3.5, 'TE0005'),
    ('ST00051', 5.0, 4.5, 5.0, 4.5, 'TE0004'), ('ST00052', 5.0, 5.0, 4.5, 4.5, 'TE0004'),
    ('ST00053', 4.5, 4.0, 4.5, 4.0, 'TE0008'), ('ST00054', 4.5, 4.5, 4.5, 4.0, 'TE0008'),
    ('ST00055', 4.0, 4.0, 4.5, 4.0, 'TE0008'), ('ST00056', 4.5, 4.0, 4.0, 4.0, 'TE0008'),
    ('ST00057', 5.0, 4.5, 5.0, 4.0, 'TE0008'), ('ST00058', 4.5, 4.5, 5.0, 4.5, 'TE0008'),
    ('ST00059', 4.0, 4.5, 4.0, 4.0, 'TE0008'), ('ST00060', 5.0, 4.0, 4.5, 4.0, 'TE0008'),
    ('ST00061', 7.0, 6.5, 7.0, 6.5, 'TE0001'), ('ST00062', 7.0, 6.5, 6.5, 6.5, 'TE0001'),
    ('ST00063', 5.5, 5.0, 5.5, 5.0, 'TE0005'), ('ST00064', 5.0, 5.0, 5.5, 5.0, 'TE0005'),
    ('ST00065', 5.5, 5.0, 5.0, 5.0, 'TE0005'), ('ST00070', 3.0, 2.5, 3.0, 2.0, 'TE0008')
) AS p (StudentId, Listening, Speaking, Reading, Writing, TeacherId) ON p.StudentId = s.StudentId;

/* ---------------------------------------------------------------------
   4. Open the classes + weekly schedules + generate the sessions (through procedures)
      Weekdays: ISO numbers (1 = Monday ... 7 = Sunday)
   --------------------------------------------------------------------- */
-- ClassNo = number of the class inside this script; FinalStatus = the status it should reach (section 6
-- reads it). Every class is created as Enrolling (DF_CLASS_Status).
DECLARE @Classes TABLE (ClassNo INT, ClassName NVARCHAR(100), CourseId VARCHAR(10), BranchId VARCHAR(10), TeacherId VARCHAR(10),
                        RoomId VARCHAR(10), StartDate DATE, MaxStudents INT, Weekdays VARCHAR(20), StartTime TIME(0),
                        EndTime TIME(0), FinalStatus NVARCHAR(20));
INSERT INTO @Classes VALUES
( 1, N'IELTS Foundation #1',            'IE-FND', 'BR01', 'TE0002', 'D1-101', DATEADD(WEEK, -21, @Monday),                   20, '1,3,5', '18:00', '20:00', N'Finished'),
( 2, N'Communication Elementary #1',    'CM-A1',  'BR02', 'TE0007', 'TD-301', DATEADD(DAY, 1, DATEADD(WEEK, -17, @Monday)),  20, '2,4',   '18:30', '20:00', N'Finished'),
( 3, N'IELTS 5.5 Intensive #1',         'IE-55',  'BR01', 'TE0001', 'D1-201', DATEADD(WEEK, -8, @Monday),                    20, '1,3,5', '18:00', '20:00', N'In progress'),
( 4, N'TOEIC 450+ #1',                  'TO-450', 'BR01', 'TE0005', 'D1-102', DATEADD(DAY, 1, DATEADD(WEEK, -6, @Monday)),   20, '2,4',   '19:00', '20:30', N'In progress'),
( 5, N'Kids Starters #1',               'KD-STA', 'BR01', 'TE0006', 'D1-LAB', DATEADD(DAY, 5, DATEADD(WEEK, -12, @Monday)),  16, '6,7',   '08:00', '09:30', N'In progress'),
( 6, N'Communication Intermediate #1',  'CM-B1',  'BR02', 'TE0004', 'TD-302', DATEADD(WEEK, -3, @Monday),                    20, '1,3',   '18:30', '20:00', N'In progress'),
( 7, N'IELTS Foundation #2',            'IE-FND', 'BR02', 'TE0008', 'TD-303', DATEADD(WEEK, -2, @Monday),                    18, '1,3,5', '18:00', '20:00', N'In progress'),
( 8, N'IELTS 6.5 Advanced #1',          'IE-65',  'BR01', 'TE0001', 'D1-201', DATEADD(DAY, 1, DATEADD(WEEK, 2, @Monday)),    20, '2,4,6', '18:00', '20:00', N'Enrolling'),
( 9, N'TOEIC 750+ #1',                  'TO-750', 'BR02', 'TE0005', 'TD-301', DATEADD(WEEK, 1, @Monday),                     20, '1,3',   '19:00', '20:30', N'Enrolling'),
(10, N'Communication Elementary #2',    'CM-A1',  'BR01', 'TE0003', 'D1-102', DATEADD(DAY, 5, DATEADD(WEEK, 1, @Monday)),    20, '6,7',   '09:00', '10:30', N'Enrolling');

DECLARE @i INT = 1, @ClassId VARCHAR(10), @ClassName NVARCHAR(100), @CourseId VARCHAR(10), @BranchId VARCHAR(10),
        @TeacherId VARCHAR(10), @RoomId VARCHAR(10), @StartDate DATE, @MaxStudents INT, @Weekdays VARCHAR(20),
        @StartTime TIME(0), @EndTime TIME(0), @Weekday TINYINT, @Pos INT;
DECLARE @ClassIdByNo TABLE (ClassNo INT PRIMARY KEY, ClassId VARCHAR(10));

-- For every class, in ClassNo order:
--   1. usp_Class_Create returns the generated ClassId (OUTPUT); @ClassIdByNo remembers it for later sections
--   2. the weekday list (a comma is appended, e.g. '1,3,5,') is cut at each comma with CHARINDEX/SUBSTRING
--      (STRING_SPLIT needs SQL Server 2016) and usp_ClassSchedule_Add adds each slot, which fires the
--      room/teacher clash trigger trg_CLASS_SCHEDULE_CheckConflict
--   3. usp_Class_GenerateSessions creates the sessions and sets the EndDate of the class
WHILE @i <= 10
BEGIN
    SELECT @ClassName = ClassName, @CourseId = CourseId, @BranchId = BranchId, @TeacherId = TeacherId, @RoomId = RoomId,
           @StartDate = StartDate, @MaxStudents = MaxStudents, @Weekdays = Weekdays + ',', @StartTime = StartTime,
           @EndTime = EndTime
    FROM @Classes WHERE ClassNo = @i;

    EXEC dbo.usp_Class_Create @ClassName, @CourseId, @BranchId, @TeacherId, @RoomId, @StartDate, @MaxStudents, NULL,
                              @ClassId OUTPUT;
    INSERT INTO @ClassIdByNo VALUES (@i, @ClassId);

    WHILE LEN(@Weekdays) > 0
    BEGIN
        SET @Pos = CHARINDEX(',', @Weekdays);
        SET @Weekday = CAST(LEFT(@Weekdays, @Pos - 1) AS TINYINT);
        SET @Weekdays = SUBSTRING(@Weekdays, @Pos + 1, 20);
        EXEC dbo.usp_ClassSchedule_Add @ClassId, @Weekday, @StartTime, @EndTime;
    END;

    -- Capture the procedure's result set (INSERT ... EXEC) so the script output stays short
    DECLARE @Generated TABLE (SessionsCreated INT, EndDate DATE);
    INSERT INTO @Generated EXEC dbo.usp_Class_GenerateSessions @ClassId;
    SET @i += 1;
END;

/* ---------------------------------------------------------------------
   5. Enrollments (through usp_Enrollment_Create: entry requirement, schedule clash, promotion)
      Order: classes 1 and 2 are taught and evaluated FIRST, only then are
      class 3 (IELTS 5.5) and class 6 (Communication B1) filled, because they
      need the prerequisite course.
   --------------------------------------------------------------------- */
-- @Enroll: who joins which class (by ClassNo), with which promotion, in which round;
-- RIGHT(StudentId, 1) picks a few students by the last digit of their ID to use a promotion.
DECLARE @Enroll TABLE (StudentId VARCHAR(10), ClassNo INT, PromotionId VARCHAR(10), Round INT);
INSERT INTO @Enroll (StudentId, ClassNo, PromotionId, Round)
SELECT StudentId, 1, CASE WHEN RIGHT(StudentId, 1) IN ('2', '7') THEN 'PR-SUMMER' END, 1 FROM @Students WHERE StudentId BETWEEN 'ST00001' AND 'ST00012'
UNION ALL SELECT StudentId, 2, CASE WHEN RIGHT(StudentId, 1) = '5' THEN 'PR-SUMMER' END, 1 FROM @Students WHERE StudentId BETWEEN 'ST00013' AND 'ST00022'
UNION ALL SELECT StudentId, 4, CASE WHEN RIGHT(StudentId, 1) = '0' THEN 'PR-REFER' END, 1 FROM @Students WHERE StudentId BETWEEN 'ST00027' AND 'ST00038'
UNION ALL SELECT StudentId, 5, CASE WHEN RIGHT(StudentId, 1) = '3' THEN 'PR-REFER' END, 1 FROM @Students WHERE StudentId BETWEEN 'ST00039' AND 'ST00050'
UNION ALL SELECT StudentId, 7, 'PR-OPEN', 1 FROM @Students WHERE StudentId BETWEEN 'ST00053' AND 'ST00060'
UNION ALL SELECT StudentId, 8, NULL, 1 FROM @Students WHERE StudentId IN ('ST00061', 'ST00062')
UNION ALL SELECT StudentId, 9, 'PR-OPEN', 1 FROM @Students WHERE StudentId BETWEEN 'ST00063' AND 'ST00065'
UNION ALL SELECT StudentId, 10, NULL, 1 FROM @Students WHERE StudentId BETWEEN 'ST00066' AND 'ST00069'
-- Round 2: needs the results of the earlier classes
UNION ALL SELECT StudentId, 3, NULL, 2 FROM @Students WHERE StudentId IN ('ST00001','ST00002','ST00003','ST00004','ST00006','ST00007','ST00008','ST00009',
                                                                         'ST00023','ST00024','ST00025','ST00026')
UNION ALL SELECT StudentId, 6, 'PR-REFER', 2 FROM @Students WHERE StudentId IN ('ST00013','ST00014','ST00015','ST00016','ST00017','ST00018','ST00020',
                                                                               'ST00051','ST00052');

DECLARE @Round INT = 1, @StudentId VARCHAR(10), @PromotionId VARCHAR(10), @ClassNo INT, @EnrolledOn DATE,
        @EmployeeId VARCHAR(10), @EnrollmentId VARCHAR(10);

-- CURSOR: usp_Enrollment_Create enrolls ONE student per call (entry requirement, schedule clash, promotion),
-- so the rows of @Enroll are read one at a time. LOCAL = visible only in this batch; FAST_FORWARD = read-only
-- and forward-only (the cheapest kind); @@FETCH_STATUS = 0 while FETCH returned a row. The cursor is closed
-- and deallocated after each round, so the next round can declare it again.
-- EnrolledOn: up to 5 days before today for a class that has not started, otherwise 6 to 10 days before the
-- start date; the academic staff member of the class branch (EM0002 / EM0004) records the enrollment.
WHILE @Round <= 2
BEGIN
    DECLARE cur_Enroll CURSOR LOCAL FAST_FORWARD FOR
        SELECT e.StudentId, e.ClassNo, e.PromotionId FROM @Enroll e WHERE e.Round = @Round ORDER BY e.ClassNo, e.StudentId;
    OPEN cur_Enroll;
    FETCH NEXT FROM cur_Enroll INTO @StudentId, @ClassNo, @PromotionId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @ClassId = m.ClassId, @BranchId = c.BranchId,
               @EnrolledOn = CASE WHEN c.StartDate > @Today THEN DATEADD(DAY, -(ABS(CHECKSUM(@StudentId)) % 6), @Today)
                                  ELSE DATEADD(DAY, -10 + ABS(CHECKSUM(@StudentId)) % 5, c.StartDate) END
        FROM @Classes c JOIN @ClassIdByNo m ON m.ClassNo = c.ClassNo WHERE c.ClassNo = @ClassNo;
        SET @EmployeeId = CASE @BranchId WHEN 'BR01' THEN 'EM0002' ELSE 'EM0004' END;

        EXEC dbo.usp_Enrollment_Create @StudentId, @ClassId, @PromotionId, @EnrolledOn, @EmployeeId, @EnrollmentId OUTPUT;
        FETCH NEXT FROM cur_Enroll INTO @StudentId, @ClassNo, @PromotionId;
    END;
    CLOSE cur_Enroll;
    DEALLOCATE cur_Enroll;

    IF @Round = 1
    BEGIN
        /* Classes 1 and 2 are over => sessions taught, attendance, grades, results */
        -- usp_Class_EvaluateResults only accepts a class In progress or Finished, hence the status change first.
        -- Attendance and grades are inserted set-based here (usp_Attendance_Save / usp_Grade_Save save one row
        -- per call); the triggers on ATTENDANCE and GRADE still check and audit every row.
        UPDATE cl SET Status = N'In progress'
        FROM dbo.CLASS cl JOIN @ClassIdByNo m ON m.ClassId = cl.ClassId WHERE m.ClassNo IN (1, 2);

        UPDATE se SET Status = N'Taught', Description = N'Session ' + CAST(se.SessionNo AS NVARCHAR(3))
        FROM dbo.CLASS_SESSION se JOIN @ClassIdByNo m ON m.ClassId = se.ClassId WHERE m.ClassNo IN (1, 2);

        INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status)
        SELECT se.SessionId, en.EnrollmentId,
               CASE WHEN en.StudentId = 'ST00005' THEN   -- often absent => fails the attendance requirement
                        CASE WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 60 THEN N'Present'
                             ELSE N'Unexcused absence' END
                    ELSE CASE WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 88 THEN N'Present'
                              WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 95 THEN N'Late'
                              WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 98 THEN N'Excused absence'
                              ELSE N'Unexcused absence' END
               END
        FROM dbo.CLASS_SESSION se
        JOIN dbo.ENROLLMENT en  ON en.ClassId = se.ClassId
        JOIN @ClassIdByNo m     ON m.ClassId = se.ClassId
        WHERE m.ClassNo IN (1, 2);

        INSERT INTO dbo.GRADE (EnrollmentId, ComponentId, Score, EnteredAt, EnteredBy)
        SELECT en.EnrollmentId, gc.ComponentId,
               CASE WHEN en.StudentId IN ('ST00011', 'ST00019')   -- low scores => fails
                    THEN 3.0 + (ABS(CHECKSUM(en.EnrollmentId, gc.ComponentId)) % 18) / 10.0
                    ELSE 6.0 + (ABS(CHECKSUM(en.EnrollmentId, gc.ComponentId)) % 36) / 10.0 END,
               cl.EndDate, N'seed'
        FROM dbo.ENROLLMENT en
        JOIN dbo.CLASS cl            ON cl.ClassId = en.ClassId
        JOIN dbo.GRADE_COMPONENT gc  ON gc.CourseId = cl.CourseId
        JOIN @ClassIdByNo m          ON m.ClassId = cl.ClassId
        WHERE m.ClassNo IN (1, 2);

        -- usp_Class_EvaluateResults (cursor) writes FinalGrade/Result, issues the certificates and marks the
        -- class Finished, so round 2 can check the prerequisite course
        DECLARE @Results TABLE (PassedCount INT, FailedCount INT);
        SELECT @ClassId = ClassId FROM @ClassIdByNo WHERE ClassNo = 1;
        INSERT INTO @Results EXEC dbo.usp_Class_EvaluateResults @ClassId;
        SELECT @ClassId = ClassId FROM @ClassIdByNo WHERE ClassNo = 2;
        INSERT INTO @Results EXEC dbo.usp_Class_EvaluateResults @ClassId;
    END;
    SET @Round += 1;
END;

/* ---------------------------------------------------------------------
   6. Classes in progress: past sessions => Taught, attendance, midterm grades
   --------------------------------------------------------------------- */
UPDATE cl SET Status = N'In progress'
FROM dbo.CLASS cl JOIN @ClassIdByNo m ON m.ClassId = cl.ClassId JOIN @Classes c ON c.ClassNo = m.ClassNo
WHERE c.FinalStatus = N'In progress';

UPDATE se SET Status = N'Taught', Description = N'Session ' + CAST(se.SessionNo AS NVARCHAR(3))
FROM dbo.CLASS_SESSION se JOIN @ClassIdByNo m ON m.ClassId = se.ClassId JOIN @Classes c ON c.ClassNo = m.ClassNo
WHERE c.FinalStatus = N'In progress' AND se.SessionDate < @Today;

INSERT INTO dbo.ATTENDANCE (SessionId, EnrollmentId, Status)
SELECT se.SessionId, en.EnrollmentId,
       CASE WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 88 THEN N'Present'
            WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 95 THEN N'Late'
            WHEN ABS(CHECKSUM(se.SessionId, en.EnrollmentId)) % 100 < 98 THEN N'Excused absence'
            ELSE N'Unexcused absence' END
FROM dbo.CLASS_SESSION se
JOIN dbo.ENROLLMENT en ON en.ClassId = se.ClassId
JOIN @ClassIdByNo m ON m.ClassId = se.ClassId JOIN @Classes c ON c.ClassNo = m.ClassNo
WHERE c.FinalStatus = N'In progress' AND se.Status = N'Taught';

-- Classes past their halfway point: scores for the coursework components (all but "Final exam")
INSERT INTO dbo.GRADE (EnrollmentId, ComponentId, Score, EnteredBy)
SELECT en.EnrollmentId, gc.ComponentId, 5.5 + (ABS(CHECKSUM(en.EnrollmentId, gc.ComponentId)) % 40) / 10.0, N'seed'
FROM dbo.ENROLLMENT en
JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
JOIN dbo.GRADE_COMPONENT gc ON gc.CourseId = cl.CourseId AND gc.ComponentName <> N'Final exam'
JOIN @ClassIdByNo m ON m.ClassId = cl.ClassId JOIN @Classes c ON c.ClassNo = m.ClassNo
WHERE c.FinalStatus = N'In progress'
  AND (SELECT COUNT(*) FROM dbo.CLASS_SESSION se WHERE se.ClassId = cl.ClassId AND se.Status = N'Taught') * 2
      >= (SELECT COUNT(*) FROM dbo.CLASS_SESSION se WHERE se.ClassId = cl.ClassId);

/* ---------------------------------------------------------------------
   7. Receipts: most students of finished/in-progress classes paid in full, one
      third pays in 2 installments (the 2nd only once it is due); classes about
      to start take a deposit.
   --------------------------------------------------------------------- */
-- E numbers the enrollments 1, 2, 3... with ROW_NUMBER() (window function). n % 3 chooses the payment method
-- and makes every third enrollment pay half; in classes still Enrolling only every second enrollment pays a
-- deposit. PaidAt = date + 09:00 + (n % 7) hours: adding a number to a DATETIME adds days, so / 24 gives hours.
-- The leading ; ends the previous statement, which a CTE (WITH) requires.
-- Each INSERT ... SELECT below fires trg_RECEIPT_UpdateAmountPaid and trg_RECEIPT_Audit ONCE for all its rows.
;WITH E AS (
    SELECT en.EnrollmentId, en.EnrolledOn, en.TuitionDue, cl.BranchId, cl.Status AS ClassStatus,
           ROW_NUMBER() OVER (ORDER BY en.EnrollmentId) AS n
    FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
)
INSERT INTO dbo.RECEIPT (EnrollmentId, PaidAt, Amount, PaymentMethod, CollectedByEmployeeId, Description)
SELECT EnrollmentId,
       CAST(CASE WHEN ClassStatus = N'Enrolling' THEN @Today ELSE EnrolledOn END AS DATETIME)
           + CAST('09:00' AS DATETIME) + CAST(n % 7 AS FLOAT) / 24,
       CASE WHEN ClassStatus = N'Enrolling' THEN 1000000
            WHEN n % 3 = 0 THEN ROUND(TuitionDue / 2, -3)
            ELSE TuitionDue END,
       CASE n % 3 WHEN 0 THEN N'Cash' WHEN 1 THEN N'Bank transfer' ELSE N'Card' END,
       CASE BranchId WHEN 'BR01' THEN 'EM0003' ELSE 'EM0005' END,
       CASE WHEN ClassStatus = N'Enrolling' THEN N'Seat deposit'
            WHEN n % 3 = 0 THEN N'Tuition installment 1' ELSE N'Full-course tuition' END
FROM E
WHERE NOT (ClassStatus = N'Enrolling' AND n % 2 = 0);

-- Second installment of the 50% payments (due after 30 days); newly started classes still owe
-- (TuitionDue - AmountPaid uses the AmountPaid the trigger has just updated for installment 1)
INSERT INTO dbo.RECEIPT (EnrollmentId, PaidAt, Amount, PaymentMethod, CollectedByEmployeeId, Description)
SELECT en.EnrollmentId, DATEADD(DAY, 30, CAST(en.EnrolledOn AS DATETIME)) + CAST('10:30' AS DATETIME),
       en.TuitionDue - en.AmountPaid, N'Bank transfer',
       CASE cl.BranchId WHEN 'BR01' THEN 'EM0003' ELSE 'EM0005' END, N'Tuition installment 2'
FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
WHERE en.AmountPaid > 0 AND en.AmountPaid < en.TuitionDue
  AND cl.Status IN (N'In progress', N'Finished')
  AND DATEADD(DAY, 30, en.EnrolledOn) < @Today
  AND RIGHT(en.StudentId, 1) NOT IN ('1', '8');   -- a few students pay late => outstanding balance

/* ---------------------------------------------------------------------
   8. Finalize the payroll of the last 2 months (cursor in usp_Payroll_Finalize)
   --------------------------------------------------------------------- */
DECLARE @Pay TABLE (TeacherId VARCHAR(10), TeacherName NVARCHAR(100), SessionCount INT, Hours DECIMAL(6,2),
                    HourlyRate DECIMAL(12,0), Bonus DECIMAL(12,0), Deduction DECIMAL(12,0), TotalPay DECIMAL(14,0),
                    Status NVARCHAR(20));
-- @PayMonth starts two months ago and the loop stops before the first day of the current month, so the last
-- two full months are finalized; afterwards the older of the two is marked Paid.
DECLARE @PayMonth DATE = DATEADD(MONTH, -2, @Today), @Month TINYINT, @Year SMALLINT;
WHILE @PayMonth < DATEADD(DAY, 1 - DAY(@Today), @Today)
BEGIN
    SET @Month = MONTH(@PayMonth); SET @Year = YEAR(@PayMonth);
    INSERT INTO @Pay EXEC dbo.usp_Payroll_Finalize @Month, @Year;
    SET @PayMonth = DATEADD(MONTH, 1, @PayMonth);
END;
UPDATE dbo.PAYROLL SET Status = N'Paid'
WHERE DATEFROMPARTS(Year, Month, 1) < DATEADD(MONTH, -1, DATEADD(DAY, 1 - DAY(@Today), @Today));

/* ---------------------------------------------------------------------
   9. Demo sign-in accounts (contained users) - demo password: see docs/SETUP.md
   --------------------------------------------------------------------- */
-- usp_Account_Create creates each contained user (CREATE USER ... WITH PASSWORD), adds it to its role and
-- writes the ACCOUNT row; it runs last because ACCOUNT refers to the EMPLOYEE/TEACHER rows above.
-- The shared password is test data; a real deployment resets it (usp_Account_ResetPassword).
EXEC dbo.usp_Account_Create N'ql_quan',     N'Demo@2026', 'MANAGER',        'EM0001', NULL;
EXEC dbo.usp_Account_Create N'gvu_lan',     N'Demo@2026', 'ACADEMIC_STAFF', 'EM0002', NULL;
EXEC dbo.usp_Account_Create N'gvu_ha',      N'Demo@2026', 'ACADEMIC_STAFF', 'EM0004', NULL;
EXEC dbo.usp_Account_Create N'kt_minh',     N'Demo@2026', 'ACCOUNTANT',     'EM0003', NULL;
EXEC dbo.usp_Account_Create N'kt_tung',     N'Demo@2026', 'ACCOUNTANT',     'EM0005', NULL;
EXEC dbo.usp_Account_Create N'gv_john',     N'Demo@2026', 'TEACHER',        NULL, 'TE0001';
EXEC dbo.usp_Account_Create N'gv_hoanganh', N'Demo@2026', 'TEACHER',        NULL, 'TE0002';
EXEC dbo.usp_Account_Create N'gv_hoa',      N'Demo@2026', 'TEACHER',        NULL, 'TE0003';
EXEC dbo.usp_Account_Create N'gv_bao',      N'Demo@2026', 'TEACHER',        NULL, 'TE0005';
GO

/* Demo data summary */
SELECT N'STUDENT' AS TableName, COUNT(*) AS RecordCount FROM dbo.STUDENT
UNION ALL SELECT N'CLASS', COUNT(*) FROM dbo.CLASS
UNION ALL SELECT N'CLASS_SESSION', COUNT(*) FROM dbo.CLASS_SESSION
UNION ALL SELECT N'ENROLLMENT', COUNT(*) FROM dbo.ENROLLMENT
UNION ALL SELECT N'RECEIPT', COUNT(*) FROM dbo.RECEIPT
UNION ALL SELECT N'ATTENDANCE', COUNT(*) FROM dbo.ATTENDANCE
UNION ALL SELECT N'GRADE', COUNT(*) FROM dbo.GRADE
UNION ALL SELECT N'CERTIFICATE', COUNT(*) FROM dbo.CERTIFICATE
UNION ALL SELECT N'PAYROLL', COUNT(*) FROM dbo.PAYROLL
UNION ALL SELECT N'ACCOUNT', COUNT(*) FROM dbo.ACCOUNT
UNION ALL SELECT N'AUDIT_LOG', COUNT(*) FROM dbo.AUDIT_LOG;
GO
