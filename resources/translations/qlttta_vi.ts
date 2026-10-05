<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="vi_VN" sourcelanguage="en">
<context>
    <name>AccountPage</name>
    <message>
        <source>New account</source>
        <translation>Tạo tài khoản</translation>
    </message>
    <message>
        <source>Lock</source>
        <translation>Khóa</translation>
    </message>
    <message>
        <source>Unlock</source>
        <translation>Mở khóa</translation>
    </message>
    <message>
        <source>Reset password</source>
        <translation>Đặt lại mật khẩu</translation>
    </message>
    <message>
        <source>e.g. gvu_hoa (letters without diacritics, digits, . and _)</source>
        <translation>VD: gvu_hoa (chữ không dấu, số, . và _)</translation>
    </message>
    <message>
        <source>Role</source>
        <translation>Vai trò</translation>
    </message>
    <message>
        <source>Employee or teacher</source>
        <translation>Nhân viên hoặc giáo viên</translation>
    </message>
    <message>
        <source>Username</source>
        <translation>Tên đăng nhập</translation>
    </message>
    <message>
        <source>Password</source>
        <translation>Mật khẩu</translation>
    </message>
    <message>
        <source>Confirm password</source>
        <translation>Nhập lại mật khẩu</translation>
    </message>
    <message>
        <source>SQL Server stores the password (hashed); the person signs in with this username and password.</source>
        <translation>SQL Server lưu mật khẩu (dạng băm); người dùng đăng nhập bằng tên đăng nhập và mật khẩu này.</translation>
    </message>
    <message>
        <source>Lock account %1? The person can no longer sign in.</source>
        <translation>Khóa tài khoản %1? Người dùng sẽ không đăng nhập được nữa.</translation>
    </message>
    <message>
        <source>Unlock account %1?</source>
        <translation>Mở khóa tài khoản %1?</translation>
    </message>
    <message>
        <source>Reset the password of %1</source>
        <translation>Đặt lại mật khẩu của %1</translation>
    </message>
    <message>
        <source>New password</source>
        <translation>Mật khẩu mới</translation>
    </message>
    <message>
        <source>Confirm new password</source>
        <translation>Nhập lại mật khẩu mới</translation>
    </message>
</context>
<context>
    <name>AccountService</name>
    <message>
        <source>No account is selected.</source>
        <translation>Chưa chọn tài khoản.</translation>
    </message>
    <message>
        <source>The password must be at least %1 characters long.</source>
        <translation>Mật khẩu phải có ít nhất %1 ký tự.</translation>
    </message>
    <message>
        <source>The password and its confirmation do not match.</source>
        <translation>Mật khẩu nhập lại không khớp.</translation>
    </message>
</context>
<context>
    <name>AttendanceDialog</name>
    <message>
        <source>Attendance</source>
        <translation>Điểm danh</translation>
    </message>
    <message>
        <source>Attendance - %1</source>
        <translation>Điểm danh - %1</translation>
    </message>
    <message>
        <source>Students without a saved mark show Present. Present and Late count as attended (at least 80% are needed to pass).</source>
        <translation>Học viên chưa được điểm danh hiển thị là Có mặt. Có mặt và Đi trễ được tính là có đi học (cần ít nhất 80% để đạt).</translation>
    </message>
    <message>
        <source>Student ID</source>
        <translation>Mã học viên</translation>
    </message>
    <message>
        <source>Full name</source>
        <translation>Họ tên</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>Notes</source>
        <translation>Ghi chú</translation>
    </message>
    <message>
        <source>All present</source>
        <translation>Tất cả có mặt</translation>
    </message>
    <message>
        <source>Save attendance</source>
        <translation>Lưu điểm danh</translation>
    </message>
    <message>
        <source>Close</source>
        <translation>Đóng</translation>
    </message>
    <message>
        <source>%1 (not saved yet)</source>
        <translation>%1 (chưa lưu)</translation>
    </message>
</context>
<context>
    <name>AuthService</name>
    <message>
        <source>Please enter your username and password.</source>
        <translation>Vui lòng nhập tên đăng nhập và mật khẩu.</translation>
    </message>
    <message>
        <source>The database server is not configured.</source>
        <translation>Chưa cấu hình máy chủ CSDL.</translation>
    </message>
    <message>
        <source>The account is locked.</source>
        <translation>Tài khoản đã bị khóa.</translation>
    </message>
    <message>
        <source>Valid SQL Server account, but no role is assigned to it in the system.</source>
        <translation>Tài khoản SQL Server hợp lệ nhưng chưa được gán vai trò trong hệ thống.</translation>
    </message>
    <message>
        <source>You are not logged in.</source>
        <translation>Bạn chưa đăng nhập.</translation>
    </message>
    <message>
        <source>The new password must be at least 8 characters long.</source>
        <translation>Mật khẩu mới tối thiểu 8 ký tự.</translation>
    </message>
    <message>
        <source>The password confirmation does not match.</source>
        <translation>Mật khẩu nhập lại không khớp.</translation>
    </message>
    <message>
        <source>The new password must differ from the old one.</source>
        <translation>Mật khẩu mới phải khác mật khẩu cũ.</translation>
    </message>
</context>
<context>
    <name>BackupPage</name>
    <message>
        <source>Back up the database</source>
        <translation>Sao lưu cơ sở dữ liệu</translation>
    </message>
    <message>
        <source>FULL: the whole database. DIFF: what changed since the last full backup. LOG: the transaction log since the last log backup (needs a full backup first). Restore = the last FULL, then the last DIFF, then the LOG files in order.</source>
        <translation>FULL: toàn bộ cơ sở dữ liệu. DIFF: phần thay đổi từ lần sao lưu FULL gần nhất. LOG: nhật ký giao dịch từ lần sao lưu LOG gần nhất (cần có một bản FULL trước). Phục hồi = bản FULL gần nhất, rồi bản DIFF gần nhất, rồi các file LOG theo thứ tự.</translation>
    </message>
    <message>
        <source>Full backup (FULL)</source>
        <translation>Sao lưu toàn bộ (FULL)</translation>
    </message>
    <message>
        <source>Differential backup (DIFF)</source>
        <translation>Sao lưu vi sai (DIFF)</translation>
    </message>
    <message>
        <source>Transaction log backup (LOG)</source>
        <translation>Sao lưu nhật ký giao dịch (LOG)</translation>
    </message>
    <message>
        <source>Default backup folder of the server</source>
        <translation>Thư mục sao lưu mặc định của máy chủ</translation>
    </message>
    <message>
        <source>Type</source>
        <translation>Loại</translation>
    </message>
    <message>
        <source>Folder on the server</source>
        <translation>Thư mục trên máy chủ</translation>
    </message>
    <message>
        <source>Run backup</source>
        <translation>Sao lưu</translation>
    </message>
    <message>
        <source>Backups made in this session</source>
        <translation>Các bản sao lưu trong phiên làm việc này</translation>
    </message>
    <message>
        <source>Backup written by SQL Server to: %1</source>
        <translation>SQL Server đã ghi bản sao lưu vào: %1</translation>
    </message>
</context>
<context>
    <name>BackupService</name>
    <message>
        <source>The backup type must be FULL, DIFF or LOG.</source>
        <translation>Kiểu sao lưu phải là FULL, DIFF hoặc LOG.</translation>
    </message>
</context>
<context>
    <name>Branch</name>
    <message>
        <source>The branch code may only contain letters, digits, dashes and underscores (at most 10).</source>
        <translation>Mã chi nhánh chỉ gồm chữ không dấu, số, dấu gạch ngang và gạch dưới (tối đa 10 ký tự).</translation>
    </message>
    <message>
        <source>The branch name is required.</source>
        <translation>Vui lòng nhập tên chi nhánh.</translation>
    </message>
    <message>
        <source>The address is required.</source>
        <translation>Vui lòng nhập địa chỉ.</translation>
    </message>
    <message>
        <source>Phone numbers contain 9-11 digits only.</source>
        <translation>Số điện thoại chỉ gồm 9-11 chữ số.</translation>
    </message>
    <message>
        <source>Invalid email address.</source>
        <translation>Email không hợp lệ.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
</context>
<context>
    <name>BranchPage</name>
    <message>
        <source>New branch</source>
        <translation>Thêm chi nhánh</translation>
    </message>
    <message>
        <source>Edit branch</source>
        <translation>Sửa chi nhánh</translation>
    </message>
    <message>
        <source>New room</source>
        <translation>Thêm phòng</translation>
    </message>
    <message>
        <source>Edit room</source>
        <translation>Sửa phòng</translation>
    </message>
    <message>
        <source>Rooms of %1</source>
        <translation>Phòng học của %1</translation>
    </message>
    <message>
        <source>Edit branch %1</source>
        <translation>Sửa chi nhánh %1</translation>
    </message>
    <message>
        <source>Branch code</source>
        <translation>Mã chi nhánh</translation>
    </message>
    <message>
        <source>Branch name</source>
        <translation>Tên chi nhánh</translation>
    </message>
    <message>
        <source>Address</source>
        <translation>Địa chỉ</translation>
    </message>
    <message>
        <source>Phone</source>
        <translation>Điện thoại</translation>
    </message>
    <message>
        <source>Email</source>
        <translation>Email</translation>
    </message>
    <message>
        <source>Founded on</source>
        <translation>Ngày thành lập</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>Edit room %1</source>
        <translation>Sửa phòng %1</translation>
    </message>
    <message>
        <source>Room code</source>
        <translation>Mã phòng</translation>
    </message>
    <message>
        <source>Branch</source>
        <translation>Chi nhánh</translation>
    </message>
    <message>
        <source>Room name</source>
        <translation>Tên phòng</translation>
    </message>
    <message>
        <source>Seats</source>
        <translation>Sức chứa</translation>
    </message>
    <message>
        <source>Room type</source>
        <translation>Loại phòng</translation>
    </message>
    <message>
        <source>Not recorded</source>
        <translation>Không ghi nhận</translation>
    </message>
</context>
<context>
    <name>CatalogService</name>
    <message>
        <source>No branch is selected.</source>
        <translation>Chưa chọn chi nhánh.</translation>
    </message>
    <message>
        <source>No room is selected.</source>
        <translation>Chưa chọn phòng.</translation>
    </message>
    <message>
        <source>No program is selected.</source>
        <translation>Chưa chọn chương trình.</translation>
    </message>
    <message>
        <source>No promotion is selected.</source>
        <translation>Chưa chọn khuyến mãi.</translation>
    </message>
</context>
<context>
    <name>ChangePasswordDialog</name>
    <message>
        <source>Change password</source>
        <translation>Đổi mật khẩu</translation>
    </message>
    <message>
        <source>Current password</source>
        <translation>Mật khẩu hiện tại</translation>
    </message>
    <message>
        <source>New password</source>
        <translation>Mật khẩu mới</translation>
    </message>
    <message>
        <source>Confirm new password</source>
        <translation>Nhập lại mật khẩu mới</translation>
    </message>
    <message>
        <source>Save</source>
        <translation>Lưu</translation>
    </message>
    <message>
        <source>Cancel</source>
        <translation>Hủy</translation>
    </message>
    <message>
        <source>Success</source>
        <translation>Thành công</translation>
    </message>
    <message>
        <source>Your password has been changed.</source>
        <translation>Đã đổi mật khẩu.</translation>
    </message>
</context>
<context>
    <name>ClassFormDialog</name>
    <message>
        <source>New class</source>
        <translation>Mở lớp</translation>
    </message>
    <message>
        <source>Edit class %1</source>
        <translation>Sửa lớp %1</translation>
    </message>
    <message>
        <source>Class name</source>
        <translation>Tên lớp</translation>
    </message>
    <message>
        <source>Course</source>
        <translation>Khóa học</translation>
    </message>
    <message>
        <source>Branch</source>
        <translation>Chi nhánh</translation>
    </message>
    <message>
        <source>Main teacher</source>
        <translation>Giáo viên chính</translation>
    </message>
    <message>
        <source>Room</source>
        <translation>Phòng</translation>
    </message>
    <message>
        <source>Start date</source>
        <translation>Khai giảng</translation>
    </message>
    <message>
        <source>Maximum size</source>
        <translation>Sĩ số tối đa</translation>
    </message>
    <message>
        <source>Tuition</source>
        <translation>Học phí</translation>
    </message>
    <message>
        <source>A new start date removes the generated sessions; they are generated again from the new date.</source>
        <translation>Đổi ngày khai giảng sẽ xóa các buổi học đã sinh; các buổi được sinh lại từ ngày mới.</translation>
    </message>
</context>
<context>
    <name>ClassInfo</name>
    <message>
        <source>The class name is required.</source>
        <translation>Vui lòng nhập tên lớp.</translation>
    </message>
    <message>
        <source>The class name must be at most %1 characters.</source>
        <translation>Tên lớp tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Please choose a course.</source>
        <translation>Vui lòng chọn khóa học.</translation>
    </message>
    <message>
        <source>Please choose a branch.</source>
        <translation>Vui lòng chọn chi nhánh.</translation>
    </message>
    <message>
        <source>Please choose a teacher.</source>
        <translation>Vui lòng chọn giáo viên.</translation>
    </message>
    <message>
        <source>Please choose a room.</source>
        <translation>Vui lòng chọn phòng học.</translation>
    </message>
    <message>
        <source>Invalid start date.</source>
        <translation>Ngày khai giảng không hợp lệ.</translation>
    </message>
    <message>
        <source>The class size must be between %1 and %2.</source>
        <translation>Sĩ số tối đa phải từ %1 đến %2.</translation>
    </message>
    <message>
        <source>The tuition cannot be negative.</source>
        <translation>Học phí không được âm.</translation>
    </message>
</context>
<context>
    <name>ClassPage</name>
    <message>
        <source>All branches</source>
        <translation>Tất cả chi nhánh</translation>
    </message>
    <message>
        <source>All statuses</source>
        <translation>Tất cả trạng thái</translation>
    </message>
    <message>
        <source>New class</source>
        <translation>Mở lớp</translation>
    </message>
    <message>
        <source>Edit</source>
        <translation>Sửa</translation>
    </message>
    <message>
        <source>Weekly schedule</source>
        <translation>Lịch tuần</translation>
    </message>
    <message>
        <source>Generate sessions</source>
        <translation>Sinh buổi học</translation>
    </message>
    <message>
        <source>Start</source>
        <translation>Bắt đầu học</translation>
    </message>
    <message>
        <source>Cancel class</source>
        <translation>Hủy lớp</translation>
    </message>
    <message>
        <source>Evaluate results</source>
        <translation>Đánh giá kết quả</translation>
    </message>
    <message>
        <source>Students</source>
        <translation>Học viên</translation>
    </message>
    <message>
        <source>Results</source>
        <translation>Kết quả</translation>
    </message>
    <message>
        <source>Class created</source>
        <translation>Đã mở lớp</translation>
    </message>
    <message>
        <source>Class %1 was created. Next, set its weekly schedule, then generate its sessions.</source>
        <translation>Đã mở lớp %1. Tiếp theo, đặt lịch tuần cho lớp rồi sinh các buổi học.</translation>
    </message>
    <message>
        <source>Generate the sessions of class %1 from its weekly schedule? Sessions generated before are replaced.</source>
        <translation>Sinh các buổi học của lớp %1 theo lịch tuần? Các buổi đã sinh trước đó sẽ được thay thế.</translation>
    </message>
    <message>
        <source>Sessions generated</source>
        <translation>Đã sinh buổi học</translation>
    </message>
    <message>
        <source>%1 sessions were created; the last one is on %2.</source>
        <translation>Đã tạo %1 buổi học; buổi cuối vào ngày %2.</translation>
    </message>
    <message>
        <source>Start class %1 - %2?</source>
        <translation>Bắt đầu học lớp %1 - %2?</translation>
    </message>
    <message>
        <source>Cancel class %1 - %2? Its open enrollments end (status Left).</source>
        <translation>Hủy lớp %1 - %2? Các ghi danh đang mở sẽ kết thúc (trạng thái Đã nghỉ).</translation>
    </message>
    <message>
        <source>Students of class %1 - %2</source>
        <translation>Học viên lớp %1 - %2</translation>
    </message>
    <message>
        <source>Close class %1 with its results? Every student gets the final grade and Passed or Failed, the students who passed get a certificate and the class becomes Finished: its grades and attendance can no longer change.</source>
        <translation>Đóng lớp %1 và tính kết quả? Mỗi học viên nhận điểm tổng kết và Đạt/Không đạt, học viên đạt được cấp chứng chỉ và lớp chuyển sang Đã kết thúc: điểm và điểm danh không thể sửa nữa.</translation>
    </message>
    <message>
        <source>Results evaluated</source>
        <translation>Đã đánh giá kết quả</translation>
    </message>
    <message>
        <source>%1 students passed, %2 failed.</source>
        <translation>%1 học viên đạt, %2 không đạt.</translation>
    </message>
    <message>
        <source>Results of class %1 - %2</source>
        <translation>Kết quả lớp %1 - %2</translation>
    </message>
    <message>
        <source>Final grade, classification, attendance and certificate number of every student (the final grade stays empty while a score is missing).</source>
        <translation>Điểm tổng kết, xếp loại, chuyên cần và số chứng chỉ của từng học viên (điểm tổng kết để trống khi còn thiếu điểm thành phần).</translation>
    </message>
