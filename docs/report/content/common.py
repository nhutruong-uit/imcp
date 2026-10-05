"""Shared report data: team members, paths, data exported from the database, facts read from the source code."""
import html
import json
import re
from pathlib import Path

REPORT_DIR = Path(__file__).resolve().parent.parent
REPO = REPORT_DIR.parent.parent
SQL = REPO / "database"
SRC = REPO / "src"
TESTS = REPO / "tests"
IMG = REPORT_DIR / "images"
DATA = REPORT_DIR / "data"
# Real student IDs for the copy handed in to the lecturer: {"<member name>": "<student ID>"}, never committed
STUDENT_IDS_FILE = REPORT_DIR / "student_ids.local.json"

# The assignment table of the report; docs/PLAN.md section 2 shows the same table in English (change both).
# The student IDs are masked (only the last 2 digits) because the repository may be public;
# use_real_student_ids() puts the real ones back for the submission build (--submission)
MEMBERS = [
    {"name": "Trương Quang Như", "student_id": "******22",
     "area": "Kiến trúc & lập trình ứng dụng (Clean Architecture, Qt, ODBC), đăng nhập theo vai trò, "
             "CI/CD, đóng gói; điều phối, tích hợp",
     "files": "src/, tests/, .github/, scripts/, packaging/",
     "report_sections": "Ch.6, Ch.8, phụ lục", "deadline": "25/10/2026"},
    {"name": "Đỗ Phạm Minh Trâm", "student_id": "******42",
     "area": "Khảo sát nghiệp vụ, phân tích yêu cầu, use case, DFD, mô hình ERD và CD",
     "files": "diagrams/*.dot (ERD, CD, use case, DFD)",
     "report_sections": "Ch.1, Ch.2, mục 3.1-3.2", "deadline": "18/10/2026"},
    {"name": "Nguyễn Việt Phú", "student_id": "******25",
     "area": "Mô hình quan hệ, chuẩn hóa, từ điển dữ liệu, ràng buộc toàn vẹn và trigger",
     "files": "01_tables.sql, 05_triggers.sql",
     "report_sections": "Mục 3.3-3.8, 4.6", "deadline": "18/10/2026"},
    {"name": "Đỗ Bình Dương", "student_id": "******08",
     "area": "Stored procedure, function, cursor, giao dịch, truy vấn SQL, XPath/XQuery",
     "files": "02_functions.sql, 04_procedures.sql, 08_demo_queries.sql",
     "report_sections": "Ch.4 (trừ 4.6)", "deadline": "18/10/2026"},
    {"name": "Nguyễn Bảo Giang", "student_id": "******09",
     "area": "Xác thực, phân quyền, view bảo mật, nhật ký, backup/restore, import/export; CSDL phân tán, "
             "hướng đối tượng, NoSQL",
     "files": "03_views.sql, 06_security.sql, 09-12_*.sql",
     "report_sections": "Ch.5, Ch.7", "deadline": "18/10/2026"},
]


def use_real_student_ids():
    """Replaces the masked student IDs with the ones of STUDENT_IDS_FILE (submission build only)."""
    if not STUDENT_IDS_FILE.exists():
        raise SystemExit(f"{STUDENT_IDS_FILE.relative_to(REPO)} not found: create it with "
                         '{"<member name>": "<student ID>", ...} for the 5 members.')
    ids = json.loads(STUDENT_IDS_FILE.read_text(encoding="utf-8"))
    missing = [m["name"] for m in MEMBERS if m["name"] not in ids]
    if missing:
        raise SystemExit(f"{STUDENT_IDS_FILE.name} has no student ID for: {', '.join(missing)}")
    for m in MEMBERS:
        m["student_id"] = ids[m["name"]]


def schema():
    return json.loads((DATA / "schema.json").read_text(encoding="utf-8"))


def query_results():
    return json.loads((DATA / "query_results.json").read_text(encoding="utf-8"))


