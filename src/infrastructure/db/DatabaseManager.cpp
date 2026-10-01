#include "infrastructure/db/DatabaseManager.h"

#include "infrastructure/db/SqlErrorMapper.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>

namespace {
const char* const kTenKetNoi = "qlttta";

// Giá trị trong chuỗi kết nối ODBC: bọc {} nếu có ký tự đặc biệt, '}' viết thành '}}'
QString giaTriOdbc(const QString& v) {
    if (!v.contains(QLatin1Char(';')) && !v.contains(QLatin1Char('{')) && !v.contains(QLatin1Char('}')) &&
        !v.contains(QLatin1Char('=')) && v.trimmed() == v)
        return v;
    QString s = v;
    s.replace(QLatin1String("}"), QLatin1String("}}"));
    return QLatin1Char('{') + s + QLatin1Char('}');
}

bool laLoiThieuDriver(const QSqlError& loi) {
    const QString t = loi.databaseText() + QLatin1Char(' ') + loi.driverText() + QLatin1Char(' ') + loi.nativeErrorCode();
    return t.contains(QLatin1String("IM002")) || t.contains(QLatin1String("Can't open lib")) ||
           t.contains(QLatin1String("Data source name not found"), Qt::CaseInsensitive) ||
           t.contains(QLatin1String("file not found"), Qt::CaseInsensitive);
}

// Máy chủ đã phản hồi nhưng từ chối đăng nhập => thử driver khác cũng vô ích
bool laLoiXacThuc(const QSqlError& loi) {
    const QString t = loi.databaseText() + QLatin1Char(' ') + loi.nativeErrorCode();
    return t.contains(QLatin1String("18456")) || t.contains(QLatin1String("Login failed"), Qt::CaseInsensitive) ||
           t.contains(QLatin1String("Cannot open database"), Qt::CaseInsensitive);
}
} // namespace

DatabaseManager::~DatabaseManager() {
    dongKetNoi();
}

QStringList DatabaseManager::danhSachDriver() {
    QStringList drivers;
    const QString tuyChinh = qEnvironmentVariable("QLTTTA_ODBC_DRIVER");
    if (!tuyChinh.isEmpty())
        drivers << tuyChinh;
#if defined(Q_OS_MACOS)
    // Bản .dmg đóng gói kèm FreeTDS (mã nguồn mở, LGPL) cùng unixODBC riêng => ưu tiên dùng trước,
    // tránh nạp lẫn driver Microsoft (vốn liên kết với unixODBC của Homebrew) vào cùng tiến trình.
    const QString kemTheo = QDir(QCoreApplication::applicationDirPath())
                                .absoluteFilePath(QStringLiteral("../Frameworks/libtdsodbc.so"));
    if (QFileInfo::exists(kemTheo))
        drivers << QFileInfo(kemTheo).canonicalFilePath();
#endif
    drivers << QStringLiteral("ODBC Driver 18 for SQL Server") << QStringLiteral("ODBC Driver 17 for SQL Server");
#if defined(Q_OS_WIN)
    drivers << QStringLiteral("SQL Server");   // driver cũ, luôn có sẵn trên Windows
#elif defined(Q_OS_MACOS)
    for (const QString& p : {QStringLiteral("/opt/homebrew/opt/freetds/lib/libtdsodbc.so"),
                             QStringLiteral("/usr/local/opt/freetds/lib/libtdsodbc.so")}) {
        if (QFileInfo::exists(p))
            drivers << QFileInfo(p).canonicalFilePath();
    }
#endif
    drivers.removeDuplicates();
    return drivers;
}