</context>
<context>
    <name>ClassService</name>
    <message>
        <source>No class is selected.</source>
        <translation>Chưa chọn lớp.</translation>
    </message>
    <message>
        <source>No time slot is selected.</source>
        <translation>Chưa chọn khung giờ.</translation>
    </message>
</context>
<context>
    <name>CollectPaymentDialog</name>
    <message>
        <source>Collect a payment</source>
        <translation>Thu học phí</translation>
    </message>
    <message>
        <source>Filter by student, class or enrollment...</source>
        <translation>Lọc theo học viên, lớp hoặc mã ghi danh...</translation>
    </message>
    <message>
        <source>Tuition payment</source>
        <translation>Thu học phí</translation>
    </message>
    <message>
        <source>Enrollment</source>
        <translation>Ghi danh</translation>
    </message>
    <message>
        <source>Amount</source>
        <translation>Số tiền</translation>
    </message>
    <message>
        <source>Payment method</source>
        <translation>Hình thức</translation>
    </message>
    <message>
        <source>Description</source>
        <translation>Nội dung</translation>
    </message>
    <message>
        <source>Collect</source>
        <translation>Thu tiền</translation>
    </message>
    <message>
        <source>Choose an enrollment in the list.</source>
        <translation>Chọn một ghi danh trong danh sách.</translation>
    </message>
    <message>
        <source>%1 - %2, class %3: still owes %4</source>
        <translation>%1 - %2, lớp %3: còn nợ %4</translation>
    </message>
</context>
<context>
    <name>Columns</name>
    <message>
        <source>Class code</source>
        <translation>Mã lớp</translation>
    </message>
    <message>
        <source>Class name</source>
        <translation>Tên lớp</translation>
    </message>
    <message>
        <source>Course</source>
        <translation>Khóa học</translation>
    </message>
    <message>
        <source>Branch</source>
        <translation>Chi nhánh</translation>
    </message>
    <message>
        <source>Teacher</source>
        <translation>Giáo viên</translation>
    </message>
    <message>
        <source>Room</source>
        <translation>Phòng</translation>
    </message>
    <message>
        <source>Schedule</source>
        <translation>Lịch học</translation>
    </message>
    <message>
        <source>Start date</source>
        <translation>Khai giảng</translation>
    </message>
    <message>
        <source>End date</source>
        <translation>Kết thúc</translation>
    </message>
    <message>
        <source>Enrolled</source>
        <translation>Sĩ số</translation>
    </message>
    <message>
        <source>Capacity</source>
        <translation>Tối đa</translation>
    </message>
    <message>
        <source>Tuition</source>
        <translation>Học phí</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>Date</source>
        <translation>Ngày học</translation>
    </message>
    <message>
        <source>Start</source>
        <translation>Bắt đầu</translation>
    </message>
    <message>
        <source>End</source>
        <translation>Kết thúc</translation>
    </message>
    <message>
        <source>Session</source>
        <translation>Buổi</translation>
    </message>
    <message>
        <source>Enrollment ID</source>
        <translation>Mã GD</translation>
    </message>
    <message>
        <source>Student ID</source>
        <translation>Mã HV</translation>
    </message>
    <message>
        <source>Full name</source>
        <translation>Họ tên</translation>
    </message>
    <message>
        <source>Date of birth</source>
        <translation>Ngày sinh</translation>
    </message>
    <message>
        <source>Gender</source>
        <translation>Giới tính</translation>
    </message>
    <message>
        <source>Phone</source>
        <translation>Điện thoại</translation>
    </message>
    <message>
        <source>Guardian</source>
        <translation>Phụ huynh</translation>
    </message>
    <message>
        <source>Guardian phone</source>
        <translation>SĐT phụ huynh</translation>
    </message>
    <message>
        <source>Registered on</source>
        <translation>Ngày đăng ký</translation>
    </message>
    <message>
        <source>Active classes</source>
        <translation>Lớp đang học</translation>
    </message>
    <message>
        <source>Balance due</source>
        <translation>Công nợ</translation>
    </message>
    <message>
        <source>Total balance due</source>
        <translation>Tổng công nợ</translation>
    </message>
    <message>
        <source>Contact</source>
        <translation>Liên lạc</translation>
    </message>
    <message>
        <source>Enrolled on</source>
        <translation>Ngày ghi danh</translation>
    </message>
    <message>
        <source>Paid</source>
        <translation>Đã đóng</translation>
    </message>
    <message>
        <source>Total paid</source>
        <translation>Tổng đã đóng</translation>
    </message>
    <message>
        <source>Outstanding</source>
        <translation>Còn nợ</translation>
    </message>
    <message>
        <source>Total outstanding</source>
        <translation>Tổng còn nợ</translation>
    </message>
    <message>
        <source>Days</source>
        <translation>Số ngày</translation>
    </message>
    <message>
        <source>Final grade</source>
        <translation>Điểm TK</translation>
    </message>
    <message>
        <source>Classification</source>
        <translation>Xếp loại</translation>
    </message>
    <message>
        <source>Attendance (%)</source>
        <translation>Chuyên cần (%)</translation>
    </message>
    <message>
        <source>Result</source>
        <translation>Kết quả</translation>
    </message>
    <message>
        <source>Year</source>
        <translation>Năm</translation>
    </message>
    <message>
        <source>Month</source>
        <translation>Tháng</translation>
    </message>
    <message>
        <source>Receipts</source>
        <translation>Số phiếu</translation>
    </message>
    <message>
        <source>Revenue</source>
        <translation>Doanh thu</translation>
    </message>
    <message>
        <source>Total revenue</source>
        <translation>Tổng doanh thu</translation>
    </message>
    <message>
        <source>Teacher ID</source>
        <translation>Mã GV</translation>
    </message>
    <message>
        <source>Sessions</source>
        <translation>Số buổi</translation>
    </message>
    <message>
        <source>Hours</source>
        <translation>Số giờ</translation>
    </message>
    <message>
        <source>Hourly rate</source>
        <translation>Đơn giá/giờ</translation>
    </message>
    <message>
        <source>Bonus</source>
        <translation>Thưởng</translation>
    </message>
    <message>
        <source>Total bonus</source>
        <translation>Tổng thưởng</translation>
    </message>
    <message>
        <source>Deductions</source>
        <translation>Khấu trừ</translation>
    </message>
    <message>
        <source>Total deductions</source>
        <translation>Tổng khấu trừ</translation>
    </message>
    <message>
        <source>Total pay</source>
        <translation>Tổng lương</translation>
    </message>
    <message>
        <source>Username</source>
        <translation>Tên đăng nhập</translation>
    </message>
    <message>
        <source>Role</source>
        <translation>Vai trò</translation>
    </message>
    <message>
        <source>Created</source>
        <translation>Ngày tạo</translation>
    </message>
    <message>
        <source>Last login</source>
        <translation>Đăng nhập cuối</translation>
    </message>
    <message>
        <source>Seats left</source>
        <translation>Còn chỗ</translation>
    </message>
    <message>
        <source>Weekday</source>
        <translation>Thứ</translation>
    </message>
    <message>
        <source>Certificate No.</source>
        <translation>Số chứng chỉ</translation>
    </message>
    <message>
        <source>Session ID</source>
        <translation>Mã buổi</translation>
    </message>
    <message>
        <source>Description</source>
        <translation>Nội dung</translation>
    </message>
    <message>
        <source>Score</source>
        <translation>Điểm</translation>
    </message>
    <message>
        <source>Receipt No.</source>
        <translation>Số phiếu</translation>
    </message>
    <message>
        <source>Paid at</source>
        <translation>Thời điểm thu</translation>
    </message>
    <message>
        <source>Amount</source>
        <translation>Số tiền</translation>
    </message>
    <message>
        <source>Total amount</source>
        <translation>Tổng số tiền</translation>
    </message>
    <message>
        <source>Payment method</source>
        <translation>Hình thức</translation>
    </message>
    <message>
        <source>Collected by</source>
        <translation>Người thu</translation>
    </message>
    <message>
        <source>Cancel reason</source>
        <translation>Lý do hủy</translation>
    </message>
    <message>
        <source>Test ID</source>
        <translation>Mã bài kiểm tra</translation>
    </message>
    <message>
        <source>Test date</source>
        <translation>Ngày kiểm tra</translation>
    </message>
    <message>
        <source>Listening</source>
        <translation>Nghe</translation>
    </message>
    <message>
        <source>Speaking</source>
        <translation>Nói</translation>
    </message>
    <message>
        <source>Reading</source>
        <translation>Đọc</translation>
    </message>
    <message>
        <source>Writing</source>
        <translation>Viết</translation>
    </message>
    <message>
        <source>Overall</source>
        <translation>Điểm chung</translation>
    </message>
    <message>
        <source>Recommended course</source>
        <translation>Khóa đề xuất</translation>
    </message>
    <message>
        <source>Graded by</source>
        <translation>Người chấm</translation>
    </message>
    <message>
        <source>Notes</source>
        <translation>Ghi chú</translation>
    </message>
    <message>
        <source>Payroll ID</source>
        <translation>Mã bảng lương</translation>
    </message>
    <message>
        <source>Program</source>
        <translation>Chương trình</translation>
    </message>
    <message>
        <source>Branch code</source>
        <translation>Mã chi nhánh</translation>
    </message>
    <message>
        <source>Address</source>
        <translation>Địa chỉ</translation>
    </message>
    <message>
        <source>Email</source>
        <translation>Thư điện tử</translation>
    </message>
    <message>
        <source>Founded on</source>
        <translation>Ngày thành lập</translation>
    </message>
    <message>
        <source>Rooms</source>
        <translation>Số phòng</translation>
    </message>
    <message>
        <source>Room code</source>
        <translation>Mã phòng</translation>
    </message>
    <message>
        <source>Seats</source>
        <translation>Sức chứa</translation>
    </message>
    <message>
        <source>Room type</source>
        <translation>Loại phòng</translation>
    </message>
    <message>
        <source>Program code</source>
        <translation>Mã chương trình</translation>
    </message>
    <message>
        <source>Target learners</source>
        <translation>Đối tượng</translation>
    </message>
    <message>
        <source>Courses</source>
        <translation>Số khóa học</translation>
    </message>
    <message>
        <source>Course code</source>
        <translation>Mã khóa</translation>
    </message>
    <message>
        <source>Level</source>
        <translation>Trình độ</translation>
    </message>
    <message>
        <source>Minutes per session</source>
        <translation>Phút/buổi</translation>
    </message>
    <message>
        <source>Minimum placement score</source>
        <translation>Điểm đầu vào tối thiểu</translation>
    </message>
    <message>
        <source>Prerequisite</source>
        <translation>Khóa tiên quyết</translation>
    </message>
    <message>
        <source>Total weight (%)</source>
        <translation>Tổng trọng số (%)</translation>
    </message>
    <message>
        <source>Syllabus</source>
        <translation>Giáo trình</translation>
    </message>
    <message>
        <source>Component ID</source>
        <translation>Mã cột điểm</translation>
    </message>
    <message>
        <source>Grade component</source>
        <translation>Cột điểm</translation>
    </message>
    <message>
        <source>Weight (%)</source>
        <translation>Trọng số (%)</translation>
    </message>
    <message>
        <source>Unit</source>
        <translation>Bài</translation>
    </message>
    <message>
        <source>Title</source>
        <translation>Tiêu đề</translation>
    </message>
    <message>
        <source>Skills</source>
        <translation>Kỹ năng</translation>
    </message>
    <message>
        <source>Textbook</source>
        <translation>Giáo trình chính</translation>
    </message>
    <message>
        <source>Units</source>
        <translation>Số bài</translation>
    </message>
    <message>
        <source>Employee ID</source>
        <translation>Mã nhân viên</translation>
    </message>
    <message>
        <source>Position</source>
        <translation>Chức vụ</translation>
    </message>
    <message>
        <source>Hire date</source>
        <translation>Ngày vào làm</translation>
    </message>
    <message>
        <source>Base salary</source>
        <translation>Lương cơ bản</translation>
    </message>
    <message>
        <source>Teacher type</source>
        <translation>Loại giáo viên</translation>
    </message>
    <message>
        <source>Nationality</source>
        <translation>Quốc tịch</translation>
    </message>
    <message>
        <source>Degree</source>
        <translation>Học vị</translation>
    </message>
    <message>
        <source>Years of experience</source>
        <translation>Số năm kinh nghiệm</translation>
    </message>
    <message>
        <source>Specialties</source>
        <translation>Chuyên môn</translation>
    </message>
    <message>
        <source>Promotion code</source>
        <translation>Mã khuyến mãi</translation>
    </message>
    <message>
        <source>Promotion</source>
        <translation>Khuyến mãi</translation>
    </message>
    <message>
        <source>Discount type</source>
        <translation>Loại giảm giá</translation>
    </message>
    <message>
        <source>Discount value</source>
        <translation>Mức giảm</translation>
    </message>
    <message>
        <source>Validity</source>
        <translation>Hiệu lực</translation>
    </message>
    <message>
        <source>Enrollments</source>
        <translation>Số ghi danh</translation>
    </message>
</context>
<context>
    <name>Course</name>
    <message>
        <source>The course code may only contain letters, digits, dashes and underscores (at most 10).</source>
        <translation>Mã khóa học chỉ gồm chữ không dấu, số, dấu gạch ngang và gạch dưới (tối đa 10 ký tự).</translation>
    </message>
    <message>
        <source>Please choose a program.</source>
        <translation>Vui lòng chọn chương trình.</translation>
    </message>
    <message>
        <source>The course name is required.</source>
        <translation>Vui lòng nhập tên khóa học.</translation>
    </message>
    <message>
        <source>Invalid level.</source>
        <translation>Trình độ không hợp lệ.</translation>
    </message>
    <message>
        <source>A course has 1 to 200 sessions.</source>
        <translation>Một khóa học có từ 1 đến 200 buổi.</translation>
    </message>
    <message>
        <source>A session lasts 30 to 240 minutes.</source>
        <translation>Một buổi học dài từ 30 đến 240 phút.</translation>
    </message>
    <message>
        <source>The tuition cannot be negative.</source>
        <translation>Học phí không được âm.</translation>
    </message>
    <message>
        <source>The minimum placement score must be between 0 and 10.</source>
        <translation>Điểm đầu vào tối thiểu phải từ 0 đến 10.</translation>
    </message>
    <message>
        <source>A course cannot be its own prerequisite.</source>
        <translation>Khóa học không thể là khóa tiên quyết của chính nó.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
