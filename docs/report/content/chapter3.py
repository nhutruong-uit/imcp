"""Chương 3 - Thiết kế cơ sở dữ liệu."""
import re

from content.common import IMG, SQL, object_counts, schema
from report_lib import sql_block

# Ý nghĩa các cột (dùng cho từ điển dữ liệu)
COLUMN_DESCRIPTIONS = {
    "BranchId": "Mã chi nhánh", "BranchName": "Tên chi nhánh", "Address": "Địa chỉ", "Phone": "Số điện thoại",
    "Email": "Địa chỉ email", "FoundedOn": "Ngày thành lập", "RoomId": "Mã phòng học", "RoomName": "Tên phòng",
    "Capacity": "Sức chứa tối đa (người)", "RoomType": "Loại phòng", "EmployeeId": "Mã nhân viên", "FullName": "Họ và tên",
    "DateOfBirth": "Ngày sinh", "Gender": "Giới tính", "Position": "Chức vụ", "HireDate": "Ngày vào làm",
    "BaseSalary": "Lương cơ bản (VNĐ/tháng)", "TeacherId": "Mã giáo viên", "Nationality": "Quốc tịch",
    "Degree": "Trình độ học vấn", "TeacherType": "Giáo viên Việt Nam / bản ngữ", "HourlyRate": "Đơn giá một giờ dạy (VNĐ)",
    "ProfileXml": "Hồ sơ năng lực dạng XML (chứng chỉ, kinh nghiệm, chuyên môn)",
    "Username": "Tên đăng nhập = tên USER trong SQL Server", "Role": "Vai trò trong ứng dụng",
    "CreatedAt": "Thời điểm tạo", "LastLoginAt": "Lần đăng nhập gần nhất", "StudentId": "Mã học viên",
    "Occupation": "Nghề nghiệp", "GuardianName": "Họ tên phụ huynh", "GuardianPhone": "SĐT phụ huynh",
    "RegisteredOn": "Ngày đăng ký hồ sơ", "Notes": "Ghi chú", "ProgramId": "Mã chương trình", "ProgramName": "Tên chương trình",
    "TargetLearners": "Đối tượng học viên", "Description": "Mô tả / nội dung", "CourseId": "Mã khóa học", "CourseName": "Tên khóa học",
    "Level": "Cấp độ theo khung CEFR", "SessionCount": "Số buổi", "SessionMinutes": "Thời lượng mỗi buổi (phút)",
    "Tuition": "Học phí (VNĐ)", "MinPlacementScore": "Điểm kiểm tra đầu vào tối thiểu",
    "PrerequisiteCourseId": "Khóa học tiên quyết (tự tham chiếu)", "SyllabusXml": "Đề cương khóa học - XML có kiểu (XSD)",
    "ComponentId": "Mã thành phần điểm", "ComponentName": "Tên cột điểm", "Weight": "Trọng số (%)", "ClassId": "Mã lớp",
    "ClassName": "Tên lớp", "EndDate": "Ngày kết thúc (buổi cuối của lớp / hết hạn khuyến mãi)",
    "MaxStudents": "Sĩ số tối đa", "Weekday": "Thứ trong tuần theo ISO 8601 (1 = thứ Hai ... 7 = Chủ nhật)", "StartTime": "Giờ bắt đầu",
    "EndTime": "Giờ kết thúc", "SessionId": "Mã buổi học", "SessionNo": "Buổi thứ", "SessionDate": "Ngày học",
    "PromotionId": "Mã khuyến mãi", "PromotionName": "Tên khuyến mãi", "DiscountType": "Phần trăm / số tiền",
    "DiscountValue": "Giá trị giảm", "StartDate": "Ngày bắt đầu (khai giảng lớp / hiệu lực khuyến mãi)", "EnrollmentId": "Mã lượt ghi danh", "EnrolledOn": "Ngày ghi danh",
    "BaseTuition": "Học phí của lớp tại thời điểm ghi danh", "DiscountAmount": "Số tiền được giảm",
    "TuitionDue": "Học phí phải đóng (cột tính toán)", "AmountPaid": "Tổng tiền đã đóng (dẫn xuất, trigger duy trì)",
    "FinalGrade": "Điểm tổng kết", "Result": "Kết quả cuối khóa", "EnrolledByEmployeeId": "Nhân viên thực hiện ghi danh",
    "ReceiptId": "Mã phiếu thu", "PaidAt": "Thời điểm thu", "Amount": "Số tiền thu", "PaymentMethod": "Hình thức thanh toán",
    "CollectedByEmployeeId": "Nhân viên thu tiền", "CancelReason": "Lý do hủy phiếu", "Score": "Điểm (thang 10)",
    "EnteredAt": "Thời điểm nhập điểm", "EnteredBy": "Người nhập điểm", "TestId": "Mã bài kiểm tra",
    "TestDate": "Ngày kiểm tra", "ListeningScore": "Điểm Nghe", "SpeakingScore": "Điểm Nói", "ReadingScore": "Điểm Đọc",
    "WritingScore": "Điểm Viết", "OverallScore": "Điểm trung bình 4 kỹ năng (cột tính toán)",
    "RecommendedCourseId": "Khóa học được đề xuất (trigger)", "GradedByTeacherId": "Giáo viên chấm", "CertificateId": "Mã chứng nhận",
    "SerialNumber": "Số hiệu chứng nhận", "IssuedOn": "Ngày cấp", "Classification": "Xếp loại", "PayrollId": "Mã bảng lương",
    "Month": "Tháng", "Year": "Năm", "Hours": "Số giờ đã dạy", "Bonus": "Thưởng", "Deduction": "Khấu trừ",
    "TotalPay": "Tổng lương (cột tính toán)", "FinalizedAt": "Thời điểm chốt", "LogId": "Mã nhật ký",
    "LoggedAt": "Thời điểm thao tác", "PerformedBy": "Người thực hiện (ORIGINAL_LOGIN)",
    "TableName": "Bảng bị tác động", "Action": "INSERT / UPDATE / DELETE", "RecordKey": "Khóa của dòng bị tác động",
    "OldData": "Dữ liệu trước khi thay đổi (XML)", "NewData": "Dữ liệu sau khi thay đổi (XML)",
    "Status": "Trạng thái",
}

