"""Chương 3 - Thiết kế cơ sở dữ liệu."""
import re

from noidung.chung import IMG, SQL, schema
from report_lib import sql_block

# Ý nghĩa các cột (dùng cho từ điển dữ liệu)
MO_TA = {
    "MaCN": "Mã chi nhánh", "TenCN": "Tên chi nhánh", "DiaChi": "Địa chỉ", "SoDienThoai": "Số điện thoại",
    "Email": "Địa chỉ email", "NgayThanhLap": "Ngày thành lập", "MaPhong": "Mã phòng học", "TenPhong": "Tên phòng",
    "SucChua": "Sức chứa tối đa (người)", "LoaiPhong": "Loại phòng", "MaNV": "Mã nhân viên", "HoTen": "Họ và tên",
    "NgaySinh": "Ngày sinh", "GioiTinh": "Giới tính", "ChucVu": "Chức vụ", "NgayVaoLam": "Ngày vào làm",
    "LuongCoBan": "Lương cơ bản (VNĐ/tháng)", "MaGV": "Mã giáo viên", "QuocTich": "Quốc tịch",
    "TrinhDo": "Trình độ học vấn", "LoaiGV": "Giáo viên Việt Nam / bản ngữ", "DonGiaGio": "Đơn giá một giờ dạy (VNĐ)",
    "HoSoXML": "Hồ sơ năng lực dạng XML (chứng chỉ, kinh nghiệm, chuyên môn)",
    "TenDangNhap": "Tên đăng nhập = tên USER trong SQL Server", "VaiTro": "Vai trò trong ứng dụng",
    "NgayTao": "Thời điểm tạo", "LanDangNhapCuoi": "Lần đăng nhập gần nhất", "MaHV": "Mã học viên",
    "NgheNghiep": "Nghề nghiệp", "TenPhuHuynh": "Họ tên phụ huynh", "SDTPhuHuynh": "SĐT phụ huynh",
    "NgayDangKy": "Ngày đăng ký hồ sơ", "GhiChu": "Ghi chú", "MaCT": "Mã chương trình", "TenCT": "Tên chương trình",
    "DoiTuong": "Đối tượng học viên", "MoTa": "Mô tả", "MaKH": "Mã khóa học", "TenKH": "Tên khóa học",
    "CapDo": "Cấp độ theo khung CEFR", "SoBuoi": "Số buổi", "ThoiLuongBuoi": "Thời lượng mỗi buổi (phút)",
    "HocPhi": "Học phí (VNĐ)", "DiemDauVaoToiThieu": "Điểm kiểm tra đầu vào tối thiểu",
    "MaKHTienQuyet": "Khóa học tiên quyết (tự tham chiếu)", "NoiDungXML": "Đề cương khóa học - XML có kiểu (XSD)",
    "MaTP": "Mã thành phần điểm", "TenTP": "Tên cột điểm", "TrongSo": "Trọng số (%)", "MaLop": "Mã lớp",
    "TenLop": "Tên lớp", "NgayKhaiGiang": "Ngày khai giảng", "NgayKetThuc": "Ngày kết thúc (buổi cuối)",
    "SiSoToiDa": "Sĩ số tối đa", "Thu": "Thứ trong tuần (2..7, 8 = Chủ nhật)", "GioBatDau": "Giờ bắt đầu",
    "GioKetThuc": "Giờ kết thúc", "MaBuoi": "Mã buổi học", "STT": "Buổi thứ", "NgayHoc": "Ngày học",
    "NoiDung": "Nội dung", "MaKM": "Mã khuyến mãi", "TenKM": "Tên khuyến mãi", "LoaiGiam": "Phần trăm / số tiền",
    "GiaTri": "Giá trị giảm", "NgayBatDau": "Ngày bắt đầu", "MaGD": "Mã lượt ghi danh", "NgayGhiDanh": "Ngày ghi danh",
    "HocPhiGoc": "Học phí của lớp tại thời điểm ghi danh", "SoTienGiam": "Số tiền được giảm",
    "HocPhiPhaiDong": "Học phí phải đóng (cột tính toán)", "DaDong": "Tổng tiền đã đóng (dẫn xuất, trigger duy trì)",
    "DiemTongKet": "Điểm tổng kết", "KetQua": "Kết quả cuối khóa", "MaNVGhiDanh": "Nhân viên thực hiện ghi danh",
    "MaPT": "Mã phiếu thu", "NgayThu": "Thời điểm thu", "SoTien": "Số tiền thu", "HinhThuc": "Hình thức thanh toán",
    "MaNVThu": "Nhân viên thu tiền", "LyDoHuy": "Lý do hủy phiếu", "Diem": "Điểm (thang 10)",
    "NgayNhap": "Thời điểm nhập điểm", "NguoiNhap": "Người nhập điểm", "MaKT": "Mã bài kiểm tra",
    "NgayKiemTra": "Ngày kiểm tra", "DiemNghe": "Điểm Nghe", "DiemNoi": "Điểm Nói", "DiemDoc": "Điểm Đọc",
    "DiemViet": "Điểm Viết", "DiemTong": "Điểm trung bình 4 kỹ năng (cột tính toán)",
    "MaKHDeXuat": "Khóa học được đề xuất (trigger)", "MaGVCham": "Giáo viên chấm", "MaCC": "Mã chứng nhận",
    "SoHieu": "Số hiệu chứng nhận", "NgayCap": "Ngày cấp", "XepLoai": "Xếp loại", "MaBL": "Mã bảng lương",
    "Thang": "Tháng", "Nam": "Năm", "SoGio": "Số giờ đã dạy", "Thuong": "Thưởng", "KhauTru": "Khấu trừ",
    "TongLuong": "Tổng lương (cột tính toán)", "NgayChot": "Thời điểm chốt", "MaNK": "Mã nhật ký",
    "ThoiGian": "Thời điểm thao tác", "NguoiThucHien": "Người thực hiện (ORIGINAL_LOGIN)",
    "BangDuLieu": "Bảng bị tác động", "HanhDong": "INSERT / UPDATE / DELETE", "KhoaChinh": "Khóa của dòng bị tác động",
    "DuLieuCu": "Dữ liệu trước khi thay đổi (XML)", "DuLieuMoi": "Dữ liệu sau khi thay đổi (XML)",
    "TrangThai": "Trạng thái",
}

