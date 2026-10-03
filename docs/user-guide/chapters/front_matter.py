"""Cover page, document information, table of contents."""
from datetime import date

from chapters.common import app_version
from content.common import MEMBERS  # the team list of the report (docs/report/content/common.py)


def cover_page(g):
    # Paragraph indexes of the template (docs/report/template/uit_report_template.docx)
    today = date.today()
    g.set_paragraph_text(4, "HƯỚNG DẪN CÀI ĐẶT VÀ SỬ DỤNG")
    g.set_paragraph_text(5, "PHẦN MỀM QLTTTA")
    g.set_paragraph_text(6, "MÔN HỌC: QUẢN LÝ THÔNG TIN - MÃ LỚP: IE103.Q21.VB2")
    g.set_paragraph_text(7, "ĐỀ TÀI: XÂY DỰNG HỆ THỐNG QUẢN LÝ TRUNG TÂM TIẾNG ANH")
    g.set_paragraph_text(8, "Giảng viên hướng dẫn: TS. Võ Phương Bình")
    g.set_paragraph_text(9, "Nhóm sinh viên thực hiện: Nhóm 1")
    g.set_paragraph_text(11, f"TP. Hồ Chí Minh, tháng {today.month} năm {today.year}")
    g.fill_table(0, [[str(i + 1), m["name"] + (" (Nhóm trưởng)" if i == 0 else ""), m["student_id"]]
                     for i, m in enumerate(MEMBERS)])
    # The template continues with the checklist and the instructor's comments: not part of a user guide
    g.remove_template_pages("CHECKLIST TIẾN ĐỘ HOÀN THÀNH")
    g.set_header_text("HƯỚNG DẪN SỬ DỤNG - QUẢN LÝ TRUNG TÂM TIẾNG ANH")


def document_info(g):
    """Document information table; the status row is filled in at the end (number of parts still missing)."""
    g.centered_title("THÔNG TIN TÀI LIỆU")
    t = g.table(["Mục", "Nội dung"], [
        ["Phần mềm", f"QLTTTA - Quản lý Trung tâm Tiếng Anh, phiên bản {app_version()}"],
        ["Hệ điều hành", "macOS 12 trở lên (máy Mac chip Apple Silicon M1/M2/M3...)\n"
                         "Windows 10/11 64-bit"],
        ["Cơ sở dữ liệu", "Microsoft SQL Server 2012 trở lên: chạy trong Docker (macOS, Windows) hoặc "
                          "cài trực tiếp trên máy Windows (bản Express/Developer miễn phí)"],
        ["Ngôn ngữ giao diện", "Tiếng Việt (mặc định) và English, đổi được ngay khi đang dùng"],
        ["Người đọc", "Giảng viên chấm đồ án, nhân viên trung tâm (quản lý, giáo vụ, kế toán, giáo viên), "
                      "thành viên nhóm khi cài đặt và demo"],
        ["Ngày cập nhật", date.today().strftime("%d/%m/%Y")],
        ["Tình trạng", ""],
    ], widths_cm=[4.0, 12.0], size=11, bold_first_col=True)
    g.status_cell = t.rows[-1].cells[1]
    g.p("Tài liệu được sinh tự động từ mã nguồn (`docs/user-guide/build_user_guide.py`): tên chức năng, "
        "phân quyền theo vai trò, tài khoản demo và ảnh màn hình luôn khớp với phiên bản phần mềm ghi ở trên.")


def fill_status(g):
    n = len(g.placeholders)
    text = ("Hoàn chỉnh" if n == 0 else
            f"Bản nháp - còn {n} mục **[CẦN BỔ SUNG]** (khung màu vàng), chủ yếu phần dành cho Windows; "
            "danh sách ở Phụ lục B")
    g._set_cell_text(g.status_cell, "")
    g._inline(g.status_cell.paragraphs[0], text, size=11)


def table_of_contents(g):
    g.toc("MỤC LỤC", 'TOC \\o "1-3" \\h \\z \\u',
          "Nhấn chuột phải > Update Field (hoặc F9) để cập nhật mục lục.")
    g.toc("DANH MỤC HÌNH ẢNH", 'TOC \\h \\z \\t "FigureCaption,1"',
          "Nhấn chuột phải > Update Field để cập nhật danh mục hình ảnh.")
    g.toc("DANH MỤC BẢNG", 'TOC \\h \\z \\t "TableCaption,1"',
          "Nhấn chuột phải > Update Field để cập nhật danh mục bảng.", page_break=False)