PREDICATES = {
    "BRANCH": "Mỗi chi nhánh có mã duy nhất, tên không trùng, địa chỉ, số điện thoại, email, ngày thành lập và trạng thái hoạt động.",
    "ROOM": "Mỗi phòng học thuộc đúng một chi nhánh, có tên (không trùng trong cùng chi nhánh), sức chứa và loại phòng.",
    "EMPLOYEE": "Mỗi nhân viên văn phòng làm việc tại một chi nhánh với một chức vụ (quản lý, giáo vụ, kế toán, tư vấn).",
    "TEACHER": "Mỗi giáo viên thuộc một chi nhánh quản lý, có trình độ, loại (Việt Nam/bản ngữ), đơn giá giờ dạy và hồ sơ năng lực XML.",
    "ACCOUNT": "Mỗi tài khoản đăng nhập ứng với đúng một nhân viên hoặc một giáo viên và có một vai trò.",
    "STUDENT": "Mỗi học viên được tiếp nhận tại một chi nhánh; học viên dưới 18 tuổi phải có thông tin phụ huynh.",
    "PROGRAM": "Chương trình đào tạo (IELTS, TOEIC, Giao tiếp, Thiếu nhi) gồm nhiều khóa học.",
    "COURSE": "Mỗi khóa học thuộc một chương trình, có cấp độ, số buổi, học phí, điều kiện đầu vào, có thể có một khóa tiên quyết.",
    "GRADE_COMPONENT": "Mỗi khóa học có các cột điểm với trọng số, tổng trọng số bằng 100%.",
    "CLASS": "Mỗi lớp là một đợt mở của khóa học tại một chi nhánh, do một giáo viên phụ trách, học tại một phòng.",
    "CLASS_SCHEDULE": "Mỗi lớp học vào một số thứ trong tuần, mỗi thứ có giờ bắt đầu - kết thúc (thực thể yếu của CLASS).",
    "CLASS_SESSION": "Mỗi buổi học thuộc một lớp, có số thứ tự, ngày, giờ, phòng, giáo viên dạy thực tế và trạng thái.",
    "PROMOTION": "Mỗi khuyến mãi giảm theo phần trăm (tối đa 50%) hoặc số tiền, có thời gian hiệu lực.",
    "ENROLLMENT": "Mỗi lượt ghi danh là việc một học viên học một lớp, lưu học phí, khuyến mãi, số tiền đã đóng và kết quả.",
    "RECEIPT": "Mỗi phiếu thu ghi nhận một lần đóng tiền cho một lượt ghi danh do một nhân viên lập; chỉ được hủy, không được xóa.",
    "ATTENDANCE": "Mỗi lượt ghi danh được điểm danh tại các buổi học của lớp với một trạng thái.",
    "GRADE": "Mỗi lượt ghi danh có một điểm cho mỗi cột điểm của khóa học.",
    "PLACEMENT_TEST": "Mỗi bài kiểm tra đầu vào của học viên có điểm 4 kỹ năng, điểm tổng và khóa học được đề xuất.",
    "CERTIFICATE": "Mỗi lượt ghi danh đạt yêu cầu được cấp tối đa một chứng nhận có số hiệu duy nhất.",
    "PAYROLL": "Mỗi giáo viên có tối đa một bảng lương cho mỗi tháng, tính từ số giờ đã dạy.",
    "AUDIT_LOG": "Mỗi dòng nhật ký ghi một thao tác thay đổi dữ liệu nhạy cảm (điểm, phiếu thu), chỉ được ghi thêm.",
}

