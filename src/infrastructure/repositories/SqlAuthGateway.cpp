#include "infrastructure/repositories/SqlAuthGateway.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlAuthGateway::SqlAuthGateway(DatabaseManager& db) : m_db(db) {}

Result<TaiKhoan> SqlAuthGateway::dangNhap(const CauHinhMayChu& cauHinh, const QString& tenDangNhap,
                                          const QString& matKhau) {
    const VoidResult ketNoi = m_db.moKetNoi(cauHinh, tenDangNhap, matKhau);
    if (!ketNoi.ok())
        return Result<TaiKhoan>::failure(ketNoi.error());

    QSqlQuery q = taoCauLenh(m_db.db());
    if (!q.exec(QStringLiteral("EXEC dbo.usp_TaiKhoan_GhiNhanDangNhap"))) {
        const QString loi = loiCua(q);
        m_db.dongKetNoi();
        return Result<TaiKhoan>::failure(loi);
    }

    TaiKhoan tk;
    if (q.next()) {
        tk.tenDangNhap = q.value(0).toString();
        tk.vaiTro = vaiTroTuMa(q.value(1).toString());
        tk.maNV = q.value(2).toString();
        tk.maGV = q.value(3).toString();
        tk.hoTen = q.value(5).toString();
        tk.maCN = q.value(6).toString();
        if (q.value(4).toString() != QStringLiteral("Hoạt động")) {
            m_db.dongKetNoi();
            return Result<TaiKhoan>::failure(QStringLiteral("Tài khoản đã bị khóa."));
        }
        return Result<TaiKhoan>::success(tk);
    }

    // Không có trong TAIKHOAN: cho phép chủ sở hữu CSDL (sa / db_owner) vào với quyền Quản lý
    QSqlQuery q2 = taoCauLenh(m_db.db());
    if (q2.exec(QStringLiteral("SELECT IS_MEMBER('db_owner'), ORIGINAL_LOGIN()")) && q2.next() &&
        q2.value(0).toInt() == 1) {
        tk.tenDangNhap = q2.value(1).toString();
        tk.hoTen = tk.tenDangNhap + QStringLiteral(" (quản trị CSDL)");
        tk.vaiTro = VaiTro::QuanLy;
        return Result<TaiKhoan>::success(tk);
    }
    tk.tenDangNhap = tenDangNhap;
    return Result<TaiKhoan>::success(tk);   // VaiTro::KhongXacDinh => AuthService từ chối
}

void SqlAuthGateway::dangXuat() {
    m_db.dongKetNoi();
}

VoidResult SqlAuthGateway::doiMatKhau(const QString& matKhauCu, const QString& matKhauMoi) {
    QSqlQuery q = taoCauLenh(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_TaiKhoan_DoiMatKhau @MatKhauCu = ?, @MatKhauMoi = ?"));
    q.addBindValue(matKhauCu);
    q.addBindValue(matKhauMoi);
    if (!q.exec())
        return VoidResult::failure(loiCua(q));
    return VoidResult::success();
}
