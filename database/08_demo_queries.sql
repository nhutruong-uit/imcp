/* =====================================================================
   File   : 08_demo_queries.sql - Demo queries (for the report and the oral defense)
   Run them one at a time in SSMS / VS Code (mssql) to present the results.

   Not part of db_init: run by hand as sa after db_init. The queries only read data, except the XML
   DML demo, which changes one row inside a transaction and rolls it back.
   Each header names the course concept the query shows:
     - Part A: joins, GROUP BY/HAVING, subqueries, relational division, CTE, window functions, PIVOT,
       recursive CTE, CROSS APPLY with a table-valued function, a view.
     - Part B: the XML methods .value(), .query(), .exist(), .nodes(), .modify(), FLWOR, FOR XML PATH
       and the XML audit trail.
     - Part C: calls of the procedures and functions of 04_procedures.sql / 02_functions.sql.
   The report quotes several queries word for word (docs/report/content/chapter4.py): keep the query
   text and the header lines unchanged; explanations go between a header line and its query.
   ===================================================================== */
USE QLTTTA;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ===================== PART A. SQL QUERIES ===================== */

-- Q1. (Multi-table join) Classes in progress: course, teacher, room, enrollment
--     INNER JOIN of five tables along their foreign keys; the foreign keys of CLASS are NOT NULL, so no class
--     is lost. fn_EnrolledCount is a scalar function evaluated for each row.
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
--     WHERE filters rows BEFORE grouping (valid receipts only), HAVING filters groups AFTER aggregation.
--     COUNT(DISTINCT ...) counts a student once even when they paid several receipts.
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
--     A correlated subquery (it uses st.StudentId of the outer row) inside NOT EXISTS = an anti-join.
--     LEFT JOIN COURSE keeps a test whose recommended course is NULL (no open course matched the score).
SELECT st.StudentId, st.FullName, pl.OverallScore, co.CourseName AS RecommendedCourse
FROM dbo.STUDENT st
JOIN dbo.PLACEMENT_TEST pl ON pl.StudentId = st.StudentId
LEFT JOIN dbo.COURSE co    ON co.CourseId = pl.RecommendedCourseId
WHERE NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en WHERE en.StudentId = st.StudentId);

-- Q4. (Relational division) Students who took EVERY IELTS course that has a started class
--      (there is no such IELTS course the student has not enrolled in)
--      Relational division written with a double NOT EXISTS: "for all courses" becomes "there is no course
--      without an enrollment". Divisor = the IELTS courses that have a class whose status is not Enrolling.
SELECT st.StudentId, st.FullName
FROM dbo.STUDENT st
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.COURSE co
    WHERE co.ProgramId = 'IELTS'
      AND EXISTS (SELECT 1 FROM dbo.CLASS cl WHERE cl.CourseId = co.CourseId AND cl.Status <> N'Enrolling')
      AND NOT EXISTS (SELECT 1 FROM dbo.ENROLLMENT en JOIN dbo.CLASS cl ON cl.ClassId = en.ClassId
                      WHERE en.StudentId = st.StudentId AND cl.CourseId = co.CourseId));

-- Q5. (CTE + window function) Top 3 students of every finished class
--     The CTE Ranking is a named result used by the next statement. DENSE_RANK() OVER (PARTITION BY ClassId
--     ORDER BY FinalGrade DESC) restarts the ranking in each class; equal grades share a rank with no gap
--     (1, 1, 2), so a class may show more than 3 students. A window function cannot be used in WHERE,
--     hence the rank is computed in the CTE and filtered outside. FinalGrade is set only for evaluated classes.
WITH Ranking AS (
    SELECT en.ClassId, st.FullName, en.FinalGrade,
           DENSE_RANK() OVER (PARTITION BY en.ClassId ORDER BY en.FinalGrade DESC) AS Rank
    FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
    WHERE en.FinalGrade IS NOT NULL
)
SELECT ClassId, Rank, FullName, FinalGrade FROM Ranking WHERE Rank <= 3 ORDER BY ClassId, Rank;

-- Q6. (Running total with a window function) Monthly revenue and year-to-date total
--     SUM(...) OVER (ORDER BY Month ROWS UNBOUNDED PRECEDING) adds each month to all the months before it.
--     fn_MonthlyRevenue (multi-statement table-valued function) returns all 12 months, 0 when there is no
--     receipt; NULL as branch = every branch.
SELECT Month, Revenue,
       SUM(Revenue) OVER (ORDER BY Month ROWS UNBOUNDED PRECEDING) AS YearToDate
FROM dbo.fn_MonthlyRevenue(YEAR(dbo.fn_Today()), NULL)
ORDER BY Month;

