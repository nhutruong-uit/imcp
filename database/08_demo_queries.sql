/* =====================================================================
   File   : 08_demo_queries.sql - Demo queries (for the report and the oral defense)
   Run them one at a time in SSMS / VS Code (mssql) to present the results.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ===================== PART A. SQL QUERIES ===================== */

-- Q1. (Multi-table join) Classes in progress: course, teacher, room, enrollment
SELECT cl.ClassId, cl.ClassName, co.CourseName, te.FullName AS TeacherName, rm.RoomName, br.BranchName,
       dbo.fn_EnrolledCount(cl.ClassId) AS EnrolledCount, cl.MaxStudents
FROM dbo.CLASS cl
JOIN dbo.COURSE co  ON co.CourseId = cl.CourseId
JOIN dbo.TEACHER te ON te.TeacherId = cl.TeacherId
JOIN dbo.ROOM rm    ON rm.RoomId = cl.RoomId
JOIN dbo.BRANCH br  ON br.BranchId = cl.BranchId
WHERE cl.Status = N'In progress'
ORDER BY br.BranchName, cl.StartDate;

-- Q2. (GROUP BY + HAVING) Programs with revenue above 50 million VND
SELECT pg.ProgramName, COUNT(DISTINCT en.StudentId) AS StudentCount, SUM(rc.Amount) AS Revenue
FROM dbo.RECEIPT rc
JOIN dbo.ENROLLMENT en ON en.EnrollmentId = rc.EnrollmentId
JOIN dbo.CLASS cl      ON cl.ClassId = en.ClassId
JOIN dbo.COURSE co     ON co.CourseId = cl.CourseId
JOIN dbo.PROGRAM pg    ON pg.ProgramId = co.ProgramId
WHERE rc.Status = N'Valid'
GROUP BY pg.ProgramName
HAVING SUM(rc.Amount) > 50000000
ORDER BY Revenue DESC;

-- Q3. (Subquery + NOT EXISTS) Students who took the placement test but never enrolled
SELECT st.StudentId, st.FullName, pl.OverallScore, co.CourseName AS RecommendedCourse
FROM dbo.STUDENT st
JOIN dbo.PLACEMENT_TEST pl ON pl.StudentId = st.StudentId
LEFT JOIN dbo.COURSE co    ON co.CourseId = pl.RecommendedCourseId
WHERE NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.StudentId = st.StudentId);

-- Q4. (Relational division) Students who took EVERY IELTS course that has a started class
--      (there is no such IELTS course the student has not enrolled in)
SELECT st.StudentId, st.FullName
FROM dbo.STUDENT st
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.COURSE co
    WHERE co.ProgramId = 'IELTS'
      AND EXISTS (SELECT 1 FROM dbo.CLASS cl WHERE cl.CourseId = co.CourseId AND cl.Status <> N'Enrolling')
      AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
                      WHERE en.StudentId = st.StudentId AND cl.CourseId = co.CourseId));

-- Q5. (CTE + window function) Top 3 students of every finished class
WITH Ranking AS (
    SELECT en.ClassId, st.FullName, en.FinalGrade,
           DENSE_RANK() OVER (PARTITION BY en.ClassId ORDER BY en.FinalGrade DESC) AS Rank
    FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
    WHERE en.FinalGrade IS NOT NULL
)
SELECT ClassId, Rank, FullName, FinalGrade FROM Ranking WHERE Rank <= 3 ORDER BY ClassId, Rank;

-- Q6. (Running total with a window function) Monthly revenue and year-to-date total
SELECT Month, Revenue,
       SUM(Revenue) OVER (ORDER BY Month ROWS UNBOUNDED PRECEDING) AS YearToDate
FROM dbo.fn_MonthlyRevenue(YEAR(dbo.fn_Today()), NULL)
ORDER BY Month;

-- Q7. (PIVOT) Number of enrollments per program x branch
SELECT ProgramName, ISNULL([BR01], 0) AS [District 1], ISNULL([BR02], 0) AS [Thu Duc]
FROM (
    SELECT pg.ProgramName, cl.BranchId, en.StudentId
    FROM dbo.ENROLLMENT en
    JOIN dbo.CLASS cl   ON cl.ClassId = en.ClassId
    JOIN dbo.COURSE co  ON co.CourseId = cl.CourseId
    JOIN dbo.PROGRAM pg ON pg.ProgramId = co.ProgramId
) src
PIVOT (COUNT(StudentId) FOR BranchId IN ([BR01], [BR02])) pv;

-- Q8. (Recursive query) Prerequisite path from IELTS 6.5 back to the first course
WITH Path AS (
    SELECT CourseId, CourseName, PrerequisiteCourseId, 0 AS Depth FROM dbo.COURSE WHERE CourseId = 'IE-65'
    UNION ALL
    SELECT co.CourseId, co.CourseName, co.PrerequisiteCourseId, p.Depth + 1
    FROM dbo.COURSE co JOIN Path p ON co.CourseId = p.PrerequisiteCourseId
)
SELECT Depth, CourseId, CourseName FROM Path ORDER BY Depth DESC;

-- Q9. Teachers who taught the most sessions last month (inline TVF)
SELECT TOP (3) te.TeacherId, te.FullName, COUNT(*) AS SessionCount
FROM dbo.TEACHER te
CROSS APPLY dbo.fn_TeacherSchedule(te.TeacherId,
                                   DATEADD(MONTH, -1, DATEADD(DAY, 1 - DAY(dbo.fn_Today()), dbo.fn_Today())),
                                   DATEADD(DAY, -DAY(dbo.fn_Today()), dbo.fn_Today())) ts
