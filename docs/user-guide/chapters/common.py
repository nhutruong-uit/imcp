"""Shared data of the user guide, read from the source code so the guide follows the application."""
import html
import re

from guide_lib import GUIDE_DIR

REPO = GUIDE_DIR.parent.parent
SCREENS = REPO / "docs" / "report" / "images" / "screens"   # tools/qlttta_screenshots (Vietnamese UI)
WINDOWS_IMAGES = GUIDE_DIR / "images" / "windows"            # taken by hand on Windows (installers, dialogs)


def translations(context: str) -> dict[str, str]:
    """English source text -> Vietnamese translation of one context of resources/translations/qlttta_vi.ts."""
    ts = (REPO / "resources" / "translations" / "qlttta_vi.ts").read_text(encoding="utf-8")
    block = re.search(rf"<context>\s*<name>{context}</name>(.*?)</context>", ts, re.S).group(1)
    return {html.unescape(source): html.unescape(target) for source, target in
            re.findall(r"<source>(.*?)</source>\s*<translation>(.*?)</translation>", block, re.S)}


def _features() -> dict[str, tuple[str, str]]:
    """Menu entries (enum Feature) -> (Vietnamese label, Vietnamese menu group), in the order of Labels::feature:
    the English names of Labels.cpp translated with the context Labels of the translation file."""
    labels = (REPO / "src" / "presentation" / "common" / "Labels.cpp").read_text(encoding="utf-8")
    group_names = dict(re.findall(r'case FeatureGroup::(\w+):\s*return LabelsText::tr\("([^"]+)"\)', labels))
    group_of_variable = dict(re.findall(r"const FeatureGroup (\w+) = FeatureGroup::(\w+);", labels))
    vi = translations("Labels")
    return {feature: (vi[name], vi[group_names[group_of_variable[variable]]]) for feature, name, variable in
            re.findall(r'case Feature::(\w+):\s*return \{f, LabelsText::tr\("([^"]+)"\),\s*QStringLiteral\("[^"]*"\),'
                       r"\s*(\w+)\}", labels)}


# Menu entries (enum Feature) -> Vietnamese label and menu group, exactly as the application shows them
FEATURES = _features()
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
