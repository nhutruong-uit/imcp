#include "infrastructure/repositories/SqlDanhMucRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlDanhMucRepository::SqlDanhMucRepository(DatabaseManager& db) : m_db(db) {}

Result<QList<ChiNhanh>> SqlDanhMucRepository::danhSachChiNhanh() {
    QSqlQuery q = taoCauLenh(m_db.db());
    if (!q.exec(QStringLiteral("SELECT MaCN, TenCN FROM dbo.CHINHANH WHERE TrangThai = N'Hoạt động' ORDER BY MaCN")))
        return Result<QList<ChiNhanh>>::failure(loiCua(q));
    QList<ChiNhanh> ds;
    while (q.next())
        ds.append({q.value(0).toString(), q.value(1).toString()});
    return Result<QList<ChiNhanh>>::success(ds);
}
