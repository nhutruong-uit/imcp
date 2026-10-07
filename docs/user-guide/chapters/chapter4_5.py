"""Chapters 4-5: signing in, the common parts of the screens, every feature by role."""
from chapters.common import ROLE_CODES, ROLES, SCREENS, demo_accounts

ROLE_SCOPE = {
    "Manager": "Toàn bộ: danh mục, học viên, lớp, ghi danh, học phí, điểm, lương, tài khoản, sao lưu",
    "AcademicStaff": "Học viên, kiểm tra xếp lớp, lớp, ghi danh, lịch học - điểm danh, sổ điểm, kết quả học tập; "
                     "xem khóa học và giáo viên (không thu học phí, không xem doanh thu, lương)",
    "Accountant": "Học viên (chỉ xem), thu học phí, công nợ, doanh thu, lương giáo viên",
    "Teacher": "Chỉ lớp mình dạy: lịch dạy, điểm danh, sổ điểm và lương của mình",
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
        "Ô **Tin cậy chứng chỉ máy chủ (TrustServerCertificate)**: ô tự **bật** khi máy chủ nằm trên chính máy bạn "
        "(`localhost`, Docker hoặc SQL Server cài trên máy; chứng chỉ tự ký) và tự **tắt** với máy chủ khác; khi bạn "
        "bấm vào ô, lựa chọn của bạn được giữ lại. Bật cho máy chủ khác thì ứng dụng hiện cảnh báo, vì người khác "
        "trong mạng có thể giả mạo máy chủ và đọc mật khẩu: chỉ bật với máy chủ bạn tin cậy. Khi tắt, driver "
        "Microsoft kiểm tra chứng chỉ; driver FreeTDS của bản macOS và driver \"SQL Server\" cũ của Windows không "
        "kiểm tra được nên không được dùng, và ứng dụng báo lỗi: hãy cài ODBC Driver 18 hoặc bật ô này nếu bạn "
        "tin cậy máy chủ (trên bản macOS, kết nối khi đó vẫn được mã hóa nhưng máy chủ không được xác minh).",
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
        "giáo viên). Màn hình gồm bốn vùng:")
    g.bullets([
        "**Thanh menu trên cùng** (Windows: ngay dưới tiêu đề cửa sổ; macOS: ở đỉnh màn hình như mọi ứng dụng Mac): "
        "menu **Hệ thống** (đổi mật khẩu, ngôn ngữ, đăng xuất, thoát; quản lý có thêm **Tài khoản** và **Sao lưu**), "
        "một menu cho mỗi nhóm chức năng giống thanh menu bên trái, và menu **Trợ giúp** > **Giới thiệu QLTTTA** "
        "(phiên bản, máy chủ, CSDL, người đang đăng nhập). Chín chức năng đầu có phím tắt **Ctrl+1** … **Ctrl+9** "
        "(trên macOS là **⌘1** … **⌘9**); di chuột lên một mục ở menu bên trái để xem phím tắt của mục đó.",
        "**Thanh menu bên trái**: các chức năng xếp theo nhóm (**CHUNG**, **ĐÀO TẠO**, **TÀI CHÍNH**, **DANH "
        "MỤC**, **HỆ THỐNG**; giáo viên có nhóm **GIẢNG DẠY**). Bấm một mục để mở; chức năng đang mở được tô "
        "sáng. Menu dài thì cuộn bằng con lăn chuột. Cuối thanh menu là họ tên và vai trò của người đang đăng nhập.",
        "**Thanh tiêu đề phía trên**: tên chức năng đang mở, nhãn vai trò, ô chọn ngôn ngữ, nút **Đổi mật "
        "khẩu** và **Đăng xuất**.",
        "**Vùng nội dung**: danh sách, form hoặc trang thống kê của chức năng.",
    ])
    g.figure(SCREENS / "ql_quan_dashboard.png", "Màn hình chính của vai trò Quản lý (trang Tổng quan)")

    g.h2("4.5. Đổi ngôn ngữ giao diện")
    g.p("Chọn **Tiếng Việt** hoặc **English** ở ô có biểu tượng quả địa cầu: ở góc dưới màn hình đăng nhập "
        "hoặc trên thanh tiêu đề của màn hình chính. Màn hình được dựng lại ngay bằng ngôn ngữ mới, người dùng "
        "vẫn đăng nhập và vẫn ở chức năng đang mở; lựa chọn được ghi nhớ cho lần sau. Dữ liệu lưu trong CSDL "
        "(họ tên, tên lớp, tên chi nhánh...) giữ nguyên, không dịch. Trên màn hình chính cũng có thể chọn ở thanh "
        "menu: **Hệ thống** > **Ngôn ngữ**.")

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
        "(ví dụ để đổi sang tài khoản khác); thanh menu có cùng lệnh ở **Hệ thống** > **Đăng xuất**. Đóng cửa sổ chính "
        "hoặc chọn **Hệ thống** > **Thoát** để thoát hẳn ứng dụng.")

    g.h2("4.8. Thao tác chung trên các màn hình danh sách")
    g.p("Hầu hết chức năng (Lớp học, Ghi danh, Thu học phí, Lương giáo viên, các danh mục...) dùng chung một "
        "kiểu màn hình: hàng bộ lọc ở trên, hàng nút thao tác, bảng dữ liệu và dòng tổng ở cuối.")
    g.figure(SCREENS / "ql_quan_outstanding_tuition.png", "Một màn hình danh sách: Công nợ học phí")
    g.table(["Thành phần", "Cách dùng"], [
        ["Bộ lọc riêng của màn hình",
         "Ví dụ chi nhánh, trạng thái, khoảng ngày, tháng/năm: chọn giá trị là danh sách được đọc lại từ CSDL."],
        ["Ô **Lọc nhanh...**",
         "Gõ một phần nội dung bất kỳ (mã, tên, ngày...): danh sách chỉ giữ các dòng có chứa đoạn chữ đó, "
         "không phân biệt hoa/thường. Bấm dấu ✕ trong ô để xóa bộ lọc."],
        ["Hàng nút thao tác",
         "Các nút thay đổi dữ liệu (**Thêm**, **Sửa**, **Hủy**...) chỉ hiện với vai trò được phép. Nút làm việc "
         "trên một dòng chỉ bấm được khi đã chọn dòng đó; ở nhiều màn hình, nhấp đúp vào dòng để mở form sửa."],
        ["Tiêu đề cột", "Bấm để sắp xếp tăng dần, bấm lần nữa để giảm dần. Độ rộng cột tự vừa nội dung; dùng "
                        "thanh cuộn ngang khi bảng có nhiều cột."],
        ["Dòng tổng ở cuối", "Số dòng đang hiển thị và tổng các cột tiền (ví dụ **Tổng đã đóng**, **Tổng còn "
                             "nợ**), tính lại ngay theo bộ lọc."],
        ["Nút **Làm mới**", "Đọc lại dữ liệu mới nhất từ CSDL (khi người khác vừa cập nhật)."],
        ["Nút **Excel**", "Lưu các dòng đang hiển thị ra file `.csv` (mặc định trong thư mục Documents/Tài "
                          "liệu) rồi mở bằng Excel hoặc ứng dụng bảng tính mặc định. File dùng mã UTF-8 nên "
                          "Excel hiển thị đúng tiếng Việt. Số tiền và các số khác được ghi dạng số thuần (ví dụ "
                          "`1500000`, không có dấu chấm và chữ ₫) để Excel cộng, lọc được. Ô bắt đầu bằng `=`, `+` "
                          "hoặc `@` được thêm dấu `'` ở đầu để Excel không chạy nội dung đó như công thức."],
        ["Nút **PDF**", "Tạo báo cáo PDF khổ A4 (tự xoay ngang khi bảng có hơn 7 cột) gồm tiêu đề trung tâm, "
                        "tên báo cáo, ngày lập, người lập, cột STT, dòng **TỔNG CỘNG** và tổng số dòng; mở ngay "
                        "sau khi lưu."],
        ["Nút **In** (Ctrl+P)", "Mở hộp **Xem trước khi in** của cùng báo cáo: xem đúng các trang sẽ in, bấm "
                                "**−**/**+** để thu nhỏ/phóng to, chọn **Nhóm theo** một cột (ví dụ **Tên lớp**) để "
                                "gom các dòng cùng giá trị dưới một dòng tiêu đề nhóm kèm dòng **Cộng nhóm** cho các "
                                "cột tiền, rồi bấm **In...** (hộp thoại in của hệ điều hành) hoặc **Lưu PDF**."],
        ["Menu chuột phải", "Nhấp chuột phải vào một dòng: dòng đó được chọn và menu hiện các nút của màn hình "
                            "(chỉ bấm được khi nút tương ứng bấm được), **Sao chép ô**, **Làm mới**, **Xuất Excel**, "
                            "**Xem trước khi in...**."],
        ["Phím tắt", "**F5** làm mới (macOS: **⌘R**), **Ctrl+F** đưa con trỏ vào ô lọc nhanh, **Ctrl+P** xem trước "
                     "khi in (macOS: **⌘F**, **⌘P**)."],
    ], widths_cm=[4.6, 11.4], caption="Các thành phần của màn hình danh sách", size=10.5)
    g.figure(SCREENS / "kt_minh_report_preview.png", "Hộp Xem trước khi in: công nợ học phí nhóm theo lớp",
             width_cm=14)
    g.tip("Muốn in hoặc gửi một phần danh sách (ví dụ công nợ của một lớp), gõ mã lớp vào ô lọc nhanh rồi "
          "mới bấm **PDF** hoặc **In**: báo cáo chỉ chứa các dòng đang hiển thị, theo thứ tự đang sắp xếp (sắp xếp "
          "theo cột dùng để nhóm thì các nhóm cũng theo thứ tự đó).")

    g.h2("4.9. Form nhập liệu và hộp xác nhận")
    g.bullets([
        "**Form nhập liệu** (thêm, sửa, ghi danh, thu tiền...) gồm các ô có nhãn và hai nút **Lưu** (hoặc tên "
        "thao tác, ví dụ **Ghi danh**, **Thu tiền**) và **Hủy**. Ô ngày có lịch để chọn; ô mã chỉ nhận chữ cái "
        "không dấu, chữ số, `-` và `_`; ô số và ô tiền chỉ nhận giá trị trong khoảng cho phép.",
        "Khi dữ liệu chưa hợp lệ hoặc CSDL từ chối, form **không đóng**: thông báo màu đỏ hiện ngay trên form "
        "(bằng ngôn ngữ giao diện) và những gì đã nhập được giữ nguyên để sửa tiếp.",
        "Thao tác khó hoàn tác (hủy lớp, bảo lưu, khóa tài khoản, chốt lương...) luôn hỏi lại bằng hộp **Xác "
        "nhận**: chọn **Có** để thực hiện, **Không** để bỏ qua.",
        "Sau khi lưu, danh sách được đọc lại và dòng vừa thêm/sửa được chọn sẵn.",
    ])


