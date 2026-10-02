#!/usr/bin/env python3
"""Xuất dữ liệu THẬT từ CSDL QLTTTA cho báo cáo (docs/report/data/), để báo cáo luôn khớp với CSDL:

  schema.json            từ điển dữ liệu: bảng, cột, kiểu, khóa, CHECK, UNIQUE, DEFAULT, số dòng
  ket_qua_truy_van.json  kết quả các truy vấn minh họa (Chương 4, 5) + "doi_tuong": số lượng bảng,
                         hàm, view, thủ tục, trigger, ràng buộc... (các con số trong báo cáo đọc từ đây)
  kiem_thu.txt           kết quả database/12_tests.sql - CHỈ ghi khi tất cả ca kiểm thử đạt (PASSED)

Cách dùng (mật khẩu sa đặt trong biến SQL_PASSWORD, không truyền trên dòng lệnh):
  SQL_PASSWORD="$(docker exec sql2022 printenv MSSQL_SA_PASSWORD)" \\
      python3 docs/report/cong_cu/xuat_du_lieu.py --docker sql2022
  SQL_PASSWORD='<mật khẩu sa>' python3 docs/report/cong_cu/xuat_du_lieu.py --server localhost,1433

Nên chạy scripts/test_all.sh trước: CSDL được khởi tạo lại từ đầu nên số liệu khớp dữ liệu mẫu.
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

# Truy vấn minh họa dùng trong báo cáo (khóa = tên mục mà noidung/*.py đọc qua chung.ket_qua())
TRUY_VAN = {
    "tong_quan": "EXEC dbo.usp_Dashboard_Stats",
    "doanh_thu_ct": """SELECT pg.ProgramName, COUNT(DISTINCT en.StudentId) AS StudentCount, SUM(rc.Amount) AS Revenue
        FROM dbo.RECEIPT rc JOIN dbo.ENROLLMENT en ON en.EnrollmentId=rc.EnrollmentId
        JOIN dbo.CLASS cl ON cl.ClassId=en.ClassId JOIN dbo.COURSE co ON co.CourseId=cl.CourseId
        JOIN dbo.PROGRAM pg ON pg.ProgramId=co.ProgramId
        WHERE rc.Status=N'Valid' GROUP BY pg.ProgramName HAVING SUM(rc.Amount) > 50000000 ORDER BY Revenue DESC""",
    "top3": """WITH Ranking AS (SELECT en.ClassId, st.FullName, en.FinalGrade,
            DENSE_RANK() OVER (PARTITION BY en.ClassId ORDER BY en.FinalGrade DESC) AS Rank
            FROM dbo.ENROLLMENT en JOIN dbo.STUDENT st ON st.StudentId=en.StudentId WHERE en.FinalGrade IS NOT NULL)
        SELECT ClassId, Rank, FullName, FinalGrade FROM Ranking WHERE Rank<=3 ORDER BY ClassId, Rank""",
    "lo_trinh": """WITH Path AS (SELECT CourseId, CourseName, PrerequisiteCourseId, 0 AS Depth FROM dbo.COURSE
            WHERE CourseId='IE-65'
            UNION ALL SELECT co.CourseId, co.CourseName, co.PrerequisiteCourseId, p.Depth+1 FROM dbo.COURSE co
            JOIN Path p ON co.CourseId=p.PrerequisiteCourseId)
        SELECT Depth, CourseId, CourseName FROM Path ORDER BY Depth DESC""",
    "pivot": """SELECT ProgramName, ISNULL([BR01],0) AS District1, ISNULL([BR02],0) AS ThuDuc
        FROM (SELECT pg.ProgramName, cl.BranchId, en.StudentId FROM dbo.ENROLLMENT en
              JOIN dbo.CLASS cl ON cl.ClassId=en.ClassId JOIN dbo.COURSE co ON co.CourseId=cl.CourseId
              JOIN dbo.PROGRAM pg ON pg.ProgramId=co.ProgramId) src
        PIVOT (COUNT(StudentId) FOR BranchId IN ([BR01],[BR02])) pv""",
    "ielts8": """SELECT TeacherId, FullName,
            ProfileXml.value('(/Profile/Certificate[@Type = "IELTS"]/@Score)[1]', 'DECIMAL(3,1)') AS IELTS
        FROM dbo.TEACHER WHERE ProfileXml.exist('/Profile/Certificate[@Type = "IELTS" and @Score >= 8.0]') = 1""",
    "nodes": """SELECT TOP 8 te.TeacherId, te.FullName, c.value('@Type','NVARCHAR(30)') AS Certificate,
            c.value('@Score','DECIMAL(5,1)') AS Score, c.value('@Year','INT') AS Year
        FROM dbo.TEACHER te CROSS APPLY te.ProfileXml.nodes('/Profile/Certificate') AS T(c)
        ORDER BY te.TeacherId, Year""",
    "nhat_quan": """SELECT CourseId, SessionCount,
            SyllabusXml.value('sum(/Syllabus/Unit/@Sessions)','INT') AS SyllabusSessions
        FROM dbo.COURSE WHERE SyllabusXml IS NOT NULL""",
    "de_cuong": "EXEC dbo.usp_Course_Syllabus @CourseId='IE-55'",
    "ky_nang": "EXEC dbo.usp_Course_FindBySkill @Skill=N'Speaking'",
    "ket_qua_lop1": """SELECT StudentId, StudentName, FinalGrade, Classification, AttendanceRate, Result
        FROM dbo.vw_LearningResults WHERE ClassId='CL0001' ORDER BY FinalGrade DESC""",
    "luong": """SELECT TOP 6 py.Year, py.Month, te.FullName, py.SessionCount, py.Hours, py.HourlyRate, py.Bonus,
            py.TotalPay
        FROM dbo.PAYROLL py JOIN dbo.TEACHER te ON te.TeacherId=py.TeacherId
        ORDER BY py.Year DESC, py.Month DESC, py.TotalPay DESC""",
    "cong_no_hv": "SELECT * FROM dbo.fn_StudentBalance('ST00028')",
    "doanh_thu_thang": """SELECT Month, ReceiptCount, Revenue FROM dbo.fn_MonthlyRevenue(YEAR(GETDATE()), NULL)
        WHERE Month BETWEEN 3 AND 10""",
    "nhat_ky": """SELECT TOP 3 CONVERT(VARCHAR(16), LoggedAt, 120) AS LoggedAt, PerformedBy, TableName, Action,
            RecordKey, CAST(NewData AS NVARCHAR(200)) AS NewData
        FROM dbo.AUDIT_LOG WHERE TableName=N'RECEIPT' ORDER BY LogId DESC""",
    "so_dong": """SELECT t.name AS TableName, SUM(p.rows) AS RecordCount FROM sys.tables t
        JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1) GROUP BY t.name ORDER BY t.name""",
    # Số lượng đối tượng CSDL - báo cáo đọc qua chung.doi_tuong(), không ghi cứng con số trong văn bản
    "doi_tuong": """SELECT
        (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS SoBang,
        (SELECT COUNT(*) FROM sys.sequences) AS SoSequence,
        (SELECT COUNT(*) FROM sys.xml_schema_collections WHERE schema_id = SCHEMA_ID('dbo')) AS SoXmlSchema,
        (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND is_ms_shipped = 0) AS SoHam,
        (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0) AS SoView,
        (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) AS SoThuTuc,
        (SELECT COUNT(*) FROM sys.triggers WHERE parent_class = 1) AS SoTrigger,
        (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name LIKE 'rl[_]%') AS SoRole,
        -- chỉ đếm ràng buộc trên bảng (bỏ bảng trả về của hàm multi-statement TVF)
        (SELECT COUNT(*) FROM sys.check_constraints WHERE OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS SoCheck,
        (SELECT COUNT(*) FROM sys.default_constraints WHERE OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS SoDefault,
        (SELECT COUNT(*) FROM sys.foreign_keys) AS SoFK,
        (SELECT COUNT(*) FROM sys.key_constraints
           WHERE type = 'PK' AND OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS SoPK,
        (SELECT COUNT(*) FROM sys.key_constraints
           WHERE type = 'UQ' AND OBJECTPROPERTY(parent_object_id, 'IsUserTable') = 1) AS SoUnique""",
}

# Từ điển dữ liệu (FOR JSON PATH, SQL Server 2016+; chỉ dùng cho báo cáo, không thuộc script CSDL 2012+)
SCHEMA_SQL = """SELECT (
 SELECT t.name AS bang,
  (SELECT c.column_id AS stt, c.name AS cot,
          CASE WHEN ty.name IN ('varchar','nvarchar','char','nchar') THEN ty.name + '(' + CASE WHEN c.max_length=-1 THEN 'MAX'
                    WHEN ty.name LIKE 'n%' THEN CAST(c.max_length/2 AS varchar) ELSE CAST(c.max_length AS varchar) END + ')'
               WHEN ty.name IN ('decimal','numeric') THEN ty.name + '(' + CAST(c.precision AS varchar) + ',' + CAST(c.scale AS varchar) + ')'
               WHEN ty.name IN ('time','datetime2') THEN ty.name + '(' + CAST(c.scale AS varchar) + ')'
               ELSE ty.name END AS kieu,
          c.is_nullable AS cho_null, c.is_identity AS identity_, c.is_computed AS tinh_toan,
          CAST(CASE WHEN EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.indexes i ON i.object_id=ic.object_id
                     AND i.index_id=ic.index_id WHERE i.is_primary_key=1 AND ic.object_id=c.object_id
                     AND ic.column_id=c.column_id) THEN 1 ELSE 0 END AS bit) AS khoa_chinh,
          (SELECT TOP 1 OBJECT_NAME(fk.referenced_object_id) FROM sys.foreign_key_columns fk
             WHERE fk.parent_object_id=c.object_id AND fk.parent_column_id=c.column_id) AS tham_chieu,
          (SELECT TOP 1 cc.definition FROM sys.computed_columns cc
             WHERE cc.object_id=c.object_id AND cc.column_id=c.column_id) AS cong_thuc,
          (SELECT TOP 1 dc.definition FROM sys.default_constraints dc
             WHERE dc.parent_object_id=c.object_id AND dc.parent_column_id=c.column_id) AS mac_dinh
   FROM sys.columns c JOIN sys.types ty ON ty.user_type_id=c.user_type_id
   WHERE c.object_id=t.object_id ORDER BY c.column_id FOR JSON PATH) AS cot,
  (SELECT ck.name AS ten, ck.definition AS dinh_nghia FROM sys.check_constraints ck
     WHERE ck.parent_object_id=t.object_id ORDER BY ck.name FOR JSON PATH) AS check_,
  (SELECT kc.name AS ten FROM sys.key_constraints kc
     WHERE kc.parent_object_id=t.object_id AND kc.type='UQ' FOR JSON PATH) AS unique_,
  (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id=t.object_id AND p.index_id IN (0,1)) AS so_dong
 FROM sys.tables t ORDER BY t.name FOR JSON PATH) AS j;"""


class KetNoi:
    """Chạy file SQL bằng sqlcmd (trong container Docker hoặc trên máy); mật khẩu qua biến môi trường."""

    def __init__(self, docker, server, user, password):
        self.docker, self.server, self.user = docker, server, user
        self.env = dict(os.environ, SQLCMDPASSWORD=password)

    def chay(self, sql_hoac_file, *tuy_chon):
        if isinstance(sql_hoac_file, Path):
            file = sql_hoac_file
        else:
            tmp = tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False, encoding="utf-8")
            tmp.write("SET NOCOUNT ON;\n" + sql_hoac_file + "\n")
            tmp.close()
            file = Path(tmp.name)
            file.chmod(0o644)   # sqlcmd trong container chạy bằng user mssql, phải đọc được file
        try:
            chung = ["-U", self.user, "-C", "-I", "-f", "65001", "-d", "QLTTTA", *tuy_chon]
            if self.docker:
                dich = f"/tmp/qlttta_{file.name}"
                subprocess.run(["docker", "cp", str(file), f"{self.docker}:{dich}"], check=True, capture_output=True)
                lenh = ["docker", "exec", "-e", "SQLCMDPASSWORD", self.docker,
                        "/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", *chung, "-i", dich]
            else:
                lenh = ["sqlcmd", "-S", self.server, *chung, "-i", str(file)]
            kq = subprocess.run(lenh, capture_output=True, text=True, encoding="utf-8", env=self.env)
            return kq.returncode, kq.stdout + kq.stderr
        finally:
            if not isinstance(sql_hoac_file, Path):
                file.unlink(missing_ok=True)


def xuat_schema(kn):
    ma, out = kn.chay(SCHEMA_SQL, "-y", "0")   # -y 0: không cắt cột JSON dài (không dùng chung được với -h)
    if ma != 0:
        sys.exit("Lỗi khi đọc từ điển dữ liệu:\n" + out)
    than = "".join(d for d in out.splitlines() if d.strip() and d.strip() != "j" and not re.fullmatch(r"-+", d.strip()))
    du_lieu = json.loads(than[than.find("["): than.rfind("]") + 1])
    (DATA / "schema.json").write_text(json.dumps(du_lieu, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"schema.json: {len(du_lieu)} bảng, {sum(len(t['cot']) for t in du_lieu)} cột")


def xuat_truy_van(kn):
    ket_qua = {}
    for ten, sql in TRUY_VAN.items():
        ma, out = kn.chay(sql, "-W", "-s", "|")
        dong = [d for d in out.splitlines() if d.strip()]
        if ma != 0 or len(dong) < 2:
            sys.exit(f"Lỗi truy vấn '{ten}':\n{out}")
        ket_qua[ten] = {"cot": dong[0].split("|"), "dong": [d.split("|") for d in dong[2:]]}
    (DATA / "ket_qua_truy_van.json").write_text(json.dumps(ket_qua, ensure_ascii=False, indent=1) + "\n",
                                                encoding="utf-8")
    dt = dict(zip(ket_qua["doi_tuong"]["cot"], ket_qua["doi_tuong"]["dong"][0]))
    print(f"ket_qua_truy_van.json: {len(ket_qua)} truy vấn; đối tượng CSDL: "
          + ", ".join(f"{k}={v}" for k, v in dt.items()))


def xuat_kiem_thu(kn):
    ma, out = kn.chay(ROOT / "database" / "12_tests.sql", "-b", "-W", "-s", "|")
    ca = sorted(d for d in out.splitlines() if re.match(r"^[TP]\d{2}\|", d))
    dat = [d for d in ca if "|PASSED|" in d]
    if ma != 0 or not ca or len(dat) != len(ca):
        print("\n".join(d for d in ca if "|PASSED|" not in d) or out[-2000:])
        sys.exit(f"Kiểm thử CSDL KHÔNG đạt ({len(dat)}/{len(ca)}) - không ghi kiem_thu.txt. Sửa lỗi trước.")
    (DATA / "kiem_thu.txt").write_text("\n".join(ca) + "\n", encoding="utf-8")
    print(f"kiem_thu.txt: {len(dat)}/{len(ca)} ca PASSED")


def main():
    ap = argparse.ArgumentParser(description="Xuất dữ liệu CSDL QLTTTA cho báo cáo")
    ap.add_argument("--docker", help="tên container SQL Server (vd sql2022, imcp-mssql)")
    ap.add_argument("--server", default="localhost,1433", help="máy chủ khi dùng sqlcmd trên máy")
    ap.add_argument("--user", default="sa")
    ap.add_argument("--chi", choices=["schema", "truy_van", "kiem_thu"], help="chỉ xuất một phần")
    a = ap.parse_args()
    mat_khau = os.environ.get("SQL_PASSWORD")
    if not mat_khau:
        sys.exit("Hãy đặt biến môi trường SQL_PASSWORD (mật khẩu tài khoản sa).")
    kn = KetNoi(a.docker, a.server, a.user, mat_khau)
    if a.chi in (None, "schema"):
        xuat_schema(kn)
    if a.chi in (None, "truy_van"):
        xuat_truy_van(kn)
    if a.chi in (None, "kiem_thu"):
        xuat_kiem_thu(kn)


if __name__ == "__main__":
    main()