TAN_TU = {
    "CHINHANH": "Mỗi chi nhánh có mã duy nhất, tên không trùng, địa chỉ, số điện thoại, email, ngày thành lập và trạng thái hoạt động.",
    "PHONGHOC": "Mỗi phòng học thuộc đúng một chi nhánh, có tên (không trùng trong cùng chi nhánh), sức chứa và loại phòng.",
    "NHANVIEN": "Mỗi nhân viên văn phòng làm việc tại một chi nhánh với một chức vụ (quản lý, giáo vụ, kế toán, tư vấn).",
    "GIAOVIEN": "Mỗi giáo viên thuộc một chi nhánh quản lý, có trình độ, loại (Việt Nam/bản ngữ), đơn giá giờ dạy và hồ sơ năng lực XML.",
    "TAIKHOAN": "Mỗi tài khoản đăng nhập ứng với đúng một nhân viên hoặc một giáo viên và có một vai trò.",
    "HOCVIEN": "Mỗi học viên được tiếp nhận tại một chi nhánh; học viên dưới 18 tuổi phải có thông tin phụ huynh.",
    "CHUONGTRINH": "Chương trình đào tạo (IELTS, TOEIC, Giao tiếp, Thiếu nhi) gồm nhiều khóa học.",
    "KHOAHOC": "Mỗi khóa học thuộc một chương trình, có cấp độ, số buổi, học phí, điều kiện đầu vào, có thể có một khóa tiên quyết.",
    "THANHPHANDIEM": "Mỗi khóa học có các cột điểm với trọng số, tổng trọng số bằng 100%.",
    "LOPHOC": "Mỗi lớp là một đợt mở của khóa học tại một chi nhánh, do một giáo viên phụ trách, học tại một phòng.",
    "LICHHOC": "Mỗi lớp học vào một số thứ trong tuần, mỗi thứ có giờ bắt đầu - kết thúc (thực thể yếu của LOPHOC).",
    "BUOIHOC": "Mỗi buổi học thuộc một lớp, có số thứ tự, ngày, giờ, phòng, giáo viên dạy thực tế và trạng thái.",
    "KHUYENMAI": "Mỗi khuyến mãi giảm theo phần trăm (tối đa 50%) hoặc số tiền, có thời gian hiệu lực.",
    "GHIDANH": "Mỗi lượt ghi danh là việc một học viên học một lớp, lưu học phí, khuyến mãi, số tiền đã đóng và kết quả.",
    "PHIEUTHU": "Mỗi phiếu thu ghi nhận một lần đóng tiền cho một lượt ghi danh do một nhân viên lập; chỉ được hủy, không được xóa.",
    "DIEMDANH": "Mỗi lượt ghi danh được điểm danh tại các buổi học của lớp với một trạng thái.",
    "DIEM": "Mỗi lượt ghi danh có một điểm cho mỗi cột điểm của khóa học.",
    "KIEMTRADAUVAO": "Mỗi bài kiểm tra đầu vào của học viên có điểm 4 kỹ năng, điểm tổng và khóa học được đề xuất.",
    "CHUNGCHI": "Mỗi lượt ghi danh đạt yêu cầu được cấp tối đa một chứng nhận có số hiệu duy nhất.",
    "BANGLUONG": "Mỗi giáo viên có tối đa một bảng lương cho mỗi tháng, tính từ số giờ đã dạy.",
    "NHATKYHETHONG": "Mỗi dòng nhật ký ghi một thao tác thay đổi dữ liệu nhạy cảm (điểm, phiếu thu), chỉ được ghi thêm.",
}