-- Q7. (PIVOT) Number of enrollments per program x branch
--     PIVOT turns the BranchId values of the rows into the columns [BR01], [BR02] with a COUNT per cell; the
--     IN list fixes the columns in advance (static PIVOT). The derived table src keeps only the needed
--     columns because PIVOT groups by every other column. COUNT already gives 0 for an empty cell, so
--     ISNULL is only a safety net.
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
--     Recursive CTE: the anchor member selects IE-65; the recursive member (after UNION ALL) joins COURSE
--     with the previous level through PrerequisiteCourseId and stops when a course has no prerequisite.
--     Depth counts the levels, so ORDER BY Depth DESC lists the path from the first course to IE-65.
--     MAXRECURSION (100 levels by default) would end a cycle in the data with an error.
WITH Path AS (
    SELECT CourseId, CourseName, PrerequisiteCourseId, 0 AS Depth FROM dbo.COURSE WHERE CourseId = 'IE-65'
    UNION ALL
    SELECT co.CourseId, co.CourseName, co.PrerequisiteCourseId, p.Depth + 1
    FROM dbo.COURSE co JOIN Path p ON co.CourseId = p.PrerequisiteCourseId
)
SELECT Depth, CourseId, CourseName FROM Path ORDER BY Depth DESC;

-- Q9. Teachers who taught the most sessions last month (inline TVF)
--     CROSS APPLY calls the inline table-valued function fn_TeacherSchedule once per teacher with that
--     teacher's TeacherId (a JOIN cannot pass a column of the left table to a function); a teacher without
--     sessions gives no row, as with an INNER JOIN. The two dates = first and last day of last month.
SELECT TOP (3) te.TeacherId, te.FullName, COUNT(*) AS SessionCount
FROM dbo.TEACHER te
CROSS APPLY dbo.fn_TeacherSchedule(te.TeacherId,
                                   DATEADD(MONTH, -1, DATEADD(DAY, 1 - DAY(dbo.fn_Today()), dbo.fn_Today())),
                                   DATEADD(DAY, -DAY(dbo.fn_Today()), dbo.fn_Today())) ts
WHERE ts.Status = N'Taught'
GROUP BY te.TeacherId, te.FullName
ORDER BY SessionCount DESC;

-- Q10. Students below 85% attendance in a class in progress (warning)
--      Query on a view (vw_LearningResults computes grade and attendance with functions); the warning comes
--      before the 80% needed to pass. SELECT * is fine in a demo; T30 of 12_tests.sql forbids it in
--      procedures, views and functions.
SELECT * FROM dbo.vw_LearningResults
WHERE Status = N'Studying' AND AttendanceRate < 85
ORDER BY AttendanceRate;

/* ===================== PART B. XPATH / XQUERY ===================== */

-- X1. .value(): first textbook and objective of every course
--     .value(XPath, SQL type) returns ONE scalar, so the path must select a single node: (...)[1] takes the
--     first one; @Year reads an attribute. Courses without a syllabus (NULL) are skipped.
SELECT CourseId, CourseName,
       SyllabusXml.value('(/Syllabus/Textbook)[1]', 'NVARCHAR(200)')    AS Textbook,
       SyllabusXml.value('(/Syllabus/Textbook/@Year)[1]', 'INT')        AS PublishedIn,
       SyllabusXml.value('(/Syllabus/Objective)[1]', 'NVARCHAR(300)')   AS Objective
FROM dbo.COURSE
WHERE SyllabusXml IS NOT NULL;

-- X2. .query(): the Units that practice Speaking, as XML
--     .query() returns XML (whole Unit elements); [Skill = "Speaking"] is an XPath predicate that keeps
--     the Units with a Skill child equal to Speaking.
SELECT CourseId, SyllabusXml.query('/Syllabus/Unit[Skill = "Speaking"]') AS SpeakingUnits
FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL;

-- X3. .exist(): teachers with an IELTS score of 8.0 or more
--     .exist() returns 1 when the XQuery finds at least one node, so it filters rows in WHERE; .value()
--     then reads the score of the first IELTS certificate.
SELECT TeacherId, FullName,
       ProfileXml.value('(/Profile/Certificate[@Type = "IELTS"]/@Score)[1]', 'DECIMAL(3,1)') AS IELTS
FROM dbo.TEACHER
WHERE ProfileXml.exist('/Profile/Certificate[@Type = "IELTS" and @Score >= 8.0]') = 1;

-- X4. .nodes() + CROSS APPLY: shred every teacher certificate into a relational result
--     .nodes() returns one row per Certificate node (T(c) names the result table and its XML column);
--     CROSS APPLY runs it for every teacher, and .value('@Type', ...) on c reads the attributes of that node.
SELECT te.TeacherId, te.FullName,
       c.value('@Type', 'NVARCHAR(30)')  AS Certificate,
       c.value('@Score', 'DECIMAL(5,1)') AS Score,
       c.value('@Year', 'INT')           AS Year