</context>
<context>
    <name>CoursePage</name>
    <message>
        <source>New course</source>
        <translation>Thêm khóa học</translation>
    </message>
    <message>
        <source>Edit course</source>
        <translation>Sửa khóa học</translation>
    </message>
    <message>
        <source>Syllabus</source>
        <translation>Giáo trình</translation>
    </message>
    <message>
        <source>Find by skill</source>
        <translation>Tìm theo kỹ năng</translation>
    </message>
    <message>
        <source>Programs</source>
        <translation>Chương trình</translation>
    </message>
    <message>
        <source>New grade component</source>
        <translation>Thêm cột điểm</translation>
    </message>
    <message>
        <source>Edit component</source>
        <translation>Sửa cột điểm</translation>
    </message>
    <message>
        <source>Delete component</source>
        <translation>Xóa cột điểm</translation>
    </message>
    <message>
        <source>Grade components of %1 (the weights must add up to 100%)</source>
        <translation>Cột điểm của %1 (tổng trọng số phải bằng 100%)</translation>
    </message>
    <message>
        <source>Edit course %1</source>
        <translation>Sửa khóa học %1</translation>
    </message>
    <message>
        <source>Entry requires a placement score of at least</source>
        <translation>Yêu cầu điểm kiểm tra đầu vào tối thiểu</translation>
    </message>
    <message>
        <source>No prerequisite</source>
        <translation>Không có khóa tiên quyết</translation>
    </message>
    <message>
        <source>Course code</source>
        <translation>Mã khóa</translation>
    </message>
    <message>
        <source>Program</source>
        <translation>Chương trình</translation>
    </message>
    <message>
        <source>Course name</source>
        <translation>Tên khóa học</translation>
    </message>
    <message>
        <source>Level (CEFR)</source>
        <translation>Trình độ (CEFR)</translation>
    </message>
    <message>
        <source>Sessions</source>
        <translation>Số buổi</translation>
    </message>
    <message>
        <source>Minutes per session</source>
        <translation>Phút/buổi</translation>
    </message>
    <message>
        <source>Tuition</source>
        <translation>Học phí</translation>
    </message>
    <message>
        <source>Entry score</source>
        <translation>Điểm đầu vào</translation>
    </message>
    <message>
        <source>Prerequisite course</source>
        <translation>Khóa tiên quyết</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>A student enters when they passed the prerequisite course or reached the entry score in their latest placement test.</source>
        <translation>Học viên được vào học khi đã đạt khóa tiên quyết hoặc đạt điểm đầu vào ở bài kiểm tra xếp lớp gần nhất.</translation>
    </message>
    <message>
        <source>Syllabus of %1 - %2</source>
        <translation>Giáo trình %1 - %2</translation>
    </message>
    <message>
        <source>This course has no syllabus yet.</source>
        <translation>Khóa học này chưa có giáo trình.</translation>
    </message>
    <message>
        <source>Edit XML</source>
        <translation>Sửa XML</translation>
    </message>
    <message>
        <source>Syllabus XML of %1</source>
        <translation>XML giáo trình của %1</translation>
    </message>
    <message>
        <source>&lt;Syllabus&gt; with &lt;Textbook&gt;, &lt;Objective&gt; and &lt;Unit No=&quot;1&quot; Sessions=&quot;6&quot;&gt; elements (title and skills). Empty = no syllabus.</source>
        <translation>&lt;Syllabus&gt; gồm các phần tử &lt;Textbook&gt;, &lt;Objective&gt; và &lt;Unit No=&quot;1&quot; Sessions=&quot;6&quot;&gt; (tiêu đề và kỹ năng). Để trống = không có giáo trình.</translation>
    </message>
    <message>
        <source>Find courses by skill</source>
        <translation>Tìm khóa học theo kỹ năng</translation>
    </message>
    <message>
        <source>Speaking, Listening, Writing, Grammar...</source>
        <translation>Speaking, Listening, Writing, Grammar...</translation>
    </message>
    <message>
        <source>Skill</source>
        <translation>Kỹ năng</translation>
    </message>
    <message>
        <source>Find</source>
        <translation>Tìm</translation>
    </message>
    <message>
        <source>Courses that practice %1</source>
        <translation>Các khóa học luyện %1</translation>
    </message>
    <message>
        <source>New program</source>
        <translation>Thêm chương trình</translation>
    </message>
    <message>
        <source>Edit program</source>
        <translation>Sửa chương trình</translation>
    </message>
    <message>
        <source>Edit program %1</source>
        <translation>Sửa chương trình %1</translation>
    </message>
    <message>
        <source>Program code</source>
        <translation>Mã chương trình</translation>
    </message>
    <message>
        <source>Program name</source>
        <translation>Tên chương trình</translation>
    </message>
    <message>
        <source>Target learners</source>
        <translation>Đối tượng</translation>
    </message>
    <message>
        <source>Description</source>
        <translation>Mô tả</translation>
    </message>
    <message>
        <source>Please select a program in the list.</source>
        <translation>Vui lòng chọn một chương trình trong danh sách.</translation>
    </message>
    <message>
        <source>Edit grade component</source>
        <translation>Sửa cột điểm</translation>
    </message>
    <message>
        <source>Course</source>
        <translation>Khóa học</translation>
    </message>
    <message>
        <source>Component name</source>
        <translation>Tên cột điểm</translation>
    </message>
    <message>
        <source>Weight (%)</source>
        <translation>Trọng số (%)</translation>
    </message>
    <message>
        <source>The components of a course whose classes were evaluated cannot change any more (open a new course instead).</source>
        <translation>Cột điểm của khóa học đã có lớp được đánh giá thì không thể thay đổi (hãy mở khóa học mới).</translation>
    </message>
    <message>
        <source>Delete the grade component %1?</source>
        <translation>Xóa cột điểm %1?</translation>
    </message>
</context>
<context>
    <name>CourseService</name>
    <message>
        <source>No course is selected.</source>
        <translation>Chưa chọn khóa học.</translation>
    </message>
    <message>
        <source>Please enter a skill, for example Speaking.</source>
        <translation>Vui lòng nhập một kỹ năng, ví dụ Speaking.</translation>
    </message>
    <message>
        <source>No grade component is selected.</source>
        <translation>Chưa chọn cột điểm.</translation>
    </message>
</context>
<context>
    <name>DashboardPage</name>
    <message>
        <source>Hello, %1</source>
        <translation>Xin chào, %1</translation>
    </message>
    <message>
        <source>Refresh</source>
        <translation>Làm mới</translation>
    </message>
    <message>
        <source>Whole center</source>
        <translation>Toàn trung tâm</translation>
    </message>
    <message>
        <source>Active students</source>
        <translation>Học viên đang học</translation>
    </message>
    <message>
        <source>Active classes</source>
        <translation>Lớp đang học</translation>
    </message>
    <message>
        <source>Classes enrolling</source>
        <translation>Lớp đang tuyển sinh</translation>
    </message>
    <message>
        <source>Revenue this month</source>
        <translation>Doanh thu tháng này</translation>
    </message>
    <message>
        <source>Outstanding tuition</source>
        <translation>Tổng công nợ học phí</translation>
    </message>
    <message>
        <source>Sessions today</source>
        <translation>Buổi học hôm nay</translation>
    </message>
    <message>
        <source>Monthly revenue - %1</source>
        <translation>Doanh thu theo tháng - năm %1</translation>
    </message>
    <message>
        <source>No permission</source>
        <translation>Không có quyền</translation>
    </message>
    <message>
        <source>No permission to view revenue, or no data yet.</source>
        <translation>Không có quyền xem doanh thu hoặc chưa có dữ liệu.</translation>
    </message>
</context>
<context>
    <name>DataPage</name>
    <message>
        <source>Quick filter...</source>
        <translation>Lọc nhanh...</translation>
    </message>
    <message>
        <source>Refresh</source>
        <translation>Làm mới</translation>
    </message>
    <message>
        <source>Excel</source>
        <translation>Excel</translation>
    </message>
    <message>
        <source>PDF</source>
        <translation>PDF</translation>
    </message>
</context>
<context>
    <name>DataTable</name>
    <message>
        <source>%1 rows</source>
        <translation>%1 dòng</translation>
    </message>
    <message>
        <source>1 row</source>
        <translation>1 dòng</translation>
    </message>
</context>
<context>
    <name>DatabaseManager</name>
    <message>
        <source>The Qt ODBC plugin (qsqlodbc) is missing. Please reinstall the application.</source>
        <translation>Thiếu plugin Qt ODBC (qsqlodbc). Hãy cài lại ứng dụng.</translation>
    </message>
    <message>
        <source>No ODBC driver for SQL Server was found on this computer.
Please install &quot;Microsoft ODBC Driver 18 for SQL Server&quot; and try again.</source>
        <translation>Không tìm thấy ODBC Driver cho SQL Server trên máy.
Hãy cài &quot;Microsoft ODBC Driver 18 for SQL Server&quot; rồi thử lại.</translation>
    </message>
    <message>
        <source>The &quot;SQL Server&quot; driver built into Windows could not connect. Install &quot;Microsoft ODBC Driver 18 for SQL Server&quot; and try again.</source>
        <translation>Driver &quot;SQL Server&quot; có sẵn của Windows không kết nối được. Hãy cài &quot;Microsoft ODBC Driver 18 for SQL Server&quot; rồi thử lại.</translation>
    </message>