THU_TU_BANG = ["CHINHANH", "PHONGHOC", "NHANVIEN", "GIAOVIEN", "TAIKHOAN", "HOCVIEN", "CHUONGTRINH", "KHOAHOC",
               "THANHPHANDIEM", "LOPHOC", "LICHHOC", "BUOIHOC", "KHUYENMAI", "GHIDANH", "PHIEUTHU", "DIEMDANH",
               "DIEM", "KIEMTRADAUVAO", "CHUNGCHI", "BANGLUONG", "NHATKYHETHONG"]


def _dep_check(defn: str) -> str:
    """Rút gọn định nghĩa CHECK cho dễ đọc."""
    vals = re.findall(r"\[(\w+)\]=N?'([^']*)'", defn)
    rest = re.sub(r"\[(\w+)\]=N?'([^']*)'", "", defn)
    if vals and re.fullmatch(r"[\s()OR]*", rest):
        col = vals[0][0]
        return f"{col} ∈ {{{', '.join(v for _, v in reversed(vals))}}}"
    s = defn.strip()
    while s.startswith("(") and s.endswith(")"):
        s = s[1:-1]
    s = re.sub(r"\[(\w+)\]", r"\1", s).replace("N'", "'")
    s = re.sub(r"\((\d+)\)", r"\1", s)
    return s


def _cot_cua_check(defn: str):
    return set(re.findall(r"\[(\w+)\]", defn))


def tu_dien(r):
    sc = {t["bang"]: t for t in schema()}
    for ten in THU_TU_BANG:
        t = sc[ten]
        checks = t.get("check_") or []
        check_cot, check_bang = {}, []
        for ck in checks:
            cols = _cot_cua_check(ck["dinh_nghia"])
            if len(cols) == 1:
                check_cot.setdefault(next(iter(cols)), []).append(_dep_check(ck["dinh_nghia"]))
            else:
                check_bang.append((ck["ten"], _dep_check(ck["dinh_nghia"])))
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
                rb.append("Tính toán: " + _dep_check(c["cong_thuc"]))
            if c.get("mac_dinh"):
                md = _dep_check(c["mac_dinh"])
                rb.append("Mặc định: " + ("sinh từ SEQUENCE" if "NEXT VALUE" in md.upper() else md))
            rb += check_cot.get(c["cot"], [])
            rows.append([c["cot"], c["kieu"].upper(), "" if c["cho_null"] else "Không",
                         "\n".join(rb), MO_TA.get(c["cot"], "")])
        r.table(["Tên cột", "Kiểu dữ liệu", "NULL", "Ràng buộc", "Ý nghĩa"], rows,
                widths_cm=[3.0, 2.9, 1.3, 4.8, 4.0], caption=f"Từ điển dữ liệu bảng {ten}", size=9)
        if check_bang:
            r.p("Ràng buộc liên thuộc tính của bảng " + ten + ": " +
                "; ".join(f"`{n}`: {d}" for n, d in check_bang) + ".", indent=False)


