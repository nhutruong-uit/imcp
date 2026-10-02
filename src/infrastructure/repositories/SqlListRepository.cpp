#include "infrastructure/repositories/SqlDanhSachRepository.h"

#include "infrastructure/db/SqlHelpers.h"

#include <QSqlRecord>

using namespace SqlHelpers;

namespace {
struct DinhNghia {
    QString sql;
    QStringList tieuDe;
    QVariantList thamSo;
};

// Thứ Hai của tuần chứa ngày d
QDate dauTuan(const QDate& d) {
    return d.addDays(1 - d.dayOfWeek());
}

const QString kGio = QStringLiteral("LEFT(CONVERT(VARCHAR(8), %1, 108), 5)");

DinhNghia dinhNghia(LoaiDanhSach loai) {
    const QDate homNay = QDate::currentDate();
    switch (loai) {
    case LoaiDanhSach::LopHoc:
        return {QStringLiteral(
                    "SELECT MaLop, TenLop, TenKH, TenCN, TenGV, TenPhong, LichHoc, NgayKhaiGiang, NgayKetThuc, "
                    "SiSoHienTai, SiSoToiDa, HocPhi, TrangThai FROM dbo.vw_LopHoc_ChiTiet "
                    "ORDER BY CASE TrangThai WHEN N'Đang học' THEN 0 WHEN N'Đang tuyển sinh' THEN 1 ELSE 2 END, "
                    "NgayKhaiGiang DESC"),
                {QStringLiteral("Mã lớp"), QStringLiteral("Tên lớp"), QStringLiteral("Khóa học"),
                 QStringLiteral("Chi nhánh"), QStringLiteral("Giáo viên"), QStringLiteral("Phòng"),
                 QStringLiteral("Lịch học"), QStringLiteral("Khai giảng"), QStringLiteral("Kết thúc"),
                 QStringLiteral("Sĩ số"), QStringLiteral("Tối đa"), QStringLiteral("Học phí"),
                 QStringLiteral("Trạng thái")},
                {}};
    case LoaiDanhSach::LichHocTuanNay:
        return {QStringLiteral("SELECT NgayHoc, %1, %2, MaLop, TenLop, STT, TenPhong, TenGV, TrangThai "
                               "FROM dbo.vw_BuoiHoc_ChiTiet WHERE NgayHoc >= ? AND NgayHoc < ? "
                               "ORDER BY NgayHoc, GioBatDau")
                    .arg(kGio.arg(QStringLiteral("GioBatDau")), kGio.arg(QStringLiteral("GioKetThuc"))),
                {QStringLiteral("Ngày học"), QStringLiteral("Bắt đầu"), QStringLiteral("Kết thúc"),
                 QStringLiteral("Mã lớp"), QStringLiteral("Tên lớp"), QStringLiteral("Buổi"),
                 QStringLiteral("Phòng"), QStringLiteral("Giáo viên"), QStringLiteral("Trạng thái")},
                {dauTuan(homNay), dauTuan(homNay).addDays(7)}};
    case LoaiDanhSach::CongNo:
        return {QStringLiteral("SELECT MaGD, MaHV, HoTen, SoLienLac, MaLop, TenLop, NgayGhiDanh, HocPhiPhaiDong, "
                               "DaDong, ConNo, SoNgayTuGhiDanh FROM dbo.vw_CongNo ORDER BY ConNo DESC"),
                {QStringLiteral("Mã GD"), QStringLiteral("Mã HV"), QStringLiteral("Họ tên"),
                 QStringLiteral("Liên lạc"), QStringLiteral("Mã lớp"), QStringLiteral("Tên lớp"),
                 QStringLiteral("Ngày ghi danh"), QStringLiteral("Học phí"), QStringLiteral("Đã đóng"),
                 QStringLiteral("Còn nợ"), QStringLiteral("Số ngày")},
                {}};
    case LoaiDanhSach::KetQuaHocTap:
        return {QStringLiteral("SELECT MaLop, TenLop, MaHV, HoTen, DiemTongKet, XepLoai, TyLeChuyenCan, KetQua, "
                               "TrangThai FROM dbo.vw_KetQuaHocTap ORDER BY MaLop, HoTen"),
                {QStringLiteral("Mã lớp"), QStringLiteral("Tên lớp"), QStringLiteral("Mã HV"),
                 QStringLiteral("Họ tên"), QStringLiteral("Điểm TK"), QStringLiteral("Xếp loại"),
                 QStringLiteral("Chuyên cần (%)"), QStringLiteral("Kết quả"), QStringLiteral("Trạng thái")},
                {}};
    case LoaiDanhSach::DoanhThuThang:
        return {QStringLiteral("SELECT Nam, Thang, TenCN, SoPhieu, DoanhThu FROM dbo.vw_DoanhThuThang "
                               "ORDER BY Nam DESC, Thang DESC, TenCN"),
                {QStringLiteral("Năm"), QStringLiteral("Tháng"), QStringLiteral("Chi nhánh"),
                 QStringLiteral("Số phiếu"), QStringLiteral("Doanh thu")},
                {}};
    case LoaiDanhSach::BangLuong:
        return {QStringLiteral("SELECT bl.Nam, bl.Thang, gv.MaGV, gv.HoTen, bl.SoBuoi, bl.SoGio, bl.DonGiaGio, "
                               "bl.Thuong, bl.KhauTru, bl.TongLuong, bl.TrangThai FROM dbo.BANGLUONG bl "
                               "JOIN dbo.GIAOVIEN gv ON gv.MaGV = bl.MaGV ORDER BY bl.Nam DESC, bl.Thang DESC, gv.HoTen"),
                {QStringLiteral("Năm"), QStringLiteral("Tháng"), QStringLiteral("Mã GV"),
                 QStringLiteral("Giáo viên"), QStringLiteral("Số buổi"), QStringLiteral("Số giờ"),
                 QStringLiteral("Đơn giá/giờ"), QStringLiteral("Thưởng"), QStringLiteral("Khấu trừ"),
                 QStringLiteral("Tổng lương"), QStringLiteral("Trạng thái")},
                {}};
    case LoaiDanhSach::TaiKhoan:
        return {QStringLiteral("EXEC dbo.usp_TaiKhoan_DanhSach"),
                {QStringLiteral("Tên đăng nhập"), QStringLiteral("Vai trò"), QStringLiteral("Họ tên"),
                 QStringLiteral("Trạng thái"), QStringLiteral("Ngày tạo"), QStringLiteral("Đăng nhập cuối")},
                {}};
    case LoaiDanhSach::LopCuaToi:
        return {QStringLiteral("SELECT MaLop, TenLop, TenKH, TenPhong, TenCN, NgayKhaiGiang, NgayKetThuc, SiSo, "
                               "TrangThai FROM dbo.vw_GV_LopCuaToi ORDER BY NgayKhaiGiang DESC"),
                {QStringLiteral("Mã lớp"), QStringLiteral("Tên lớp"), QStringLiteral("Khóa học"),
                 QStringLiteral("Phòng"), QStringLiteral("Chi nhánh"), QStringLiteral("Khai giảng"),
                 QStringLiteral("Kết thúc"), QStringLiteral("Sĩ số"), QStringLiteral("Trạng thái")},
                {}};
    case LoaiDanhSach::LichDayCuaToi:
        return {QStringLiteral("SELECT NgayHoc, %1, %2, MaLop, TenLop, STT, TenPhong, TrangThai "
                               "FROM dbo.vw_GV_LichDayCuaToi WHERE NgayHoc >= ? ORDER BY NgayHoc, GioBatDau")
                    .arg(kGio.arg(QStringLiteral("GioBatDau")), kGio.arg(QStringLiteral("GioKetThuc"))),
                {QStringLiteral("Ngày dạy"), QStringLiteral("Bắt đầu"), QStringLiteral("Kết thúc"),
                 QStringLiteral("Mã lớp"), QStringLiteral("Tên lớp"), QStringLiteral("Buổi"),
                 QStringLiteral("Phòng"), QStringLiteral("Trạng thái")},
                {dauTuan(homNay)}};
    case LoaiDanhSach::LuongCuaToi:
        return {QStringLiteral("SELECT Nam, Thang, SoBuoi, SoGio, DonGiaGio, Thuong, KhauTru, TongLuong, TrangThai "
                               "FROM dbo.vw_GV_LuongCuaToi ORDER BY Nam DESC, Thang DESC"),
                {QStringLiteral("Năm"), QStringLiteral("Tháng"), QStringLiteral("Số buổi"),
                 QStringLiteral("Số giờ"), QStringLiteral("Đơn giá/giờ"), QStringLiteral("Thưởng"),
                 QStringLiteral("Khấu trừ"), QStringLiteral("Tổng lương"), QStringLiteral("Trạng thái")},
                {}};
    }
    return {};
}
} // namespace

SqlDanhSachRepository::SqlDanhSachRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlDanhSachRepository::layDanhSach(LoaiDanhSach loai) {
    const DinhNghia dn = dinhNghia(loai);
    QSqlQuery q = taoCauLenh(m_db.db());
    if (!q.prepare(dn.sql))
        return Result<TableData>::failure(loiCua(q));
    for (const QVariant& v : dn.thamSo)
        q.addBindValue(v);
    if (!q.exec())
        return Result<TableData>::failure(loiCua(q));

    TableData bang;
    bang.columns = dn.tieuDe;
    const int soCot = q.record().count();
    while (q.next()) {
        QVariantList dong;
        dong.reserve(soCot);
        for (int i = 0; i < soCot; ++i)
            dong.append(q.value(i));
        bang.rows.append(dong);
    }
    return Result<TableData>::success(bang);
}