def object_counts():
    """Number of database objects counted in the real database (tools/export_data.py) - instead of hard-coded figures."""
    result = query_results()["object_counts"]
    counts = {column: int(value) for column, value in zip(result["columns"], result["rows"][0])}
    counts["ConstraintCount"] = (counts["CheckCount"] + counts["DefaultCount"] + counts["ForeignKeyCount"]
                                 + counts["PrimaryKeyCount"] + counts["UniqueCount"])
    return counts


# Expected / actual values in the result table of 12_tests.sql (English) -> Vietnamese labels for the report
RESULT_LABELS_VI = {"Rejected": "Từ chối", "Succeeded": "Thành công", "Wrong result": "Sai kết quả", "Error": "Lỗi"}


def database_tests():
    """Rows TestId|Description|Expected|Actual|Verdict|Message of 12_tests.sql (Verdict = PASSED/FAILED)."""
    rows = []
    for line in (DATA / "database_tests.txt").read_text(encoding="utf-8").splitlines():
        parts = line.split("|")
        if len(parts) >= 6:
            rows.append(parts[:6])
    return rows


def unit_test_suites():
    """Unit test executables (qlttta_add_test in tests/CMakeLists.txt); the end-to-end test is declared apart."""
    return re.findall(r"^qlttta_add_test\((\w+)", (TESTS / "CMakeLists.txt").read_text(encoding="utf-8"), re.M)


def e2e_scenarios():
    """Test functions of tests/tst_e2e_gui.cpp: its private slots without the Qt Test hooks and *_data tables."""
    slots = (TESTS / "tst_e2e_gui.cpp").read_text(encoding="utf-8").split("private slots:", 1)[1]
    hooks = {"initTestCase", "cleanupTestCase", "init", "cleanup"}
    return [name for name in re.findall(r"^    void (\w+)\(\)", slots, re.M)
            if name not in hooks and not name.endswith("_data")]


def macos_min_version():
    """Oldest macOS the .dmg runs on: the major version of the macOS runner pinned in release.yml (the bundled
    Homebrew libraries are built for it, see scripts/package-macos.sh)."""
    text = (REPO / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
    return re.search(r"^\s*runs-on:\s*macos-(\d+)\b", text, re.M).group(1)


def _vietnamese(context):
    """English source text -> Vietnamese translation of one context of resources/translations/qlttta_vi.ts."""
    ts = (REPO / "resources" / "translations" / "qlttta_vi.ts").read_text(encoding="utf-8")
    block = re.search(rf"<context>\s*<name>{context}</name>(.*?)</context>", ts, re.S).group(1)
    return {html.unescape(source): html.unescape(target) for source, target in
            re.findall(r"<source>(.*?)</source>\s*<translation>(.*?)</translation>", block, re.S)}


def menu_by_role():
    """[(role, [menu entries])] in Vietnamese, as the application shows them: Permissions::allowedFeatures for the
    menu of each role, Labels for the English names and the translation file for the Vietnamese ones."""
    labels = (SRC / "presentation" / "common" / "Labels.cpp").read_text(encoding="utf-8")
    feature_names = dict(re.findall(r'case Feature::(\w+):\s*return \{f, LabelsText::tr\("([^"]+)"\)', labels))
    role_names = dict(re.findall(r'case Role::(\w+):\s*return LabelsText::tr\("([^"]+)"\)', labels))
    vi = _vietnamese("Labels")
    permissions = (SRC / "application" / "services" / "Permissions.cpp").read_text(encoding="utf-8")
    body = re.search(r"allowedFeatures\(Role role\)\s*\{(.*?)\n\}", permissions, re.S).group(1)
    return [(vi[role_names[role]], [vi[feature_names[f]] for f in re.findall(r"Feature::(\w+)", features)])
            for role, features in re.findall(r"case Role::(\w+):\s*return\s*\{(.*?)\};", body, re.S)]
