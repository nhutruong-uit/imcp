# Kế hoạch và phân công - Đồ án IE103 Nhóm 1

**Hạn nộp báo cáo: đầu tháng 11/2026.** Lịch dưới đây tính mốc nộp là **thứ Tư 04/11/2026**;
dời theo thông báo chính thức của giảng viên.

## 1. Cách làm việc

- **Lập trình**: nhóm trưởng + Claude Code (theo `CLAUDE.md`). Các thành viên khác **sở hữu một mảng
  nội dung**: hiểu sâu phần CSDL tương ứng, kiểm thử bằng SSMS/VS Code, viết phần báo cáo,
  làm slide và trả lời vấn đáp phần đó. Thay đổi đều đi qua GitHub (issue/PR), lịch sử commit là minh chứng.
- Họp nhóm 30 phút mỗi tối Chủ nhật (online): báo cáo tiến độ theo checklist bên dưới.
- Giảng viên cho phép dùng AI, nhưng **mỗi người phải trả lời được mọi câu hỏi về phần mình**.
  Khi nhờ Claude giải thích, hãy tự chạy lại câu lệnh và ghi chú bằng lời của mình.

## 2. Phân công

| Thành viên | Mảng sở hữu | File phụ trách | Phần báo cáo | Demo khi báo cáo |
|---|---|---|---|---|
| **Trương Quang Như** (NT, 25540022) | Kiến trúc & ứng dụng: Clean Architecture, Qt, kết nối ODBC, đăng nhập, CI/CD, đóng gói; tích hợp | `src/`, `tests/`, `.github/`, `scripts/package-*`, `packaging/` | Ch.6 (Trình bày thông tin), Ch.8, phụ lục cài đặt | Chạy ứng dụng 4 vai trò, file cài trên Win/Mac |
| **Đỗ Phạm Minh Trâm** (25540042) | Khảo sát & phân tích: quy trình nghiệp vụ trung tâm, tác nhân, use case, DFD, ERD (Chen), CD | báo cáo Ch.1-2, hình ERD/CD | Ch.1, Ch.2, mục 3.1-3.2 | Trình bày bài toán, ERD |
| **Nguyễn Việt Phú** (25540025) | Mô hình logic & ràng buộc: chuyển ERD → quan hệ, chuẩn hóa 3NF, từ điển dữ liệu, RBTV, **trigger** | `01_tables.sql`, `05_triggers.sql` | Mục 3.3-3.7, 4.6 | Vi phạm ràng buộc trực tiếp trong SSMS (thu vượt học phí, trùng lịch...) |
| **Đỗ Bình Dương** (25540008) | Lập trình CSDL: **stored procedure, function, cursor**, giao dịch, truy vấn SQL, **XML/XPath/XQuery** | `02_functions.sql`, `04_procedures.sql`, `08_demo_queries.sql` | Ch.4 (trừ 4.6) | Gọi `usp_GhiDanh`, `usp_LopHoc_XetKetQua` (cursor), truy vấn XQuery |
| **Nguyễn Bảo Giang** (25540009) | An ninh & mô hình tiên tiến: **xác thực, phân quyền, view bảo mật**, audit, **backup/restore**, import/export, CSDL phân tán, OODB, NoSQL | `03_views.sql`, `06_security.sql`, `09`-`11_*.sql` | Ch.5, Ch.7 | Đăng nhập SSMS bằng `gv_john` bị chặn bảng HOCVIEN; backup → restore; view phân tán |

Mỗi người làm **slide cho phần mình** (3-4 slide), nhóm trưởng ghép và thống nhất mẫu.

## 3. Lịch thực hiện

