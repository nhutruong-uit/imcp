#include "infrastructure/db/SqlErrorMapper.h"

#include <QHash>
#include <QRegularExpression>
#include <QStringList>

QString SqlErrorMapper::lamSachThongDiep(const QString& thongDiepGoc) {
    // Một lỗi có thể gồm nhiều bản ghi chẩn đoán; chỉ lấy bản ghi đầu tiên có nội dung
    static const QRegularExpression tienTo(QStringLiteral("^(\\s*\\[[^\\]]*\\])+\\s*"));
    static const QRegularExpression maQodbc(QStringLiteral("\\s*QODBC[^:]*:.*$"));
    // QODBC (Qt 6) nối SQLSTATE vào cuối thông điệp: "Mật khẩu ... không đúng., 37000"
    static const QRegularExpression duoiSqlState(QStringLiteral("\\s*,\\s*[0-9A-Z]{5}(;[0-9A-Z]{5})*\\s*$"));
    const QStringList dong = thongDiepGoc.split(QRegularExpression(QStringLiteral("[\\r\\n]+")),
                                                Qt::SkipEmptyParts);
    for (QString d : dong) {
        d.remove(tienTo);
        d.remove(maQodbc);
        d.remove(duoiSqlState);
        d = d.trimmed();
        if (!d.isEmpty() && !d.startsWith(QLatin1String("The statement has been terminated")))
            return d;
    }
    return thongDiepGoc.trimmed();
}

QString SqlErrorMapper::thongBaoRangBuoc(const QString& tenRangBuoc) {
    static const QHash<QString, QString> bang = {
        {QStringLiteral("CK_HOCVIEN_PhuHuynh"), QStringLiteral("Học viên dưới 18 tuổi phải có thông tin phụ huynh.")},
        {QStringLiteral("CK_HOCVIEN_LienLac"), QStringLiteral("Cần ít nhất một số điện thoại liên lạc.")},
        {QStringLiteral("CK_HOCVIEN_SoDienThoai"), QStringLiteral("Số điện thoại chỉ gồm 9-11 chữ số.")},
        {QStringLiteral("CK_HOCVIEN_Email"), QStringLiteral("Email không đúng định dạng.")},
        {QStringLiteral("CK_HOCVIEN_NgaySinh"), QStringLiteral("Ngày sinh không hợp lệ (học viên từ 4 tuổi).")},
        {QStringLiteral("CK_GHIDANH_DaDong"), QStringLiteral("Số tiền đã đóng vượt quá học phí phải đóng.")},
        {QStringLiteral("CK_DIEM_Diem"), QStringLiteral("Điểm phải nằm trong khoảng 0 - 10.")},
        {QStringLiteral("UQ_GHIDANH_MaHV_MaLop"), QStringLiteral("Học viên đã ghi danh lớp này.")},
        {QStringLiteral("UX_HOCVIEN_SoDienThoai"), QStringLiteral("Số điện thoại đã được dùng cho học viên khác.")},
        {QStringLiteral("UX_HOCVIEN_Email"), QStringLiteral("Email đã được dùng cho học viên khác.")},
        {QStringLiteral("FK_GHIDANH_HOCVIEN"), QStringLiteral("Học viên đang có dữ liệu ghi danh, không thể xóa.")},
    };
    return bang.value(tenRangBuoc, QStringLiteral("Dữ liệu vi phạm ràng buộc toàn vẹn: %1").arg(tenRangBuoc));
}

QString SqlErrorMapper::thongBao(const QSqlError& loi) {
    if (!loi.isValid())
        return QString();

    const QString goc = loi.databaseText().isEmpty() ? loi.text() : loi.databaseText();
    const QString thongDiep = lamSachThongDiep(goc);
    const QStringList ma = loi.nativeErrorCode().split(QLatin1Char(';'), Qt::SkipEmptyParts);
    auto coMa = [&ma](const char* m) { return ma.contains(QLatin1String(m)); };

    if (coMa("18456") || goc.contains(QLatin1String("Login failed"), Qt::CaseInsensitive))
        return QStringLiteral("Sai tên đăng nhập hoặc mật khẩu, hoặc tài khoản đã bị khóa.");
    if (coMa("4060") || goc.contains(QLatin1String("Cannot open database"), Qt::CaseInsensitive))
        return QStringLiteral("Không mở được cơ sở dữ liệu. Kiểm tra lại tên CSDL trong phần cấu hình máy chủ.");
    if (goc.contains(QLatin1String("TCP Provider"), Qt::CaseInsensitive) ||
        goc.contains(QLatin1String("Login timeout expired"), Qt::CaseInsensitive) ||
        goc.contains(QLatin1String("server was not found"), Qt::CaseInsensitive) ||
        goc.contains(QLatin1String("Named Pipes"), Qt::CaseInsensitive) ||
        goc.contains(QLatin1String("Communication link failure"), Qt::CaseInsensitive))
        return QStringLiteral("Không kết nối được máy chủ SQL Server.\n"
                              "Kiểm tra địa chỉ máy chủ, cổng (mặc định 1433) và dịch vụ SQL Server đang chạy.");
    if (goc.contains(QLatin1String("certificate"), Qt::CaseInsensitive) ||
        goc.contains(QLatin1String("SSL Provider"), Qt::CaseInsensitive))
        return QStringLiteral("Lỗi chứng chỉ bảo mật của máy chủ. Hãy bật \"Tin cậy chứng chỉ máy chủ\" "
                              "trong phần cấu hình máy chủ.");
    if (coMa("229") || coMa("230") || coMa("262") || coMa("297") ||
        goc.contains(QLatin1String("permission was denied"), Qt::CaseInsensitive))
        return QStringLiteral("Bạn không có quyền thực hiện thao tác này (SQL Server từ chối).");

    if (coMa("2627") || coMa("2601") || coMa("547") || goc.contains(QLatin1String("constraint"))) {
        static const QRegularExpression tenRangBuoc(
            QStringLiteral("(?:constraint|index)\\s+['\"]([A-Za-z0-9_]+)['\"]"), QRegularExpression::CaseInsensitiveOption);
        const auto m = tenRangBuoc.match(goc);
        if (m.hasMatch())
            return thongBaoRangBuoc(m.captured(1));
    }

    // Lỗi nghiệp vụ từ THROW/RAISERROR: thông điệp đã là tiếng Việt
    return thongDiep;
}