def chuong3(r):
    r.h1("CHƯƠNG 3: THIẾT KẾ CƠ SỞ DỮ LIỆU")

    # ------------------------------------------------------------------ 3.1
    r.h2("3.1. Mô hình quan niệm - sơ đồ thực thể kết hợp (ERD)")
    r.p("Mô hình quan niệm được vẽ theo ký hiệu Chen như bài giảng: **hình chữ nhật** là thực thể (thuộc tính khóa "
        "gạch dưới), **hình thoi** là mối kết hợp, bản số **(min,max)** ghi cạnh thực thể tham gia. Do có 21 thực thể, "
        "sơ đồ được tách thành 2 phân hệ dùng chung một số thực thể (tô xám ở sơ đồ thứ hai).")
    r.figure(IMG / "diagrams" / "erd_1_to_chuc_dao_tao.png", "ERD phân hệ tổ chức - nhân sự - đào tạo - lớp học", width_cm=16.5)
    r.figure(IMG / "diagrams" / "erd_2_hoc_vien_tai_chinh.png", "ERD phân hệ học viên - ghi danh - tài chính - kết quả", width_cm=16.5)
    r.p("Một số điểm thiết kế đáng chú ý:")
    r.bullets([
        "**GHIDANH là thực thể kết hợp** giữa HOCVIEN và LOPHOC (quan hệ n-n), được nâng thành thực thể vì bản thân nó "
        "tham gia các mối kết hợp khác: đóng tiền (PHIEUTHU), điểm danh, điểm, chứng nhận.",
        "**DIEMDANH và DIEM là mối kết hợp n-n có thuộc tính** (GHIDANH-BUOIHOC với TrangThai, "
        "GHIDANH-THANHPHANDIEM với Diem), khi chuyển sang mô hình quan hệ sẽ thành bảng riêng.",
        "**Mối kết hợp đệ quy** *tiên quyết* trên KHOAHOC: một khóa có tối đa một khóa tiên quyết (0,1) và có thể là "
        "tiên quyết của nhiều khóa (0,n), tạo thành lộ trình IELTS Foundation → 5.5 → 6.5.",
        "**LICHHOC là thực thể yếu** của LOPHOC (khóa = MaLop + Thu), xóa lớp thì xóa lịch theo (ON DELETE CASCADE).",
        "**Thuộc tính dẫn xuất** (ký hiệu /): DiemTong, HocPhiPhaiDong, DaDong, TongLuong - được lưu và duy trì tự động "
        "để truy vấn nhanh (cột tính toán hoặc trigger).",
        "**Thuộc tính phức hợp, đa trị** (chứng chỉ của giáo viên, các Unit của đề cương) được lưu dạng XML thay vì "
        "tách nhiều bảng phụ - minh họa mô hình dữ liệu bán cấu trúc của Chương 2.",
    ])
    r.table(["Mối kết hợp", "Thực thể (bản số)", "Ý nghĩa"], [
        ["có", "CHINHANH (1,n) - PHONGHOC (1,1)", "Mỗi phòng thuộc đúng một chi nhánh, chi nhánh có ít nhất một phòng"],
        ["gồm", "CHUONGTRINH (1,n) - KHOAHOC (1,1)", "Khóa học thuộc một chương trình"],
        ["tiên quyết", "KHOAHOC (0,1) - KHOAHOC (0,n)", "Đệ quy: khóa học cần hoàn thành khóa khác trước"],
        ["mở thành", "KHOAHOC (0,n) - LOPHOC (1,1)", "Mỗi lớp là một đợt mở của một khóa học"],
        ["phụ trách", "GIAOVIEN (0,n) - LOPHOC (1,1)", "Mỗi lớp có một giáo viên chính"],
        ["gồm buổi / dạy", "LOPHOC (0,n) - BUOIHOC (1,1); GIAOVIEN (0,n) - BUOIHOC (1,1)", "Buổi học có giáo viên dạy thực tế (có thể dạy thay)"],
        ["đăng ký / có học viên", "HOCVIEN (0,n) - GHIDANH (1,1) - LOPHOC (0,n)", "Quan hệ n-n học viên - lớp qua thực thể kết hợp"],
        ["đóng tiền", "GHIDANH (0,n) - PHIEUTHU (1,1)", "Một lượt ghi danh đóng nhiều đợt"],
        ["DIEMDANH", "GHIDANH (0,n) - BUOIHOC (0,n)", "n-n có thuộc tính TrangThai"],
        ["DIEM", "GHIDANH (0,n) - THANHPHANDIEM (0,n)", "n-n có thuộc tính Diem"],
        ["được cấp", "GHIDANH (0,1) - CHUNGCHI (1,1)", "1-1: mỗi lượt ghi danh đạt có tối đa một chứng nhận"],
        ["đăng nhập", "TAIKHOAN (0,1) - NHANVIEN/GIAOVIEN (0,1)", "Mỗi người có tối đa một tài khoản"],
    ], widths_cm=[3.0, 6.4, 6.6], caption="Các mối kết hợp chính và bản số", size=9.5)

    # ------------------------------------------------------------------ 3.2
    r.h2("3.2. Mô hình quan niệm hướng đối tượng - sơ đồ lớp (CD)")
    r.p("Ngoài ERD, bài giảng giới thiệu mô hình CD (UML Class Diagram) ở mức quan niệm. Sơ đồ CD của hệ thống "
        "thể hiện thêm những gì ERD không diễn đạt được: **tổng quát hóa** (lớp trừu tượng NGUOI là cha của HOCVIEN, "
        "GIAOVIEN, NHANVIEN với các thuộc tính chung họ tên, ngày sinh, giới tính, liên lạc), **phương thức** của "
        "lớp (ghiDanh, thuHocPhi, xetKetQua...), quan hệ **thành phần** (BUOIHOC là thành phần của LOPHOC), "
        "**kết tập** (PHIEUTHU thuộc GHIDANH) và thuộc tính kiểu tập hợp `set(...)`, bộ `tuple(...)`.")
    r.figure(IMG / "diagrams" / "cd_lop.png", "Sơ đồ lớp (CD) của hệ thống QLTTTA", width_cm=15.5)
    r.p("Khi cài đặt trên hệ quản trị quan hệ, lớp trừu tượng NGUOI được hiện thực theo chiến lược **mỗi lớp con một "
        "bảng** (HOCVIEN, GIAOVIEN, NHANVIEN lặp lại các cột chung) vì ba đối tượng có vòng đời, khóa và quyền truy cập "
        "khác nhau; các phương thức được hiện thực thành thủ tục/hàm trong CSDL và use case trong ứng dụng.")

    # ------------------------------------------------------------------ 3.3
    r.h2("3.3. Chuyển đổi ERD sang mô hình quan hệ")
    r.p("Áp dụng các quy tắc chuyển đổi theo bản số của mối kết hợp:")
    r.table(["Trường hợp", "Quy tắc", "Áp dụng trong đồ án"], [
        ["Thực thể mạnh", "Mỗi thực thể thành một quan hệ, thuộc tính khóa thành khóa chính",
         "CHINHANH, HOCVIEN, KHOAHOC, LOPHOC..."],
        ["(1,1) - (1,n) / (0,n)", "Đưa khóa chính bên nhiều vào làm khóa ngoại ở bên (1,1)",
         "LOPHOC(MaKH, MaCN, MaGV, MaPhong), PHIEUTHU(MaGD, MaNVThu)"],
        ["(0,1) - (0,n) đệ quy", "Khóa ngoại cho phép NULL tham chiếu chính quan hệ đó",
         "KHOAHOC(MaKHTienQuyet) → KHOAHOC"],
        ["(0,1) - (1,1)", "Khóa ngoại đặt ở bên (1,1), thêm UNIQUE để giữ tính 1-1",
         "CHUNGCHI(MaGD UNIQUE); TAIKHOAN(MaNV/MaGV + filtered unique index)"],
        ["(n) - (n) có thuộc tính", "Tạo quan hệ mới, khóa = tổ hợp khóa hai bên, kèm thuộc tính của mối kết hợp",
         "DIEMDANH(__MaBuoi, MaGD__, TrangThai), DIEM(__MaGD, MaTP__, Diem)"],
        ["Thực thể kết hợp", "Quan hệ có khóa riêng (surrogate) + UNIQUE trên cặp khóa ngoại",
         "GHIDANH(__MaGD__, MaHV, MaLop, ...) với UNIQUE(MaHV, MaLop)"],
        ["Thực thể yếu", "Khóa = khóa của thực thể chủ + khóa riêng phần, xóa lan truyền",
         "LICHHOC(__MaLop, Thu__, ...) ON DELETE CASCADE"],
        ["Thuộc tính đa trị/phức hợp", "Tách bảng riêng hoặc lưu XML (mô hình bán cấu trúc)",
         "THANHPHANDIEM (bảng riêng), HoSoXML, NoiDungXML (XML)"],
    ], widths_cm=[3.2, 6.2, 6.6], caption="Quy tắc chuyển đổi ERD sang mô hình quan hệ", size=9.5)

    # ------------------------------------------------------------------ 3.4
    r.h2("3.4. Lược đồ quan hệ")
    r.p("Lược đồ CSDL QLTTTA gồm 21 quan hệ (khóa chính gạch dưới). Mỗi quan hệ kèm tân từ mô tả ngữ nghĩa:")
    sc = {t["bang"]: t for t in schema()}
    for i, ten in enumerate(THU_TU_BANG, 1):
        cols = []
        for c in sc[ten]["cot"]:
            ten_cot = c["cot"]
            if c.get("tinh_toan"):
                ten_cot = "/" + ten_cot
            cols.append(f"__{ten_cot}__" if c.get("khoa_chinh") else ten_cot)
        r.p(f"**{i}. {ten}** (" + ", ".join(cols) + ")", indent=False, after=20)
        r.p(f"*Tân từ:* {TAN_TU[ten]}", indent=True, after=100)

    # ------------------------------------------------------------------ 3.5
    r.h2("3.5. Từ điển dữ liệu")
    r.p("Từ điển dữ liệu dưới đây được **trích xuất tự động từ CSDL đã cài đặt** (sys.columns, sys.check_constraints, "
        "sys.foreign_keys...) nên luôn khớp với script `01_tables.sql`. Quy ước đặt tên: bảng viết hoa không dấu, cột "
        "PascalCase; ràng buộc `PK_<BANG>`, `FK_<CON>_<CHA>`, `CK_<BANG>_<Cot>`, `UQ_...`, `DF_...`. Mã nghiệp vụ "
        "(HV00001, LH0001, GD000001...) được sinh bởi **SEQUENCE** trong ràng buộc DEFAULT.")
    tu_dien(r)

    # ------------------------------------------------------------------ 3.6
    r.h2("3.6. Chuẩn hóa lược đồ")
    r.p("Kiểm tra các dạng chuẩn dựa trên phụ thuộc hàm (PTH) của từng quan hệ:")
    r.bullets([
        "**1NF**: mọi thuộc tính đều nguyên tố. Các dữ liệu đa trị (lịch học nhiều buổi/tuần, cột điểm, điểm danh) "
        "đã được tách thành LICHHOC, THANHPHANDIEM, DIEMDANH. Riêng HoSoXML và NoiDungXML là kiểu XML được SQL Server "
        "xem như một giá trị; chỉ dùng để lưu/tra cứu hồ sơ, không tham gia khóa hay phép kết.",
        "**2NF**: các quan hệ có khóa ghép (LICHHOC, DIEMDANH, DIEM) không có thuộc tính nào phụ thuộc vào một phần "
        "khóa. Ví dụ DIEM: (MaGD, MaTP) → Diem; tên cột điểm TenTP phụ thuộc MaTP nên nằm ở THANHPHANDIEM chứ không ở DIEM.",
        "**3NF/BCNF**: không có phụ thuộc bắc cầu vào khóa. Ví dụ tên khóa học không lưu trong LOPHOC (LOPHOC → MaKH → "
        "TenKH), tên chi nhánh không lưu trong HOCVIEN. Mọi PTH có vế trái là siêu khóa (kể cả khóa dự tuyển như "
        "TenCN, (MaCN, TenPhong), (MaHV, MaLop), SoHieu) nên lược đồ đạt **BCNF**.",
    ])
    r.p("Một số thuộc tính **dư thừa có kiểm soát** được giữ lại vì lý do nghiệp vụ và hiệu năng, kèm cơ chế bảo đảm nhất quán:")
    r.table(["Thuộc tính", "Vì sao giữ lại", "Cơ chế bảo đảm nhất quán"], [
        ["GHIDANH.DaDong", "Truy vấn công nợ rất thường xuyên, tránh SUM trên PHIEUTHU mỗi lần", "Trigger trg_PHIEUTHU_CapNhatDaDong + CHECK DaDong ≤ HocPhiPhaiDong"],
        ["GHIDANH.HocPhiGoc", "Học phí lớp có thể thay đổi sau này; lượt ghi danh phải giữ giá tại thời điểm đăng ký", "Ghi nhận một lần trong usp_GhiDanh (dữ liệu lịch sử, không phải dư thừa)"],
        ["HocPhiPhaiDong, DiemTong, TongLuong", "Công thức cố định trong cùng dòng", "Cột tính toán PERSISTED - DBMS tự tính"],
        ["LOPHOC.MaCN", "Lớp phải gắn chi nhánh để phân mảnh dữ liệu theo chi nhánh (Chương 7)", "Trigger trg_LOPHOC_KiemTraPhong: phòng phải cùng chi nhánh"],
        ["GHIDANH.DiemTongKet, KetQua", "Chốt kết quả cuối khóa, không đổi khi sửa trọng số về sau", "Chỉ ghi bởi usp_LopHoc_XetKetQua; khóa sửa điểm sau khi lớp kết thúc"],
    ], widths_cm=[3.4, 6.4, 6.2], caption="Thuộc tính dư thừa có kiểm soát", size=9.5)

    # ------------------------------------------------------------------ 3.7
    r.h2("3.7. Ràng buộc toàn vẹn")
    r.p("Ràng buộc toàn vẹn (RBTV) được phân loại theo bài giảng và cài đặt bằng công cụ phù hợp nhất: ràng buộc "
        "khai báo (CHECK, FK, UNIQUE) khi đủ khả năng diễn đạt, trigger khi ràng buộc liên quan nhiều dòng/nhiều bảng, "
        "thủ tục khi ràng buộc gắn với một thao tác nghiệp vụ.")
    r.table(["Loại RBTV", "Ví dụ trong đồ án", "Cài đặt"], [
        ["Miền giá trị", "0 ≤ Diem ≤ 10; SucChua 1..100; GioiTinh ∈ {Nam, Nữ, Khác}; SĐT 9-11 chữ số; CapDo ∈ {A1..C2}", "CHECK (72 ràng buộc)"],
        ["Liên thuộc tính một quan hệ", "Dưới 18 tuổi phải có phụ huynh; GioKetThuc > GioBatDau; giáo viên bản ngữ ≠ quốc tịch Việt Nam; "
         "SoTienGiam ≤ HocPhiGoc; khuyến mãi % ≤ 50", "CHECK nhiều cột"],
        ["Liên bộ một quan hệ", "Không trùng SĐT/email học viên; không trùng (MaHV, MaLop); mỗi GV một bảng lương/tháng; "
         "hai lớp không trùng phòng/giờ", "UNIQUE, filtered unique index, trigger LICHHOC"],
        ["Khóa chính, khóa ngoại", "21 khóa chính, 32 khóa ngoại; xóa lan truyền LICHHOC, BUOIHOC, DIEMDANH", "PRIMARY KEY, FOREIGN KEY"],
        ["Liên thuộc tính nhiều quan hệ", "Phòng của lớp cùng chi nhánh; SiSoToiDa ≤ SucChua; cột điểm thuộc đúng khóa học; "
         "học viên điểm danh thuộc lớp của buổi", "Trigger"],
        ["Liên bộ nhiều quan hệ", "DaDong = Σ PHIEUTHU.SoTien hợp lệ; sĩ số ≤ SiSoToiDa; chỉ cấp chứng nhận khi Đạt; "
         "Σ TrongSo của khóa = 100%", "Trigger, thủ tục + view kiểm tra"],
        ["Do chu trình / nghiệp vụ thời gian", "Ghi danh cần khóa tiên quyết hoặc điểm đầu vào; buổi đã dạy không được sửa; "
         "không sửa điểm khi lớp đã kết thúc", "Thủ tục, trigger"],
    ], widths_cm=[3.4, 8.8, 3.8], caption="Phân loại ràng buộc toàn vẹn", size=9.5)

    r.h3("3.7.1. RBTV liên bộ nhiều quan hệ: số tiền đã đóng")
    r.p("**Nội dung**: ∀ g ∈ GHIDANH: g.DaDong = Σ{p.SoTien | p ∈ PHIEUTHU, p.MaGD = g.MaGD, p.TrangThai = 'Hợp lệ'} "
        "và g.DaDong ≤ g.HocPhiPhaiDong.")
    r.p("**Bối cảnh**: GHIDANH, PHIEUTHU. **Bảng tầm ảnh hưởng** (+: có thể vi phạm, -: không vi phạm):")
    r.table(["Quan hệ", "Thêm", "Xóa", "Sửa"], [
        ["GHIDANH", "- (DaDong mặc định 0)", "- (có FK từ PHIEUTHU)", "+ (DaDong, HocPhiGoc, SoTienGiam)"],
        ["PHIEUTHU", "+", "+ (chặn bằng INSTEAD OF DELETE)", "+ (SoTien, TrangThai, MaGD)"],
    ], widths_cm=[3.0, 3.6, 4.6, 4.8], caption="Bảng tầm ảnh hưởng của RBTV số tiền đã đóng", size=10,
        align=["left", "center", "center", "center"])
    r.p("**Cài đặt**: trigger `trg_PHIEUTHU_CapNhatDaDong` (AFTER INSERT, UPDATE) tính lại DaDong cho mọi MaGD có "
        "trong `inserted` ∪ `deleted` và ROLLBACK nếu vượt học phí; `trg_PHIEUTHU_KhongXoa` (INSTEAD OF DELETE) chặn xóa; "
        "CHECK `CK_GHIDANH_DaDong` chặn sửa trực tiếp sai lệch. Mã nguồn trình bày ở mục 4.6.")

    r.h3("3.7.2. RBTV liên bộ: không trùng lịch phòng và giáo viên")
    r.p("**Nội dung**: với hai lớp l1 ≠ l2 đang tuyển sinh/đang học, có khoảng thời gian học giao nhau, nếu tồn tại "
        "hai dòng lịch cùng thứ có giờ chồng lấn thì l1.MaPhong ≠ l2.MaPhong và l1.MaGV ≠ l2.MaGV.")
    r.table(["Quan hệ", "Thêm", "Xóa", "Sửa"], [
        ["LICHHOC", "+", "-", "+ (Thu, GioBatDau, GioKetThuc)"],
        ["LOPHOC", "- (lớp mới chưa có lịch)", "-", "+ (MaPhong, MaGV, ngày, TrangThai)"],
    ], widths_cm=[3.0, 4.2, 2.6, 6.2], caption="Bảng tầm ảnh hưởng của RBTV trùng lịch", size=10,
        align=["left", "center", "center", "center"])
    r.p("**Cài đặt**: trigger `trg_LICHHOC_KiemTraTrungLich`; với học viên, thủ tục `usp_GhiDanh` kiểm tra học viên "
        "không học hai lớp trùng giờ. Trường hợp sửa LOPHOC được kiểm soát qua thủ tục nghiệp vụ (ứng dụng không cập "
        "nhật bảng trực tiếp).")

    r.h3("3.7.3. RBTV tổng trọng số cột điểm bằng 100%")
    r.p("SQL Server không hỗ trợ ràng buộc trì hoãn (deferred constraint) như chuẩn SQL, nên nếu kiểm tra bằng trigger "
        "thì không thể thêm lần lượt từng cột điểm. Nhóm chọn cách: view `vw_KhoaHoc_TrongSoChuaHopLe` liệt kê khóa học "
        "sai trọng số và thủ tục `usp_LopHoc_XetKetQua` từ chối xét kết quả nếu khóa học còn trong view này - kiểm tra "
        "đúng tại thời điểm ràng buộc có ý nghĩa nghiệp vụ.")

    # ------------------------------------------------------------------ 3.8
    r.h2("3.8. Mô hình XML trong CSDL")
    r.p("Theo Chương 2 của môn học (mô hình dữ liệu có cấu trúc và XML), hai loại dữ liệu bán cấu trúc được lưu bằng "
        "kiểu `XML` của SQL Server thay vì tách nhiều bảng:")
    r.bullets([
        "**Đề cương khóa học** (`KHOAHOC.NoiDungXML`) là **XML có kiểu**: ràng buộc bởi XML Schema Collection "
        "`xsc_DeCuongKhoaHoc` (giáo trình, mục tiêu, các Unit với số buổi và kỹ năng). SQL Server từ chối tài liệu sai cấu trúc.",
        "**Hồ sơ năng lực giáo viên** (`GIAOVIEN.HoSoXML`) là **XML không kiểu**: mỗi giáo viên có số lượng chứng chỉ, "
        "điểm, kinh nghiệm khác nhau; cấu trúc linh hoạt.",
        "**Nhật ký kiểm toán** lưu ảnh dữ liệu cũ/mới dạng XML (FOR XML PATH) để một bảng nhật ký dùng chung cho nhiều bảng.",
    ])
    r.code("XML Schema Collection - cấu trúc đề cương khóa học (01_tables.sql)",
           sql_block(SQL, "01_tables.sql", "CREATE XML SCHEMA COLLECTION", "GO\n\n/* ----"))
    r.code("Ví dụ tài liệu XML đề cương khóa IE-55 (07_seed_data.sql)",
           """<DeCuong>
  <GiaoTrinh TacGia="Cambridge University Press" NamXB="2023">Cambridge IELTS 18</GiaoTrinh>
  <MucTieu>Đạt band 5.5 - 6.0, thành thạo chiến lược làm bài từng dạng câu hỏi</MucTieu>
  <Unit So="1" SoBuoi="6"><TenUnit>Listening Section 1-4</TenUnit><KyNang>Listening</KyNang></Unit>
  <Unit So="3" SoBuoi="6"><TenUnit>Writing Task 1: Biểu đồ</TenUnit><KyNang>Writing</KyNang></Unit>
  ...
</DeCuong>""", lang="xml")
    r.table(["Tiêu chí", "Mô hình quan hệ (tách bảng)", "Mô hình XML (cột XML)"], [
        ["Cấu trúc", "Cố định, mọi dòng cùng cột", "Linh hoạt, phân cấp, số phần tử thay đổi"],
        ["Ràng buộc", "PK, FK, CHECK mạnh", "XSD kiểm tra cấu trúc/kiểu; không có FK tới phần tử XML"],
        ["Truy vấn", "SQL, phép kết, chỉ mục B-tree", "XPath/XQuery (.value, .query, .nodes, .exist), XML index"],
        ["Phù hợp", "Dữ liệu giao dịch: ghi danh, phiếu thu, điểm", "Hồ sơ, tài liệu mô tả, nhật ký, trao đổi dữ liệu"],
        ["Trong đồ án", "19 bảng nghiệp vụ", "Đề cương, hồ sơ giáo viên, nhật ký, xuất/nhập học viên"],
    ], widths_cm=[2.8, 6.2, 7.0], caption="So sánh mô hình quan hệ và mô hình XML", size=10)