TABLE_ORDER = ["BRANCH", "ROOM", "EMPLOYEE", "TEACHER", "ACCOUNT", "STUDENT", "PROGRAM", "COURSE",
               "GRADE_COMPONENT", "CLASS", "CLASS_SCHEDULE", "CLASS_SESSION", "PROMOTION", "ENROLLMENT", "RECEIPT", "ATTENDANCE",
               "GRADE", "PLACEMENT_TEST", "CERTIFICATE", "PAYROLL", "AUDIT_LOG"]


def _pretty_check(defn: str) -> str:
    """Rút gọn định nghĩa CHECK / DEFAULT cho dễ đọc."""
    d = defn.strip()
    m = re.fullmatch(r"\(NOT \[(\w+)\] like '%\[\^0-9\]%' AND \(len\(\[\1\]\)>=\((\d+)\) AND len\(\[\1\]\)<=\((\d+)\)\)\)", d)
    if m:
        return f"{m.group(1)}: chỉ gồm chữ số, dài {m.group(2)}-{m.group(3)} ký tự"
    m = re.fullmatch(r"\(\[(\w+)\] like '%_@_%\._%'\)", d)
    if m:
        return f"{m.group(1)}: đúng dạng email"
    m = re.fullmatch(r"\(\[(\w+)\]>=\(?([\d.]+)\)? AND \[\1\]<=\(?([\d.]+)\)?\)", d)
    if m:
        return f"{m.group(2)} ≤ {m.group(1)} ≤ {m.group(3)}"
    thay = {"(CONVERT([date],getdate()))": "ngày hiện tại", "(getdate())": "thời điểm hiện tại",
            "(original_login())": "người đăng nhập (ORIGINAL_LOGIN)"}
    if d in thay:
        return thay[d]
    vals = re.findall(r"\[(\w+)\]=N?'([^']*)'", defn)
    rest = re.sub(r"\[(\w+)\]=N?'([^']*)'", "", defn)
    if vals and re.fullmatch(r"[\s()OR]*", rest):
        col = vals[0][0]
        return f"{col} ∈ {{{', '.join(v for _, v in reversed(vals))}}}"
    s = defn.strip()
    while s.startswith("(") and s.endswith(")"):
        s = s[1:-1]
    s = re.sub(r"(?<![A-Za-z0-9_])N'", "'", re.sub(r"\[(\w+)\]", r"\1", s))   # bỏ tiền tố N của chuỗi Unicode
    s = re.sub(r"\((\d+)\)", r"\1", s)
    for a, b in ((">=", " ≥ "), ("<=", " ≤ "), ("<>", " ≠ "), (">", " > "), ("<", " < ")):
        s = s.replace(a, b) if a in (">=", "<=", "<>") else re.sub(rf"(?<![≥≤≠ ]){re.escape(a)}(?!=)", b, s)
    return re.sub(r"\s{2,}", " ", s)


def _check_columns(defn: str):
    return set(re.findall(r"\[(\w+)\]", defn))


def data_dictionary(r):
    sc = {t["bang"]: t for t in schema()}
    for ten in TABLE_ORDER:
        t = sc[ten]
        checks = t.get("check_") or []
        check_cot, check_bang = {}, []
        for ck in checks:
            cols = _check_columns(ck["dinh_nghia"])
            if len(cols) == 1:
                check_cot.setdefault(next(iter(cols)), []).append(_pretty_check(ck["dinh_nghia"]))
            else:
                check_bang.append((ck["ten"], _pretty_check(ck["dinh_nghia"])))
        rows = []
        for c in t["cot"]:
            rb = []
            if c.get("khoa_chinh"):
                rb.append("PK")
            if c.get("tham_chieu"):
                rb.append(f"FK → {c['tham_chieu']}")
            if c.get("identity_"):
                rb.append("IDENTITY")
            if c.get("cong_thuc"):
                rb.append("Tính toán: " + _pretty_check(c["cong_thuc"]))
            if c.get("mac_dinh"):
                md = _pretty_check(c["mac_dinh"])
                rb.append("Mặc định: " + ("sinh từ SEQUENCE" if "NEXT VALUE" in md.upper() else md))
            rb += check_cot.get(c["cot"], [])
            rows.append([c["cot"], c["kieu"].upper(), "" if c["cho_null"] else "Không",
                         "\n".join(rb), COLUMN_DESCRIPTIONS.get(c["cot"], "")])
        r.table(["Tên cột", "Kiểu dữ liệu", "NULL", "Ràng buộc", "Ý nghĩa"], rows,
                widths_cm=[3.0, 2.9, 1.3, 4.8, 4.0], caption=f"Từ điển dữ liệu bảng {ten}", size=9)
        if check_bang:
            r.p("Ràng buộc liên thuộc tính của bảng " + ten + ": " +
                "; ".join(f"`{n}`: {d}" for n, d in check_bang) + ".", indent=False)