def chapter5(g):
    g.h1("CHƯƠNG 5. HƯỚNG DẪN THEO CHỨC NĂNG")
    g.p("Mỗi mục dưới đây ghi rõ vai trò được dùng chức năng (theo Bảng 1.1). Ảnh minh họa chụp bằng tài "
        "khoản demo tương ứng, với dữ liệu mẫu. Thứ tự các mục đi theo công việc của trung tâm: tiếp nhận học "
        "viên, mở lớp, ghi danh, thu học phí, dạy - điểm danh - nhập điểm, xét kết quả, trả lương.")

    g.h2("5.1. Tổng quan")
    g.p("*Vai trò: Quản lý, Giáo vụ, Kế toán.* Trang mở đầu sau khi đăng nhập, gồm lời chào, ngày hôm nay, "
        "sáu thẻ số liệu và biểu đồ doanh thu theo tháng của năm hiện tại. Ô **Toàn trung tâm** cho phép xem "
        "số liệu của riêng một chi nhánh. Bấm **Làm mới** để cập nhật số liệu.")
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
             "Trang Tổng quan của Giáo vụ: không có quyền xem doanh thu")

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
        "có trạng thái **Tiềm năng** và được chọn sẵn trong danh sách.",
    ])
    g.h3("5.2.3. Sửa thông tin")
    g.p("Chọn một học viên rồi bấm **Sửa** (hoặc nhấp đúp vào dòng đó). Hộp thoại **Sửa thông tin học viên** "
        "cho phép đổi mọi thông tin trừ mã học viên, kể cả **Trạng thái** (ví dụ chuyển sang **Bảo lưu** hoặc "
        "**Ngừng học**) và **Ngày đăng ký**. Bấm **Lưu** để ghi, **Hủy** để bỏ qua. Trạng thái **Hoàn thành** do "
        "hệ thống tự đặt khi học viên học xong lớp cuối cùng (không còn lớp nào đang học); khi ghi danh lớp mới, "
        "học viên tự chuyển lại **Đang học**. Các ô chữ không cho gõ quá độ dài tối đa của CSDL.")
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
    g.h3("5.2.5. Hồ sơ, ghi danh và kiểm tra xếp lớp từ danh sách học viên")
    g.bullets([
        "**Hồ sơ**: xem thông tin chính, các lần ghi danh (lớp, học phí, đã đóng, trạng thái, kết quả) và các bài "
        "kiểm tra xếp lớp của học viên đang chọn.",
        "**Ghi danh**: mở form ghi danh (mục 5.5) với học viên đang chọn điền sẵn.",
        "**Kiểm tra xếp lớp**: mở form nhập điểm kiểm tra (mục 5.3) với học viên đang chọn điền sẵn.",
    ])
    g.p("Nút **Ghi danh** chỉ hiện với vai trò được ghi danh (mục 5.5), nút **Kiểm tra xếp lớp** chỉ hiện với vai trò "
        "được nhập điểm kiểm tra (mục 5.3); hiện nay đó là Quản lý và Giáo vụ.")
    g.h3("5.2.6. Xuất, nhập danh sách bằng XML")
    g.bullets([
        "**Xuất XML**: lưu học viên của chi nhánh đang chọn ở ô lọc chi nhánh (hoặc của mọi chi nhánh) ra một "
        "file `.xml`, ví dụ để chuyển dữ liệu sang chi nhánh khác.",
        "**Nhập XML**: trước hết chọn chi nhánh nhận học viên ở ô **Tất cả chi nhánh**, rồi bấm **Nhập XML** và "
        "chọn file. Ứng dụng hỏi lại **Nhập học viên từ <file> vào <chi nhánh>?**; khi xong, thông báo số học "
        "viên đã nhập và số bị bỏ qua (trùng số điện thoại/email, hoặc thiếu họ tên/ngày sinh).",
    ])

    g.h2("5.3. Kiểm tra xếp lớp")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Danh sách các bài kiểm tra đầu vào: mã bài, ngày kiểm tra, học viên, "
        "điểm **Nghe**, **Nói**, **Đọc**, **Viết**, **Điểm chung** (trung bình 4 kỹ năng, do CSDL tính) và "
        "**Khóa đề xuất** (khóa học phù hợp với điểm, do CSDL chọn).")
    g.figure(SCREENS / "gvu_lan_placement_tests.png", "Danh sách bài kiểm tra xếp lớp")
    g.steps([
        "Bấm **Thêm bài kiểm tra**. Form **Bài kiểm tra xếp lớp mới** mở ra.",
        "Gõ mã, họ tên hoặc SĐT vào ô **Tìm học viên**, bấm **Tìm**, rồi chọn đúng người ở ô **Học viên**.",
        "Nhập điểm **Nghe**, **Nói**, **Đọc**, **Viết** (0 đến 10); chọn **Người chấm** (hoặc **Không ghi "
        "nhận**), **Ngày kiểm tra** và ghi chú nếu có.",
        "Bấm **Lưu**. Ứng dụng báo điểm chung và khóa học đề xuất, ví dụ **Bài PT00045: điểm chung 5,13. Khóa "
        "học đề xuất: TOEIC 750+**.",
    ])
    g.tip("Điểm kiểm tra **gần nhất** của học viên được dùng khi ghi danh vào khóa học có yêu cầu điểm đầu vào.")

    g.h2("5.4. Lớp học")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Danh sách lớp với mã lớp, tên lớp, khóa học, chi nhánh, giáo viên, phòng, "
        "lịch học trong tuần, ngày khai giảng và kết thúc, sĩ số/tối đa, học phí, trạng thái. Lọc theo chi nhánh "
        "và trạng thái ở hai ô đầu. Lớp **Đang học** xếp trước, rồi đến lớp **Đang tuyển sinh**, cuối cùng là "
        "các lớp khác; trong mỗi nhóm lớp mới khai giảng đứng trên.")
    g.figure(SCREENS / "gvu_lan_classes.png", "Màn hình Lớp học và các nút quản lý vòng đời lớp")
    g.p("Một lớp đi qua các bước sau, mỗi bước là một nút trên màn hình:")
    g.steps([
        "**Mở lớp**: nhập **Tên lớp**, chọn **Khóa học**, **Chi nhánh**, **Giáo viên chính**, **Phòng** (chỉ "
        "phòng của chi nhánh đã chọn), **Khai giảng**, **Sĩ số tối đa**; **Học phí** điền sẵn theo khóa học. "
        "Bấm **Lưu**: lớp mới có trạng thái **Đang tuyển sinh** và ứng dụng nhắc bước tiếp theo. Chi nhánh phải "
        "đang hoạt động và phòng không được ở trạng thái **Bảo trì**.",
        "**Lịch tuần**: chọn **Thứ**, giờ **Từ** - **Đến** rồi bấm **Lưu khung giờ**; mỗi thứ một khung giờ, "
        "lưu lại một thứ đã có thì đổi giờ của thứ đó. Chọn một dòng rồi bấm **Xóa khung giờ** để bỏ. Mỗi thay "
        "đổi xóa các buổi học đã sinh; khi đóng cửa sổ, ứng dụng hỏi **Sinh các buổi học của lớp ... theo lịch "
        "tuần?** để sinh lại theo lịch mới. Khi lớp đã có buổi **Đã dạy** hoặc **Đã hủy** thì lịch tuần không đổi "
        "được nữa.",
        "**Sinh buổi học**: tạo đủ số buổi của khóa học theo lịch tuần, bắt đầu từ ngày khai giảng; ứng dụng "
        "báo số buổi đã tạo và ngày của buổi cuối (cũng là ngày kết thúc lớp). Chạy lại thì các buổi cũ được "
        "thay thế, nên chỉ chạy lại được khi chưa có buổi nào **Đã dạy** hoặc **Đã hủy**.",
        "Ghi danh học viên (mục 5.5), rồi **Bắt đầu học** khi lớp khai giảng: lớp chuyển sang **Đang học**.",
        "Hết khóa, khi không còn buổi **Chưa dạy**, bấm **Đánh giá kết quả**: mỗi học viên nhận điểm tổng kết và "
        "**Đạt**/**Không đạt**, học viên đạt được cấp chứng chỉ, lớp chuyển sang **Đã kết thúc** và bảng kết "
        "quả mở ra. Sau bước này điểm và điểm danh của lớp không sửa được nữa.",
    ])
    g.bullets([
        "**Sửa**: đổi tên lớp, giáo viên chính, phòng, ngày khai giảng, sĩ số tối đa, học phí (khóa học và chi "
        "nhánh giữ nguyên). Các buổi **Chưa dạy** từ hôm nay trở đi theo giáo viên và phòng mới; buổi đã qua giữ "
        "giáo viên đã dạy buổi đó. Đổi ngày khai giảng thì các buổi "
        "đã sinh bị xóa và ứng dụng sinh lại từ ngày mới. Học phí mới chỉ áp dụng cho các lần ghi danh sau.",
        "**Hủy lớp**: chỉ khi lớp chưa có học viên đóng tiền; các ghi danh đang mở chuyển sang **Đã nghỉ**.",
        "**Học viên** và **Kết quả**: xem danh sách học viên của lớp và bảng kết quả (điểm tổng kết, xếp loại, "
        "chuyên cần, số chứng chỉ), có nút **Excel**/**PDF**.",
    ])
    g.table(["Thao tác", "Quy tắc CSDL kiểm tra"], [
        ["Mở lớp, sửa lớp",
         "Khóa học **Đang mở**, giáo viên **Đang dạy**, chi nhánh đang hoạt động (**Chi nhánh không tồn tại hoặc "
         "đang tạm ngừng**); phòng thuộc chi nhánh của lớp, không **Bảo trì** (**Phòng đang bảo trì; hãy chọn "
         "phòng khác**) và đủ chỗ cho sĩ số tối đa; sĩ số tối đa không nhỏ hơn số học viên đang học; chỉ đổi ngày khai giảng khi lớp **Đang tuyển "
         "sinh** và chưa có buổi nào đã dạy hoặc đã hủy; ngày khai giảng mới không làm học viên của lớp bị trùng "
         "lịch với lớp khác của họ."],
        ["Lịch tuần", "Chỉ với lớp **Đang tuyển sinh** hoặc **Đang học** và chưa có buổi đã dạy hoặc đã hủy "
                      "(**Lịch tuần của lớp đã có buổi đã dạy hoặc đã hủy thì không thể thay đổi nữa**); giờ học "
                      "trong khoảng 07:00-22:00; không trùng phòng, không trùng giáo viên với lớp khác cùng thứ "
                      "và cùng giờ; không làm học viên của lớp bị trùng lịch với lớp khác của họ."],
        ["Bắt đầu / hủy lớp",
         "Lớp đi theo thứ tự **Đang tuyển sinh** → **Đang học** → **Đã kết thúc**, hoặc **Đã hủy**. Lớp đã kết "
         "thúc hoặc đã hủy không mở lại được: hãy mở lớp mới."],
        ["Đánh giá kết quả",
         "Không còn buổi **Chưa dạy**; tổng trọng số các cột điểm của khóa học bằng 100%. Đạt khi điểm tổng kết "
         "từ 5 và chuyên cần từ 80%."],
    ], widths_cm=[3.6, 12.4], caption="Quy tắc CSDL kiểm tra khi quản lý lớp học", size=10)

    g.h2("5.5. Ghi danh")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Mọi lượt ghi danh: mã ghi danh, học viên, lớp, khóa học, chi nhánh, ngày "
        "ghi danh, học phí phải đóng, đã đóng, còn nợ, trạng thái, điểm tổng kết và kết quả. Lọc theo trạng thái "
        "ở ô **Tất cả trạng thái**; dòng tổng cho biết **Tổng đã đóng** và **Tổng còn nợ**.")
    g.figure(SCREENS / "gvu_lan_enrollments.png", "Danh sách ghi danh")
    g.steps([
        "Bấm **Ghi danh mới**.",
        "Gõ mã, họ tên hoặc SĐT vào ô **Tìm học viên**, bấm **Tìm**, chọn **Học viên**.",
        "Chọn **Lớp** (chỉ các lớp **Đang tuyển sinh** hoặc **Đang học**); dòng bên dưới cho biết học phí và số "
        "chỗ còn trống.",
        "Kiểm tra **Ngày ghi danh** (hôm nay hoặc một ngày đã qua khi nhập lại phiếu giấy, không chọn được ngày "
        "trong tương lai), chọn **Khuyến mãi** nếu có (chỉ các khuyến mãi còn hiệu lực vào ngày ghi danh) rồi bấm "
        "**Ghi danh**.",
    ])
    g.bullets([
        "**Chuyển lớp**: chọn lượt ghi danh, bấm **Chuyển lớp**, chọn lớp ở ô **Lớp mới** (chỉ các lớp cùng khóa "
        "học, cùng chi nhánh còn chỗ) rồi bấm **Chuyển lớp**. Các khoản đã đóng được giữ nguyên, học phí theo "
        "lớp mới và chuyên cần được tính lại từ ngày chuyển.",
        "**Bảo lưu**, **Học lại**, **Nghỉ học**: đổi trạng thái lượt ghi danh sau khi xác nhận. Học viên không "
        "còn lớp nào đang học thì tự chuyển sang **Bảo lưu** (hoặc **Ngừng học** khi nghỉ học); học lại thì "
        "chuyển về **Đang học**.",
    ])
    g.table(["Thao tác", "Quy tắc CSDL kiểm tra"], [
        ["Ghi danh",
         "Học viên chưa **Ngừng học** và chưa có trong lớp; lớp **Đang tuyển sinh** hoặc **Đang học** và còn chỗ; "
         "không trùng giờ với lớp khác học viên đang học; mã khuyến mãi còn hiệu lực. Khóa có điều kiện đầu vào: "
         "học viên phải **Đạt** khóa tiên quyết, hoặc có bài kiểm tra xếp lớp gần nhất đủ điểm tối thiểu (chỉ khi "
         "khóa có quy định điểm tối thiểu)."],
        ["Chuyển lớp",
         "Chỉ chuyển lượt ghi danh **Đang học** hoặc **Bảo lưu**, sang lớp **cùng khóa học và cùng chi nhánh** "
         "đang tuyển sinh hoặc đang học, còn chỗ và không trùng giờ. Nếu học viên đã đóng nhiều hơn học phí mới "
         "thì phải hủy bớt phiếu thu trước. Điểm danh ở lớp cũ bị xóa."],
        ["Bảo lưu, học lại, nghỉ học",
         "Không đổi được lượt ghi danh đã **Hoàn thành**; học lại chỉ khi không trùng giờ với lớp khác của học viên."],
    ], widths_cm=[3.6, 12.4], caption="Quy tắc CSDL kiểm tra khi ghi danh và chuyển lớp", size=10)

    g.h2("5.6. Lịch học - điểm danh")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Các buổi học của một tuần (thứ Hai đến Chủ nhật): ngày học, giờ bắt đầu, "
        "giờ kết thúc, lớp, buổi thứ mấy, phòng, giáo viên, nội dung và trạng thái (**Chưa dạy**, **Đã dạy**, "
        "**Đã hủy**). Dùng hai nút mũi tên để sang **Tuần trước**/**Tuần sau**, nút **Tuần này** để quay về "
        "tuần hiện tại; gõ tên phòng hoặc giáo viên vào ô lọc nhanh để xem lịch của một phòng/một giáo viên.")
    g.figure(SCREENS / "gvu_lan_weekly_schedule.png", "Lịch học - điểm danh của một tuần")
    g.bullets([
        "**Cập nhật buổi học**: chọn **Trạng thái** (ví dụ **Đã dạy** sau khi dạy xong, **Đã hủy** khi nghỉ) "
        "và ghi **Nội dung** bài học. Chỉ đánh dấu **Đã dạy** từ ngày học trở đi; buổi đã dạy không đổi lại được.",
        "**Điểm danh** (hoặc nhấp đúp vào buổi học): mỗi học viên của lớp một dòng; chọn **Có mặt**, **Đi trễ**, "
        "**Vắng có phép** hoặc **Vắng không phép** và ghi chú nếu cần. Nút **Tất cả có mặt** chọn nhanh cho cả "
        "lớp; bấm **Lưu điểm danh** để ghi. Học viên chưa được điểm danh hiện chữ **(chưa lưu)** sau họ tên.",
    ])
    g.tip("Chỉ **Có mặt** và **Đi trễ** được tính là có đi học; học viên cần chuyên cần từ 80% để đạt.")

    g.h2("5.7. Sổ điểm")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Bảng điểm của một lớp: mỗi học viên một dòng, mỗi cột điểm của khóa học "
        "(kèm trọng số) một cột và cột **Điểm TK** (điểm tổng kết theo trọng số, để trống khi còn thiếu điểm).")
    g.figure(SCREENS / "gvu_lan_grade_book.png", "Sổ điểm của một lớp")
    g.steps([
        "Chọn lớp ở ô **Lớp**.",
        "Nhấp đúp vào ô điểm, nhập điểm từ 0 đến 10 (tối đa 2 chữ số thập phân) rồi Enter; làm tiếp với các ô "
        "khác. Dòng cuối cho biết số điểm chưa lưu; điểm ngoài khoảng 0-10 không được nhận và dòng cuối báo lý "
        "do.",
        "Bấm **Lưu điểm**: mọi điểm vừa nhập được lưu cùng lúc (lỗi một điểm thì không điểm nào được lưu). Đổi "
        "sang lớp khác khi còn điểm chưa lưu thì ứng dụng hỏi có lưu không; nếu lưu không được, sổ điểm ở lại "
        "lớp cũ và giữ nguyên các điểm vừa nhập. Bấm **Làm mới** để đọc lại cả danh sách lớp (lớp vừa mở "
        "hoặc vừa kết thúc ở màn hình khác).",
    ])
    g.bullets([
        "Lớp **Đã kết thúc** thì điểm đã chốt: bảng chỉ để xem. Điểm tổng kết dưới 5 hiện màu đỏ; từ 5 trở "
        "lên chưa chắc **Đạt** vì còn cần chuyên cần từ 80%."
        "Khi tổng trọng số các cột điểm khác 100%, màn hình hiện cảnh báo: lớp chưa thể đánh giá kết quả cho "
        "đến khi quản lý sửa cột điểm của khóa học (mục 5.13).",
        "Mọi lần sửa điểm được CSDL ghi vào nhật ký (điểm cũ, điểm mới, người sửa, thời điểm).",
    ])

    g.h2("5.8. Kết quả học tập")
    g.p("*Vai trò: Quản lý, Giáo vụ.* Kết quả của từng học viên trong từng lớp: điểm tổng kết (**Điểm TK**), "
        "xếp loại (Xuất sắc, Giỏi, Khá, Trung bình), tỷ lệ chuyên cần (%), kết quả (**Đạt**/**Không đạt**) và "
        "trạng thái ghi danh. Sắp xếp theo mã lớp rồi họ tên; gõ mã lớp vào ô lọc nhanh để xem bảng điểm một "
        "lớp và xuất PDF.")
    g.figure(SCREENS / "gvu_lan_learning_results.png", "Kết quả học tập")

    g.h2("5.9. Thu học phí")
    g.p("*Vai trò: Quản lý, Kế toán.* Danh sách phiếu thu trong khoảng ngày chọn ở ô **Từ** ... **đến** (mặc "
        "định ba tháng gần nhất), lọc thêm theo trạng thái (**Hợp lệ**, **Đã hủy**). Dòng tổng cho biết tổng số "
        "tiền của các phiếu đang hiển thị.")
    g.figure(SCREENS / "kt_minh_tuition.png", "Danh sách phiếu thu (Kế toán)")
    g.steps([
        "Bấm **Thu tiền**. Form **Thu học phí** liệt kê các lượt ghi danh còn nợ; gõ vào ô **Lọc theo học viên, "
        "lớp hoặc mã ghi danh...** để tìm nhanh rồi chọn một dòng.",
        "Ô **Số tiền** điền sẵn số còn nợ (không nhập được số lớn hơn); sửa lại nếu học viên đóng một phần.",
        "Chọn **Hình thức** (**Tiền mặt**, **Chuyển khoản**, **Thẻ**), ghi **Nội dung** rồi bấm **Thu tiền**.",
        "Ứng dụng hỏi **Đã lập phiếu thu <số>. In phiếu ngay?** - chọn **Có** để mở phiếu thu (khổ A5) trong hộp "
        "**Xem trước khi in**: bấm **In...** để in ra máy in, hoặc **Lưu PDF** để lưu file (mặc định trong thư mục "
        "Documents/Tài liệu) và mở ra.",
    ])
    g.bullets([
        "**In phiếu thu**: mở lại phiếu đang chọn trong hộp xem trước để in hoặc lưu PDF (phiếu đã hủy có chữ "
        "**ĐÃ HỦY**).",
        "**Hủy phiếu thu**: nhập **Lý do** (bắt buộc) rồi bấm **Hủy phiếu thu**. Phiếu không bị xóa mà chuyển "
        "sang **Đã hủy**; số tiền không còn được tính là đã đóng.",
    ])
    g.warning("Phiếu thu không bao giờ bị xóa, kể cả với quản lý; mọi lần lập và hủy phiếu được CSDL ghi vào "
              "nhật ký. Giáo vụ không thu học phí nên không có chức năng này.")

    g.h2("5.10. Công nợ học phí")
    g.p("*Vai trò: Quản lý, Giáo vụ, Kế toán.* Các lượt ghi danh **còn nợ học phí**, số nợ lớn nhất đứng đầu: "
        "mã ghi danh, học viên, số liên lạc, lớp, ngày ghi danh, học phí, đã đóng, còn nợ và số ngày kể từ khi "
        "ghi danh. Dòng tổng cho biết **Tổng đã đóng** và **Tổng còn nợ** của các dòng đang hiển thị (ảnh ở "
        "mục 4.8). Dùng danh sách này để nhắc học viên đóng học phí.")

    g.h2("5.11. Doanh thu")
    g.p("*Vai trò: Quản lý, Kế toán.* Ô đầu tiên chọn cách xem:")
    g.bullets([
        "**Theo tháng**: năm, tháng, chi nhánh, số phiếu thu và doanh thu; tháng gần nhất đứng đầu.",
        "**Theo khóa học, trong một khoảng thời gian**: chọn từ ngày - đến ngày (mặc định từ đầu tháng tới hôm "
        "nay) và chi nhánh; doanh thu được gom theo chi nhánh, chương trình và khóa học.",
    ])
    g.p("Dòng tổng cho biết **Tổng doanh thu**. Chỉ phiếu thu **Hợp lệ** được tính.")
    g.figure(SCREENS / "kt_minh_revenue.png", "Doanh thu theo tháng và chi nhánh (Kế toán)")

    g.h2("5.12. Lương giáo viên")
    g.p("*Vai trò: Quản lý, Kế toán.* Bảng lương theo tháng của từng giáo viên: số buổi, số giờ, đơn giá mỗi "
        "giờ, thưởng, khấu trừ, tổng lương và trạng thái (**Đã chốt** hoặc **Đã chi trả**). Lọc theo năm và tháng; "
        "dòng tổng cộng thưởng, khấu trừ và tổng lương của các dòng đang hiển thị.")
    g.figure(SCREENS / "kt_minh_payroll.png", "Bảng lương giáo viên (Kế toán)")
    g.bullets([
        "**Chốt lương tháng**: chọn **Tháng**, **Năm** (mặc định tháng trước) rồi bấm **Chốt lương**. CSDL đếm "
        "các buổi **Đã dạy** của từng giáo viên trong tháng, tính số giờ, thưởng 500.000 đ khi dạy từ 20 buổi. "
        "Có thể chốt lại một tháng (ví dụ khi vừa cập nhật buổi dạy, hoặc chốt tạm tháng đang chạy để xem trước); "
        "các dòng đã chi trả không bị thay đổi, khoản khấu trừ đã nhập được giữ (lương không được thấp hơn khoản "
        "khấu trừ). Không chốt được tháng chưa tới.",
        "**Khấu trừ**: nhập số tiền khấu trừ của dòng đang chọn (không lớn hơn lương của tháng); tổng lương do "
        "CSDL tính lại: số giờ × đơn giá + thưởng - khấu trừ.",
        "**Đã chi trả**: ghi nhận đã trả lương sau khi xác nhận, chỉ khi tháng đó đã kết thúc (các buổi dạy cuối "
        "tháng còn được tính). Dòng đã chi trả không thể thay đổi nữa.",
    ])

    g.h2("5.13. Danh mục")
    g.p("*Vai trò: Quản lý (thêm, sửa); Giáo vụ xem **Khóa học** và **Giáo viên**.* Các danh mục là dữ liệu "
        "nền mà các chức năng khác dùng. Mục danh mục không bị xóa mà chuyển sang trạng thái ngừng (ví dụ "
        "**Tạm ngưng**, **Ngừng mở**, **Đã nghỉ**) để giữ lịch sử; mục ngừng không còn hiện trong các ô chọn.")
    g.h3("5.13.1. Khóa học")
    g.p("Danh sách khóa học (mã, tên, chương trình, trình độ, số buổi, phút/buổi, học phí, điểm đầu vào tối "
        "thiểu, khóa tiên quyết, trạng thái). Bảng dưới là các **cột điểm** của khóa đang chọn và trọng số.")
    g.figure(SCREENS / "ql_quan_courses.png", "Danh mục khóa học và cột điểm của khóa đang chọn")
    g.bullets([
        "**Thêm khóa học**, **Sửa khóa học**: mã khóa (chữ không dấu, số, `-`, `_`), chương trình, tên, trình "
        "độ (CEFR), số buổi, phút/buổi, học phí, **Điểm đầu vào** và **Khóa tiên quyết**. Học viên được vào học "
        "khi đã đạt khóa tiên quyết hoặc đạt điểm đầu vào ở bài kiểm tra xếp lớp gần nhất. CSDL từ chối khóa "
        "tiên quyết tạo thành vòng (A cần B, B lại cần A) và không cho **Ngừng mở** khóa còn lớp đang hoạt động.",
        "**Thêm cột điểm**, **Sửa cột điểm**, **Xóa cột điểm** (bên phải tiêu đề bảng cột điểm): tổng trọng số "
        "phải bằng 100% trước khi đánh giá kết quả lớp. Không xóa được cột đã có điểm; khóa học đã có lớp được "
        "đánh giá thì cột điểm bị khóa (hãy mở khóa học mới).",
        "**Giáo trình**: xem các bài học của khóa (lấy từ tài liệu XML của khóa); quản lý bấm **Sửa XML** để sửa "
        "tài liệu, CSDL kiểm tra tài liệu theo XML Schema của trung tâm.",
        "**Tìm theo kỹ năng**: nhập kỹ năng (ví dụ `Speaking`) để tìm các khóa có luyện kỹ năng đó.",
        "**Chương trình**: danh sách chương trình đào tạo; quản lý thêm, sửa chương trình tại đây.",
    ])
    g.h3("5.13.2. Giáo viên, Nhân viên")
    g.bullets([
        "**Thêm giáo viên**, **Sửa**: họ tên, ngày sinh, giới tính, quốc tịch, điện thoại, email, học vị, loại "
        "giáo viên (Việt Nam / Bản ngữ), đơn giá/giờ, chi nhánh, ngày vào làm, trạng thái và **Hồ sơ (XML)** "
        "(chứng chỉ, kinh nghiệm). Mã `TE...` được sinh tự động. **Tìm theo chứng chỉ**: ví dụ IELTS từ 8.0 trở lên.",
        "**Thêm nhân viên**, **Sửa**: họ tên, ngày sinh, giới tính, điện thoại, email, địa chỉ, chức vụ, chi "
        "nhánh, ngày vào làm, lương cơ bản, trạng thái. Mã `EM...` được sinh tự động.",
        "Người từ 18 tuổi trở lên vào ngày vào làm; điện thoại, email không trùng. Không chuyển sang **Đã nghỉ** "
        "khi tài khoản đăng nhập còn hoạt động (khóa tài khoản trước, mục 5.14) hoặc giáo viên còn là giáo viên "
        "chính của lớp đang hoạt động (đổi giáo viên của lớp trước, mục 5.4).",
    ])
    g.h3("5.13.3. Chi nhánh - phòng học, Khuyến mãi")
    g.bullets([
        "**Thêm chi nhánh**, **Sửa chi nhánh**: mã, tên, địa chỉ, điện thoại, email, ngày thành lập, trạng thái. "
        "Không **Tạm ngưng** chi nhánh còn lớp đang hoạt động.",
        "Bảng **Phòng học của <chi nhánh>** ở dưới: **Thêm phòng**, **Sửa phòng** (mã, chi nhánh, tên, sức "
        "chứa, loại phòng, trạng thái **Sẵn sàng**/**Bảo trì**). Phòng đang dùng cho lớp hoạt động phải giữ "
        "chi nhánh và đủ chỗ cho sĩ số tối đa của lớp.",
        "**Thêm khuyến mãi**, **Sửa**: mã, tên, **Loại giảm giá** (**Phần trăm**, tối đa 50%, hoặc **Số tiền**), "
        "**Mức giảm**, **Hiệu lực từ** - **Hiệu lực đến**. Muốn ngừng sớm thì sửa ngày hết hiệu lực; các lượt "
        "ghi danh trước đó giữ nguyên số tiền đã giảm. Khi đã có học viên dùng khuyến mãi thì không đổi được loại "
        "giảm giá, mức giảm và ngày bắt đầu (chuyển lớp sẽ áp lại khuyến mãi), và ngày hết hiệu lực không được "
        "trước lần ghi danh cuối cùng đã dùng nó; tên thì vẫn đổi được.",
    ])
    g.figure(SCREENS / "ql_quan_branches.png", "Chi nhánh và phòng học của chi nhánh đang chọn")

    g.h2("5.14. Tài khoản")
    g.p("*Vai trò: Quản lý.* Danh sách tài khoản đăng nhập: tên đăng nhập, vai trò, họ tên nhân viên/giáo "
        "viên, trạng thái (**Hoạt động** hoặc **Đã khóa**), ngày tạo và lần đăng nhập cuối (hiển thị theo múi giờ "
        "của máy tính đang chạy ứng dụng).")
    g.figure(SCREENS / "ql_quan_accounts.png", "Danh sách tài khoản (Quản lý)")
    g.bullets([
        "**Tạo tài khoản**: chọn **Vai trò** (" + ", ".join(ROLES[role] for role in ROLE_CODES.values())
        + "), chọn **Nhân viên hoặc giáo viên** chưa có tài khoản (vai trò Giáo viên chọn giáo viên, các vai trò "
        "khác chọn nhân viên), nhập **Tên đăng nhập**, **Mật khẩu**, **Nhập lại mật khẩu** rồi bấm **Lưu**. Tên "
        "đăng nhập chỉ gồm chữ cái không dấu, chữ số, dấu chấm và dấu gạch dưới, ít nhất 3 ký tự; mật khẩu ít "
        "nhất 8 ký tự. Tài khoản là người dùng SQL Server: SQL Server lưu mật khẩu (dạng băm).",
        "**Khóa** / **Mở khóa**: tài khoản bị khóa không đăng nhập được nữa (thông báo ở mục 4.3). Không khóa "
        "được tài khoản đang dùng để đăng nhập.",
        "**Đặt lại mật khẩu**: nhập **Mật khẩu mới** hai lần cho người quên mật khẩu.",
        "Không tạo được tài khoản cho nhân viên hoặc giáo viên đã nghỉ.",
    ])

    g.h2("5.15. Sao lưu")
    g.p("*Vai trò: Quản lý.* Sao lưu CSDL `QLTTTA` ngay trên máy chủ SQL Server:")
    g.steps([
        "Chọn **Loại**: **Sao lưu toàn bộ (FULL)**, **Sao lưu vi sai (DIFF)** (phần thay đổi từ bản FULL gần "
        "nhất) hoặc **Sao lưu nhật ký giao dịch (LOG)** (cần có một bản FULL trước).",
        "Để trống ô **Thư mục trên máy chủ** để dùng thư mục sao lưu mặc định của máy chủ, hoặc nhập một thư "
        "mục **trên máy chủ SQL Server** (không phải trên máy đang chạy ứng dụng).",
        "Bấm **Sao lưu**. Ứng dụng báo đường dẫn file SQL Server đã ghi; các bản sao lưu trong phiên làm việc "
        "được liệt kê bên dưới.",
    ])
    g.figure(SCREENS / "ql_quan_backup.png", "Màn hình sao lưu cơ sở dữ liệu")
    g.p("Khôi phục (restore) làm trong SSMS hoặc bằng lệnh `RESTORE` theo thứ tự: bản FULL gần nhất, rồi bản "
        "DIFF gần nhất, rồi các file LOG theo thứ tự thời gian.")

    g.h2("5.16. Chức năng dành cho giáo viên")
    g.p("*Vai trò: Giáo viên.* Giáo viên chỉ thấy dữ liệu của chính mình (CSDL lọc theo tài khoản đăng nhập):")
    g.bullets([
        "**Lớp của tôi**: các lớp được phân công, kèm khóa học, phòng, chi nhánh, ngày khai giảng/kết thúc, sĩ "
        "số và trạng thái. Nút **Học viên** (hoặc nhấp đúp vào lớp) xem danh sách học viên kèm chuyên cần; nút "
        "**Giáo trình** xem các bài học của khóa.",
        "**Lịch dạy**: các buổi dạy của mình theo tuần, với **Cập nhật buổi học** và **Điểm danh** như mục 5.6. "
        "Giáo viên chỉ cập nhật và điểm danh các buổi do chính mình dạy.",
        "**Sổ điểm của tôi**: nhập điểm các lớp mình dạy, cách dùng như mục 5.7.",
        "**Lương của tôi**: bảng lương từng tháng (số buổi, số giờ, đơn giá, thưởng, khấu trừ, tổng lương, "
        "trạng thái).",
    ])
    g.figure(SCREENS / "gv_john_my_teaching_schedule.png", "Lịch dạy của giáo viên")
    g.figure(SCREENS / "gv_john_my_grade_book.png", "Sổ điểm của giáo viên")

    g.h2("5.17. Việc vẫn làm trong SSMS")
    g.p("Mọi nghiệp vụ hằng ngày đã có trên ứng dụng. Một số việc quản trị ít dùng vẫn làm trong SSMS hoặc VS "
        "Code, chọn CSDL `QLTTTA`:")
    g.bullets([
        "Xem nhật ký thay đổi điểm và phiếu thu: bảng `AUDIT_LOG` (chỉ đọc, không ai sửa hay xóa được). Tài "
        "khoản quản lý đọc được bảng này.",
        "Khôi phục CSDL từ các bản sao lưu (mục 5.15): cần quản trị viên SQL Server (tài khoản `sa` hoặc đăng "
        "nhập Windows như mục 2.3.4), vì lệnh `RESTORE` tạo lại cả CSDL; tài khoản quản lý của ứng dụng không "
        "có quyền này.",
        "Xóa hẳn chi nhánh, khóa học, giáo viên, nhân viên: ứng dụng chỉ chuyển sang trạng thái ngừng để giữ "
        "lịch sử. Việc xóa hẳn cũng cần quản trị viên SQL Server (tài khoản quản lý không có quyền DELETE trên "
        "các bảng này), và CSDL vẫn từ chối xóa dòng đã có lịch sử (lớp, ghi danh, phiếu thu...).",
    ])
    g.p("Tham số và ví dụ của từng thủ tục nằm trong `database/04_procedures.sql` và Chương 4 của báo cáo đồ án.")
