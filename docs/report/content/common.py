"""Dữ liệu dùng chung cho báo cáo: thành viên, đường dẫn, dữ liệu xuất từ CSDL."""
import json
from pathlib import Path

REPORT_DIR = Path(__file__).resolve().parent.parent
REPO = REPORT_DIR.parent.parent
SQL = REPO / "database"
IMG = REPORT_DIR / "images"
DATA = REPORT_DIR / "data"

THANH_VIEN = [
    {"ten": "Trương Quang Như", "mssv": "25540022",
     "mang": "Kiến trúc & lập trình ứng dụng (Clean Architecture, Qt, ODBC), đăng nhập theo vai trò, "
             "CI/CD, đóng gói; điều phối, tích hợp",
     "file": "src/, tests/, .github/, scripts/, packaging/",
     "bao_cao": "Ch.6, Ch.8, phụ lục", "han": "25/10/2026"},
    {"ten": "Đỗ Phạm Minh Trâm", "mssv": "25540042",
     "mang": "Khảo sát nghiệp vụ, phân tích yêu cầu, use case, DFD, mô hình ERD và CD",
     "file": "diagrams/*.dot (ERD, CD, use case, DFD)",
     "bao_cao": "Ch.1, Ch.2, mục 3.1-3.2", "han": "18/10/2026"},
    {"ten": "Nguyễn Việt Phú", "mssv": "25540025",
     "mang": "Mô hình quan hệ, chuẩn hóa, từ điển dữ liệu, ràng buộc toàn vẹn và trigger",
     "file": "01_tables.sql, 05_triggers.sql",
     "bao_cao": "Mục 3.3-3.8, 4.6", "han": "18/10/2026"},
    {"ten": "Đỗ Bình Dương", "mssv": "25540008",
     "mang": "Stored procedure, function, cursor, giao dịch, truy vấn SQL, XPath/XQuery",
     "file": "02_functions.sql, 04_procedures.sql, 08_demo_queries.sql",
     "bao_cao": "Ch.4 (trừ 4.6)", "han": "18/10/2026"},
    {"ten": "Nguyễn Bảo Giang", "mssv": "25540009",
     "mang": "Xác thực, phân quyền, view bảo mật, nhật ký, backup/restore, import/export; CSDL phân tán, "
             "hướng đối tượng, NoSQL",
     "file": "03_views.sql, 06_security.sql, 09-12_*.sql",
     "bao_cao": "Ch.5, Ch.7", "han": "18/10/2026"},
]


def schema():
    return json.loads((DATA / "schema.json").read_text(encoding="utf-8"))


def ket_qua():
    return json.loads((DATA / "query_results.json").read_text(encoding="utf-8"))


def doi_tuong():
    """Số lượng đối tượng CSDL đếm từ CSDL thật (tools/export_data.py) - dùng thay cho con số ghi cứng."""
    k = ket_qua()["doi_tuong"]
    d = {cot: int(gt) for cot, gt in zip(k["cot"], k["dong"][0])}
    d["SoRangBuoc"] = d["SoCheck"] + d["SoDefault"] + d["SoFK"] + d["SoPK"] + d["SoUnique"]
    return d


# Kỳ vọng / thực tế trong bảng kết quả của 12_tests.sql (tiếng Anh) -> nhãn tiếng Việt cho báo cáo
KET_QUA_VI = {"Rejected": "Từ chối", "Succeeded": "Thành công", "Wrong result": "Sai kết quả", "Error": "Lỗi"}


def kiem_thu():
    """Các dòng TestId|Description|Expected|Actual|Verdict|Message của 12_tests.sql (Verdict = PASSED/FAILED)."""
    rows = []
    for line in (DATA / "database_tests.txt").read_text(encoding="utf-8").splitlines():
        parts = line.split("|")
        if len(parts) >= 6:
            rows.append(parts[:6])
    return rows