def chapter3(r):
    r.h1("CHƯƠNG 3: THIẾT KẾ CƠ SỞ DỮ LIỆU")

    # ------------------------------------------------------------------ 3.1
    r.h2("3.1. Mô hình quan niệm - sơ đồ thực thể kết hợp (ERD)")
    r.p("Mô hình quan niệm được vẽ theo ký hiệu Chen như bài giảng: **hình chữ nhật** là thực thể (thuộc tính khóa "
        f"gạch dưới), **hình thoi** là mối kết hợp, bản số **(min,max)** ghi cạnh thực thể tham gia. Do có "
        f"{object_counts()['SoBang']} thực thể, sơ đồ được tách thành 2 phân hệ dùng chung một số thực thể (tô xám ở sơ đồ "
        "thứ hai). Tên thực thể, thuộc tính trong sơ đồ dùng đúng tên bảng, cột tiếng Anh của CSDL.")
    r.figures_landscape([
        (IMG / "diagrams" / "erd_1_organization_training.png", "ERD phân hệ tổ chức - nhân sự - đào tạo - lớp học"),
        (IMG / "diagrams" / "erd_2_students_finance.png", "ERD phân hệ học viên - ghi danh - tài chính - kết quả"),
    ])
    r.p("Một số điểm thiết kế đáng chú ý:")
    r.bullets([
        "**ENROLLMENT là thực thể kết hợp** giữa STUDENT và CLASS (quan hệ n-n), được nâng thành thực thể vì bản thân nó "
        "tham gia các mối kết hợp khác: đóng tiền (RECEIPT), điểm danh, điểm, chứng nhận.",
        "**ATTENDANCE và GRADE là mối kết hợp n-n có thuộc tính** (ENROLLMENT-CLASS_SESSION với Status, "
        "ENROLLMENT-GRADE_COMPONENT với Score), khi chuyển sang mô hình quan hệ sẽ thành bảng riêng.",
        "**Mối kết hợp đệ quy** *tiên quyết* trên COURSE: một khóa có tối đa một khóa tiên quyết (0,1) và có thể là "
        "tiên quyết của nhiều khóa (0,n), tạo thành lộ trình IELTS Foundation → 5.5 → 6.5.",
        "**CLASS_SCHEDULE là thực thể yếu** của CLASS (khóa = ClassId + Weekday), xóa lớp thì xóa lịch theo (ON DELETE CASCADE).",
        "**Thuộc tính dẫn xuất** (ký hiệu /): OverallScore, TuitionDue, AmountPaid, TotalPay - được lưu và duy trì tự động "
        "để truy vấn nhanh (cột tính toán hoặc trigger).",
        "**Thuộc tính phức hợp, đa trị** (chứng chỉ của giáo viên, các Unit của đề cương) được lưu dạng XML thay vì "
        "tách nhiều bảng phụ - minh họa mô hình dữ liệu bán cấu trúc của Chương 2.",
    ])
    r.table(["Mối kết hợp", "Thực thể (bản số)", "Ý nghĩa"], [
        ["có", "BRANCH (1,n) - ROOM (1,1)", "Mỗi phòng thuộc đúng một chi nhánh, chi nhánh có ít nhất một phòng"],
        ["gồm", "PROGRAM (1,n) - COURSE (1,1)", "Khóa học thuộc một chương trình"],
        ["tiên quyết", "COURSE (0,1) - COURSE (0,n)", "Đệ quy: khóa học cần hoàn thành khóa khác trước"],
        ["mở thành", "COURSE (0,n) - CLASS (1,1)", "Mỗi lớp là một đợt mở của một khóa học"],
        ["phụ trách", "TEACHER (0,n) - CLASS (1,1)", "Mỗi lớp có một giáo viên chính"],
        ["gồm buổi / dạy", "CLASS (0,n) - CLASS_SESSION (1,1); TEACHER (0,n) - CLASS_SESSION (1,1)", "Buổi học có giáo viên dạy thực tế (có thể dạy thay)"],
        ["đăng ký / có học viên", "STUDENT (0,n) - ENROLLMENT (1,1) - CLASS (0,n)", "Quan hệ n-n học viên - lớp qua thực thể kết hợp"],
        ["đóng tiền", "ENROLLMENT (0,n) - RECEIPT (1,1)", "Một lượt ghi danh đóng nhiều đợt"],
        ["ATTENDANCE", "ENROLLMENT (0,n) - CLASS_SESSION (0,n)", "n-n có thuộc tính Status"],
        ["GRADE", "ENROLLMENT (0,n) - GRADE_COMPONENT (0,n)", "n-n có thuộc tính Score"],
        ["được cấp", "ENROLLMENT (0,1) - CERTIFICATE (1,1)", "1-1: mỗi lượt ghi danh đạt có tối đa một chứng nhận"],
        ["đăng nhập", "ACCOUNT (0,1) - EMPLOYEE/TEACHER (0,1)", "Mỗi người có tối đa một tài khoản"],
    ], widths_cm=[3.0, 6.4, 6.6], caption="Các mối kết hợp chính và bản số", size=9.5)

    # ------------------------------------------------------------------ 3.2
    r.h2("3.2. Mô hình quan niệm hướng đối tượng - sơ đồ lớp (CD)")
    r.p("Ngoài ERD, bài giảng giới thiệu mô hình CD (UML Class Diagram) ở mức quan niệm. Sơ đồ CD của hệ thống "
        "thể hiện thêm những gì ERD không diễn đạt được: **tổng quát hóa** (lớp trừu tượng Person là cha của Student, "
        "Teacher, Employee với các thuộc tính chung họ tên, ngày sinh, giới tính, liên lạc), **phương thức** của "
        "lớp (enroll, pay, evaluateResults...), quan hệ **thành phần** (ClassSession là thành phần của Class), "
        "**kết tập** (Receipt thuộc Enrollment) và thuộc tính kiểu tập hợp `set(...)`, bộ `tuple(...)`.")
    r.figure(IMG / "diagrams" / "class_diagram.png", "Sơ đồ lớp (CD) của hệ thống QLTTTA", width_cm=15.5)
    r.p("Khi cài đặt trên hệ quản trị quan hệ, lớp trừu tượng Person được hiện thực theo chiến lược **mỗi lớp con một "
        "bảng** (STUDENT, TEACHER, EMPLOYEE lặp lại các cột chung) vì ba đối tượng có vòng đời, khóa và quyền truy cập "
        "khác nhau; các phương thức được hiện thực thành thủ tục/hàm trong CSDL và use case trong ứng dụng.")

    # ------------------------------------------------------------------ 3.3
    r.h2("3.3. Chuyển đổi ERD sang mô hình quan hệ")
    r.p("Áp dụng các quy tắc chuyển đổi theo bản số của mối kết hợp:")
    r.table(["Trường hợp", "Quy tắc", "Áp dụng trong đồ án"], [
        ["Thực thể mạnh", "Mỗi thực thể thành một quan hệ, thuộc tính khóa thành khóa chính",
         "BRANCH, STUDENT, COURSE, CLASS..."],
        ["(1,1) - (1,n) / (0,n)", "Đưa khóa chính bên nhiều vào làm khóa ngoại ở bên (1,1)",
         "CLASS(CourseId, BranchId, TeacherId, RoomId), RECEIPT(EnrollmentId, CollectedByEmployeeId)"],
        ["(0,1) - (0,n) đệ quy", "Khóa ngoại cho phép NULL tham chiếu chính quan hệ đó",
         "COURSE(PrerequisiteCourseId) → COURSE"],
        ["(0,1) - (1,1)", "Khóa ngoại đặt ở bên (1,1), thêm UNIQUE để giữ tính 1-1",
         "CERTIFICATE(EnrollmentId UNIQUE); ACCOUNT(EmployeeId/TeacherId + filtered unique index)"],
        ["(n) - (n) có thuộc tính", "Tạo quan hệ mới, khóa = tổ hợp khóa hai bên, kèm thuộc tính của mối kết hợp",
         "ATTENDANCE(__SessionId, EnrollmentId__, Status), GRADE(__EnrollmentId, ComponentId__, Score)"],
        ["Thực thể kết hợp", "Quan hệ có khóa riêng (surrogate) + UNIQUE trên cặp khóa ngoại",
         "ENROLLMENT(__EnrollmentId__, StudentId, ClassId, ...) với UNIQUE(StudentId, ClassId)"],
        ["Thực thể yếu", "Khóa = khóa của thực thể chủ + khóa riêng phần, xóa lan truyền",
         "CLASS_SCHEDULE(__ClassId, Weekday__, ...) ON DELETE CASCADE"],
        ["Thuộc tính đa trị/phức hợp", "Tách bảng riêng hoặc lưu XML (mô hình bán cấu trúc)",
         "GRADE_COMPONENT (bảng riêng), ProfileXml, SyllabusXml (XML)"],
    ], widths_cm=[3.2, 6.2, 6.6], caption="Quy tắc chuyển đổi ERD sang mô hình quan hệ", size=9.5)

    # ------------------------------------------------------------------ 3.4
    r.h2("3.4. Lược đồ quan hệ")
    r.p(f"Lược đồ CSDL QLTTTA gồm {object_counts()['SoBang']} quan hệ (khóa chính gạch dưới). Mỗi quan hệ kèm tân từ mô tả ngữ nghĩa:")
    sc = {t["bang"]: t for t in schema()}
    for i, ten in enumerate(TABLE_ORDER, 1):
        cols = []
        for c in sc[ten]["cot"]:
            ten_cot = c["cot"]
            if c.get("tinh_toan"):
                ten_cot = "/" + ten_cot
            cols.append(f"__{ten_cot}__" if c.get("khoa_chinh") else ten_cot)
        r.p(f"**{i}. {ten}** (" + ", ".join(cols) + ")", indent=False, after=20)
        r.p(f"*Tân từ:* {PREDICATES[ten]}", indent=True, after=100)

    # ------------------------------------------------------------------ 3.5
    r.h2("3.5. Từ điển dữ liệu")
    r.p("Từ điển dữ liệu dưới đây được **trích xuất tự động từ CSDL đã cài đặt** (sys.columns, sys.check_constraints, "
        "sys.foreign_keys...) nên luôn khớp với script `01_tables.sql`. Quy ước đặt tên (tiếng Anh): bảng viết hoa dạng "
        "`UPPER_SNAKE_CASE`, cột `PascalCase`; ràng buộc `PK_<TABLE>`, `FK_<CHILD>_<PARENT>`, `CK_<TABLE>_<Column>`, "
        "`UQ_...`, `DF_...`; giá trị lưu trong CSDL cũng bằng tiếng Anh (`Studying`, `Passed`...), giao diện tiếng "
        "Việt hiển thị bản dịch. Mã nghiệp vụ "
        "(ST00001, CL0001, EN000001...) được sinh bởi **SEQUENCE** trong ràng buộc DEFAULT.")
    data_dictionary(r)

    # ------------------------------------------------------------------ 3.6
    r.h2("3.6. Chuẩn hóa lược đồ")
    r.p("Kiểm tra các dạng chuẩn dựa trên phụ thuộc hàm (PTH) của từng quan hệ:")
    r.bullets([
        "**1NF**: mọi thuộc tính đều nguyên tố. Các dữ liệu đa trị (lịch học nhiều buổi/tuần, cột điểm, điểm danh) "
        "đã được tách thành CLASS_SCHEDULE, GRADE_COMPONENT, ATTENDANCE. Riêng ProfileXml và SyllabusXml là kiểu XML được SQL Server "
        "xem như một giá trị; chỉ dùng để lưu/tra cứu hồ sơ, không tham gia khóa hay phép kết.",
        "**2NF**: các quan hệ có khóa ghép (CLASS_SCHEDULE, ATTENDANCE, GRADE) không có thuộc tính nào phụ thuộc vào một phần "
        "khóa. Ví dụ GRADE: (EnrollmentId, ComponentId) → Score; tên cột điểm ComponentName phụ thuộc ComponentId nên nằm ở GRADE_COMPONENT chứ không ở GRADE.",
        "**3NF/BCNF**: không có phụ thuộc bắc cầu vào khóa. Ví dụ tên khóa học không lưu trong CLASS (CLASS → CourseId → "
        "CourseName), tên chi nhánh không lưu trong STUDENT. Mọi PTH có vế trái là siêu khóa (kể cả khóa dự tuyển như "
        "BranchName, (BranchId, RoomName), (StudentId, ClassId), SerialNumber) nên lược đồ đạt **BCNF**.",
    ])
    r.p("Một số thuộc tính **dư thừa có kiểm soát** được giữ lại vì lý do nghiệp vụ và hiệu năng, kèm cơ chế bảo đảm nhất quán:")
    r.table(["Thuộc tính", "Vì sao giữ lại", "Cơ chế bảo đảm nhất quán"], [
        ["ENROLLMENT.AmountPaid", "Truy vấn công nợ rất thường xuyên, tránh SUM trên RECEIPT mỗi lần", "Trigger trg_RECEIPT_UpdateAmountPaid + CHECK AmountPaid ≤ TuitionDue"],
        ["ENROLLMENT.BaseTuition", "Học phí lớp có thể thay đổi sau này; lượt ghi danh phải giữ giá tại thời điểm đăng ký", "Ghi nhận một lần trong usp_Enrollment_Create (dữ liệu lịch sử, không phải dư thừa)"],
        ["TuitionDue, OverallScore, TotalPay", "Công thức cố định trong cùng dòng", "Cột tính toán PERSISTED - DBMS tự tính"],
        ["CLASS.BranchId", "Lớp phải gắn chi nhánh để phân mảnh dữ liệu theo chi nhánh (Chương 7)", "Trigger trg_CLASS_CheckRoom: phòng phải cùng chi nhánh"],
        ["ENROLLMENT.FinalGrade, Result", "Chốt kết quả cuối khóa, không đổi khi sửa trọng số về sau", "Chỉ ghi bởi usp_Class_EvaluateResults; khóa sửa điểm sau khi lớp kết thúc"],
    ], widths_cm=[3.4, 6.4, 6.2], caption="Thuộc tính dư thừa có kiểm soát", size=9.5)

    # ------------------------------------------------------------------ 3.7
    r.h2("3.7. Ràng buộc toàn vẹn")
    r.p("Ràng buộc toàn vẹn (RBTV) được phân loại theo bài giảng và cài đặt bằng công cụ phù hợp nhất: ràng buộc "
        "khai báo (CHECK, FK, UNIQUE) khi đủ khả năng diễn đạt, trigger khi ràng buộc liên quan nhiều dòng/nhiều bảng, "
        "thủ tục khi ràng buộc gắn với một thao tác nghiệp vụ.")
    r.table(["Loại RBTV", "Ví dụ trong đồ án", "Cài đặt"], [
        ["Miền giá trị", "0 ≤ Score ≤ 10; Capacity 1..100; Gender ∈ {Male, Female, Other}; SĐT 9-11 chữ số; Level ∈ {A1..C2}",
         f"CHECK ({object_counts()['SoCheck']} ràng buộc)"],
        ["Liên thuộc tính một quan hệ", "Dưới 18 tuổi phải có phụ huynh; EndTime > StartTime; giáo viên bản ngữ ≠ quốc tịch Việt Nam; "
         "DiscountAmount ≤ BaseTuition; khuyến mãi % ≤ 50", "CHECK nhiều cột"],
        ["Liên bộ một quan hệ", "Không trùng SĐT/email học viên; không trùng (StudentId, ClassId); mỗi GV một bảng lương/tháng; "
         "hai lớp không trùng phòng/giờ", "UNIQUE, filtered unique index, trigger CLASS_SCHEDULE"],
        ["Khóa chính, khóa ngoại", f"{object_counts()['SoPK']} khóa chính, {object_counts()['SoFK']} khóa ngoại; xóa lan truyền "
         "CLASS_SCHEDULE, CLASS_SESSION, ATTENDANCE", "PRIMARY KEY, FOREIGN KEY"],
        ["Liên thuộc tính nhiều quan hệ", "Phòng của lớp cùng chi nhánh; MaxStudents ≤ Capacity; cột điểm thuộc đúng khóa học; "
         "học viên điểm danh thuộc lớp của buổi", "Trigger"],
        ["Liên bộ nhiều quan hệ", "AmountPaid = Σ RECEIPT.Amount hợp lệ; sĩ số ≤ MaxStudents; chỉ cấp chứng nhận khi Đạt; "
         "Σ Weight của khóa = 100%", "Trigger, thủ tục + view kiểm tra"],
        ["Do chu trình / nghiệp vụ thời gian", "Ghi danh cần khóa tiên quyết hoặc điểm đầu vào; buổi đã dạy không được sửa; "
         "không sửa điểm khi lớp đã kết thúc", "Thủ tục, trigger"],
    ], widths_cm=[3.4, 8.8, 3.8], caption="Phân loại ràng buộc toàn vẹn", size=9.5)

    r.h3("3.7.1. RBTV liên bộ nhiều quan hệ: số tiền đã đóng")
    r.p("**Nội dung**: ∀ g ∈ ENROLLMENT: g.AmountPaid = Σ{p.Amount | p ∈ RECEIPT, p.EnrollmentId = g.EnrollmentId, p.Status = 'Valid'} "
        "và g.AmountPaid ≤ g.TuitionDue.")
    r.p("**Bối cảnh**: ENROLLMENT, RECEIPT. **Bảng tầm ảnh hưởng** (+: có thể vi phạm, -: không vi phạm):")
    r.table(["Quan hệ", "Thêm", "Xóa", "Sửa"], [
        ["ENROLLMENT", "- (AmountPaid mặc định 0)", "- (có FK từ RECEIPT)", "+ (AmountPaid, BaseTuition, DiscountAmount)"],
        ["RECEIPT", "+", "+ (chặn bằng INSTEAD OF DELETE)", "+ (Amount, Status, EnrollmentId)"],
    ], widths_cm=[3.0, 3.6, 4.6, 4.8], caption="Bảng tầm ảnh hưởng của RBTV số tiền đã đóng", size=10,
        align=["left", "center", "center", "center"])
    r.p("**Cài đặt**: trigger `trg_RECEIPT_UpdateAmountPaid` (AFTER INSERT, UPDATE) tính lại AmountPaid cho mọi EnrollmentId có "
        "trong `inserted` ∪ `deleted` và ROLLBACK nếu vượt học phí; `trg_RECEIPT_PreventDelete` (INSTEAD OF DELETE) chặn xóa; "
        "CHECK `CK_ENROLLMENT_AmountPaid` chặn sửa trực tiếp sai lệch. Mã nguồn trình bày ở mục 4.6.")

    r.h3("3.7.2. RBTV liên bộ: không trùng lịch phòng và giáo viên")
    r.p("**Nội dung**: với hai lớp l1 ≠ l2 đang tuyển sinh/đang học, có khoảng thời gian học giao nhau, nếu tồn tại "
        "hai dòng lịch cùng thứ có giờ chồng lấn thì l1.RoomId ≠ l2.RoomId và l1.TeacherId ≠ l2.TeacherId.")
    r.table(["Quan hệ", "Thêm", "Xóa", "Sửa"], [
        ["CLASS_SCHEDULE", "+", "-", "+ (Weekday, StartTime, EndTime)"],
        ["CLASS", "- (lớp mới chưa có lịch)", "-", "+ (RoomId, TeacherId, ngày, Status)"],
    ], widths_cm=[3.0, 4.2, 2.6, 6.2], caption="Bảng tầm ảnh hưởng của RBTV trùng lịch", size=10,
        align=["left", "center", "center", "center"])
    r.p("**Cài đặt**: trigger `trg_CLASS_SCHEDULE_CheckConflict`; với học viên, thủ tục `usp_Enrollment_Create` kiểm tra học viên "
        "không học hai lớp trùng giờ. Trường hợp sửa CLASS được kiểm soát qua thủ tục nghiệp vụ (ứng dụng không cập "
        "nhật bảng trực tiếp).")

    r.h3("3.7.3. RBTV tổng trọng số cột điểm bằng 100%")
    r.p("SQL Server không hỗ trợ ràng buộc trì hoãn (deferred constraint) như chuẩn SQL, nên nếu kiểm tra bằng trigger "
        "thì không thể thêm lần lượt từng cột điểm. Nhóm chọn cách: view `vw_CourseInvalidWeights` liệt kê khóa học "
        "sai trọng số và thủ tục `usp_Class_EvaluateResults` từ chối xét kết quả nếu khóa học còn trong view này - kiểm tra "
        "đúng tại thời điểm ràng buộc có ý nghĩa nghiệp vụ.")

    # ------------------------------------------------------------------ 3.8
    r.h2("3.8. Mô hình XML trong CSDL")
    r.p("Theo Chương 2 của môn học (mô hình dữ liệu có cấu trúc và XML), hai loại dữ liệu bán cấu trúc được lưu bằng "
        "kiểu `XML` của SQL Server thay vì tách nhiều bảng:")
    r.bullets([
        "**Đề cương khóa học** (`COURSE.SyllabusXml`) là **XML có kiểu**: ràng buộc bởi XML Schema Collection "
        "`xsc_CourseSyllabus` (giáo trình, mục tiêu, các Unit với số buổi và kỹ năng). SQL Server từ chối tài liệu sai cấu trúc.",
        "**Hồ sơ năng lực giáo viên** (`TEACHER.ProfileXml`) là **XML không kiểu**: mỗi giáo viên có số lượng chứng chỉ, "
        "điểm, kinh nghiệm khác nhau; cấu trúc linh hoạt.",
        "**Nhật ký kiểm toán** lưu ảnh dữ liệu cũ/mới dạng XML (FOR XML PATH) để một bảng nhật ký dùng chung cho nhiều bảng.",
    ])
    r.code("XML Schema Collection - cấu trúc đề cương khóa học (01_tables.sql)",
           sql_block(SQL, "01_tables.sql", "CREATE XML SCHEMA COLLECTION", "GO\n\n/* ----"))
    r.code("Ví dụ tài liệu XML đề cương khóa IE-55 (07_seed_data.sql)",
           """<Syllabus>
  <Textbook Author="Cambridge University Press" Year="2023">Cambridge IELTS 18</Textbook>
  <Objective>Reach band 5.5 - 6.0 and master the strategy for every question type</Objective>
  <Unit No="1" Sessions="6"><Title>Listening Section 1-4</Title><Skill>Listening</Skill></Unit>
  <Unit No="3" Sessions="6"><Title>Writing Task 1: Charts</Title><Skill>Writing</Skill></Unit>
  ...
</Syllabus>""", lang="xml")
    r.table(["Tiêu chí", "Mô hình quan hệ (tách bảng)", "Mô hình XML (cột XML)"], [
        ["Cấu trúc", "Cố định, mọi dòng cùng cột", "Linh hoạt, phân cấp, số phần tử thay đổi"],
        ["Ràng buộc", "PK, FK, CHECK mạnh", "XSD kiểm tra cấu trúc/kiểu; không có FK tới phần tử XML"],
        ["Truy vấn", "SQL, phép kết, chỉ mục B-tree", "XPath/XQuery (.value, .query, .nodes, .exist), XML index"],
        ["Phù hợp", "Dữ liệu giao dịch: ghi danh, phiếu thu, điểm", "Hồ sơ, tài liệu mô tả, nhật ký, trao đổi dữ liệu"],
        ["Trong đồ án", "19 bảng nghiệp vụ", "Đề cương, hồ sơ giáo viên, nhật ký, xuất/nhập học viên"],
    ], widths_cm=[2.8, 6.2, 7.0], caption="So sánh mô hình quan hệ và mô hình XML", size=10)