WHERE ts.Status = N'Taught'
GROUP BY te.TeacherId, te.FullName
ORDER BY SessionCount DESC;

-- Q10. Students below 85% attendance in a class in progress (warning)
SELECT * FROM dbo.vw_LearningResults
WHERE Status = N'Studying' AND AttendanceRate < 85
ORDER BY AttendanceRate;

/* ===================== PART B. XPATH / XQUERY ===================== */

-- X1. .value(): first textbook and objective of every course
SELECT CourseId, CourseName,
       SyllabusXml.value('(/Syllabus/Textbook)[1]', 'NVARCHAR(200)')    AS Textbook,
       SyllabusXml.value('(/Syllabus/Textbook/@Year)[1]', 'INT')        AS PublishedIn,
       SyllabusXml.value('(/Syllabus/Objective)[1]', 'NVARCHAR(300)')   AS Objective
FROM dbo.COURSE
WHERE SyllabusXml IS NOT NULL;

-- X2. .query(): the Units that practice Speaking, as XML
SELECT CourseId, SyllabusXml.query('/Syllabus/Unit[Skill = "Speaking"]') AS SpeakingUnits
FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL;

-- X3. .exist(): teachers with an IELTS score of 8.0 or more
SELECT TeacherId, FullName,
       ProfileXml.value('(/Profile/Certificate[@Type = "IELTS"]/@Score)[1]', 'DECIMAL(3,1)') AS IELTS
FROM dbo.TEACHER
WHERE ProfileXml.exist('/Profile/Certificate[@Type = "IELTS" and @Score >= 8.0]') = 1;

-- X4. .nodes() + CROSS APPLY: shred every teacher certificate into a relational result
SELECT te.TeacherId, te.FullName,
       c.value('@Type', 'NVARCHAR(30)')  AS Certificate,
       c.value('@Score', 'DECIMAL(5,1)') AS Score,
       c.value('@Year', 'INT')           AS Year
FROM dbo.TEACHER te
CROSS APPLY te.ProfileXml.nodes('/Profile/Certificate') AS T(c)
ORDER BY te.TeacherId, Year;

-- X5. FLWOR: Units with 6 sessions or more, sorted by session count, rebuilt as new XML
SELECT CourseId,
       SyllabusXml.query('
           for $u in /Syllabus/Unit
           where $u/@Sessions >= 6
           order by $u/@Sessions descending
           return <Unit no="{data($u/@No)}" sessions="{data($u/@Sessions)}">{data($u/Title)}</Unit>') AS LongUnits
FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL;

-- X6. XML/relational consistency check: total sessions of the Units = COURSE.SessionCount
SELECT CourseId, SessionCount,
       SyllabusXml.value('sum(/Syllabus/Unit/@Sessions)', 'INT') AS SyllabusSessions,
       CASE WHEN SessionCount = SyllabusXml.value('sum(/Syllabus/Unit/@Sessions)', 'INT')
            THEN N'Match' ELSE N'Mismatch' END AS CheckResult
FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL;

-- X7. .modify(): add a certificate to a teacher profile (XML DML) - inside a transaction, then rolled back
BEGIN TRANSACTION;
UPDATE dbo.TEACHER
SET ProfileXml.modify('insert <Certificate Type="CELTA" Year="2026"/> as last into (/Profile)[1]')
WHERE TeacherId = 'TE0003';
SELECT ProfileXml FROM dbo.TEACHER WHERE TeacherId = 'TE0003';
ROLLBACK TRANSACTION;

-- X8. FOR XML PATH: classes with their students (nested structure)
SELECT cl.ClassId AS '@ClassId', cl.ClassName AS 'ClassName',
       (SELECT st.StudentId AS '@StudentId', st.FullName AS 'text()'
        FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
        WHERE en.ClassId = cl.ClassId
        FOR XML PATH('Student'), TYPE) AS 'Students'
FROM dbo.CLASS cl
WHERE cl.Status = N'In progress'
FOR XML PATH('Class'), ROOT('Center');

-- X9. Audit trail: old/new data (XML) of the grade changes
SELECT TOP (10) dbo.fn_UtcToCenterTime(LoggedAtUtc) AS LoggedAtCenter, PerformedBy, Action, RecordKey,
       OldData.value('(/Grade/Score)[1]', 'DECIMAL(4,2)') AS OldScore,
       NewData.value('(/Grade/Score)[1]', 'DECIMAL(4,2)') AS NewScore
FROM dbo.AUDIT_LOG
WHERE TableName = N'GRADE'
ORDER BY LogId DESC;

/* ===================== PART C. CALLING PROCEDURES / FUNCTIONS ===================== */
EXEC dbo.usp_Dashboard_Stats;
EXEC dbo.usp_Student_Search @Keyword = N'Nguyễn';
EXEC dbo.usp_Course_FindBySkill @Skill = N'Speaking';
EXEC dbo.usp_Course_Syllabus @CourseId = 'IE-55';
EXEC dbo.usp_Teacher_FindByCertificate @CertificateType = N'IELTS', @MinScore = 8.0;
SELECT * FROM dbo.fn_StudentBalance('ST00031');
SELECT dbo.fn_Classification(8.25) AS Classification, dbo.fn_Weekday(dbo.fn_Today()) AS TodayWeekday;
GO
