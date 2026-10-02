"""Trang bìa, checklist, phân công, mục lục."""
from content.common import THANH_VIEN, kiem_thu


def trang_bia(r):
    # Chỉ số đoạn văn theo mẫu (template/uit_report_template.docx)
    r.set_paragraph_text(4, "BÁO CÁO ĐỒ ÁN MÔN HỌC")
    r.set_paragraph_text(5, "QUẢN LÝ THÔNG TIN")
    r.set_paragraph_text(6, "MÃ LỚP: IE103.Q21.VB2")
    r.set_paragraph_text(7, "ĐỀ TÀI: XÂY DỰNG HỆ THỐNG QUẢN LÝ TRUNG TÂM TIẾNG ANH")
    r.set_paragraph_text(8, "Giảng viên hướng dẫn: TS. Võ Phương Bình")
    r.set_paragraph_text(9, "Nhóm sinh viên thực hiện: Nhóm 1")
    r.set_paragraph_text(11, "TP. Hồ Chí Minh, tháng 11 năm 2026")
    r.fill_table(0, [[str(i + 1), tv["ten"] + (" (Nhóm trưởng)" if i == 0 else ""), tv["mssv"]]
                     for i, tv in enumerate(THANH_VIEN)])


def checklist(r):
    X = "X"
    rows = [
        ["Khảo sát hiện trạng, phân tích yêu cầu (use case, DFD)", "", "", "", X],
        ["Thiết kế CSDL: ERD, CD, mô hình quan hệ, chuẩn hóa, ràng buộc toàn vẹn", "", "", "", X],
        ["Cài đặt CSDL SQL Server và dữ liệu mẫu", "", "", "", X],
        ["Stored procedure, function, trigger, cursor, giao dịch", "", "", "", X],
        ["Truy vấn SQL, mô hình XML, XPath/XQuery", "", "", "", X],
        ["An ninh: xác thực, phân quyền, view, nhật ký, backup/restore, import/export", "", "", "", X],
        [f"Kiểm thử CSDL ({len(kiem_thu())} ca) và unit test ứng dụng", "", "", "", X],
        ["Ứng dụng Qt đa nền tảng: menu theo vai trò, form, báo cáo", "", X, "", ""],
        ["CI/CD và đóng gói file cài Windows/macOS", "", "", X, ""],
        ["Mô hình CSDL tiên tiến: hướng đối tượng, phân tán, NoSQL", "", "", "", X],
    ]
    r.fill_table(1, rows, header=["Nội dung đồ án", "25%", "50%", "75%", "100%"])


def phan_cong(r):
    r.centered_title("BẢNG PHÂN CÔNG CÔNG VIỆC")
    r.p("Nhóm làm việc trên kho mã nguồn GitHub chung (nhánh `develop` → `main`), mọi thay đổi đi qua "
        "Pull Request nên lịch sử commit thể hiện đóng góp của từng thành viên. Mỗi thành viên **sở hữu** "
        "một mảng nội dung: hiểu sâu phần CSDL tương ứng, kiểm thử, viết phần báo cáo, trình bày và trả lời "
        "vấn đáp phần đó.", indent=True)
    rows = [[tv["ten"] + "\n" + tv["mssv"], tv["mang"], tv["file"], tv["bao_cao"], tv["han"]]
            for tv in THANH_VIEN]
    r.table(["Thành viên", "Mảng phụ trách", "Sản phẩm / file", "Phần báo cáo", "Hạn hoàn thành"],
            rows, widths_cm=[3.2, 4.6, 3.6, 2.6, 2.0], size=10, bold_first_col=True,
            align=["left", "left", "left", "left", "center"])


def muc_luc(r):
    r.toc("MỤC LỤC", 'TOC \\o "1-3" \\h \\z \\u',
          "Nhấn chuột phải > Update Field (hoặc F9) để cập nhật mục lục.")
    r.toc("DANH MỤC HÌNH ẢNH", 'TOC \\h \\z \\t "FigureCaption,1"',
          "Nhấn chuột phải > Update Field để cập nhật danh mục hình ảnh.")
    r.toc("DANH MỤC BẢNG", 'TOC \\h \\z \\t "TableCaption,1"',
          "Nhấn chuột phải > Update Field để cập nhật danh mục bảng.", page_break=False)
