#include "infrastructure/repositories/SqlThongKeRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlThongKeRepository::SqlThongKeRepository(DatabaseManager& db) : m_db(db) {}

Result<ThongKeTongQuan> SqlThongKeRepository::tongQuan() {
    QSqlQuery q = taoCauLenh(m_db.db());
    if (!q.exec(QStringLiteral("EXEC dbo.usp_ThongKe_TongQuan")))
        return Result<ThongKeTongQuan>::failure(loiCua(q));
    ThongKeTongQuan tk;
    if (q.next()) {
        tk.hocVienDangHoc = q.value(0).toInt();
        tk.lopDangHoc = q.value(1).toInt();
        tk.lopTuyenSinh = q.value(2).toInt();
        tk.doanhThuThangNay = q.value(3).toLongLong();
        tk.tongCongNo = q.value(4).toLongLong();
        tk.buoiHocHomNay = q.value(5).toInt();
    }
    return Result<ThongKeTongQuan>::success(tk);
}

Result<QList<DoanhThuThang>> SqlThongKeRepository::doanhThuTheoThang(int nam) {
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral("SELECT Thang, DoanhThu FROM dbo.fn_DoanhThuTheoThang(?, NULL) ORDER BY Thang"));
    q.addBindValue(nam);
    if (!q.exec())
        return Result<QList<DoanhThuThang>>::failure(loiCua(q));
    QList<DoanhThuThang> ds;
    while (q.next())
        ds.append({q.value(0).toInt(), q.value(1).toLongLong()});
    return Result<QList<DoanhThuThang>>::success(ds);
}
