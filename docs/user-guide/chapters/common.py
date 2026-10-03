"""Shared data of the user guide, read from the source code so the guide follows the application."""
import re

from guide_lib import GUIDE_DIR

REPO = GUIDE_DIR.parent.parent
SCREENS = REPO / "docs" / "report" / "images" / "screens"   # tools/qlttta_screenshots (Vietnamese UI)
WINDOWS_IMAGES = GUIDE_DIR / "images" / "windows"            # taken by hand on Windows (installers, dialogs)

# Menu entries (enum Feature) -> Vietnamese label and menu group, as in resources/translations/qlttta_vi.ts
FEATURES = {
    "Dashboard": ("Tổng quan", "Chung"),
    "Students": ("Học viên", "Đào tạo"),
    "Classes": ("Lớp học", "Đào tạo"),
    "WeeklySchedule": ("Lịch học tuần này", "Đào tạo"),
    "LearningResults": ("Kết quả học tập", "Đào tạo"),
    "OutstandingTuition": ("Công nợ học phí", "Tài chính"),
    "Revenue": ("Doanh thu", "Tài chính"),
    "Payroll": ("Lương giáo viên", "Tài chính"),
    "Accounts": ("Tài khoản", "Hệ thống"),
    "MyClasses": ("Lớp của tôi", "Giảng dạy"),
    "MyTeachingSchedule": ("Lịch dạy", "Giảng dạy"),
    "MyPay": ("Lương của tôi", "Giảng dạy"),
}
ROLES = {"Manager": "Quản lý", "AcademicStaff": "Giáo vụ", "Accountant": "Kế toán", "Teacher": "Giáo viên"}
ROLE_CODES = {"MANAGER": "Manager", "ACADEMIC_STAFF": "AcademicStaff", "ACCOUNTANT": "Accountant",
              "TEACHER": "Teacher"}


def app_version() -> str:
    text = (REPO / "CMakeLists.txt").read_text(encoding="utf-8")
    return re.search(r"project\(\s*QLTTTA\b.*?\bVERSION\s+([\d.]+)", text, re.S).group(1)


def allowed_features() -> dict[str, list[str]]:
    """Role -> features shown in the menu, read from Permissions::allowedFeatures (Permissions.cpp)."""
    text = (REPO / "src" / "application" / "services" / "Permissions.cpp").read_text(encoding="utf-8")
    body = re.search(r"allowedFeatures\(Role role\)\s*\{(.*?)\n\}", text, re.S).group(1)
    result = {}
    for role, features in re.findall(r"case Role::(\w+):\s*return\s*\{(.*?)\};", body, re.S):
        result[role] = re.findall(r"Feature::(\w+)", features)
    return result


def demo_accounts() -> list[tuple[str, str, str]]:
    """(username, password, role) of the demo accounts created by database/07_seed_data.sql."""
    text = (REPO / "database" / "07_seed_data.sql").read_text(encoding="utf-8")
    return [(user, password, ROLE_CODES[role]) for user, password, role in
            re.findall(r"usp_Account_Create\s+N'(\w+)',\s*N'([^']+)',\s*'(\w+)'", text)]