</context>
<context>
    <name>DbMessages</name>
    <message>
        <source>The student&apos;s full name must not be empty.</source>
        <translation>Họ tên học viên không được để trống.</translation>
    </message>
    <message>
        <source>The phone number is already used by another student.</source>
        <translation>Số điện thoại đã được dùng cho một học viên khác.</translation>
    </message>
    <message>
        <source>The email is already used by another student.</source>
        <translation>Email đã được dùng cho một học viên khác.</translation>
    </message>
    <message>
        <source>Student not found.</source>
        <translation>Không tìm thấy học viên.</translation>
    </message>
    <message>
        <source>The student has an enrollment history and cannot be deleted. Change the status to &quot;Dropped out&quot; instead.</source>
        <translation>Học viên đã có lịch sử ghi danh, không thể xóa. Hãy chuyển trạng thái sang &quot;Ngừng học&quot;.</translation>
    </message>
    <message>
        <source>The course does not exist or is no longer offered.</source>
        <translation>Khóa học không tồn tại hoặc đã ngừng mở.</translation>
    </message>
    <message>
        <source>The teacher does not exist or is no longer teaching.</source>
        <translation>Giáo viên không tồn tại hoặc không còn giảng dạy.</translation>
    </message>
    <message>
        <source>Class not found.</source>
        <translation>Không tìm thấy lớp học.</translation>
    </message>
    <message>
        <source>The class has no weekly schedule yet.</source>
        <translation>Lớp chưa có lịch học trong tuần.</translation>
    </message>
    <message>
        <source>The class already has taught or cancelled sessions; its sessions cannot be regenerated.</source>
        <translation>Lớp đã có buổi đã dạy/đã hủy, không thể sinh lại lịch.</translation>
    </message>
    <message>
        <source>Some students of this class have paid tuition; refund or transfer them before cancelling the class.</source>
        <translation>Lớp đã có học viên đóng học phí, cần hoàn tiền/chuyển lớp trước khi hủy.</translation>
    </message>
    <message>
        <source>Session not found.</source>
        <translation>Không tìm thấy buổi học.</translation>
    </message>
    <message>
        <source>You can only update sessions you teach.</source>
        <translation>Bạn chỉ được cập nhật buổi học do mình phụ trách.</translation>
    </message>
    <message>
        <source>The sessions of a finished or cancelled class cannot be changed.</source>
        <translation>Không được thay đổi buổi học của lớp đã kết thúc hoặc đã hủy.</translation>
    </message>
    <message>
        <source>A class can only move from Enrolling to In progress, or from Enrolling or In progress to Cancelled.</source>
        <translation>Lớp chỉ được chuyển từ Đang tuyển sinh sang Đang học, hoặc từ Đang tuyển sinh / Đang học sang Đã hủy.</translation>
    </message>
    <message>
        <source>Only an enrolling or in-progress class can be changed.</source>
        <translation>Chỉ được thay đổi lớp đang tuyển sinh hoặc đang học.</translation>
    </message>
    <message>
        <source>The start date can only change while the class is enrolling and none of its sessions has been taught or cancelled.</source>
        <translation>Chỉ được đổi ngày khai giảng khi lớp đang tuyển sinh và chưa có buổi nào đã dạy hoặc đã hủy.</translation>
    </message>
    <message>
        <source>The maximum size cannot be lower than the number of students enrolled in the class.</source>
        <translation>Sĩ số tối đa không được nhỏ hơn số học viên đang ghi danh trong lớp.</translation>
    </message>
    <message>
        <source>Schedule slot not found.</source>
        <translation>Không tìm thấy khung giờ.</translation>
    </message>
    <message>
        <source>The student does not exist or has dropped out.</source>
        <translation>Học viên không tồn tại hoặc đã ngừng học.</translation>
    </message>
    <message>
        <source>The class no longer accepts enrollments.</source>
        <translation>Lớp không còn nhận ghi danh.</translation>
    </message>
    <message>
        <source>The student is already enrolled in this class.</source>
        <translation>Học viên đã ghi danh lớp này.</translation>
    </message>
    <message>
        <source>The student does not meet the entry requirement of course %1 (complete the prerequisite course or score at least %2 in the placement test).</source>
        <translation>Học viên chưa đạt điều kiện đầu vào của khóa %1 (cần hoàn thành khóa tiên quyết hoặc điểm kiểm tra đầu vào &gt;= %2).</translation>
    </message>
    <message>
        <source>The student does not meet the entry requirement of course %1 (complete the prerequisite course first).</source>
        <translation>Học viên chưa đạt điều kiện đầu vào của khóa %1 (cần hoàn thành khóa tiên quyết trước).</translation>
    </message>
    <message>
        <source>The class schedule clashes with another class the student is taking.</source>
        <translation>Lịch học của lớp bị trùng với một lớp khác học viên đang theo học.</translation>
    </message>
    <message>
        <source>The promotion code does not exist or has expired.</source>
        <translation>Mã khuyến mãi không tồn tại hoặc đã hết hạn.</translation>
    </message>
    <message>
        <source>Active enrollment not found.</source>
        <translation>Không tìm thấy lượt ghi danh đang hiệu lực.</translation>
    </message>
    <message>
        <source>A student can only be transferred to an open class of the same course and branch.</source>
        <translation>Chỉ được chuyển học viên sang lớp đang mở của cùng khóa học và cùng chi nhánh.</translation>
    </message>
    <message>
        <source>Enrollment not found.</source>
        <translation>Không tìm thấy lượt ghi danh.</translation>
    </message>
    <message>
        <source>The student has paid more than the tuition of the new class; cancel a receipt before the transfer.</source>
        <translation>Học viên đã đóng nhiều hơn học phí của lớp mới; hãy hủy phiếu thu trước khi chuyển lớp.</translation>
    </message>
    <message>
        <source>Only an enrollment that is not completed can be set to Studying, On hold or Left.</source>
        <translation>Chỉ ghi danh chưa hoàn thành mới được chuyển sang Đang học, Bảo lưu hoặc Đã nghỉ.</translation>
    </message>
    <message>
        <source>The current account is not linked to an employee who can collect payments.</source>
        <translation>Tài khoản hiện tại không gắn với nhân viên thu tiền.</translation>
    </message>
    <message>
        <source>Valid enrollment not found.</source>
        <translation>Không tìm thấy lượt ghi danh hợp lệ.</translation>
    </message>
    <message>
        <source>A reason is required to cancel a receipt.</source>
        <translation>Phải nhập lý do hủy phiếu thu.</translation>
    </message>
    <message>
        <source>No valid receipt found to cancel.</source>
        <translation>Không tìm thấy phiếu thu hợp lệ để hủy.</translation>
    </message>
    <message>
        <source>You can only take attendance for sessions you teach.</source>
        <translation>Bạn chỉ được điểm danh buổi học do mình phụ trách.</translation>
    </message>
    <message>
        <source>You can only view the attendance of sessions you teach.</source>
        <translation>Bạn chỉ được xem điểm danh buổi học do mình phụ trách.</translation>
    </message>
    <message>
        <source>You can only enter grades for classes you teach.</source>
        <translation>Bạn chỉ được nhập điểm lớp do mình phụ trách.</translation>
    </message>
    <message>
        <source>The class has finished and its results are final; grades can no longer be changed.</source>
        <translation>Lớp đã kết thúc và xét kết quả, không thể sửa điểm.</translation>
    </message>
    <message>
        <source>The class has finished and its results are final; attendance can no longer be changed.</source>
        <translation>Lớp đã kết thúc và xét kết quả, không thể sửa điểm danh.</translation>
    </message>
    <message>
        <source>The class does not exist or has not started yet.</source>
        <translation>Lớp không tồn tại hoặc chưa bắt đầu học.</translation>
    </message>
    <message>
        <source>The grade component weights of the course do not add up to 100%.</source>
        <translation>Tổng trọng số các cột điểm của khóa học chưa bằng 100%.</translation>
    </message>
    <message>
        <source>Grades are still missing for %1 student(s).</source>
        <translation>Còn %1 học viên chưa nhập đủ điểm.</translation>
    </message>
    <message>
        <source>The class still has scheduled sessions; mark them as taught or cancelled first.</source>
        <translation>Lớp vẫn còn buổi chưa dạy; hãy đánh dấu các buổi đó là đã dạy hoặc đã hủy trước.</translation>
    </message>
    <message>
        <source>Payroll cannot be finalized for a future month.</source>
        <translation>Không thể chốt lương cho tháng trong tương lai.</translation>
    </message>
    <message>
        <source>Payroll row not found.</source>
        <translation>Không tìm thấy dòng bảng lương.</translation>
    </message>
    <message>
        <source>A paid payroll row can no longer be changed.</source>
        <translation>Dòng lương đã chi trả thì không thể thay đổi.</translation>
    </message>
    <message>
        <source>The deduction cannot be larger than the pay of the month.</source>
        <translation>Khấu trừ không được lớn hơn lương của tháng.</translation>
    </message>
    <message>
        <source>A username may only contain letters without diacritics, digits, dots and underscores (at least 3 characters).</source>
        <translation>Tên đăng nhập chỉ gồm chữ không dấu, số, dấu chấm, gạch dưới (tối thiểu 3 ký tự).</translation>
    </message>
    <message>
        <source>The password must be at least 8 characters long.</source>
        <translation>Mật khẩu tối thiểu 8 ký tự.</translation>
    </message>
    <message>
        <source>The username already exists.</source>
        <translation>Tên đăng nhập đã tồn tại.</translation>
    </message>
    <message>
        <source>An account cannot be created for an employee or teacher who has left.</source>
        <translation>Không thể tạo tài khoản cho nhân viên hoặc giáo viên đã nghỉ việc.</translation>
    </message>
    <message>
        <source>Invalid role.</source>
        <translation>Vai trò không hợp lệ.</translation>
    </message>
    <message>
        <source>Account not found.</source>
        <translation>Không tìm thấy tài khoản.</translation>
    </message>
    <message>
        <source>Choose whether to lock or unlock the account.</source>
        <translation>Hãy chọn khóa hoặc mở khóa tài khoản.</translation>
    </message>
    <message>
        <source>You cannot lock the account you are signed in with.</source>
        <translation>Không thể tự khóa tài khoản đang đăng nhập.</translation>
    </message>
    <message>
        <source>The current password is incorrect.</source>
        <translation>Mật khẩu hiện tại không đúng.</translation>
    </message>
    <message>
        <source>The new password is not strong enough: it needs uppercase and lowercase letters, digits or special characters.</source>
        <translation>Mật khẩu mới chưa đủ mạnh: cần chữ hoa, chữ thường, chữ số hoặc ký tự đặc biệt.</translation>
    </message>
    <message>
        <source>The backup type must be FULL, DIFF or LOG.</source>
        <translation>Loại sao lưu phải là FULL, DIFF hoặc LOG.</translation>
    </message>
    <message>
        <source>The record to update does not exist.</source>
        <translation>Bản ghi cần cập nhật không tồn tại.</translation>
    </message>
    <message>
        <source>This code is already used.</source>
        <translation>Mã này đã được sử dụng.</translation>
    </message>
    <message>
        <source>A code may only contain letters, digits, dashes and underscores.</source>
        <translation>Mã chỉ gồm chữ không dấu, số, dấu gạch ngang và gạch dưới.</translation>
    </message>
    <message>
        <source>A branch with active classes cannot be suspended.</source>
        <translation>Không thể tạm ngưng chi nhánh đang có lớp hoạt động.</translation>
    </message>
    <message>
        <source>A course with active classes cannot be discontinued.</source>
        <translation>Không thể ngừng mở khóa học đang có lớp hoạt động.</translation>
    </message>
    <message>
        <source>The prerequisite would make a loop: a course cannot require itself, not even through other courses.</source>
        <translation>Khóa tiên quyết tạo thành vòng lặp: một khóa học không thể yêu cầu chính nó, kể cả qua các khóa khác.</translation>
    </message>
    <message>
        <source>The syllabus does not follow the XML schema of the center: %1</source>
        <translation>Giáo trình không đúng lược đồ XML của trung tâm: %1</translation>
    </message>
    <message>
        <source>A grade component that already has scores cannot be deleted.</source>
        <translation>Không thể xóa cột điểm đã có điểm.</translation>
    </message>
    <message>
        <source>An employee or teacher with an active account or an active class cannot be set to Left: lock the account and hand the classes over first.</source>
        <translation>Không thể chuyển nhân viên/giáo viên đang có tài khoản hoạt động hoặc lớp đang học sang Đã nghỉ: hãy khóa tài khoản và bàn giao lớp trước.</translation>
    </message>
    <message>
        <source>The room must belong to the same branch as the class.</source>
        <translation>Phòng học phải thuộc cùng chi nhánh với lớp học.</translation>
    </message>
    <message>
        <source>The maximum class size exceeds the capacity of the room.</source>
        <translation>Sĩ số tối đa của lớp vượt quá sức chứa của phòng học.</translation>
    </message>
    <message>
        <source>Schedule conflict with class %1 (same room %2).</source>
        <translation>Trùng lịch với lớp %1 (cùng phòng %2).</translation>
    </message>
    <message>
        <source>Schedule conflict with class %1 (same teacher %2).</source>
        <translation>Trùng lịch với lớp %1 (cùng giáo viên %2).</translation>
    </message>
    <message>
        <source>Class %1 is full.</source>
        <translation>Lớp %1 đã đủ sĩ số tối đa.</translation>
    </message>
    <message>
        <source>The amount exceeds the tuition the student still owes.</source>
        <translation>Số tiền thu vượt quá học phí còn nợ của học viên.</translation>
    </message>
    <message>
        <source>Receipts cannot be deleted. Use the Cancel receipt function instead.</source>
        <translation>Không được xóa phiếu thu. Hãy dùng chức năng Hủy phiếu thu.</translation>
    </message>
    <message>
        <source>The student does not belong to the class of this session.</source>
        <translation>Học viên không thuộc lớp của buổi học này.</translation>
    </message>
    <message>
        <source>The grade component does not belong to the course of the class.</source>
        <translation>Cột điểm không thuộc khóa học của lớp.</translation>
    </message>
    <message>
        <source>The audit log is append-only; it cannot be changed or deleted.</source>
        <translation>Nhật ký hệ thống chỉ được ghi thêm, không được sửa hoặc xóa.</translation>
    </message>
    <message>
        <source>Certificates are only issued to students who passed.</source>
        <translation>Chỉ cấp chứng nhận cho học viên có kết quả Đạt.</translation>
    </message>
    <message>
        <source>The date, time, room and teacher of a taught session cannot be changed.</source>
        <translation>Không được thay đổi thời gian, phòng, giáo viên của buổi đã dạy.</translation>
    </message>
    <message>
        <source>A taught session cannot change its status.</source>
        <translation>Không được thay đổi trạng thái của buổi đã dạy.</translation>
    </message>
    <message>
        <source>A session can only be marked as taught on or after its date.</source>
        <translation>Chỉ được đánh dấu đã dạy từ ngày diễn ra buổi học trở đi.</translation>
    </message>
    <message>
        <source>The room is used by an active class: it must stay in the branch of the class and hold its maximum size.</source>
        <translation>Phòng đang được một lớp sử dụng: phòng phải ở cùng chi nhánh với lớp và đủ chỗ cho sĩ số tối đa của lớp.</translation>
    </message>
    <message>
        <source>The grade components of a course with evaluated classes cannot be changed; open a new course instead.</source>
        <translation>Không được thay đổi thành phần điểm của khóa học đã có lớp được đánh giá kết quả; hãy mở khóa học mới.</translation>
    </message>
    <message>
        <source>An enrollment cannot be dated in the future.</source>
        <translation>Không thể ghi danh với ngày trong tương lai.</translation>
    </message>
    <message>
        <source>A payment cannot be dated in the future.</source>
        <translation>Không thể ghi phiếu thu với thời điểm trong tương lai.</translation>
    </message>
    <message>
        <source>A month can only be marked as paid after it has ended.</source>
        <translation>Chỉ đánh dấu đã trả lương được khi tháng đó đã kết thúc.</translation>
    </message>
    <message>
        <source>A promotion already used by enrollments keeps its discount and start date; only its name and end date can change.</source>
        <translation>Khuyến mãi đã được dùng cho ghi danh thì giữ nguyên mức giảm và ngày bắt đầu; chỉ đổi được tên và ngày kết thúc.</translation>
    </message>
    <message>
        <source>The end date cannot be before the last enrollment that used the promotion.</source>
        <translation>Ngày kết thúc không được trước lần ghi danh cuối cùng đã dùng khuyến mãi này.</translation>
    </message>
    <message>
        <source>The room is under maintenance; choose another room.</source>
        <translation>Phòng đang bảo trì; hãy chọn phòng khác.</translation>
    </message>
    <message>
        <source>The branch does not exist or is suspended.</source>
        <translation>Chi nhánh không tồn tại hoặc đang tạm ngừng.</translation>
    </message>
    <message>
        <source>The weekly schedule of a class with taught or cancelled sessions can no longer change.</source>
        <translation>Lịch tuần của lớp đã có buổi đã dạy hoặc đã hủy thì không thể thay đổi nữa.</translation>
    </message>
</context>
<context>
    <name>DbValues</name>
    <message>
        <source>Active</source>
        <translation>Hoạt động</translation>
    </message>
    <message>
        <source>Suspended</source>
        <translation>Tạm ngưng</translation>
    </message>
    <message>
        <source>Locked</source>
        <translation>Đã khóa</translation>
    </message>
    <message>
        <source>Left</source>
        <translation>Đã nghỉ</translation>
    </message>
    <message>
        <source>Cancelled</source>
        <translation>Đã hủy</translation>
    </message>
    <message>
        <source>Lecture</source>
        <translation>Lý thuyết</translation>
    </message>
    <message>
        <source>Lab</source>
        <translation>Phòng Lab</translation>
    </message>
    <message>
        <source>Multi-purpose</source>
        <translation>Đa năng</translation>
    </message>
    <message>
        <source>Available</source>
        <translation>Sẵn sàng</translation>
    </message>
    <message>
        <source>Maintenance</source>
        <translation>Bảo trì</translation>
    </message>
    <message>
        <source>Male</source>
        <translation>Nam</translation>
    </message>
    <message>
        <source>Female</source>
        <translation>Nữ</translation>
    </message>
    <message>
        <source>Other</source>
        <translation>Khác</translation>
    </message>
    <message>
        <source>Manager</source>
        <translation>Quản lý</translation>
    </message>
    <message>
        <source>Academic staff</source>
        <translation>Giáo vụ</translation>
    </message>
    <message>
        <source>Accountant</source>
        <translation>Kế toán</translation>
    </message>
    <message>
        <source>Consultant</source>
        <translation>Tư vấn</translation>
    </message>
    <message>
        <source>Bachelor</source>
        <translation>Cử nhân</translation>
    </message>
    <message>
        <source>Master</source>
        <translation>Thạc sĩ</translation>
    </message>
    <message>
        <source>PhD</source>
        <translation>Tiến sĩ</translation>
    </message>
    <message>
        <source>Vietnamese</source>
        <translation>Việt Nam</translation>
    </message>
    <message>
        <source>Native</source>
        <translation>Bản ngữ</translation>
    </message>
    <message>
        <source>Working</source>
        <translation>Đang làm</translation>
    </message>
    <message>
        <source>Teaching</source>
        <translation>Đang dạy</translation>
    </message>
    <message>
        <source>On leave</source>
        <translation>Tạm nghỉ</translation>
    </message>
    <message>
        <source>Prospective</source>
        <translation>Tiềm năng</translation>
    </message>
    <message>
        <source>Studying</source>
        <translation>Đang học</translation>
    </message>
    <message>
        <source>On hold</source>
        <translation>Bảo lưu</translation>
    </message>
    <message>
        <source>Dropped out</source>
        <translation>Ngừng học</translation>
    </message>
    <message>
        <source>Open</source>
        <translation>Đang mở</translation>
    </message>
    <message>
        <source>Discontinued</source>
        <translation>Ngừng mở</translation>
    </message>
    <message>
        <source>Enrolling</source>
        <translation>Đang tuyển sinh</translation>
    </message>
    <message>
        <source>In progress</source>
        <translation>Đang học</translation>
    </message>
    <message>
        <source>Finished</source>
        <translation>Đã kết thúc</translation>
    </message>
    <message>
        <source>Scheduled</source>
        <translation>Chưa dạy</translation>
    </message>
    <message>
        <source>Taught</source>
        <translation>Đã dạy</translation>
    </message>
    <message>
        <source>Completed</source>
        <translation>Hoàn thành</translation>
    </message>
    <message>
        <source>Passed</source>
        <translation>Đạt</translation>
    </message>
    <message>
        <source>Failed</source>
        <translation>Không đạt</translation>
    </message>
    <message>
        <source>Excellent</source>
        <translation>Xuất sắc</translation>
    </message>
    <message>
        <source>Very good</source>
        <translation>Giỏi</translation>
    </message>
    <message>
        <source>Good</source>
        <translation>Khá</translation>
    </message>
    <message>
        <source>Average</source>
        <translation>Trung bình</translation>
    </message>
    <message>
        <source>Present</source>
        <translation>Có mặt</translation>
    </message>
    <message>
        <source>Late</source>
        <translation>Đi trễ</translation>
    </message>
    <message>
        <source>Excused absence</source>
        <translation>Vắng có phép</translation>
    </message>
    <message>
        <source>Unexcused absence</source>
        <translation>Vắng không phép</translation>
    </message>
    <message>
        <source>Cash</source>
        <translation>Tiền mặt</translation>
    </message>
    <message>
        <source>Bank transfer</source>
        <translation>Chuyển khoản</translation>
    </message>
    <message>
        <source>Card</source>
        <translation>Thẻ</translation>
    </message>
    <message>
        <source>Valid</source>
        <translation>Hợp lệ</translation>
    </message>
    <message>
        <source>Finalized</source>
        <translation>Đã chốt</translation>
    </message>
    <message>
        <source>Paid</source>
        <translation>Đã chi trả</translation>
    </message>
    <message>
        <source>PERCENT</source>
        <translation>Phần trăm</translation>
    </message>
    <message>
        <source>AMOUNT</source>
        <translation>Số tiền</translation>
    </message>
    <message>
        <source>Expired</source>
        <translation>Hết hạn</translation>
    </message>
    <message>
        <source>Upcoming</source>
        <translation>Chưa bắt đầu</translation>
    </message>
