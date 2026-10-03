"""Chapters 4-5: signing in, the common parts of the screens, every feature by role."""
from chapters.common import ROLE_CODES, ROLES, SCREENS, demo_accounts

ROLE_SCOPE = {
    "Manager": "Toàn bộ: học viên, lớp, công nợ, doanh thu, lương, tài khoản",
    "AcademicStaff": "Học viên, lớp, lịch học, kết quả học tập, công nợ (không xem lương, doanh thu)",
    "Accountant": "Học viên (chỉ xem), công nợ, doanh thu, lương giáo viên",
    "Teacher": "Chỉ lớp mình dạy, lịch dạy và lương của mình",
}


def chapter4(g):
    g.h1("CHƯƠNG 4. ĐĂNG NHẬP VÀ GIAO DIỆN CHUNG")

    g.h2("4.1. Mở ứng dụng")
    g.bullets([
        "**macOS**: mở **Launchpad** hoặc thư mục **Applications**, chọn **QLTTTA**.",
        "**Windows**: menu **Start > QLTTTA**, biểu tượng ngoài màn hình, hoặc `QLTTTA.exe` của bản portable.",
    ])
    g.p("Màn hình đầu tiên là **Đăng nhập**. Bên trái là tên và mô tả phần mềm; bên phải là ô **Tên đăng "
        "nhập**, **Mật khẩu**, nút **Đăng nhập**, liên kết **Cấu hình máy chủ**, ô chọn ngôn ngữ và số phiên "
        "bản ở góc dưới.")
    g.figure(SCREENS / "login.png", "Màn hình đăng nhập", width_cm=13.5)

    g.h2("4.2. Cấu hình máy chủ (lần chạy đầu tiên)")
    g.p("Trước lần đăng nhập đầu tiên, khai báo SQL Server mà ứng dụng sẽ kết nối:")
    g.steps([
        "Bấm **Cấu hình máy chủ ▸** dưới nút Đăng nhập; khung **Máy chủ SQL Server** mở ra.",
        "Ô **Máy chủ**: nhập địa chỉ theo Bảng 4.1.",
        "Ô **CSDL**: giữ `QLTTTA` (tên CSDL do script tạo ra).",
        "Ô **Tin cậy chứng chỉ máy chủ (TrustServerCertificate)**: giữ **bật** khi dùng Docker hoặc SQL Server "
        "cài trên máy (chứng chỉ tự ký). Chỉ tắt khi máy chủ có chứng chỉ do tổ chức tin cậy cấp. Khi đã tắt, "
        "ứng dụng không tự chuyển sang driver khác để bỏ qua bước kiểm tra chứng chỉ. Bản macOS dùng driver "
        "FreeTDS: kết nối vẫn được mã hóa nhưng driver này không kiểm tra chứng chỉ, nên ô này không có tác dụng.",
    ])
    g.figure(SCREENS / "login_server_settings.png", "Khung cấu hình máy chủ SQL Server", width_cm=14.0)
    g.table(["SQL Server đang chạy ở đâu", "Nhập vào ô Máy chủ"], [
        ["Docker trên cùng máy (macOS hoặc Windows)", "`localhost,1433` (giá trị mặc định)"],
        ["SQL Server Express cài trên cùng máy Windows", "`localhost\\SQLEXPRESS` hoặc `TEN-MAY\\SQLEXPRESS`"],
        ["SQL Server Developer (instance mặc định) trên cùng máy Windows", "`localhost`"],
        ["Máy khác trong mạng", "`<địa chỉ IP>,<cổng>`, ví dụ `192.168.1.10,1433`"],
    ], widths_cm=[8.5, 7.5], caption="Giá trị ô Máy chủ theo cách cài SQL Server", size=10.5)
    g.p("Cấu hình được lưu khi bấm **Đăng nhập**, nên chỉ cần khai báo một lần. Dấu phẩy (`,`) ngăn cách "
        "địa chỉ và **cổng**; dấu gạch chéo ngược (`\\`) ngăn cách tên máy và **tên instance**.")

    g.h2("4.3. Đăng nhập")
    g.p("Nhập **Tên đăng nhập**, **Mật khẩu** rồi bấm **Đăng nhập** (hoặc Enter). Nút đổi thành **Đang kết "
        "nối...** trong lúc chờ máy chủ trả lời. Lần sau ứng dụng tự điền tên đăng nhập gần nhất. Tài khoản do "
        "quản lý cấp là **tài khoản SQL Server** (người dùng của CSDL `QLTTTA`). Dữ liệu mẫu có sẵn các tài "
        "khoản demo sau:")
    accounts = demo_accounts()
    g.table(["Tên đăng nhập", "Mật khẩu", "Vai trò", "Phạm vi dữ liệu"],
            [[f"`{user}`", f"`{password}`", ROLES[role], ROLE_SCOPE[role]] for user, password, role in accounts],
            widths_cm=[3.2, 2.6, 2.4, 7.8], caption="Tài khoản demo trong dữ liệu mẫu", size=10)
    g.warning("Đây là mật khẩu demo dùng chung, chỉ để chấm đồ án và trình diễn. Khi triển khai thật, mỗi "
              "người phải đổi mật khẩu ngay sau lần đăng nhập đầu (mục 4.6).")
    g.p("Nếu đăng nhập không được, dòng chữ đỏ dưới ô mật khẩu cho biết nguyên nhân:")
    g.table(["Thông báo", "Ý nghĩa và cách xử lý"], [
        ["Sai tên đăng nhập hoặc mật khẩu, hoặc tài khoản đã bị khóa.",
         "Kiểm tra lại (mật khẩu phân biệt chữ hoa/thường); nếu đúng mà vẫn lỗi, nhờ quản lý kiểm tra tài khoản."],
        ["Không kết nối được máy chủ SQL Server...",
         "SQL Server chưa chạy hoặc ô Máy chủ sai: xem mục 4.2 và Chương 6."],
        ["Không mở được cơ sở dữ liệu...", "Ô CSDL sai hoặc chưa chạy script khởi tạo CSDL (Chương 2)."],
        ["Lỗi chứng chỉ bảo mật của máy chủ...", "Bật **Tin cậy chứng chỉ máy chủ** trong Cấu hình máy chủ."],
        ["Tài khoản SQL Server hợp lệ nhưng chưa được gán vai trò...",
         "Tài khoản chưa thuộc vai trò nào của hệ thống: nhờ quản trị CSDL gán vai trò."],
    ], widths_cm=[6.5, 9.5], caption="Thông báo lỗi khi đăng nhập", size=10)

    g.h2("4.4. Màn hình chính")
    g.p("Sau khi đăng nhập, cửa sổ chính mở ở chức năng đầu tiên của vai trò (Tổng quan, hoặc Lớp của tôi với "
        "giáo viên). Màn hình gồm ba vùng:")
    g.bullets([
        "**Thanh menu bên trái**: các chức năng xếp theo nhóm (**CHUNG**, **ĐÀO TẠO**, **TÀI CHÍNH**, **HỆ "
        "THỐNG**; giáo viên có nhóm **GIẢNG DẠY**). Bấm một mục để mở; chức năng đang mở được tô sáng. Cuối "
        "thanh menu là họ tên và vai trò của người đang đăng nhập.",
        "**Thanh tiêu đề phía trên**: tên chức năng đang mở, nhãn vai trò, ô chọn ngôn ngữ, nút **Đổi mật "
        "khẩu** và **Đăng xuất**.",
        "**Vùng nội dung**: danh sách hoặc trang thống kê của chức năng.",
    ])
    g.figure(SCREENS / "ql_quan_dashboard.png", "Màn hình chính của vai trò Quản lý (trang Tổng quan)")

    g.h2("4.5. Đổi ngôn ngữ giao diện")
    g.p("Chọn **Tiếng Việt** hoặc **English** ở ô có biểu tượng quả địa cầu: ở góc dưới màn hình đăng nhập "
        "hoặc trên thanh tiêu đề của màn hình chính. Màn hình được dựng lại ngay bằng ngôn ngữ mới, người dùng "
        "vẫn đăng nhập và vẫn ở chức năng đang mở; lựa chọn được ghi nhớ cho lần sau. Dữ liệu lưu trong CSDL "
        "(họ tên, tên lớp, tên chi nhánh...) giữ nguyên, không dịch.")

    g.h2("4.6. Đổi mật khẩu")
    g.steps([
        "Bấm **Đổi mật khẩu** trên thanh tiêu đề.",
        "Nhập **Mật khẩu hiện tại**, **Mật khẩu mới** và **Nhập lại mật khẩu mới**.",
        "Bấm **Lưu**. Khi thành công, ứng dụng báo **Đã đổi mật khẩu**; lần đăng nhập sau dùng mật khẩu mới.",
    ])
    g.figure(SCREENS / "change_password.png", "Hộp thoại đổi mật khẩu", width_cm=9.5)
    g.p("Mật khẩu mới phải có **ít nhất 8 ký tự**, khác mật khẩu cũ và hai lần nhập phải giống nhau. SQL "
        "Server còn có thể từ chối mật khẩu quá đơn giản theo chính sách mật khẩu của máy chủ: nên dùng cả chữ "
        "hoa, chữ thường, chữ số và ký hiệu (ví dụ dạng `Demo@2026`).")

    g.h2("4.7. Đăng xuất và thoát")
    g.p("Bấm **Đăng xuất**, chọn **Đồng ý** ở câu hỏi **Bạn muốn đăng xuất?** để quay về màn hình đăng nhập "
        "(ví dụ để đổi sang tài khoản khác). Đóng cửa sổ chính để thoát hẳn ứng dụng.")

    g.h2("4.8. Thao tác chung trên các danh sách")
    g.p("Các chức năng tra cứu (Lớp học, Lịch học, Công nợ, Doanh thu, Lương...) dùng chung một kiểu màn hình:")
    g.figure(SCREENS / "ql_quan_outstanding_tuition.png", "Một màn hình danh sách: Công nợ học phí")
    g.table(["Thành phần", "Cách dùng"], [
        ["Ô **Lọc nhanh trong danh sách...**",
         "Gõ một phần nội dung bất kỳ (mã, tên, ngày...): danh sách chỉ giữ các dòng có chứa đoạn chữ đó, "
         "không phân biệt hoa/thường. Bấm dấu ✕ trong ô để xóa bộ lọc."],
        ["Tiêu đề cột", "Bấm để sắp xếp tăng dần, bấm lần nữa để giảm dần. Độ rộng cột tự vừa nội dung; dùng "
                        "thanh cuộn ngang khi bảng có nhiều cột."],
        ["Dòng tổng ở cuối", "Số dòng đang hiển thị và tổng các cột tiền (ví dụ **Tổng đã đóng**, **Tổng còn "
                             "nợ**), tính lại ngay theo bộ lọc."],
        ["Nút **Làm mới**", "Đọc lại dữ liệu mới nhất từ CSDL (khi người khác vừa cập nhật)."],
        ["Nút **Excel**", "Lưu các dòng đang hiển thị ra file `.csv` (mặc định trong thư mục Documents/Tài "
                          "liệu) rồi mở bằng Excel hoặc ứng dụng bảng tính mặc định. File dùng mã UTF-8 nên "
                          "Excel hiển thị đúng tiếng Việt. Ô bắt đầu bằng `=`, `+` hoặc `@` được thêm dấu `'` ở "
                          "đầu để Excel không chạy nội dung đó như công thức."],
        ["Nút **Xuất báo cáo PDF**", "Tạo báo cáo PDF khổ A4 (tự xoay ngang khi bảng có hơn 7 cột) gồm tiêu đề "
                                     "trung tâm, tên báo cáo, ngày lập, người lập, cột STT, dòng **TỔNG CỘNG** và "
                                     "tổng số dòng; mở ngay sau khi lưu."],
    ], widths_cm=[4.6, 11.4], caption="Các thành phần của màn hình danh sách", size=10.5)
    g.tip("Muốn in hoặc gửi một phần danh sách (ví dụ công nợ của một lớp), gõ mã lớp vào ô lọc nhanh rồi "
          "mới bấm **Xuất báo cáo PDF**: báo cáo chỉ chứa các dòng đang hiển thị.")