FROM dbo.TEACHER te
CROSS APPLY te.ProfileXml.nodes('/Profile/Certificate') AS T(c)
ORDER BY te.TeacherId, Year;

-- X5. FLWOR: Units with 6 sessions or more, sorted by session count, rebuilt as new XML
--     FLWOR = for / let / where / order by / return, the loop of XQuery. The return clause builds NEW
--     elements; {...} computes their content and data() takes the atomic value of a node.
SELECT CourseId,
       SyllabusXml.query('
           for $u in /Syllabus/Unit
           where $u/@Sessions >= 6
           order by $u/@Sessions descending
           return <Unit no="{data($u/@No)}" sessions="{data($u/@Sessions)}">{data($u/Title)}</Unit>') AS LongUnits
FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL;

-- X6. XML/relational consistency check: total sessions of the Units = COURSE.SessionCount
--     sum() is an XQuery aggregate over every Sessions attribute; comparing it with the relational column
--     SessionCount checks that the XML document and the table agree.
SELECT CourseId, SessionCount,
       SyllabusXml.value('sum(/Syllabus/Unit/@Sessions)', 'INT') AS SyllabusSessions,
       CASE WHEN SessionCount = SyllabusXml.value('sum(/Syllabus/Unit/@Sessions)', 'INT')
            THEN N'Match' ELSE N'Mismatch' END AS CheckResult
FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL;

-- X7. .modify(): add a certificate to a teacher profile (XML DML) - inside a transaction, then rolled back
--     .modify() is XML DML (insert / replace value of / delete), used as UPDATE ... SET column.modify(...);
--     "as last into (/Profile)[1]" appends the new element at the end of the first Profile element.
BEGIN TRANSACTION;
UPDATE dbo.TEACHER
SET ProfileXml.modify('insert <Certificate Type="CELTA" Year="2026"/> as last into (/Profile)[1]')
WHERE TeacherId = 'TE0003';
SELECT ProfileXml FROM dbo.TEACHER WHERE TeacherId = 'TE0003';
ROLLBACK TRANSACTION;

-- X8. FOR XML PATH: classes with their students (nested structure)
--     FOR XML PATH builds XML from rows: an alias starting with @ becomes an attribute, text() the text of
--     the element, any other alias a child element. The nested subquery with TYPE returns real XML (not
--     escaped text); ROOT adds a single root element.
SELECT cl.ClassId AS '@ClassId', cl.ClassName AS 'ClassName',
       (SELECT st.StudentId AS '@StudentId', st.FullName AS 'text()'
        FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId = en.StudentId
        WHERE en.ClassId = cl.ClassId
        FOR XML PATH('Student'), TYPE) AS 'Students'
FROM dbo.CLASS cl
WHERE cl.Status = N'In progress'
FOR XML PATH('Class'), ROOT('Center');

-- X9. Audit trail: old/new data (XML) of the grade changes
--     Reads the XML written by the trigger trg_GRADE_Audit with .value(); for an INSERT the old side is an
--     empty Grade element, so OldScore is NULL. LoggedAtUtc is shown in the center's local time.
SELECT TOP (10) dbo.fn_UtcToCenterTime(LoggedAtUtc) AS LoggedAtCenter, PerformedBy, Action, RecordKey,
       OldData.value('(/Grade/Score)[1]', 'DECIMAL(4,2)') AS OldScore,
       NewData.value('(/Grade/Score)[1]', 'DECIMAL(4,2)') AS NewScore
FROM dbo.AUDIT_LOG
WHERE TableName = N'GRADE'
ORDER BY LogId DESC;

/* ===================== PART C. CALLING PROCEDURES / FUNCTIONS ===================== */
-- Named parameters (@Keyword = ...) make the calls readable; usp_Dashboard_Stats and usp_Student_Search are
-- also called by the application. A table-valued function is used in FROM, a scalar function in SELECT.
EXEC dbo.usp_Dashboard_Stats;
EXEC dbo.usp_Student_Search @Keyword = N'Nguyễn';
EXEC dbo.usp_Course_FindBySkill @Skill = N'Speaking';
EXEC dbo.usp_Course_Syllabus @CourseId = 'IE-55';
EXEC dbo.usp_Teacher_FindByCertificate @CertificateType = N'IELTS', @MinScore = 8.0;
SELECT * FROM dbo.fn_StudentBalance('ST00031');
SELECT dbo.fn_Classification(8.25) AS Classification, dbo.fn_Weekday(dbo.fn_Today()) AS TodayWeekday;
GO