</context>
<context>
    <name>Employee</name>
    <message>
        <source>Full name is required.</source>
        <translation>Vui lòng nhập họ tên.</translation>
    </message>
    <message>
        <source>Full name must be at most %1 characters.</source>
        <translation>Họ tên tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Invalid date of birth.</source>
        <translation>Ngày sinh không hợp lệ.</translation>
    </message>
    <message>
        <source>Staff must be at least 18 years old on the hire date.</source>
        <translation>Nhân sự phải đủ 18 tuổi vào ngày vào làm.</translation>
    </message>
    <message>
        <source>Invalid gender.</source>
        <translation>Giới tính không hợp lệ.</translation>
    </message>
    <message>
        <source>Phone numbers contain 9-11 digits only.</source>
        <translation>Số điện thoại chỉ gồm 9-11 chữ số.</translation>
    </message>
    <message>
        <source>Invalid email address.</source>
        <translation>Email không hợp lệ.</translation>
    </message>
    <message>
        <source>Address must be at most %1 characters.</source>
        <translation>Địa chỉ tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Invalid position.</source>
        <translation>Chức vụ không hợp lệ.</translation>
    </message>
    <message>
        <source>Please choose a branch.</source>
        <translation>Vui lòng chọn chi nhánh.</translation>
    </message>
    <message>
        <source>The salary cannot be negative.</source>
        <translation>Lương không được âm.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
</context>
<context>
    <name>EmployeePage</name>
    <message>
        <source>New employee</source>
        <translation>Thêm nhân viên</translation>
    </message>
    <message>
        <source>Edit</source>
        <translation>Sửa</translation>
    </message>
    <message>
        <source>Edit employee %1</source>
        <translation>Sửa nhân viên %1</translation>
    </message>
    <message>
        <source>Full name</source>
        <translation>Họ tên</translation>
    </message>
    <message>
        <source>Date of birth</source>
        <translation>Ngày sinh</translation>
    </message>
    <message>
        <source>Gender</source>
        <translation>Giới tính</translation>
    </message>
    <message>
        <source>Phone</source>
        <translation>Điện thoại</translation>
    </message>
    <message>
        <source>Email</source>
        <translation>Email</translation>
    </message>
    <message>
        <source>Address</source>
        <translation>Địa chỉ</translation>
    </message>
    <message>
        <source>Position</source>
        <translation>Chức vụ</translation>
    </message>
    <message>
        <source>Branch</source>
        <translation>Chi nhánh</translation>
    </message>
    <message>
        <source>Hire date</source>
        <translation>Ngày vào làm</translation>
    </message>
    <message>
        <source>Base salary</source>
        <translation>Lương cơ bản</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
</context>
<context>
    <name>EnrollDialog</name>
    <message>
        <source>New enrollment</source>
        <translation>Ghi danh mới</translation>
    </message>
    <message>
        <source>Student ID, name or phone...</source>
        <translation>Mã, họ tên hoặc SĐT học viên...</translation>
    </message>
    <message>
        <source>Find</source>
        <translation>Tìm</translation>
    </message>
    <message>
        <source>Find student</source>
        <translation>Tìm học viên</translation>
    </message>
    <message>
        <source>Student</source>
        <translation>Học viên</translation>
    </message>
    <message>
        <source>Class</source>
        <translation>Lớp</translation>
    </message>
    <message>
        <source>Enrollment date</source>
        <translation>Ngày ghi danh</translation>
    </message>
    <message>
        <source>Promotion</source>
        <translation>Khuyến mãi</translation>
    </message>
    <message>
        <source>Enroll</source>
        <translation>Ghi danh</translation>
    </message>
    <message>
        <source>No student matches &quot;%1&quot;.</source>
        <translation>Không có học viên nào khớp với &quot;%1&quot;.</translation>
    </message>
    <message>
        <source>No promotion</source>
        <translation>Không khuyến mãi</translation>
    </message>
    <message>
        <source>%1 - %2, tuition %3, %4 seats left</source>
        <translation>%1 - %2, học phí %3, còn %4 chỗ</translation>
    </message>
</context>
<context>
    <name>EnrollmentPage</name>
    <message>
        <source>All statuses</source>
        <translation>Tất cả trạng thái</translation>
    </message>
    <message>
        <source>New enrollment</source>
        <translation>Ghi danh mới</translation>
    </message>
    <message>
        <source>Transfer class</source>
        <translation>Chuyển lớp</translation>
    </message>
    <message>
        <source>Put on hold</source>
        <translation>Bảo lưu</translation>
    </message>
    <message>
        <source>Resume</source>
        <translation>Học lại</translation>
    </message>
    <message>
        <source>Leave</source>
        <translation>Nghỉ học</translation>
    </message>
    <message>
        <source>There is no other open class of the same course and branch.</source>
        <translation>Không có lớp nào khác đang mở cùng khóa học và chi nhánh.</translation>
    </message>
    <message>
        <source>Transfer %1 to another class</source>
        <translation>Chuyển %1 sang lớp khác</translation>
    </message>
    <message>
        <source>%1 - %2 (%3 seats left)</source>
        <translation>%1 - %2 (còn %3 chỗ)</translation>
    </message>
    <message>
        <source>Current class</source>
        <translation>Lớp hiện tại</translation>
    </message>
    <message>
        <source>New class</source>
        <translation>Lớp mới</translation>
    </message>
    <message>
        <source>The payments stay with the enrollment; the tuition of the new class applies and the attendance starts again.</source>
        <translation>Các khoản đã đóng được giữ nguyên; học phí theo lớp mới và chuyên cần được tính lại từ đầu.</translation>
    </message>
    <message>
        <source>Transfer</source>
        <translation>Chuyển lớp</translation>
    </message>
    <message>
        <source>Put the enrollment of %1 in %2 on hold?</source>
        <translation>Bảo lưu ghi danh của %1 ở lớp %2?</translation>
    </message>
    <message>
        <source>Resume the enrollment of %1 in %2?</source>
        <translation>Cho %1 học lại ở lớp %2?</translation>
    </message>
    <message>
        <source>End the enrollment of %1 in %2 (the student leaves the class)?</source>
        <translation>Kết thúc ghi danh của %1 ở lớp %2 (học viên nghỉ học)?</translation>
    </message>
</context>
<context>
    <name>EnrollmentRequest</name>
    <message>
        <source>Please choose a student.</source>
        <translation>Vui lòng chọn học viên.</translation>
    </message>
    <message>
        <source>Please choose a class.</source>
        <translation>Vui lòng chọn lớp.</translation>
    </message>
    <message>
        <source>The enrollment date cannot be in the future.</source>
        <translation>Ngày ghi danh không được ở tương lai.</translation>
    </message>
</context>
<context>
    <name>EnrollmentService</name>
    <message>
        <source>No enrollment is selected.</source>
        <translation>Chưa chọn ghi danh.</translation>
    </message>
    <message>
        <source>Please choose the new class.</source>
        <translation>Vui lòng chọn lớp mới.</translation>
    </message>
    <message>
        <source>The student is already in this class.</source>
        <translation>Học viên đã ở trong lớp này.</translation>
    </message>
</context>
<context>
    <name>FormDialog</name>
    <message>
        <source>Save</source>
        <translation>Lưu</translation>
    </message>
    <message>
        <source>Cancel</source>
        <translation>Hủy</translation>
    </message>
    <message>
        <source>Close</source>
        <translation>Đóng</translation>
    </message>
</context>
<context>
    <name>Format</name>
    <message>
        <source>%1B</source>
        <translation>%1 tỷ</translation>
    </message>
    <message>
        <source>%1M</source>
        <translation>%1 tr</translation>
    </message>
    <message>
        <source>Yes</source>
        <translation>Có</translation>
    </message>
</context>
<context>
    <name>GradeBookPage</name>
    <message>
        <source>Refresh</source>
        <translation>Làm mới</translation>
    </message>
    <message>
        <source>Excel</source>
        <translation>Excel</translation>
    </message>
    <message>
        <source>PDF</source>
        <translation>PDF</translation>
    </message>
    <message>
        <source>Save grades</source>
        <translation>Lưu điểm</translation>
    </message>
    <message>
        <source>Class</source>
        <translation>Lớp</translation>
    </message>
    <message>
        <source>Grade book %1</source>
        <translation>Sổ điểm %1</translation>
    </message>
    <message>
        <source>Save the scores you typed before reloading?</source>
        <translation>Lưu các điểm vừa nhập trước khi tải lại?</translation>
    </message>
    <message>
        <source>Double-click a score to change it (0 to 10), then save.</source>
        <translation>Nhấp đúp vào ô điểm để nhập (0 đến 10), rồi bấm Lưu điểm.</translation>
    </message>
    <message>
        <source>The class has finished: its grades are final.</source>
        <translation>Lớp đã kết thúc: điểm đã chốt.</translation>
    </message>
    <message>
        <source>Warning: the weights of the course add up to %1%, not 100%: the class cannot be evaluated.</source>
        <translation>Cảnh báo: tổng trọng số của khóa học là %1%, không phải 100%: lớp chưa thể đánh giá kết quả.</translation>
    </message>
    <message>
        <source>%1 students, %2 with every score</source>
        <translation>%1 học viên, %2 học viên đủ điểm</translation>
    </message>
    <message>
        <source>%1 scores not saved yet</source>
        <translation>%1 điểm chưa lưu</translation>
    </message>
    <message>
        <source>Scores are between 0 and 10, with at most 2 decimals.</source>
        <translation>Điểm từ 0 đến 10, tối đa 2 chữ số thập phân.</translation>
    </message>
</context>
<context>
    <name>GradeComponent</name>
    <message>
        <source>Please choose a course.</source>
        <translation>Vui lòng chọn khóa học.</translation>
    </message>
    <message>
        <source>The component name is required.</source>
        <translation>Vui lòng nhập tên cột điểm.</translation>
    </message>
    <message>
        <source>The weight must be above 0 and at most 100.</source>
        <translation>Trọng số phải lớn hơn 0 và tối đa 100.</translation>
    </message>
</context>
<context>
    <name>GradeService</name>
    <message>
        <source>No class is selected.</source>
        <translation>Chưa chọn lớp.</translation>
    </message>
    <message>
        <source>A score has no student or grade component.</source>
        <translation>Có điểm chưa gắn với học viên hoặc cột điểm.</translation>
    </message>
    <message>
        <source>Grades must be between 0 and 10.</source>
        <translation>Điểm phải từ 0 đến 10.</translation>
    </message>
</context>
<context>
    <name>I18n</name>
    <message>
        <source>English Center Management</source>
        <translation>Quản lý Trung tâm Tiếng Anh</translation>
    </message>
</context>
<context>
    <name>Labels</name>
    <message>
        <source>Manager</source>
        <translation>Quản lý</translation>
    </message>
    <message>
        <source>Academic staff</source>
        <translation>Giáo vụ</translation>
    </message>
    <message>
        <source>Accountant</source>
        <translation>Kế toán</translation>
    </message>
    <message>
        <source>Teacher</source>
        <translation>Giáo viên</translation>
    </message>
    <message>
        <source>Unknown</source>
        <translation>Không xác định</translation>
    </message>
    <message>
        <source>Placement tests</source>
        <translation>Kiểm tra xếp lớp</translation>
    </message>
    <message>
        <source>Enrollments</source>
        <translation>Ghi danh</translation>
    </message>
    <message>
        <source>Timetable &amp; attendance</source>
        <translation>Lịch học - điểm danh</translation>
    </message>
    <message>
        <source>Grade book</source>
        <translation>Sổ điểm</translation>
    </message>
    <message>
        <source>Tuition collection</source>
        <translation>Thu học phí</translation>
    </message>
    <message>
        <source>Courses</source>
        <translation>Khóa học</translation>
    </message>
    <message>
        <source>Teachers</source>
        <translation>Giáo viên</translation>
    </message>
    <message>
        <source>Employees</source>
        <translation>Nhân viên</translation>
    </message>
    <message>
        <source>Branches &amp; rooms</source>
        <translation>Chi nhánh - phòng học</translation>
    </message>
    <message>
        <source>Promotions</source>
        <translation>Khuyến mãi</translation>
    </message>
    <message>
        <source>Backup</source>
        <translation>Sao lưu</translation>
    </message>
    <message>
        <source>My grade book</source>
        <translation>Sổ điểm của tôi</translation>
    </message>
    <message>
        <source>General</source>
        <translation>Chung</translation>
    </message>
    <message>
        <source>Training</source>
        <translation>Đào tạo</translation>
    </message>
    <message>
        <source>Finance</source>
        <translation>Tài chính</translation>
    </message>
    <message>
        <source>Catalogs</source>
        <translation>Danh mục</translation>
    </message>
    <message>
        <source>Teaching</source>
        <translation>Giảng dạy</translation>
    </message>
    <message>
        <source>Overview</source>
        <translation>Tổng quan</translation>
    </message>
    <message>
        <source>Students</source>
        <translation>Học viên</translation>
    </message>
    <message>
        <source>Classes</source>
        <translation>Lớp học</translation>
    </message>
    <message>
        <source>Learning results</source>
        <translation>Kết quả học tập</translation>
    </message>
    <message>
        <source>Outstanding tuition</source>
        <translation>Công nợ học phí</translation>
    </message>
    <message>
        <source>Revenue</source>
        <translation>Doanh thu</translation>
    </message>
    <message>
        <source>Teacher payroll</source>
        <translation>Lương giáo viên</translation>
    </message>
    <message>
        <source>Accounts</source>
        <translation>Tài khoản</translation>
    </message>
    <message>
        <source>System</source>
        <translation>Hệ thống</translation>
    </message>
    <message>
        <source>%1 (database administrator)</source>
        <translation>%1 (quản trị CSDL)</translation>
    </message>
    <message>
        <source>My classes</source>
        <translation>Lớp của tôi</translation>
    </message>
    <message>
        <source>Teaching schedule</source>
        <translation>Lịch dạy</translation>
    </message>
    <message>
        <source>My pay</source>
        <translation>Lương của tôi</translation>
    </message>
</context>
<context>
    <name>ListService</name>
    <message>
        <source>You are not allowed to view this feature.</source>
        <translation>Bạn không có quyền xem chức năng này.</translation>
    </message>
    <message>
        <source>This feature has no lookup list.</source>
        <translation>Chức năng không có danh sách tra cứu.</translation>
    </message>
