---
paths:
  - "tests/**"
  - "database/12_kiem_thu.sql"
---
# Quy tắc kiểm thử

## Tên và cấu trúc test C++ (Qt Test)
- Tên hàm test: `doiTuong_dieuKien_ketQuaMongDoi` - vd `themHocVien_khongHopLe_khongGoiRepository`.
- Unit test (`tst_domain`, `tst_application`, `tst_sqlerrormapper`): không cần CSDL; use case test bằng
  **repository giả** viết ngay trong file test (mẫu `FakeHocVienRepository` trong `tst_application.cpp`).
- Test mới cho bộ đã có: thêm private slot vào đúng file. Bộ test mới: `qlttta_add_test(tst_xxx <thư viện>)` trong `tests/CMakeLists.txt`.

## End-to-end (`tst_e2e_gui.cpp`, cần CSDL thật, tự SKIP khi thiếu `QLTTTA_E2E_PASSWORD`)
- Thao tác như người dùng: `dangNhap(...)` qua `LoginDialog`, `w.moChucNang(ChucNang::...)`, tìm widget bằng `objectName`.
- Gõ tiếng Việt bằng `goChu()` (không dùng `QTest::keyClicks` với ký tự có dấu); hộp thoại modal xử lý bằng
  `QTimer::singleShot` hoặc `BatHopThoai`; chờ bằng `QTRY_*` (không `QTest::qWait` cố định).
- **Trả dữ liệu về như cũ** (xóa bản ghi đã thêm, đổi lại giá trị đã sửa) - các test khác dựa vào dữ liệu mẫu.
- Chức năng mới trong `PhanQuyen` được `moiVaiTro_moMoiChucNang_coDuLieu` tự mở; vẫn cần kịch bản riêng cho nghiệp vụ chính.

## Kiểm thử CSDL (`database/12_kiem_thu.sql`)
- Mã ca: `Txx` (ràng buộc, nghiệp vụ, kết quả xử lý) hoặc `Pxx` (phân quyền, dùng `EXECUTE AS USER ... REVERT`); số tiếp theo chưa dùng.
- Mỗi ca chạy trong `BEGIN TRAN ... ROLLBACK` (không để lại dữ liệu), ghi vào `#KetQua`, và **đăng ký trong
  `#MongDoi`**: ca "Từ chối" kèm mẫu thông báo (`N'%đủ sĩ số%'`; lỗi hệ thống thì dùng tên đối tượng/ràng buộc,
  vd `N'%CK_HOCVIEN_Email%'`), ca "Thành công" để `NULL`.
- Ca "Thành công" phải **so kết quả với giá trị tính độc lập hoặc kịch bản dựng sẵn** (mẫu T17-T24), không chỉ "chạy không lỗi".
```sql
-- T28: <mô tả>
BEGIN TRY
    BEGIN TRAN;
    <thao tác vi phạm>;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T28', N'<nội dung>', N'Từ chối', N'Thành công', NULL);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #KetQua VALUES ('T28', N'<nội dung>', N'Từ chối', N'Từ chối', ERROR_MESSAGE());
END CATCH;
GO
```

## Trước khi báo "xong"
- Chạy `scripts/test_all.sh` (hoặc ít nhất `ctest --preset ...` + `12_kiem_thu.sql`) và dán kết quả thật.
- Nghi ngờ test "xanh nhầm": thử cố ý làm sai một dòng code/SQL, test phải đỏ, rồi hoàn tác.
- Không xóa, không nới lỏng kỳ vọng của test cũ trừ khi đặc tả thay đổi thật - ghi rõ lý do trong báo cáo/PR.