QString DatabaseManager::chuoiKetNoi(const QString& driver, const CauHinhMayChu& cauHinh,
                                     const QString& tenDangNhap, const QString& matKhau) {
    if (driver.contains(QLatin1String("tdsodbc"))) {
        // FreeTDS: máy chủ và cổng tách riêng, giao thức TDS 7.4 (SQL Server 2012+), mã hóa bắt buộc
        QString host = cauHinh.mayChu.trimmed();
        QString port = QStringLiteral("1433");
        const int phay = host.indexOf(QLatin1Char(','));
        if (phay > 0) {
            port = host.mid(phay + 1).trimmed();
            host = host.left(phay).trimmed();
        }
        QString s = QStringLiteral("DRIVER={%1};SERVER=%2;DATABASE=%3;UID=%4;PWD=%5;"
                                   "TDS_Version=7.4;ClientCharset=UTF-8;Encryption=require;APP=QLTTTA;")
                        .arg(driver, giaTriOdbc(host), giaTriOdbc(cauHinh.csdl.trimmed()), giaTriOdbc(tenDangNhap),
                             giaTriOdbc(matKhau));
        if (!host.contains(QLatin1Char('\\')))
            s += QStringLiteral("PORT=%1;").arg(port);
        return s;
    }

    QString s = QStringLiteral("DRIVER={%1};SERVER=%2;DATABASE=%3;UID=%4;PWD=%5;")
                    .arg(driver, giaTriOdbc(cauHinh.mayChu.trimmed()), giaTriOdbc(cauHinh.csdl.trimmed()),
                         giaTriOdbc(tenDangNhap), giaTriOdbc(matKhau));
    if (driver != QLatin1String("SQL Server")) {
        s += QStringLiteral("Encrypt=yes;TrustServerCertificate=%1;")
                 .arg(cauHinh.tinCayChungChi ? QStringLiteral("yes") : QStringLiteral("no"));
    }
    s += QStringLiteral("APP=QLTTTA;");
    return s;
}

VoidResult DatabaseManager::moKetNoi(const CauHinhMayChu& cauHinh, const QString& tenDangNhap,
                                     const QString& matKhau) {
    dongKetNoi();
    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QODBC")))
        return VoidResult::failure(QStringLiteral("Thiếu plugin Qt ODBC (qsqlodbc). Hãy cài lại ứng dụng."));

    QSqlError loiCuoi;          // lỗi của driver thử sau cùng
    QSqlError loiCoYNghia;      // lỗi đầu tiên không phải "thiếu driver" (đã tới được driver/máy chủ)
    for (const QString& driver : danhSachDriver()) {
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QODBC"), QLatin1String(kTenKetNoi));
            db.setDatabaseName(chuoiKetNoi(driver, cauHinh, tenDangNhap, matKhau));
            db.setConnectOptions(QStringLiteral("SQL_ATTR_LOGIN_TIMEOUT=8"));
            if (db.open()) {
                m_driver = driver;
                QSqlQuery(db).exec(QStringLiteral("SET DATEFORMAT ymd; SET LANGUAGE us_english;"));
                return VoidResult::success();
            }
            loiCuoi = db.lastError();
        }
        QSqlDatabase::removeDatabase(QLatin1String(kTenKetNoi));
        if (laLoiXacThuc(loiCuoi))
            return VoidResult::failure(SqlErrorMapper::thongBao(loiCuoi));   // sai mật khẩu => dừng
        if (!laLoiThieuDriver(loiCuoi) && !loiCoYNghia.isValid())
            loiCoYNghia = loiCuoi;   // lỗi khác (mạng, TLS...) => vẫn thử driver tiếp theo
    }

    if (loiCoYNghia.isValid())
        return VoidResult::failure(SqlErrorMapper::thongBao(loiCoYNghia));
    return VoidResult::failure(QStringLiteral(
        "Không tìm thấy ODBC Driver cho SQL Server trên máy.\n"
        "Hãy cài \"Microsoft ODBC Driver 18 for SQL Server\" rồi thử lại."));
}

void DatabaseManager::dongKetNoi() {
    if (QSqlDatabase::contains(QLatin1String(kTenKetNoi))) {
        {
            QSqlDatabase db = QSqlDatabase::database(QLatin1String(kTenKetNoi), false);
            db.close();
        }
        QSqlDatabase::removeDatabase(QLatin1String(kTenKetNoi));
    }
    m_driver.clear();
}

bool DatabaseManager::daKetNoi() const {
    return QSqlDatabase::contains(QLatin1String(kTenKetNoi)) &&
           QSqlDatabase::database(QLatin1String(kTenKetNoi), false).isOpen();
}

QSqlDatabase DatabaseManager::db() const {
    return QSqlDatabase::database(QLatin1String(kTenKetNoi), false);
}