| Tuần | Thời gian | Nhóm trưởng (+ Claude Code) | Thành viên | Mốc hoàn thành |
|---|---|---|---|---|
| 1 | 01-04/10 | ✅ CSDL đầy đủ + dữ liệu mẫu, khung ứng dụng Clean Architecture, CI/CD, báo cáo nháp | Cài SQL Server + SSMS/VS Code, chạy `db_init`, đăng nhập thử 4 tài khoản demo | Mọi người chạy được CSDL trên máy mình |
| 2 | 05-11/10 | Module **Lớp học** (mở lớp, lịch tuần, sinh buổi học), **Ghi danh**, **Thu học phí + in biên lai PDF**; phát hành bản cài đầu tiên lên `main` | Đọc kỹ file phụ trách, chạy từng đối tượng trong SSMS, ghi câu hỏi/đề xuất thành Issue; viết nháp phần báo cáo | Bản cài v0.2 thử trên 1 máy Windows "sạch" |
| 3 | 12-18/10 | Module giáo viên: **Điểm danh**, **Nhập điểm**, **Xét kết quả**; **Quản lý tài khoản** (tạo/khóa/đặt lại mật khẩu), **Sao lưu** từ ứng dụng | Hoàn thiện phần báo cáo + hình chụp SSMS; Trâm hoàn thiện ERD/CD; Giang chuẩn bị kịch bản demo bảo mật | Báo cáo đủ các chương (bản 1) |
| 4 | 19-25/10 | Báo cáo thống kê (doanh thu, sĩ số, kết quả lớp), import Excel/XML, hoàn thiện giao diện; **đóng băng tính năng 25/10** | Rà soát chéo báo cáo (mỗi người đọc 1 chương của người khác), làm slide phần mình | Release `v1.0.0` trên `main` |
| 5 | 26/10-01/11 | Sửa lỗi, kiểm thử trên máy Windows và Mac sạch, chụp lại toàn bộ màn hình, xuất báo cáo PDF | **Tập vấn đáp chéo**: mỗi người trả lời câu hỏi phần của người khác; quay video demo dự phòng | Báo cáo + slide bản cuối |
| 6 | 02-04/11 | Nộp báo cáo, gửi link Release (đã mời giảng viên vào repo) | Tập trình bày 1 lần đầy đủ theo thời gian quy định | **Nộp** |

## 4. Checklist báo cáo (cập nhật vào trang "Checklist tiến độ" của báo cáo)

- [x] Phân tích bài toán, thiết kế mô hình dữ liệu, cài đặt CSDL (Lab 6 - Bài tập tổng hợp)
- [x] Trigger, stored procedure, function, cursor (Lab 2)
- [x] Phân quyền, xác thực, backup/restore, import/export (Lab 3)
- [x] XQuery, XPath (Lab 5)
- [~] Report: báo cáo PDF từ ứng dụng (danh sách) - cần thêm báo cáo có tham số, biên lai
- [~] Ứng dụng: Menu/Form - đã có Học viên, cần thêm Lớp học, Ghi danh, Học phí, Điểm danh, Điểm
- [x] CSDL tiên tiến: phân tán (demo), hướng đối tượng, NoSQL (báo cáo)

## 5. Chuẩn bị vấn đáp - câu hỏi thường gặp theo mảng

**Phân tích & ERD (Trâm)**: Vì sao GHIDANH là thực thể riêng chứ không phải thuộc tính? Bản số (min,max)
giữa HOCVIEN và LOPHOC? Liên kết đệ quy KHOAHOC tiên quyết biểu diễn thế nào? Khác nhau giữa ERD và CD?

**Mô hình quan hệ & RBTV (Phú)**: Lược đồ đạt chuẩn mấy? Vì sao lưu `DaDong` (thuộc tính dẫn xuất) mà vẫn
không vi phạm 3NF/không mất nhất quán? Bối cảnh và cách kiểm tra ràng buộc "Đã đóng = tổng phiếu thu"?
Trigger xử lý nhiều dòng (inserted có nhiều bản ghi) ra sao? INSTEAD OF khác AFTER thế nào?

**Lập trình CSDL (Dương)**: Khi nào dùng function, khi nào dùng procedure? Inline TVF khác multi-statement TVF?
Vì sao dùng cursor trong `usp_LopHoc_XetKetQua` và có thể viết lại không cần cursor không? `SET XACT_ABORT ON`
để làm gì? `.value()` khác `.query()`? `.nodes()` + `CROSS APPLY` hoạt động thế nào?

**An ninh & tiên tiến (Giang)**: Contained user khác login + user thế nào, ưu điểm khi backup/restore sang máy khác?
Ownership chaining là gì, vì sao giáo viên đọc được view dù bị DENY bảng HOCVIEN? DENY và REVOKE khác nhau?
Chiến lược Full/Diff/Log, RPO? Phân mảnh ngang theo chi nhánh có đầy đủ, tách biệt, tái thiết được không?
Chuyển GHIDANH sang MongoDB thì nhúng (embed) hay tham chiếu?

**Ứng dụng & kiến trúc (Như)**: Clean Architecture chia mấy tầng, vì sao giao diện không gọi SQL trực tiếp?
Đăng nhập được xác thực ở đâu? Làm sao chạy trên cả Windows và macOS? CI/CD tạo file cài như thế nào?
Vì sao chọn SQL Server thay vì SQLite?
