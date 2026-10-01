#include "infrastructure/repositories/SqlHocVienRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlHocVienRepository::SqlHocVienRepository(DatabaseManager& db) : m_db(db) {}

Result<QList<HocVien>> SqlHocVienRepository::timKiem(const BoLocHocVien& boLoc) {
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_HocVien_TimKiem @TuKhoa = ?, @MaCN = ?, @TrangThai = ?"));
    q.addBindValue(chuoiHoacNull(boLoc.tuKhoa));
    q.addBindValue(chuoiHoacNull(boLoc.maCN));
    q.addBindValue(chuoiHoacNull(boLoc.trangThai));
    if (!q.exec())
        return Result<QList<HocVien>>::failure(loiCua(q));

    // Cột: MaHV, HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, TenPhuHuynh, SDTPhuHuynh,
    //      MaCN, TenCN, NgayDangKy, TrangThai, SoLopDangHoc, TongConNo
    QList<HocVien> ds;
    while (q.next()) {
        HocVien hv;
        hv.maHV = q.value(0).toString();
        hv.hoTen = q.value(1).toString();
        hv.ngaySinh = q.value(2).toDate();
        hv.gioiTinh = q.value(3).toString();
        hv.soDienThoai = q.value(4).toString();
        hv.email = q.value(5).toString();
        hv.tenPhuHuynh = q.value(6).toString();
        hv.sdtPhuHuynh = q.value(7).toString();
        hv.maCN = q.value(8).toString();
        hv.tenCN = q.value(9).toString();
        hv.ngayDangKy = q.value(10).toDate();
        hv.trangThai = q.value(11).toString();
        hv.soLopDangHoc = q.value(12).toInt();
        hv.tongConNo = q.value(13).toLongLong();
        ds.append(hv);
    }
    return Result<QList<HocVien>>::success(ds);
}

Result<HocVien> SqlHocVienRepository::layTheoMa(const QString& maHV) {
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_HocVien_ChiTiet @MaHV = ?"));
    q.addBindValue(maHV);
    if (!q.exec())
        return Result<HocVien>::failure(loiCua(q));
    if (!q.next())
        return Result<HocVien>::failure(QStringLiteral("Không tìm thấy học viên %1.").arg(maHV));

    HocVien hv;
    hv.maHV = q.value(0).toString();
    hv.hoTen = q.value(1).toString();
    hv.ngaySinh = q.value(2).toDate();
    hv.gioiTinh = q.value(3).toString();
    hv.soDienThoai = q.value(4).toString();
    hv.email = q.value(5).toString();
    hv.diaChi = q.value(6).toString();
    hv.ngheNghiep = q.value(7).toString();
    hv.tenPhuHuynh = q.value(8).toString();
    hv.sdtPhuHuynh = q.value(9).toString();
    hv.maCN = q.value(10).toString();
    hv.ngayDangKy = q.value(11).toDate();
    hv.trangThai = q.value(12).toString();
    hv.ghiChu = q.value(13).toString();
    return Result<HocVien>::success(hv);
}

Result<QString> SqlHocVienRepository::them(const HocVien& hv) {
    // Gọi thủ tục có tham số OUTPUT qua một lô lệnh rồi SELECT giá trị ra (cách ổn định nhất với ODBC)
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral(
        "SET NOCOUNT ON; DECLARE @MaMoi VARCHAR(10); "
        "EXEC dbo.usp_HocVien_Them @HoTen = ?, @NgaySinh = ?, @GioiTinh = ?, @SoDienThoai = ?, @Email = ?, "
        "@DiaChi = ?, @NgheNghiep = ?, @TenPhuHuynh = ?, @SDTPhuHuynh = ?, @MaCN = ?, @GhiChu = ?, "
        "@MaHV = @MaMoi OUTPUT; SELECT @MaMoi;"));
    q.addBindValue(hv.hoTen);
    q.addBindValue(hv.ngaySinh);
    q.addBindValue(hv.gioiTinh);
    q.addBindValue(chuoiHoacNull(hv.soDienThoai));
    q.addBindValue(chuoiHoacNull(hv.email));
    q.addBindValue(chuoiHoacNull(hv.diaChi));
    q.addBindValue(chuoiHoacNull(hv.ngheNghiep));
    q.addBindValue(chuoiHoacNull(hv.tenPhuHuynh));
    q.addBindValue(chuoiHoacNull(hv.sdtPhuHuynh));
    q.addBindValue(hv.maCN);
    q.addBindValue(chuoiHoacNull(hv.ghiChu));
    if (!q.exec())
        return Result<QString>::failure(loiCua(q));
    if (!q.next())
        return Result<QString>::failure(QStringLiteral("Không nhận được mã học viên mới."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlHocVienRepository::capNhat(const HocVien& hv) {
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral(
        "EXEC dbo.usp_HocVien_CapNhat @MaHV = ?, @HoTen = ?, @NgaySinh = ?, @GioiTinh = ?, @SoDienThoai = ?, "
        "@Email = ?, @DiaChi = ?, @NgheNghiep = ?, @TenPhuHuynh = ?, @SDTPhuHuynh = ?, @MaCN = ?, "
        "@TrangThai = ?, @GhiChu = ?"));
    q.addBindValue(hv.maHV);
    q.addBindValue(hv.hoTen);
    q.addBindValue(hv.ngaySinh);
    q.addBindValue(hv.gioiTinh);
    q.addBindValue(chuoiHoacNull(hv.soDienThoai));
    q.addBindValue(chuoiHoacNull(hv.email));
    q.addBindValue(chuoiHoacNull(hv.diaChi));
    q.addBindValue(chuoiHoacNull(hv.ngheNghiep));
    q.addBindValue(chuoiHoacNull(hv.tenPhuHuynh));
    q.addBindValue(chuoiHoacNull(hv.sdtPhuHuynh));
    q.addBindValue(hv.maCN);
    q.addBindValue(hv.trangThai);
    q.addBindValue(chuoiHoacNull(hv.ghiChu));
    if (!q.exec())
        return VoidResult::failure(loiCua(q));
    return VoidResult::success();
}

VoidResult SqlHocVienRepository::xoa(const QString& maHV) {
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_HocVien_Xoa @MaHV = ?"));
    q.addBindValue(maHV);
    if (!q.exec())
        return VoidResult::failure(loiCua(q));
    return VoidResult::success();
}