</context>
<context>
    <name>LoginDialog</name>
    <message>
        <source>Sign in - English Center Management</source>
        <translation>Đăng nhập - Quản lý Trung tâm Tiếng Anh</translation>
    </message>
    <message>
        <source>English center management system: students, classes, enrollment, tuition, attendance and learning results.</source>
        <translation>Hệ thống quản lý trung tâm tiếng Anh: học viên, lớp học, ghi danh, học phí, điểm danh, kết quả học tập.</translation>
    </message>
    <message>
        <source>IE103 project - Information Management · UIT · Group 1</source>
        <translation>Đồ án IE103 - Quản lý thông tin · UIT · Nhóm 1</translation>
    </message>
    <message>
        <source>Sign in</source>
        <translation>Đăng nhập</translation>
    </message>
    <message>
        <source>Use the account issued by your manager (a SQL Server account).</source>
        <translation>Dùng tài khoản được quản lý cấp (tài khoản SQL Server).</translation>
    </message>
    <message>
        <source>Username</source>
        <translation>Tên đăng nhập</translation>
    </message>
    <message>
        <source>Password</source>
        <translation>Mật khẩu</translation>
    </message>
    <message>
        <source>Server settings</source>
        <translation>Cấu hình máy chủ</translation>
    </message>
    <message>
        <source>SQL Server</source>
        <translation>Máy chủ SQL Server</translation>
    </message>
    <message>
        <source>localhost,1433 or PC-NAME\SQLEXPRESS</source>
        <translation>localhost,1433 hoặc TEN-MAY\SQLEXPRESS</translation>
    </message>
    <message>
        <source>Trust server certificate (TrustServerCertificate)</source>
        <translation>Tin cậy chứng chỉ máy chủ (TrustServerCertificate)</translation>
    </message>
    <message>
        <source>Server</source>
        <translation>Máy chủ</translation>
    </message>
    <message>
        <source>Database</source>
        <translation>CSDL</translation>
    </message>
    <message>
        <source>Version %1</source>
        <translation>Phiên bản %1</translation>
    </message>
    <message>
        <source>Connecting...</source>
        <translation>Đang kết nối...</translation>
    </message>
</context>
<context>
    <name>MainWindow</name>
    <message>
        <source>English Center Management</source>
        <translation>Quản lý Trung tâm Tiếng Anh</translation>
    </message>
    <message>
        <source>Change password</source>
        <translation>Đổi mật khẩu</translation>
    </message>
    <message>
        <source>Log out</source>
        <translation>Đăng xuất</translation>
    </message>
    <message>
        <source>Do you want to log out?</source>
        <translation>Bạn muốn đăng xuất?</translation>
    </message>
</context>
<context>
    <name>MyClassesPage</name>
    <message>
        <source>Students</source>
        <translation>Học viên</translation>
    </message>
    <message>
        <source>Syllabus</source>
        <translation>Giáo trình</translation>
    </message>
    <message>
        <source>Students of class %1 - %2</source>
        <translation>Học viên lớp %1 - %2</translation>
    </message>
    <message>
        <source>Syllabus of %1</source>
        <translation>Giáo trình %1</translation>
    </message>
    <message>
        <source>This course has no syllabus yet.</source>
        <translation>Khóa học này chưa có giáo trình.</translation>
    </message>
</context>
<context>
    <name>NewAccount</name>
    <message>
        <source>A username may only contain letters without diacritics, digits, dots and underscores (3 to %1 characters).</source>
        <translation>Tên đăng nhập chỉ gồm chữ không dấu, số, dấu chấm và gạch dưới (từ 3 đến %1 ký tự).</translation>
    </message>
    <message>
        <source>The password must be at least %1 characters long.</source>
        <translation>Mật khẩu phải có ít nhất %1 ký tự.</translation>
    </message>
    <message>
        <source>The password and its confirmation do not match.</source>
        <translation>Mật khẩu nhập lại không khớp.</translation>
    </message>
    <message>
        <source>Please choose a role.</source>
        <translation>Vui lòng chọn vai trò.</translation>
    </message>
    <message>
        <source>Please choose the employee or teacher who will use the account.</source>
        <translation>Vui lòng chọn nhân viên hoặc giáo viên sử dụng tài khoản.</translation>
    </message>
</context>
<context>
    <name>PayrollPage</name>
    <message>
        <source>All years</source>
        <translation>Tất cả các năm</translation>
    </message>
    <message>
        <source>All months</source>
        <translation>Tất cả các tháng</translation>
    </message>
    <message>
        <source>Month %1</source>
        <translation>Tháng %1</translation>
    </message>
    <message>
        <source>Finalize month</source>
        <translation>Chốt lương tháng</translation>
    </message>
    <message>
        <source>Deduction</source>
        <translation>Khấu trừ</translation>
    </message>
    <message>
        <source>Mark as paid</source>
        <translation>Đã chi trả</translation>
    </message>
    <message>
        <source>Finalize the payroll of a month</source>
        <translation>Chốt bảng lương tháng</translation>
    </message>
    <message>
        <source>Month</source>
        <translation>Tháng</translation>
    </message>
    <message>
        <source>Year</source>
        <translation>Năm</translation>
    </message>
    <message>
        <source>Counts the taught sessions of every teacher in that month. A month can be finalized again; paid rows never change.</source>
        <translation>Đếm số buổi đã dạy của từng giáo viên trong tháng. Có thể chốt lại một tháng; các dòng đã chi trả không bị thay đổi.</translation>
    </message>
    <message>
        <source>Finalize</source>
        <translation>Chốt lương</translation>
    </message>
    <message>
        <source>Payroll of %1/%2</source>
        <translation>Bảng lương tháng %1/%2</translation>
    </message>
    <message>
        <source>Deduction - %1, %2/%3</source>
        <translation>Khấu trừ - %1, tháng %2/%3</translation>
    </message>
    <message>
        <source>The total pay is recomputed by the database: hours x rate + bonus - deduction.</source>
        <translation>Tổng lương do cơ sở dữ liệu tính lại: số giờ x đơn giá + thưởng - khấu trừ.</translation>
    </message>
    <message>
        <source>Record that %1 has been paid %2 for %3/%4? A paid row can no longer change.</source>
        <translation>Ghi nhận đã chi trả cho %1 số tiền %2 của tháng %3/%4? Dòng đã chi trả không thể thay đổi.</translation>
    </message>
</context>
<context>
    <name>PayrollService</name>
    <message>
        <source>Invalid month.</source>
        <translation>Tháng không hợp lệ.</translation>
    </message>
    <message>
        <source>Payroll cannot be finalized for a future month.</source>
        <translation>Không thể chốt lương cho tháng trong tương lai.</translation>
    </message>
    <message>
        <source>No payroll row is selected.</source>
        <translation>Chưa chọn dòng bảng lương.</translation>
    </message>
    <message>
        <source>The deduction cannot be negative.</source>
        <translation>Khấu trừ không được âm.</translation>
    </message>
</context>
<context>
    <name>PlacementPage</name>
    <message>
        <source>New test</source>
        <translation>Thêm bài kiểm tra</translation>
    </message>
    <message>
        <source>Placement test saved</source>
        <translation>Đã lưu bài kiểm tra xếp lớp</translation>
    </message>
    <message>
        <source>Test %1: overall score %2. No open course matches this score.</source>
        <translation>Bài %1: điểm chung %2. Không có khóa học đang mở phù hợp với điểm này.</translation>
    </message>
    <message>
        <source>Test %1: overall score %2. Recommended course: %3.</source>
        <translation>Bài %1: điểm chung %2. Khóa học đề xuất: %3.</translation>
    </message>
</context>
<context>
    <name>PlacementTest</name>
    <message>
        <source>Please choose a student.</source>
        <translation>Vui lòng chọn học viên.</translation>
    </message>
    <message>
        <source>Scores must be between 0 and 10.</source>
        <translation>Điểm phải từ 0 đến 10.</translation>
    </message>
    <message>
        <source>The test date cannot be in the future.</source>
        <translation>Ngày kiểm tra không được ở tương lai.</translation>
    </message>
    <message>
        <source>Notes must be at most %1 characters.</source>
        <translation>Ghi chú tối đa %1 ký tự.</translation>
    </message>
</context>
<context>
    <name>PlacementTestDialog</name>
    <message>
        <source>New placement test</source>
        <translation>Bài kiểm tra xếp lớp mới</translation>
    </message>
    <message>
        <source>Student ID, name or phone...</source>
        <translation>Mã, họ tên hoặc SĐT học viên...</translation>
    </message>
    <message>
        <source>Find</source>
        <translation>Tìm</translation>
    </message>
    <message>
        <source>Not recorded</source>
        <translation>Không ghi nhận</translation>
    </message>
    <message>
        <source>Find student</source>
        <translation>Tìm học viên</translation>
    </message>
    <message>
        <source>Student</source>
        <translation>Học viên</translation>
    </message>
    <message>
        <source>Listening</source>
        <translation>Nghe</translation>
    </message>
    <message>
        <source>Speaking</source>
        <translation>Nói</translation>
    </message>
    <message>
        <source>Reading</source>
        <translation>Đọc</translation>
    </message>
    <message>
        <source>Writing</source>
        <translation>Viết</translation>
    </message>
    <message>
        <source>Overall score</source>
        <translation>Điểm chung</translation>
    </message>
    <message>
        <source>Graded by</source>
        <translation>Người chấm</translation>
    </message>
    <message>
        <source>Test date</source>
        <translation>Ngày kiểm tra</translation>
    </message>
    <message>
        <source>Notes</source>
        <translation>Ghi chú</translation>
    </message>
    <message>
        <source>No student matches &quot;%1&quot;.</source>
        <translation>Không có học viên nào khớp với &quot;%1&quot;.</translation>
    </message>
</context>
<context>
    <name>Program</name>
    <message>
        <source>The program code may only contain letters, digits, dashes and underscores (at most 10).</source>
        <translation>Mã chương trình chỉ gồm chữ không dấu, số, dấu gạch ngang và gạch dưới (tối đa 10 ký tự).</translation>
    </message>
    <message>
        <source>The program name is required.</source>
        <translation>Vui lòng nhập tên chương trình.</translation>
    </message>
</context>
<context>
    <name>Promotion</name>
    <message>
        <source>The promotion code may only contain letters, digits, dashes and underscores (at most 10).</source>
        <translation>Mã khuyến mãi chỉ gồm chữ không dấu, số, dấu gạch ngang và gạch dưới (tối đa 10 ký tự).</translation>
    </message>
    <message>
        <source>The promotion name is required.</source>
        <translation>Vui lòng nhập tên khuyến mãi.</translation>
    </message>
    <message>
        <source>Invalid discount type.</source>
        <translation>Loại giảm giá không hợp lệ.</translation>
    </message>
    <message>
        <source>The discount must be greater than 0.</source>
        <translation>Mức giảm phải lớn hơn 0.</translation>
    </message>
    <message>
        <source>A percentage discount is at most 50%.</source>
        <translation>Giảm theo phần trăm tối đa 50%.</translation>
    </message>
    <message>
        <source>Invalid dates.</source>
        <translation>Ngày không hợp lệ.</translation>
    </message>
    <message>
        <source>The end date cannot be before the start date.</source>
        <translation>Ngày kết thúc không được trước ngày bắt đầu.</translation>
    </message>
</context>
<context>
    <name>PromotionPage</name>
    <message>
        <source>New promotion</source>
        <translation>Thêm khuyến mãi</translation>
    </message>
    <message>
        <source>Edit</source>
        <translation>Sửa</translation>
    </message>
    <message>
        <source>Edit promotion %1</source>
        <translation>Sửa khuyến mãi %1</translation>
    </message>
    <message>
        <source>Promotion code</source>
        <translation>Mã khuyến mãi</translation>
    </message>
    <message>
        <source>Promotion name</source>
        <translation>Tên khuyến mãi</translation>
    </message>
    <message>
        <source>Discount type</source>
        <translation>Loại giảm giá</translation>
    </message>
    <message>
        <source>Discount value</source>
        <translation>Mức giảm</translation>
    </message>
    <message>
        <source>Valid from</source>
        <translation>Hiệu lực từ</translation>
    </message>
    <message>
        <source>Valid until</source>
        <translation>Hiệu lực đến</translation>
    </message>
</context>
<context>
    <name>ReceiptPrinter</name>
    <message>
        <source>Phone: %1</source>
        <translation>Điện thoại: %1</translation>
    </message>
    <message>
        <source>TUITION RECEIPT</source>
        <translation>PHIẾU THU HỌC PHÍ</translation>
    </message>
    <message>
        <source>No. %1 - %2</source>
        <translation>Số %1 - %2</translation>
    </message>
    <message>
        <source>CANCELLED</source>
        <translation>ĐÃ HỦY</translation>
    </message>
    <message>
        <source>Student</source>
        <translation>Học viên</translation>
    </message>
    <message>
        <source>Class</source>
        <translation>Lớp</translation>
    </message>
    <message>
        <source>Course</source>
        <translation>Khóa học</translation>
    </message>
    <message>
        <source>Description</source>
        <translation>Nội dung</translation>
    </message>
    <message>
        <source>Payment method</source>
        <translation>Hình thức</translation>
    </message>
    <message>
        <source>Amount</source>
        <translation>Số tiền</translation>
    </message>
    <message>
        <source>Tuition due</source>
        <translation>Học phí phải đóng</translation>
    </message>
    <message>
        <source>Paid so far</source>
        <translation>Đã đóng</translation>
    </message>
    <message>
        <source>Balance</source>
        <translation>Còn nợ</translation>
    </message>
    <message>
        <source>Payer</source>
        <translation>Người nộp tiền</translation>
    </message>
    <message>
        <source>Collected by</source>
        <translation>Người thu</translation>
    </message>
    <message>
        <source>Receipt %1</source>
        <translation>Phiếu thu %1</translation>
    </message>
</context>
<context>
    <name>ReceiptRequest</name>
    <message>
        <source>Please choose an enrollment.</source>
        <translation>Vui lòng chọn ghi danh.</translation>
    </message>
    <message>
        <source>The amount must be greater than 0.</source>
        <translation>Số tiền phải lớn hơn 0.</translation>
    </message>
    <message>
        <source>The amount is larger than the tuition still owed.</source>
        <translation>Số tiền lớn hơn học phí còn nợ.</translation>
    </message>
    <message>
        <source>Invalid payment method.</source>
        <translation>Hình thức thanh toán không hợp lệ.</translation>
    </message>
    <message>
        <source>The description must be at most %1 characters.</source>
        <translation>Nội dung tối đa %1 ký tự.</translation>
    </message>
</context>
<context>
    <name>RevenueChart</name>
    <message>
        <source>No data yet</source>
        <translation>Chưa có dữ liệu</translation>
    </message>
</context>
<context>
    <name>RevenuePage</name>
    <message>
        <source>By month</source>
        <translation>Theo tháng</translation>
    </message>
    <message>
        <source>By course, for a period</source>
        <translation>Theo khóa học, trong một khoảng thời gian</translation>
    </message>
    <message>
        <source>All branches</source>
        <translation>Tất cả chi nhánh</translation>
    </message>
</context>
<context>
    <name>Room</name>
    <message>
        <source>The room code may only contain letters, digits, dashes and underscores (at most 10).</source>
        <translation>Mã phòng chỉ gồm chữ không dấu, số, dấu gạch ngang và gạch dưới (tối đa 10 ký tự).</translation>
    </message>
    <message>
        <source>Please choose a branch.</source>
        <translation>Vui lòng chọn chi nhánh.</translation>
    </message>
    <message>
        <source>The room name is required.</source>
        <translation>Vui lòng nhập tên phòng.</translation>
    </message>
    <message>
        <source>The capacity must be between 1 and 100.</source>
        <translation>Sức chứa phải từ 1 đến 100.</translation>
    </message>
    <message>
        <source>Invalid room type.</source>
        <translation>Loại phòng không hợp lệ.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
