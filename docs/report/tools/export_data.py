#!/usr/bin/env python3
"""Exports REAL data from the QLTTTA database for the report (docs/report/data/), so the report always matches
the database:

  schema.json          data dictionary: tables, columns, types, keys, CHECK, UNIQUE, DEFAULT, row counts
  query_results.json   results of the demo queries (chapters 4, 5) + "object_counts": number of tables,
                       functions, views, procedures, triggers, constraints... (the report reads its figures here)
  database_tests.txt   results of database/12_tests.sql - ONLY written when every test case PASSED

Usage (the sa password is read from SQL_PASSWORD, never passed on the command line):
  SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" \\
      python3 docs/report/tools/export_data.py --docker sql2022
  SQL_PASSWORD='<sa password>' python3 docs/report/tools/export_data.py --server localhost,1433

Run scripts/test_all.sh first: it re-creates the database, so the figures match the seed data.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "docs" / "report" / "data"

# Demo queries used by the report (key = name read by content/*.py through common.query_results())
QUERIES = {
    "dashboard": "EXEC dbo.usp_Dashboard_Stats",
    "revenue_by_program": """SELECT pg.ProgramName, COUNT(DISTINCT en.StudentId) AS StudentCount, SUM(rc.Amount) AS Revenue
        FROM dbo.RECEIPT rc JOIN dbo.ENROLLMENT en ON en.EnrollmentId=rc.EnrollmentId
        JOIN dbo.CLASS cl ON cl.ClassId=en.ClassId JOIN dbo.COURSE co ON co.CourseId=cl.CourseId
        JOIN dbo.PROGRAM pg ON pg.ProgramId=co.ProgramId
        WHERE rc.Status=N'Valid' GROUP BY pg.ProgramName HAVING SUM(rc.Amount) > 50000000 ORDER BY Revenue DESC""",
    "top3_per_class": """WITH Ranking AS (SELECT en.ClassId, st.FullName, en.FinalGrade,
            DENSE_RANK() OVER (PARTITION BY en.ClassId ORDER BY en.FinalGrade DESC) AS Rank
            FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId=en.StudentId WHERE en.FinalGrade IS NOT NULL)
        SELECT ClassId, Rank, FullName, FinalGrade FROM Ranking WHERE Rank<=3 ORDER BY ClassId, Rank""",
    "prerequisite_path": """WITH Path AS (SELECT CourseId, CourseName, PrerequisiteCourseId, 0 AS Depth FROM dbo.COURSE
            WHERE CourseId='IE-65'
            UNION ALL SELECT co.CourseId, co.CourseName, co.PrerequisiteCourseId, p.Depth+1 FROM dbo.COURSE co
            JOIN Path p ON co.CourseId=p.PrerequisiteCourseId)
        SELECT Depth, CourseId, CourseName FROM Path ORDER BY Depth DESC""",
    "enrollments_pivot": """SELECT ProgramName, ISNULL([BR01],0) AS District1, ISNULL([BR02],0) AS ThuDuc
        FROM (SELECT pg.ProgramName, cl.BranchId, en.StudentId FROM dbo.ENROLLMENT en
              JOIN dbo.CLASS cl ON cl.ClassId=en.ClassId JOIN dbo.COURSE co ON co.CourseId=cl.CourseId
              JOIN dbo.PROGRAM pg ON pg.ProgramId=co.ProgramId) src
        PIVOT (COUNT(StudentId) FOR BranchId IN ([BR01],[BR02])) pv""",
    "ielts_teachers": """SELECT TeacherId, FullName,
            ProfileXml.value('(/Profile/Certificate[@Type = "IELTS"]/@Score)[1]', 'DECIMAL(3,1)') AS IELTS
        FROM dbo.TEACHER WHERE ProfileXml.exist('/Profile/Certificate[@Type = "IELTS" and @Score >= 8.0]') = 1""",
    "teacher_certificates": """SELECT TOP 8 te.TeacherId, te.FullName, c.value('@Type','NVARCHAR(30)') AS Certificate,
            c.value('@Score','DECIMAL(5,1)') AS Score, c.value('@Year','INT') AS Year
        FROM dbo.TEACHER te CROSS APPLY te.ProfileXml.nodes('/Profile/Certificate') AS T(c)
        ORDER BY te.TeacherId, Year""",
    "syllabus_consistency": """SELECT CourseId, SessionCount,
            SyllabusXml.value('sum(/Syllabus/Unit/@Sessions)','INT') AS SyllabusSessions
        FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL""",
    "course_syllabus": "EXEC dbo.usp_Course_Syllabus @CourseId='IE-55'",
    "courses_by_skill": "EXEC dbo.usp_Course_FindBySkill @Skill=N'Speaking'",
    "class1_results": """SELECT StudentId, StudentName, FinalGrade, Classification, AttendanceRate, Result
        FROM dbo.vw_LearningResults WHERE ClassId='CL0001' ORDER BY FinalGrade DESC""",
    "payroll": """SELECT TOP 6 py.Year, py.Month, te.FullName, py.SessionCount, py.Hours, py.HourlyRate, py.Bonus,
            py.TotalPay
        FROM dbo.PAYROLL py JOIN dbo.TEACHER te ON te.TeacherId=py.TeacherId
        ORDER BY py.Year DESC, py.Month DESC, py.TotalPay DESC""",
    "student_balance": "SELECT * FROM dbo.fn_StudentBalance('ST00028')",
    "monthly_revenue": """SELECT Month, ReceiptCount, Revenue FROM dbo.fn_MonthlyRevenue(YEAR(GETDATE()), NULL)
        WHERE Month BETWEEN 3 AND 10""",
    "audit_log": """SELECT TOP 3 CONVERT(VARCHAR(16), LoggedAt, 120) AS LoggedAt, PerformedBy, TableName, Action,
            RecordKey, CAST(NewData AS NVARCHAR(200)) AS NewData
        FROM dbo.AUDIT_LOG WHERE TableName=N'RECEIPT' ORDER BY LogId DESC""",
    "row_counts": """SELECT t.name AS TableName, SUM(p.rows) AS RecordCount FROM sys.tables t
        JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1) GROUP BY t.name ORDER BY t.name""",
    # Number of database objects - read by the report through common.object_counts(), never hard-coded in the text
    "object_counts": """SELECT
        (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS TableCount,
        (SELECT COUNT(*) FROM sys.sequences) AS SequenceCount,
        (SELECT COUNT(*) FROM sys.xml_schema_collections WHERE schema_id = SCHEMA_ID('dbo')) AS XmlSchemaCount,
        (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND is_ms_shipped = 0) AS FunctionCount,
        (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0) AS ViewCount,
        (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) AS ProcedureCount,
        (SELECT COUNT(*) FROM sys.triggers WHERE parent_class = 1) AS TriggerCount,
        (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name LIKE 'rl[_]%') AS RoleCount,
        -- only constraints of tables (not of the table returned by a multi-statement TVF)
        (SELECT COUNT(*) FROM sys.check_constraints WHERE OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS CheckCount,
        (SELECT COUNT(*) FROM sys.default_constraints WHERE OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS DefaultCount,
        (SELECT COUNT(*) FROM sys.foreign_keys) AS ForeignKeyCount,
        (SELECT COUNT(*) FROM sys.key_constraints
           WHERE type = 'PK' AND OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS PrimaryKeyCount,
        (SELECT COUNT(*) FROM sys.key_constraints
           WHERE type = 'UQ' AND OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS UniqueCount""",
}

# Data dictionary (FOR JSON PATH needs SQL Server 2016+; only used for the report, not part of the 2012+ scripts)
SCHEMA_SQL = """SELECT (
 SELECT t.name AS table_name,
  (SELECT c.column_id AS position, c.name AS name,
          CASE WHEN ty.name IN ('varchar','nvarchar','char','nchar') THEN ty.name + '(' + CASE WHEN c.max_length=-1 THEN 'MAX'
                    WHEN ty.name LIKE 'n%' THEN CAST(c.max_length/2 AS varchar) ELSE CAST(c.max_length AS varchar) END + ')'
               WHEN ty.name IN ('decimal','numeric') THEN ty.name + '(' + CAST(c.precision AS varchar) + ',' + CAST(c.scale AS varchar) + ')'
               WHEN ty.name IN ('time','datetime2') THEN ty.name + '(' + CAST(c.scale AS varchar) + ')'
               ELSE ty.name END AS data_type,
          c.is_nullable AS is_nullable, c.is_identity AS is_identity, c.is_computed AS is_computed,
          CAST(CASE WHEN EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.indexes i ON i.object_id=ic.object_id
                     AND i.index_id=ic.index_id WHERE i.is_primary_key=1 AND ic.object_id=c.object_id
                     AND ic.column_id=c.column_id) THEN 1 ELSE 0 END AS bit) AS is_primary_key,
          (SELECT TOP 1 OBJECT_NAME(fk.referenced_object_id) FROM sys.foreign_key_columns fk
             WHERE fk.parent_object_id=c.object_id AND fk.parent_column_id=c.column_id) AS referenced_table,
          (SELECT TOP 1 cc.definition FROM sys.computed_columns cc
             WHERE cc.object_id=c.object_id AND cc.column_id=c.column_id) AS formula,
          (SELECT TOP 1 dc.definition FROM sys.default_constraints dc
             WHERE dc.parent_object_id=c.object_id AND dc.parent_column_id=c.column_id) AS default_value
   FROM sys.columns c JOIN sys.types ty ON ty.user_type_id=c.user_type_id
   WHERE c.object_id=t.object_id ORDER BY c.column_id FOR JSON PATH) AS columns,
  (SELECT ck.name AS name, ck.definition AS definition FROM sys.check_constraints ck
     WHERE ck.parent_object_id=t.object_id ORDER BY ck.name FOR JSON PATH) AS checks,
  (SELECT kc.name AS name FROM sys.key_constraints kc
     WHERE kc.parent_object_id=t.object_id AND kc.type='UQ' FOR JSON PATH) AS uniques,
  (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id=t.object_id AND p.index_id IN (0,1)) AS row_count
 FROM sys.tables t ORDER BY t.name FOR JSON PATH) AS j;"""


class SqlRunner:
    """Runs a SQL file with sqlcmd (inside the Docker container or on this machine); password via the environment."""

    def __init__(self, docker, server, user, password):
        self.docker, self.server, self.user = docker, server, user
        self.env = dict(os.environ, SQLCMDPASSWORD=password)

    def run(self, sql_or_file, *options):
        if isinstance(sql_or_file, Path):
            file = sql_or_file
        else:
            tmp = tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False, encoding="utf-8")
            tmp.write("SET NOCOUNT ON;\n" + sql_or_file + "\n")
            tmp.close()
            file = Path(tmp.name)
            file.chmod(0o644)   # sqlcmd runs as the mssql user inside the container and must read the file
        try:
            common = ["-U", self.user, "-C", "-I", "-f", "65001", "-d", "QLTTTA", *options]
            if self.docker:
                target = f"/tmp/qlttta_{file.name}"
                subprocess.run(["docker", "cp", str(file), f"{self.docker}:{target}"], check=True, capture_output=True)
                command = ["docker", "exec", "-e", "SQLCMDPASSWORD", self.docker,
                           "/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", *common, "-i", target]
            else:
                command = ["sqlcmd", "-S", self.server, *common, "-i", str(file)]
            result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", env=self.env)
            return result.returncode, result.stdout + result.stderr
        finally:
            if not isinstance(sql_or_file, Path):
                file.unlink(missing_ok=True)


def export_schema(runner):
    code, out = runner.run(SCHEMA_SQL, "-y", "0")   # -y 0: do not truncate the long JSON column (incompatible with -h)
    if code != 0:
        sys.exit("Cannot read the data dictionary:\n" + out)
    body = "".join(line for line in out.splitlines()
                   if line.strip() and line.strip() != "j" and not re.fullmatch(r"-+", line.strip()))
    tables = json.loads(body[body.find("["): body.rfind("]") + 1])
    (DATA / "schema.json").write_text(json.dumps(tables, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"schema.json: {len(tables)} tables, {sum(len(t['columns']) for t in tables)} columns")


def export_queries(runner):
    results = {}
    for name, sql in QUERIES.items():
        code, out = runner.run(sql, "-W", "-s", "|")
        lines = [line for line in out.splitlines() if line.strip()]
        if code != 0 or len(lines) < 2:
            sys.exit(f"Query '{name}' failed:\n{out}")
        results[name] = {"columns": lines[0].split("|"), "rows": [line.split("|") for line in lines[2:]]}
    (DATA / "query_results.json").write_text(json.dumps(results, ensure_ascii=False, indent=1) + "\n",
                                             encoding="utf-8")
    counts = dict(zip(results["object_counts"]["columns"], results["object_counts"]["rows"][0]))
    print(f"query_results.json: {len(results)} queries; database objects: "
          + ", ".join(f"{k}={v}" for k, v in counts.items()))


def export_tests(runner):
    code, out = runner.run(ROOT / "database" / "12_tests.sql", "-b", "-W", "-s", "|")
    cases = sorted(line for line in out.splitlines() if re.match(r"^[TP]\d{2}\|", line))
    passed = [line for line in cases if "|PASSED|" in line]
    if code != 0 or not cases or len(passed) != len(cases):
        print("\n".join(line for line in cases if "|PASSED|" not in line) or out[-2000:])
        sys.exit(f"Database tests FAILED ({len(passed)}/{len(cases)}) - database_tests.txt not written. Fix them first.")
    (DATA / "database_tests.txt").write_text("\n".join(cases) + "\n", encoding="utf-8")
    print(f"database_tests.txt: {len(passed)}/{len(cases)} cases PASSED")


def main():
    ap = argparse.ArgumentParser(description="Export the QLTTTA database data used by the report")
    ap.add_argument("--docker", help="SQL Server container name (e.g. sql2022, imcp-mssql)")
    ap.add_argument("--server", default="localhost,1433", help="server when sqlcmd runs on this machine")
    ap.add_argument("--user", default="sa")
    ap.add_argument("--only", choices=["schema", "queries", "tests"], help="export only one part")
    a = ap.parse_args()
    password = os.environ.get("SQL_PASSWORD")
    if not password:
        sys.exit("Set the SQL_PASSWORD environment variable (password of the sa account).")
    runner = SqlRunner(a.docker, a.server, a.user, password)
    if a.only in (None, "schema"):
        export_schema(runner)
    if a.only in (None, "queries"):
        export_queries(runner)
    if a.only in (None, "tests"):
        export_tests(runner)


if __name__ == "__main__":
    main()