def chapter5(g):
    g.h1("CHƯƠNG 5. HƯỚNG DẪN THEO CHỨC NĂNG")
    g.p("Mỗi mục dưới đây ghi rõ vai trò được dùng chức năng (theo Bảng 1.1). Ảnh minh họa chụp bằng tài "
        "khoản demo tương ứng, với dữ liệu mẫu.")

    g.h2("5.1. Tổng quan")
    g.p("*Vai trò: Quản lý, Giáo vụ, Kế toán.* Trang mở đầu sau khi đăng nhập, gồm lời chào, ngày hôm nay, "
        "sáu thẻ số liệu và biểu đồ doanh thu theo tháng của năm hiện tại. Bấm **Làm mới** để cập nhật số liệu.")
    g.table(["Thẻ số liệu", "Ý nghĩa"], [
        ["Học viên đang học", "Số học viên đang theo học ít nhất một lớp (có lượt ghi danh Đang học)"],
        ["Lớp đang học", "Số lớp có trạng thái Đang học"],
        ["Lớp đang tuyển sinh", "Số lớp có trạng thái Đang tuyển sinh (đang nhận ghi danh)"],
        ["Doanh thu tháng này", "Tổng tiền thu trong tháng; hiện \"Không có quyền\" với vai trò không được xem "
                                "doanh thu"],
        ["Tổng công nợ học phí", "Tổng số tiền học phí học viên còn nợ"],
        ["Buổi học hôm nay", "Số buổi học có lịch trong ngày"],
    ], widths_cm=[4.6, 11.4], caption="Các thẻ số liệu trên trang Tổng quan", size=10.5)
    g.figure(SCREENS / "gvu_lan_dashboard.png",
             "Trang Tổng quan của Giáo vụ: không có quyền xem doanh thu nên biểu đồ để trống")

    g.h2("5.2. Học viên")
    g.p("*Vai trò: Quản lý, Giáo vụ (xem, thêm, sửa, xóa); Kế toán (chỉ xem).* Danh sách học viên với mã, họ "
        "tên, ngày sinh, giới tính, điện thoại, phụ huynh, chi nhánh, ngày đăng ký, trạng thái, số lớp đang "
        "học và công nợ. Dòng cuối cho biết số học viên tìm thấy.")
    g.figure(SCREENS / "ql_quan_students.png", "Danh sách học viên")
    g.h3("5.2.1. Tìm kiếm")
    g.bullets([
        "Gõ mã học viên, họ tên hoặc số điện thoại vào ô **Tìm mã, họ tên, SĐT...**: danh sách tự lọc sau khi "
        "ngừng gõ khoảng nửa giây (tìm trực tiếp trong CSDL).",
        "Chọn chi nhánh ở ô **Tất cả chi nhánh** và trạng thái ở ô **Tất cả trạng thái** (Tiềm năng, Đang "
        "học, Bảo lưu, Ngừng học, Hoàn thành) để thu hẹp kết quả.",
        "Nút **Excel** và **PDF** xuất danh sách đang hiển thị như mục 4.8.",
    ])
    g.h3("5.2.2. Thêm học viên")
    g.steps([
        "Bấm **Thêm**. Hộp thoại **Thêm học viên** mở ra.",
        "Nhập các ô bắt buộc (có dấu `*`): **Họ tên**, **Ngày sinh**, **Chi nhánh**; nhập thêm giới tính, "
        "điện thoại, email, địa chỉ, nghề nghiệp, ghi chú nếu có.",
        "Nếu học viên **dưới 18 tuổi**, tiêu đề khung phụ huynh có thêm dấu `*`: bắt buộc nhập **Họ tên "
        "phụ huynh** và **SĐT phụ huynh**.",
        "Bấm **Lưu**. **Mã học viên** (`ST` và 5 chữ số, ví dụ `ST00073`) được sinh tự động; học viên mới "
        "có trạng thái **Tiềm "
        "năng** và được chọn sẵn trong danh sách.",
    ])
    g.h3("5.2.3. Sửa thông tin")
    g.p("Chọn một học viên rồi bấm **Sửa** (hoặc nhấp đúp vào dòng đó). Hộp thoại **Sửa thông tin học viên** "
        "cho phép đổi mọi thông tin trừ mã học viên, kể cả **Trạng thái** (ví dụ chuyển sang **Bảo lưu** hoặc "
        "**Ngừng học**). Bấm **Lưu** để ghi, **Hủy** để bỏ qua. Trạng thái **Hoàn thành** do hệ thống tự đặt khi "
        "học viên học xong lớp cuối cùng (không còn lớp nào đang học); khi ghi danh lớp mới, học viên tự chuyển "
        "lại **Đang học**. Các ô chữ không cho gõ quá độ dài tối đa của CSDL.")
    g.figure(SCREENS / "gvu_lan_student_form.png", "Hộp thoại sửa thông tin học viên", width_cm=10.5)
    g.p("Khi dữ liệu chưa hợp lệ, hộp thoại không đóng và hiện thông báo màu đỏ. Các quy tắc được kiểm tra "
        "ở ứng dụng và một lần nữa trong CSDL:")
    g.table(["Quy tắc", "Thông báo"], [
        ["Họ tên bắt buộc, tối đa 100 ký tự", "Họ tên không được để trống. / Họ tên tối đa 100 ký tự."],
        ["Học viên từ 4 tuổi trở lên", "Học viên phải từ 4 tuổi trở lên."],
        ["Số điện thoại gồm 9-11 chữ số (ô chỉ nhận chữ số)", "Số điện thoại chỉ gồm 9-11 chữ số."],
        ["Có ít nhất một số điện thoại (học viên hoặc phụ huynh)",
         "Cần ít nhất một số điện thoại liên lạc (học viên hoặc phụ huynh)."],
        ["Dưới 18 tuổi phải có họ tên và SĐT phụ huynh",
         "Học viên dưới 18 tuổi phải có họ tên và số điện thoại phụ huynh."],
        ["Email đúng định dạng, không dấu, tối đa 100 ký tự", "Email không đúng định dạng."],
        ["Địa chỉ tối đa 200 ký tự, nghề nghiệp tối đa 50 ký tự, họ tên phụ huynh tối đa 100 ký tự, ghi chú tối "
         "đa 500 ký tự", "Địa chỉ tối đa 200 ký tự. / Nghề nghiệp tối đa 50 ký tự. / Họ tên phụ huynh tối đa 100 "
         "ký tự. / Ghi chú tối đa 500 ký tự."],
        ["Số điện thoại, email không trùng với học viên khác",
         "Số điện thoại đã được dùng cho học viên khác. / Email đã được dùng cho học viên khác."],
        ["Phải chọn chi nhánh", "Chưa chọn chi nhánh."],
    ], widths_cm=[7.0, 9.0], caption="Quy tắc kiểm tra thông tin học viên", size=10)
    g.h3("5.2.4. Xóa học viên")
    g.p("Chọn học viên, bấm **Xóa** và xác nhận câu hỏi **Xóa học viên <mã> - <họ tên>?**. Chỉ xóa được học "
        "viên **chưa từng ghi danh**; học viên đã có dữ liệu ghi danh thì CSDL từ chối (thông báo **Học viên "
        "đang có dữ liệu ghi danh, không thể xóa**) - khi đó hãy sửa trạng thái thành **Ngừng học**.")
    g.warning("Xóa học viên không hoàn tác được. Kế toán và giáo viên không thấy các nút Thêm, Sửa, Xóa.")

    g.h2("5.3. Lớp học")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Danh sách lớp với mã lớp, tên lớp, khóa học, chi nhánh, giáo viên, phòng, "
        "lịch học trong tuần, ngày khai giảng và kết thúc, sĩ số/tối đa, học phí, trạng thái. Lớp **Đang học** "
        "xếp trước, rồi đến lớp **Đang tuyển sinh**, cuối cùng là các lớp khác; trong mỗi nhóm lớp mới khai "
        "giảng đứng trên.")
    g.figure(SCREENS / "ql_quan_classes.png", "Danh sách lớp học")

    g.h2("5.4. Lịch học tuần này")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Mọi buổi học từ thứ Hai đến Chủ nhật của tuần hiện tại, theo thứ tự "
        "ngày và giờ: ngày học, giờ bắt đầu, giờ kết thúc, lớp, buổi thứ mấy, phòng, giáo viên, trạng thái buổi "
        "(**Chưa dạy**, **Đã dạy**...). Gõ tên phòng hoặc giáo viên vào ô lọc nhanh để xem lịch của một phòng/"
        "một giáo viên.")
    g.figure(SCREENS / "gvu_lan_weekly_schedule.png", "Lịch học tuần này")

    g.h2("5.5. Kết quả học tập")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Kết quả của từng học viên trong từng lớp: điểm tổng kết (**Điểm TK**), "
        "xếp loại (Xuất sắc, Giỏi, Khá, Trung bình), tỷ lệ chuyên cần (%), kết quả (**Đạt**/**Không đạt**) và "
        "trạng thái ghi danh. Sắp xếp theo mã lớp rồi họ tên; gõ mã lớp vào ô lọc nhanh để xem bảng điểm một "
        "lớp và xuất PDF.")
    g.figure(SCREENS / "gvu_lan_learning_results.png", "Kết quả học tập")

    g.h2("5.6. Công nợ học phí")
    g.p("*Vai trò: Quản lý, Giáo vụ, Kế toán.* Các lượt ghi danh **còn nợ học phí**, số nợ lớn nhất đứng đầu: "
        "mã ghi danh, học viên, số liên lạc, lớp, ngày ghi danh, học phí, đã đóng, còn nợ và số ngày kể từ khi "
        "ghi danh. Dòng tổng cho biết **Tổng đã đóng** và **Tổng còn nợ** của các dòng đang hiển thị (ảnh ở "
        "mục 4.8). Dùng danh sách này để nhắc học viên đóng học phí.")

    g.h2("5.7. Doanh thu")
    g.p("*Vai trò: Quản lý, Kế toán.* Doanh thu theo **tháng** và **chi nhánh**: năm, tháng, chi nhánh, số "
        "phiếu thu và tổng tiền; tháng gần nhất đứng đầu. Dòng tổng cho biết **Tổng doanh thu**. Gõ tên chi "
        "nhánh (ví dụ `Thu Duc`) vào ô lọc nhanh để xem riêng một chi nhánh.")
    g.figure(SCREENS / "kt_minh_revenue.png", "Doanh thu theo tháng và chi nhánh (Kế toán)")

    g.h2("5.8. Lương giáo viên")
    g.p("*Vai trò: Quản lý, Kế toán.* Bảng lương đã chốt theo tháng của từng giáo viên: số buổi, số giờ, đơn "
        "giá mỗi giờ, thưởng, khấu trừ, tổng lương và trạng thái (**Đã chốt** hoặc **Đã chi trả**). Dòng tổng "
        "cộng thưởng, khấu trừ và tổng lương của các dòng đang hiển thị.")
    g.figure(SCREENS / "kt_minh_payroll.png", "Bảng lương giáo viên (Kế toán)")

    g.h2("5.9. Tài khoản")
    g.p("*Vai trò: Quản lý.* Danh sách tài khoản đăng nhập: tên đăng nhập, vai trò, họ tên nhân viên/giáo "
        "viên, trạng thái (**Hoạt động** hoặc **Đã khóa**), ngày tạo và lần đăng nhập cuối (hiển thị theo múi giờ "
        "của máy tính đang chạy ứng dụng). Màn hình này chỉ "
        "để tra cứu; việc tạo, khóa/mở khóa tài khoản và đặt lại mật khẩu do quản lý thực hiện trong SSMS (đăng "
        "nhập bằng tài khoản quản lý, chọn CSDL `QLTTTA`) bằng các thủ tục `usp_Account_Create`, "
        "`usp_Account_Lock`, `usp_Account_ResetPassword` (xem "
        "`docs/DATABASE.md`).")
    g.figure(SCREENS / "ql_quan_accounts.png", "Danh sách tài khoản (Quản lý)")
    g.code("SSMS (đăng nhập bằng tài khoản quản lý)",
           "-- Tạo tài khoản cho giáo viên TE0004\n"
           "EXEC dbo.usp_Account_Create N'gv_emily', N'<mật khẩu>', 'TEACHER',\n"
           "     NULL, 'TE0004';\n"
           "-- Khóa (1) rồi mở khóa (0)\n"
           "EXEC dbo.usp_Account_Lock N'gv_emily', 1;\n"
           "EXEC dbo.usp_Account_Lock N'gv_emily', 0;\n"
           "-- Đặt lại mật khẩu\n"
           "EXEC dbo.usp_Account_ResetPassword N'gv_emily', N'<mật khẩu mới>';")
    g.bullets([
        "**Tên đăng nhập**: chỉ gồm chữ cái không dấu, chữ số, dấu chấm và dấu gạch dưới, ít nhất 3 ký tự "
        "(tên có dấu như `gv_ánh` bị từ chối) và chưa có tài khoản nào dùng. **Mật khẩu** ít nhất 8 ký tự.",
        "**Vai trò**: " + ", ".join(f"`{code}` ({ROLES[role]})" for code, role in ROLE_CODES.items())
        + ". Tài khoản giáo viên cần mã giáo viên (`TE...`, tham số thứ năm); các vai trò khác cần mã nhân "
        "viên (`EM...`, tham số thứ tư).",
        "**Khóa / mở khóa**: tham số thứ hai bắt buộc là `1` (khóa) hoặc `0` (mở khóa). Không khóa được tài "
        "khoản đang dùng để đăng nhập. Tài khoản bị khóa không đăng nhập được nữa (thông báo ở mục 4.3) và hiện "
        "**Đã khóa** trong danh sách.",
    ])

    g.h2("5.10. Chức năng dành cho giáo viên")
    g.p("*Vai trò: Giáo viên.* Giáo viên chỉ thấy dữ liệu của chính mình (CSDL lọc theo tài khoản đăng nhập):")
    g.bullets([
        "**Lớp của tôi**: các lớp được phân công, kèm khóa học, phòng, chi nhánh, ngày khai giảng/kết thúc, sĩ "
        "số và trạng thái.",
        "**Lịch dạy**: các buổi dạy từ thứ Hai của tuần hiện tại trở đi, theo ngày và giờ.",
        "**Lương của tôi**: bảng lương từng tháng (số buổi, số giờ, đơn giá, thưởng, khấu trừ, tổng lương, "
        "trạng thái).",
    ])
    g.figure(SCREENS / "gv_john_my_teaching_schedule.png", "Lịch dạy của giáo viên")

    g.h2("5.11. Nghiệp vụ thực hiện trực tiếp trong CSDL")
    g.p("Phiên bản hiện tại của ứng dụng tập trung vào tra cứu và quản lý học viên. Các nghiệp vụ còn lại đã có "
        "đầy đủ trong CSDL dưới dạng thủ tục lưu trữ (stored procedure), có kiểm tra quyền theo vai trò, và "
        "được trình diễn bằng SSMS hoặc VS Code (đăng nhập bằng tài khoản demo, chọn CSDL `QLTTTA`):")
    g.table(["Nghiệp vụ", "Thủ tục", "Vai trò được phép"], [
        ["Ghi danh học viên vào lớp", "`usp_Enrollment_Create`", "Quản lý, Giáo vụ"],
        ["Chuyển lớp", "`usp_Enrollment_TransferClass`", "Quản lý, Giáo vụ"],
        ["Lập / hủy phiếu thu học phí", "`usp_Receipt_Create`, `usp_Receipt_Cancel`", "Quản lý, Kế toán"],
        ["Điểm danh, nhập điểm", "`usp_Attendance_Save`, `usp_Grade_Save`", "Quản lý, Giáo vụ, Giáo viên"],
        ["Mở lớp, sinh lịch học", "`usp_Class_Create`, `usp_Class_GenerateSessions`", "Quản lý, Giáo vụ"],
        ["Bắt đầu / hủy lớp", "`usp_Class_UpdateStatus`", "Quản lý, Giáo vụ"],
        ["Xét kết quả cuối khóa, cấp chứng nhận", "`usp_Class_EvaluateResults`", "Quản lý, Giáo vụ"],
    ], widths_cm=[5.0, 7.0, 4.0], caption="Nghiệp vụ thực hiện bằng thủ tục trong CSDL", size=10)
    g.p("Mỗi thủ tục tự kiểm tra quy tắc nghiệp vụ trước khi ghi. Khi vi phạm, SSMS hiện thông báo lỗi (tiếng "
        "Anh, ví dụ `The student is already enrolled in this class.`) và dữ liệu không thay đổi. Các quy tắc "
        "người dùng hay gặp:")
    g.table(["Nghiệp vụ", "Quy tắc CSDL kiểm tra"], [
        ["Ghi danh",
         "Học viên chưa **Ngừng học** và chưa có trong lớp; lớp **Đang tuyển sinh** hoặc **Đang học** và còn chỗ; "
         "không trùng giờ với lớp khác học viên đang học; mã khuyến mãi còn hiệu lực. Khóa có điều kiện đầu vào: "
         "học viên phải **Đạt** khóa tiên quyết, hoặc có bài kiểm tra xếp lớp gần nhất đủ điểm tối thiểu (chỉ khi "
         "khóa có quy định điểm tối thiểu)."],
        ["Chuyển lớp",
         "Chỉ chuyển lượt ghi danh **Đang học** hoặc **Bảo lưu**, sang lớp **cùng khóa học và cùng chi nhánh** "
         "đang tuyển sinh hoặc đang học, còn chỗ và không trùng giờ. Học phí tính lại theo lớp mới (áp dụng lại "
         "khuyến mãi của lượt ghi danh); nếu học viên đã đóng nhiều hơn học phí mới thì phải hủy bớt phiếu thu "
         "trước. Phiếu thu và điểm được giữ, điểm danh ở lớp cũ bị xóa; tỷ lệ chuyên cần ở lớp mới tính từ ngày "
         "chuyển."],
        ["Bắt đầu / hủy lớp",
         "Lớp đi theo thứ tự **Đang tuyển sinh** → **Đang học** → **Đã kết thúc** (khi xét kết quả), hoặc **Đã "
         "hủy**. Lớp đã kết thúc hoặc đã hủy không mở lại được: hãy mở lớp mới. Không hủy được lớp đã có học viên "
         "đóng tiền; khi hủy, các lượt ghi danh còn lại chuyển sang **Đã nghỉ**."],
        ["Điểm danh, nhập điểm",
         "Giáo viên chỉ điểm danh các buổi mình dạy và chỉ nhập điểm lớp mình dạy. Buổi học chỉ được đánh dấu "
         "**Đã dạy** từ ngày học trở đi và không đổi lại được. Lớp **Đã kết thúc** đã được xét kết quả nên không "
         "sửa buổi học, điểm danh và điểm được nữa; chỉ xét kết quả khi lớp không còn buổi **Chưa dạy**."],
    ], widths_cm=[3.6, 12.4], caption="Quy tắc CSDL kiểm tra khi ghi danh, chuyển lớp, mở/hủy lớp, điểm danh và nhập điểm",
        size=10)
    g.p("Tham số và ví dụ của từng thủ tục nằm trong `database/04_procedures.sql` và Chương 4 của báo cáo đồ án.")
