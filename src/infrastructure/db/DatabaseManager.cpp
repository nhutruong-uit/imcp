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
    // Driver đóng gói kèm ứng dụng (Contents/Frameworks) khi phát hành bản .dmg
    const QString kemTheo = QDir(QCoreApplication::applicationDirPath())
                                .absoluteFilePath(QStringLiteral("../Frameworks/libmsodbcsql.18.dylib"));
    if (QFileInfo::exists(kemTheo))
        drivers << QFileInfo(kemTheo).canonicalFilePath();
#endif
    drivers << QStringLiteral("ODBC Driver 18 for SQL Server") << QStringLiteral("ODBC Driver 17 for SQL Server");
#if defined(Q_OS_WIN)
    drivers << QStringLiteral("SQL Server");   // driver cũ, luôn có sẵn trên Windows
#endif
    return drivers;
}

QString DatabaseManager::chuoiKetNoi(const QString& driver, const CauHinhMayChu& cauHinh,
                                     const QString& tenDangNhap, const QString& matKhau) {
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

    QSqlError loiCuoi;
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
        if (!laLoiThieuDriver(loiCuoi))
            break;   // lỗi thật (sai mật khẩu, không tới được máy chủ...) => không thử driver khác
    }

    if (laLoiThieuDriver(loiCuoi))
        return VoidResult::failure(QStringLiteral(
            "Không tìm thấy ODBC Driver cho SQL Server trên máy.\n"
            "Hãy cài \"Microsoft ODBC Driver 18 for SQL Server\" rồi thử lại."));
    return VoidResult::failure(SqlErrorMapper::thongBao(loiCuoi));
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