</context>
<context>
    <name>ScheduleDialog</name>
    <message>
        <source>Weekly schedule - %1</source>
        <translation>Lịch tuần - %1</translation>
    </message>
    <message>
        <source>Weekly schedule of %1 - %2</source>
        <translation>Lịch tuần của lớp %1 - %2</translation>
    </message>
    <message>
        <source>Save slot</source>
        <translation>Lưu khung giờ</translation>
    </message>
    <message>
        <source>Remove slot</source>
        <translation>Xóa khung giờ</translation>
    </message>
    <message>
        <source>Weekday</source>
        <translation>Thứ</translation>
    </message>
    <message>
        <source>From</source>
        <translation>Từ</translation>
    </message>
    <message>
        <source>To</source>
        <translation>Đến</translation>
    </message>
    <message>
        <source>Close</source>
        <translation>Đóng</translation>
    </message>
    <message>
        <source>Remove the %1 slot?</source>
        <translation>Xóa khung giờ %1?</translation>
    </message>
    <message>
        <source>A change removes the generated sessions; they are generated again from the new timetable when you close this window. Once a session was taught the timetable is fixed.</source>
        <translation>Mỗi thay đổi sẽ xóa các buổi học đã sinh; khi đóng cửa sổ này, ứng dụng sinh lại buổi học theo lịch mới. Khi đã có buổi được dạy thì lịch tuần không đổi được nữa.</translation>
    </message>
</context>
<context>
    <name>ScheduleSlot</name>
    <message>
        <source>Invalid weekday.</source>
        <translation>Thứ không hợp lệ.</translation>
    </message>
    <message>
        <source>The end time must be after the start time.</source>
        <translation>Giờ kết thúc phải sau giờ bắt đầu.</translation>
    </message>
    <message>
        <source>Classes take place between 07:00 and 22:00.</source>
        <translation>Lớp học diễn ra trong khoảng 07:00 - 22:00.</translation>
    </message>
</context>
<context>
    <name>SessionService</name>
    <message>
        <source>Invalid date.</source>
        <translation>Ngày không hợp lệ.</translation>
    </message>
    <message>
        <source>No session is selected.</source>
        <translation>Chưa chọn buổi học.</translation>
    </message>
    <message>
        <source>Invalid attendance status for %1.</source>
        <translation>Trạng thái điểm danh không hợp lệ của %1.</translation>
    </message>
    <message>
        <source>Notes must be at most %1 characters (%2).</source>
        <translation>Ghi chú tối đa %1 ký tự (%2).</translation>
    </message>
</context>
<context>
    <name>SessionUpdate</name>
    <message>
        <source>No session is selected.</source>
        <translation>Chưa chọn buổi học.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
    <message>
        <source>A session can only be marked as taught on or after its date.</source>
        <translation>Buổi học chỉ được đánh dấu đã dạy từ ngày của buổi đó trở đi.</translation>
    </message>
    <message>
        <source>The description must be at most %1 characters.</source>
        <translation>Nội dung tối đa %1 ký tự.</translation>
    </message>
</context>
<context>
    <name>SqlBackupRepository</name>
    <message>
        <source>The backup file name was not returned.</source>
        <translation>Không nhận được tên file sao lưu.</translation>
    </message>
</context>
<context>
    <name>SqlCatalogRepository</name>
    <message>
        <source>Branch %1 was not found.</source>
        <translation>Không tìm thấy chi nhánh %1.</translation>
    </message>
    <message>
        <source>Room %1 was not found.</source>
        <translation>Không tìm thấy phòng %1.</translation>
    </message>
    <message>
        <source>Program %1 was not found.</source>
        <translation>Không tìm thấy chương trình %1.</translation>
    </message>
    <message>
        <source>Promotion %1 was not found.</source>
        <translation>Không tìm thấy khuyến mãi %1.</translation>
    </message>
</context>
<context>
    <name>SqlClassRepository</name>
    <message>
        <source>Class %1 was not found.</source>
        <translation>Không tìm thấy lớp %1.</translation>
    </message>
    <message>
        <source>The new class ID was not returned.</source>
        <translation>Không nhận được mã lớp mới.</translation>
    </message>
</context>
<context>
    <name>SqlCourseRepository</name>
    <message>
        <source>Course %1 was not found.</source>
        <translation>Không tìm thấy khóa học %1.</translation>
    </message>
</context>
<context>
    <name>SqlEnrollmentRepository</name>
    <message>
        <source>The new enrollment ID was not returned.</source>
        <translation>Không nhận được mã ghi danh mới.</translation>
    </message>
</context>
<context>
    <name>SqlErrorMapper</name>
    <message>
        <source>Students under 18 need guardian information.</source>
        <translation>Học viên dưới 18 tuổi phải có thông tin phụ huynh.</translation>
    </message>
    <message>
        <source>At least one contact phone number is required.</source>
        <translation>Cần ít nhất một số điện thoại liên lạc.</translation>
    </message>
    <message>
        <source>Phone numbers contain 9-11 digits only.</source>
        <translation>Số điện thoại chỉ gồm 9-11 chữ số.</translation>
    </message>
    <message>
        <source>Invalid email address.</source>
        <translation>Email không đúng định dạng.</translation>
    </message>
    <message>
        <source>Invalid date of birth (students must be at least 4 years old).</source>
        <translation>Ngày sinh không hợp lệ (học viên từ 4 tuổi).</translation>
    </message>
    <message>
        <source>The amount paid exceeds the tuition due.</source>
        <translation>Số tiền đã đóng vượt quá học phí phải đóng.</translation>
    </message>
    <message>
        <source>Grades must be between 0 and 10.</source>
        <translation>Điểm phải nằm trong khoảng 0 - 10.</translation>
    </message>
    <message>
        <source>The student is already enrolled in this class.</source>
        <translation>Học viên đã ghi danh lớp này.</translation>
    </message>
    <message>
        <source>This phone number is already used by another student.</source>
        <translation>Số điện thoại đã được dùng cho học viên khác.</translation>
    </message>
    <message>
        <source>This email is already used by another student.</source>
        <translation>Email đã được dùng cho học viên khác.</translation>
    </message>
    <message>
        <source>The student has enrollment records and cannot be deleted.</source>
        <translation>Học viên đang có dữ liệu ghi danh, không thể xóa.</translation>
    </message>
    <message>
        <source>Another branch already has this name.</source>
        <translation>Đã có chi nhánh khác mang tên này.</translation>
    </message>
    <message>
        <source>This branch already has a room with this name.</source>
        <translation>Chi nhánh đã có phòng mang tên này.</translation>
    </message>
    <message>
        <source>Another program already has this name.</source>
        <translation>Đã có chương trình khác mang tên này.</translation>
    </message>
    <message>
        <source>Another course already has this name.</source>
        <translation>Đã có khóa học khác mang tên này.</translation>
    </message>
    <message>
        <source>The course already has a grade component with this name.</source>
        <translation>Khóa học đã có cột điểm mang tên này.</translation>
    </message>
    <message>
        <source>This phone number is already used by another employee.</source>
        <translation>Số điện thoại này đã được nhân viên khác sử dụng.</translation>
    </message>
    <message>
        <source>This email is already used by another employee.</source>
        <translation>Email này đã được nhân viên khác sử dụng.</translation>
    </message>
    <message>
        <source>This phone number is already used by another teacher.</source>
        <translation>Số điện thoại này đã được giáo viên khác sử dụng.</translation>
    </message>
    <message>
        <source>This email is already used by another teacher.</source>
        <translation>Email này đã được giáo viên khác sử dụng.</translation>
    </message>
    <message>
        <source>Staff must be at least 18 years old on the hire date.</source>
        <translation>Nhân sự phải đủ 18 tuổi vào ngày vào làm.</translation>
    </message>
    <message>
        <source>A native-speaker teacher cannot have Vietnamese nationality.</source>
        <translation>Giáo viên bản ngữ không thể có quốc tịch Việt Nam.</translation>
    </message>
    <message>
        <source>A course cannot be its own prerequisite.</source>
        <translation>Khóa học không thể là khóa tiên quyết của chính nó.</translation>
    </message>
    <message>
        <source>The discount must be positive, and at most 50 for a percentage.</source>
        <translation>Mức giảm phải lớn hơn 0, và tối đa 50 nếu giảm theo phần trăm.</translation>
    </message>
    <message>
        <source>The end date cannot be before the start date.</source>
        <translation>Ngày kết thúc không được trước ngày bắt đầu.</translation>
    </message>
    <message>
        <source>A time slot must end after it starts and stay between 07:00 and 22:00.</source>
        <translation>Khung giờ phải kết thúc sau khi bắt đầu và nằm trong 07:00 - 22:00.</translation>
    </message>
    <message>
        <source>This person already has an account.</source>
        <translation>Người này đã có tài khoản.</translation>
    </message>
    <message>
        <source>The data violates an integrity constraint: %1</source>
        <translation>Dữ liệu vi phạm ràng buộc toàn vẹn: %1</translation>
    </message>
    <message>
        <source>Wrong username or password, or the account is locked.</source>
        <translation>Sai tên đăng nhập hoặc mật khẩu, hoặc tài khoản đã bị khóa.</translation>
    </message>
    <message>
        <source>Cannot open the database. Check the database name in the server settings.</source>
        <translation>Không mở được cơ sở dữ liệu. Kiểm tra lại tên CSDL trong phần cấu hình máy chủ.</translation>
    </message>
    <message>
        <source>Cannot connect to SQL Server.
Check the server address, the port (1433 by default) and that the SQL Server service is running.</source>
        <translation>Không kết nối được máy chủ SQL Server.
Kiểm tra địa chỉ máy chủ, cổng (mặc định 1433) và dịch vụ SQL Server đang chạy.</translation>
    </message>
    <message>
        <source>The server&apos;s security certificate was rejected. Turn on &quot;Trust server certificate&quot; in the server settings.</source>
        <translation>Lỗi chứng chỉ bảo mật của máy chủ. Hãy bật &quot;Tin cậy chứng chỉ máy chủ&quot; trong phần cấu hình máy chủ.</translation>
    </message>
    <message>
        <source>You do not have permission to perform this action (denied by SQL Server).</source>
        <translation>Bạn không có quyền thực hiện thao tác này (SQL Server từ chối).</translation>
    </message>
    <message>
        <source>The text is not well-formed XML: %1</source>
        <translation>Nội dung không phải XML hợp lệ: %1</translation>
    </message>
    <message>
        <source>The pay of the month would fall below its deduction: lower the deduction first.</source>
        <translation>Lương của tháng sẽ thấp hơn khoản khấu trừ: hãy giảm khoản khấu trừ trước.</translation>
    </message>
</context>
<context>
    <name>SqlPlacementRepository</name>
    <message>
        <source>The new placement test was not returned.</source>
        <translation>Không nhận được bài kiểm tra mới.</translation>
    </message>
</context>
<context>
    <name>SqlStaffRepository</name>
    <message>
        <source>Employee %1 was not found.</source>
        <translation>Không tìm thấy nhân viên %1.</translation>
    </message>
    <message>
        <source>The new employee ID was not returned.</source>
        <translation>Không nhận được mã nhân viên mới.</translation>
    </message>
    <message>
        <source>Teacher %1 was not found.</source>
        <translation>Không tìm thấy giáo viên %1.</translation>
    </message>
    <message>
        <source>The new teacher ID was not returned.</source>
        <translation>Không nhận được mã giáo viên mới.</translation>
    </message>
</context>
<context>
    <name>SqlStudentRepository</name>
    <message>
        <source>Student %1 was not found.</source>
        <translation>Không tìm thấy học viên %1.</translation>
    </message>
    <message>
        <source>The new student ID was not returned.</source>
        <translation>Không nhận được mã học viên mới.</translation>
    </message>
</context>
<context>
    <name>SqlTuitionRepository</name>
    <message>
        <source>The new receipt ID was not returned.</source>
        <translation>Không nhận được số phiếu thu mới.</translation>
    </message>
    <message>
        <source>Receipt %1 was not found.</source>
        <translation>Không tìm thấy phiếu thu %1.</translation>
    </message>
</context>
<context>
    <name>StaffService</name>
    <message>
        <source>No employee is selected.</source>
        <translation>Chưa chọn nhân viên.</translation>
    </message>
    <message>
        <source>No teacher is selected.</source>
        <translation>Chưa chọn giáo viên.</translation>
    </message>
    <message>
        <source>Please enter a certificate type, for example IELTS.</source>
        <translation>Vui lòng nhập loại chứng chỉ, ví dụ IELTS.</translation>
    </message>
</context>
<context>
    <name>StatisticsService</name>
    <message>
        <source>Invalid year.</source>
        <translation>Năm không hợp lệ.</translation>
    </message>
    <message>
        <source>Invalid dates.</source>
        <translation>Ngày không hợp lệ.</translation>
    </message>
    <message>
        <source>The start date must not be after the end date.</source>
        <translation>Ngày bắt đầu không được sau ngày kết thúc.</translation>
    </message>
</context>
<context>
    <name>Student</name>
    <message>
        <source>Full name is required.</source>
        <translation>Họ tên không được để trống.</translation>
    </message>
    <message>
        <source>Full name must be at most 100 characters.</source>
        <translation>Họ tên tối đa 100 ký tự.</translation>
    </message>
    <message>
        <source>Invalid date of birth.</source>
        <translation>Ngày sinh không hợp lệ.</translation>
    </message>
    <message>
        <source>Students must be at least 4 years old.</source>
        <translation>Học viên phải từ 4 tuổi trở lên.</translation>
    </message>
    <message>
        <source>Invalid gender.</source>
        <translation>Giới tính không hợp lệ.</translation>
    </message>
    <message>
        <source>Phone numbers contain 9-11 digits only.</source>
        <translation>Số điện thoại chỉ gồm 9-11 chữ số.</translation>
    </message>
    <message>
        <source>Guardian phone numbers contain 9-11 digits only.</source>
        <translation>Số điện thoại phụ huynh chỉ gồm 9-11 chữ số.</translation>
    </message>
    <message>
        <source>Invalid email address.</source>
        <translation>Email không đúng định dạng.</translation>
    </message>
    <message>
        <source>Address must be at most %1 characters.</source>
        <translation>Địa chỉ tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Occupation must be at most %1 characters.</source>
        <translation>Nghề nghiệp tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Guardian name must be at most %1 characters.</source>
        <translation>Họ tên phụ huynh tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Notes must be at most %1 characters.</source>
        <translation>Ghi chú tối đa %1 ký tự.</translation>
    </message>
    <message>
        <source>Students under 18 need a guardian name and phone number.</source>
        <translation>Học viên dưới 18 tuổi phải có họ tên và số điện thoại phụ huynh.</translation>
    </message>
    <message>
        <source>At least one contact phone number is required (student or guardian).</source>
        <translation>Cần ít nhất một số điện thoại liên lạc (học viên hoặc phụ huynh).</translation>
    </message>
    <message>
        <source>Please choose a branch.</source>
        <translation>Chưa chọn chi nhánh.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
    <message>
        <source>The registration date cannot be in the future.</source>
        <translation>Ngày đăng ký không được ở tương lai.</translation>
    </message>
</context>
<context>
    <name>StudentFormDialog</name>
    <message>
        <source>Student details</source>
        <translation>Thông tin học viên</translation>
    </message>
    <message>
        <source>Add student</source>
        <translation>Thêm học viên</translation>
    </message>
    <message>
        <source>Personal information</source>
        <translation>Thông tin cá nhân</translation>
    </message>
    <message>
        <source>Student ID</source>
        <translation>Mã học viên</translation>
    </message>
    <message>
        <source>Generated when saved</source>
        <translation>Tự động sinh khi lưu</translation>
    </message>
    <message>
        <source>Full name *</source>
        <translation>Họ tên *</translation>
    </message>
    <message>
        <source>Date of birth *</source>
        <translation>Ngày sinh *</translation>
    </message>
    <message>
        <source>Gender</source>
        <translation>Giới tính</translation>
    </message>
    <message>
        <source>Phone</source>
        <translation>Điện thoại</translation>
    </message>
    <message>
        <source>Email</source>
        <translation>Email</translation>
    </message>
    <message>
        <source>Address</source>
        <translation>Địa chỉ</translation>
    </message>
    <message>
        <source>Occupation</source>
        <translation>Nghề nghiệp</translation>
    </message>
    <message>
        <source>Branch *</source>
        <translation>Chi nhánh *</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>Registered on</source>
        <translation>Ngày đăng ký</translation>
    </message>
    <message>
        <source>Guardian information (required for students under 18)</source>
        <translation>Thông tin phụ huynh (bắt buộc nếu học viên dưới 18 tuổi)</translation>
    </message>
    <message>
        <source>Guardian name</source>
        <translation>Họ tên phụ huynh</translation>
    </message>
    <message>
        <source>Guardian phone</source>
        <translation>SĐT phụ huynh</translation>
    </message>
    <message>
        <source>Notes</source>
        <translation>Ghi chú</translation>
    </message>
    <message>
        <source>Save</source>
        <translation>Lưu</translation>
    </message>
    <message>
        <source>Cancel</source>
        <translation>Hủy</translation>
    </message>
    <message>
        <source>Edit student</source>
        <translation>Sửa thông tin học viên</translation>
    </message>
    <message>
        <source>Guardian information * (student under 18)</source>
        <translation>Thông tin phụ huynh * (học viên dưới 18 tuổi)</translation>
    </message>
    <message>
        <source>Guardian information (optional)</source>
        <translation>Thông tin phụ huynh (không bắt buộc)</translation>
    </message>
</context>
<context>
    <name>StudentPage</name>
    <message>
        <source>Search by ID, name, phone...</source>
        <translation>Tìm mã, họ tên, SĐT...</translation>
    </message>
    <message>
        <source>All branches</source>
        <translation>Tất cả chi nhánh</translation>
    </message>
    <message>
        <source>All statuses</source>
        <translation>Tất cả trạng thái</translation>
    </message>
    <message>
        <source>Add</source>
        <translation>Thêm</translation>
    </message>
    <message>
        <source>Edit</source>
        <translation>Sửa</translation>
    </message>
    <message>
        <source>Delete</source>
        <translation>Xóa</translation>
    </message>
    <message>
        <source>Excel</source>
        <translation>Excel</translation>
    </message>
    <message>
        <source>PDF</source>
        <translation>PDF</translation>
    </message>
    <message>
        <source>Profile</source>
        <translation>Hồ sơ</translation>
    </message>
    <message>
        <source>Enroll</source>
        <translation>Ghi danh</translation>
    </message>
    <message>
        <source>Placement test</source>
        <translation>Kiểm tra xếp lớp</translation>
    </message>
    <message>
        <source>Export XML</source>
        <translation>Xuất XML</translation>
    </message>
    <message>
        <source>Import XML</source>
        <translation>Nhập XML</translation>
    </message>
    <message>
        <source>StudentList</source>
        <translation>DanhSachHocVien</translation>
    </message>
    <message>
        <source>Student list</source>
        <translation>Danh sách học viên</translation>
    </message>
    <message>
        <source>%1 students</source>
        <translation>%1 học viên</translation>
    </message>
    <message>
        <source>Student enrolled</source>
        <translation>Đã ghi danh</translation>
    </message>
    <message>
        <source>Enrollment %1 was created.</source>
        <translation>Đã tạo ghi danh %1.</translation>
    </message>
    <message>
        <source>Placement test saved</source>
        <translation>Đã lưu bài kiểm tra xếp lớp</translation>
    </message>
    <message>
        <source>Overall score %1. No open course matches this score.</source>
        <translation>Điểm chung %1. Không có khóa học đang mở phù hợp với điểm này.</translation>
    </message>
    <message>
        <source>Overall score %1. Recommended course: %2.</source>
        <translation>Điểm chung %1. Khóa học đề xuất: %2.</translation>
    </message>
    <message>
        <source>Export students to XML</source>
        <translation>Xuất danh sách học viên ra XML</translation>
    </message>
    <message>
        <source>Choose the branch of the imported students in the branch filter first.</source>
        <translation>Hãy chọn chi nhánh cho các học viên được nhập ở bộ lọc chi nhánh trước.</translation>
    </message>
    <message>
        <source>Import students from XML</source>
        <translation>Nhập học viên từ XML</translation>
    </message>
    <message>
        <source>Import the students of %1 into %2?</source>
        <translation>Nhập học viên từ %1 vào %2?</translation>
    </message>
    <message>
        <source>Import finished</source>
        <translation>Đã nhập xong</translation>
    </message>
    <message>
        <source>%1 students imported, %2 skipped (phone or email already used, or no name or date of birth).</source>
        <translation>Đã nhập %1 học viên, bỏ qua %2 (trùng số điện thoại/email, hoặc thiếu họ tên/ngày sinh).</translation>
    </message>
    <message>
        <source>Please select a student in the list.</source>
        <translation>Hãy chọn một học viên trong danh sách.</translation>
    </message>
    <message>
        <source>Delete student %1 - %2?</source>
        <translation>Xóa học viên %1 - %2?</translation>
    </message>
</context>
<context>
    <name>StudentProfileDialog</name>
    <message>
        <source>Student profile %1</source>
        <translation>Hồ sơ học viên %1</translation>
    </message>
    <message>
        <source>Born %1 · %2 · Phone %3 · %4 · Registered %5 · Status: %6</source>
        <translation>Sinh ngày %1 · %2 · ĐT %3 · %4 · Đăng ký %5 · Trạng thái: %6</translation>
    </message>
    <message>
        <source>Enrollments</source>
        <translation>Ghi danh</translation>
    </message>
    <message>
        <source>Placement tests</source>
        <translation>Kiểm tra xếp lớp</translation>
    </message>
    <message>
        <source>Close</source>
        <translation>Đóng</translation>
    </message>
</context>
<context>
    <name>StudentService</name>
    <message>
        <source>No student is selected.</source>
        <translation>Chưa chọn học viên.</translation>
    </message>
    <message>
        <source>The student ID is missing.</source>
        <translation>Thiếu mã học viên.</translation>
    </message>
    <message>
        <source>Please choose the branch of the imported students.</source>
        <translation>Vui lòng chọn chi nhánh cho các học viên được nhập.</translation>
    </message>
    <message>
        <source>The file is not a student export: it has no &lt;Students&gt; element.</source>
        <translation>File không phải danh sách học viên đã xuất: không có phần tử &lt;Students&gt;.</translation>
    </message>
</context>
<context>
    <name>TableDialog</name>
    <message>
        <source>Excel</source>
        <translation>Excel</translation>
    </message>
    <message>
        <source>PDF</source>
        <translation>PDF</translation>
    </message>
    <message>
        <source>Close</source>
        <translation>Đóng</translation>
    </message>
</context>
<context>
    <name>TableExporter</name>
    <message>
        <source>ENGLISH CENTER — QLTTTA MANAGEMENT SYSTEM</source>
        <translation>TRUNG TÂM ANH NGỮ — HỆ THỐNG QUẢN LÝ QLTTTA</translation>
    </message>
    <message>
        <source>Created on: %1</source>
        <translation>Ngày lập: %1</translation>
    </message>
    <message>
        <source>Prepared by: %1</source>
        <translation>Người lập: %1</translation>
    </message>
    <message>
        <source>No.</source>
        <translation>STT</translation>
    </message>
    <message>
        <source>GRAND TOTAL</source>
        <translation>TỔNG CỘNG</translation>
    </message>
    <message>
        <source>Total rows: %1</source>
        <translation>Tổng số dòng: %1</translation>
    </message>
    <message>
        <source>Cannot set up the page size.</source>
        <translation>Không thiết lập được khổ giấy.</translation>
    </message>
</context>
<context>
    <name>Teacher</name>
    <message>
        <source>Phone numbers contain 9-11 digits only.</source>
        <translation>Số điện thoại chỉ gồm 9-11 chữ số.</translation>
    </message>
    <message>
        <source>A valid email address is required.</source>
        <translation>Vui lòng nhập email hợp lệ.</translation>
    </message>
    <message>
        <source>The nationality is required.</source>
        <translation>Vui lòng nhập quốc tịch.</translation>
    </message>
    <message>
        <source>A native-speaker teacher cannot have Vietnamese nationality.</source>
        <translation>Giáo viên bản ngữ không thể có quốc tịch Việt Nam.</translation>
    </message>
    <message>
        <source>Invalid degree.</source>
        <translation>Học vị không hợp lệ.</translation>
    </message>
    <message>
        <source>Invalid teacher type.</source>
        <translation>Loại giáo viên không hợp lệ.</translation>
    </message>
    <message>
        <source>The hourly rate must be greater than 0.</source>
        <translation>Đơn giá/giờ phải lớn hơn 0.</translation>
    </message>
    <message>
        <source>Please choose a branch.</source>
        <translation>Vui lòng chọn chi nhánh.</translation>
    </message>
    <message>
        <source>Invalid status.</source>
        <translation>Trạng thái không hợp lệ.</translation>
    </message>
</context>
<context>
    <name>TeacherPage</name>
    <message>
        <source>New teacher</source>
        <translation>Thêm giáo viên</translation>
    </message>
    <message>
        <source>Edit</source>
        <translation>Sửa</translation>
    </message>
    <message>
        <source>Find by certificate</source>
        <translation>Tìm theo chứng chỉ</translation>
    </message>
    <message>
        <source>Edit teacher %1</source>
        <translation>Sửa giáo viên %1</translation>
    </message>
    <message>
        <source>Full name</source>
        <translation>Họ tên</translation>
    </message>
    <message>
        <source>Date of birth</source>
        <translation>Ngày sinh</translation>
    </message>
    <message>
        <source>Gender</source>
        <translation>Giới tính</translation>
    </message>
    <message>
        <source>Nationality</source>
        <translation>Quốc tịch</translation>
    </message>
    <message>
        <source>Phone</source>
        <translation>Điện thoại</translation>
    </message>
    <message>
        <source>Email</source>
        <translation>Email</translation>
    </message>
    <message>
        <source>Degree</source>
        <translation>Học vị</translation>
    </message>
    <message>
        <source>Teacher type</source>
        <translation>Loại giáo viên</translation>
    </message>
    <message>
        <source>Hourly rate</source>
        <translation>Đơn giá/giờ</translation>
    </message>
    <message>
        <source>Branch</source>
        <translation>Chi nhánh</translation>
    </message>
    <message>
        <source>Hire date</source>
        <translation>Ngày vào làm</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>Profile (XML)</source>
        <translation>Hồ sơ (XML)</translation>
    </message>
    <message>
        <source>Find teachers by certificate</source>
        <translation>Tìm giáo viên theo chứng chỉ</translation>
    </message>
    <message>
        <source>Certificate</source>
        <translation>Chứng chỉ</translation>
    </message>
    <message>
        <source>Minimum score</source>
        <translation>Điểm tối thiểu</translation>
    </message>
    <message>
        <source>Find</source>
        <translation>Tìm</translation>
    </message>
    <message>
        <source>Teachers with %1 of at least %2</source>
        <translation>Giáo viên có %1 từ %2 trở lên</translation>
    </message>
</context>
<context>
    <name>TimetablePage</name>
    <message>
        <source>Previous week</source>
        <translation>Tuần trước</translation>
    </message>
    <message>
        <source>This week</source>
        <translation>Tuần này</translation>
    </message>
    <message>
        <source>Next week</source>
        <translation>Tuần sau</translation>
    </message>
    <message>
        <source>Update session</source>
        <translation>Cập nhật buổi học</translation>
    </message>
    <message>
        <source>Attendance</source>
        <translation>Điểm danh</translation>
    </message>
    <message>
        <source>%1 - %2</source>
        <translation>%1 - %2</translation>
    </message>
    <message>
        <source>%1 - %2, session %3, %4</source>
        <translation>%1 - %2, buổi %3, %4</translation>
    </message>
    <message>
        <source>Session</source>
        <translation>Buổi học</translation>
    </message>
    <message>
        <source>Content of the lesson</source>
        <translation>Nội dung bài học</translation>
    </message>
    <message>
        <source>Status</source>
        <translation>Trạng thái</translation>
    </message>
    <message>
        <source>Content</source>
        <translation>Nội dung</translation>
    </message>
</context>
<context>
    <name>TuitionPage</name>
    <message>
        <source>All receipts</source>
        <translation>Tất cả phiếu thu</translation>
    </message>
    <message>
        <source>From</source>
        <translation>Từ</translation>
    </message>
    <message>
        <source>to</source>
        <translation>đến</translation>
    </message>
    <message>
        <source>Collect payment</source>
        <translation>Thu tiền</translation>
    </message>
    <message>
        <source>Cancel receipt</source>
        <translation>Hủy phiếu thu</translation>
    </message>
    <message>
        <source>Print receipt</source>
        <translation>In phiếu thu</translation>
    </message>
    <message>
        <source>Receipt %1 was recorded. Print it now?</source>
        <translation>Đã lập phiếu thu %1. In phiếu ngay?</translation>
    </message>
    <message>
        <source>Cancel receipt %1</source>
        <translation>Hủy phiếu thu %1</translation>
    </message>
    <message>
        <source>The receipt stays in the history with the status Cancelled; the amount is no longer counted as paid.</source>
        <translation>Phiếu thu vẫn được lưu với trạng thái Đã hủy; số tiền không còn được tính là đã đóng.</translation>
    </message>
    <message>
        <source>Reason</source>
        <translation>Lý do</translation>
    </message>
    <message>
        <source>Save the receipt as PDF</source>
        <translation>Lưu phiếu thu thành PDF</translation>
    </message>
</context>
<context>
    <name>TuitionService</name>
    <message>
        <source>The start date must not be after the end date.</source>
        <translation>Ngày bắt đầu không được sau ngày kết thúc.</translation>
    </message>
    <message>
        <source>No receipt is selected.</source>
        <translation>Chưa chọn phiếu thu.</translation>
    </message>
    <message>
        <source>A reason is required to cancel a receipt.</source>
        <translation>Cần nhập lý do để hủy phiếu thu.</translation>
    </message>
    <message>
        <source>The reason must be at most %1 characters.</source>
        <translation>Lý do tối đa %1 ký tự.</translation>
    </message>
</context>
<context>
    <name>UiHelpers</name>
    <message>
        <source>Could not complete the action</source>
        <translation>Không thực hiện được</translation>
    </message>
    <message>
        <source>Confirm</source>
        <translation>Xác nhận</translation>
    </message>
    <message>
        <source>Yes</source>
        <translation>Đồng ý</translation>
    </message>
    <message>
        <source>No</source>
        <translation>Không</translation>
    </message>
    <message>
        <source>Export to Excel (CSV)</source>
        <translation>Xuất Excel (CSV)</translation>
    </message>
    <message>
        <source>Export PDF report</source>
        <translation>Xuất báo cáo PDF</translation>
    </message>
    <message>
        <source>Language</source>
        <translation>Ngôn ngữ</translation>
    </message>
</context>
</TS>
