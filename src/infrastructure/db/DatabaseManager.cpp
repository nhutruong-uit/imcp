#include "infrastructure/db/DatabaseManager.h"

#include "infrastructure/db/SqlErrorMapper.h"

#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>

namespace {
const char* const kConnectionName = "qlttta";

// Value inside an ODBC connection string: wrapped in {} when it has special characters, '}' written as '}}'
QString odbcValue(const QString& v) {
    if (!v.contains(QLatin1Char(';')) && !v.contains(QLatin1Char('{')) && !v.contains(QLatin1Char('}')) &&
        !v.contains(QLatin1Char('=')) && v.trimmed() == v)
        return v;
    QString s = v;
    s.replace(QLatin1String("}"), QLatin1String("}}"));
    return QLatin1Char('{') + s + QLatin1Char('}');
}

bool isMissingDriverError(const QSqlError& error) {
    const QString t = error.databaseText() + QLatin1Char(' ') + error.driverText() + QLatin1Char(' ') +
                      error.nativeErrorCode();
    return t.contains(QLatin1String("IM002")) || t.contains(QLatin1String("Can't open lib")) ||
           t.contains(QLatin1String("Data source name not found"), Qt::CaseInsensitive) ||
           t.contains(QLatin1String("file not found"), Qt::CaseInsensitive);
}

// The server answered but rejected the login => trying another driver is pointless
bool isAuthenticationError(const QSqlError& error) {
    const QString t = error.databaseText() + QLatin1Char(' ') + error.nativeErrorCode();
    return t.contains(QLatin1String("18456")) || t.contains(QLatin1String("Login failed"), Qt::CaseInsensitive) ||
           t.contains(QLatin1String("Cannot open database"), Qt::CaseInsensitive);
}
} // namespace

DatabaseManager::~DatabaseManager() {
    close();
}

QStringList DatabaseManager::candidateDrivers() {
    QStringList drivers;
    const QString custom = qEnvironmentVariable("QLTTTA_ODBC_DRIVER");
    if (!custom.isEmpty())
        drivers << custom;
#if defined(Q_OS_MACOS)
    // The .dmg bundles FreeTDS (open source, LGPL) with its own unixODBC => try it first, so the Microsoft
    // driver (linked against Homebrew's unixODBC) is never loaded into the same process.
    const QString bundled = QDir(QCoreApplication::applicationDirPath())
                                .absoluteFilePath(QStringLiteral("../Frameworks/libtdsodbc.so"));
    if (QFileInfo::exists(bundled))
        drivers << QFileInfo(bundled).canonicalFilePath();
#endif
    drivers << QStringLiteral("ODBC Driver 18 for SQL Server") << QStringLiteral("ODBC Driver 17 for SQL Server");
#if defined(Q_OS_WIN)
    drivers << QStringLiteral("SQL Server"); // legacy driver, always present on Windows
#elif defined(Q_OS_MACOS)
    for (const QString& path : {QStringLiteral("/opt/homebrew/opt/freetds/lib/libtdsodbc.so"),
                                QStringLiteral("/usr/local/opt/freetds/lib/libtdsodbc.so")}) {
        if (QFileInfo::exists(path))
            drivers << QFileInfo(path).canonicalFilePath();
    }
#endif
    drivers.removeDuplicates();
    return drivers;
}

QString DatabaseManager::connectionString(const QString& driver, const ServerConfig& config,
                                          const QString& username, const QString& password) {
    if (driver.contains(QLatin1String("tdsodbc"))) {
        // FreeTDS: separate server and port, TDS protocol 7.4 (SQL Server 2012+), encryption required
        QString host = config.host.trimmed();
        QString port = QStringLiteral("1433");
        const int comma = host.indexOf(QLatin1Char(','));
        if (comma > 0) {
            port = host.mid(comma + 1).trimmed();
            host = host.left(comma).trimmed();
        }
        QString s = QStringLiteral("DRIVER={%1};SERVER=%2;DATABASE=%3;UID=%4;PWD=%5;"
                                   "TDS_Version=7.4;ClientCharset=UTF-8;Encryption=require;APP=QLTTTA;")
                        .arg(driver, odbcValue(host), odbcValue(config.database.trimmed()),
                             odbcValue(username), odbcValue(password));
        if (!host.contains(QLatin1Char('\\')))
            s += QStringLiteral("PORT=%1;").arg(port);
        return s;
    }

    QString s = QStringLiteral("DRIVER={%1};SERVER=%2;DATABASE=%3;UID=%4;PWD=%5;")
                    .arg(driver, odbcValue(config.host.trimmed()), odbcValue(config.database.trimmed()),
                         odbcValue(username), odbcValue(password));
    if (driver != QLatin1String("SQL Server")) {
        s += QStringLiteral("Encrypt=yes;TrustServerCertificate=%1;")
                 .arg(config.trustServerCertificate ? QStringLiteral("yes") : QStringLiteral("no"));
    }
    s += QStringLiteral("APP=QLTTTA;");
    return s;
}

VoidResult DatabaseManager::open(const ServerConfig& config, const QString& username,
                                 const QString& password) {
    close();
    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QODBC")))
        return VoidResult::failure(
            tr("The Qt ODBC plugin (qsqlodbc) is missing. Please reinstall the application."));

    QSqlError lastError;       // error of the last driver tried
    QSqlError meaningfulError; // first error that is not "driver missing" (the driver/server was reached)
    for (const QString& driver : candidateDrivers()) {
        {
            QSqlDatabase db =
                QSqlDatabase::addDatabase(QStringLiteral("QODBC"), QLatin1String(kConnectionName));
            db.setDatabaseName(connectionString(driver, config, username, password));
            db.setConnectOptions(QStringLiteral("SQL_ATTR_LOGIN_TIMEOUT=8"));
            if (db.open()) {
                m_driver = driver;
                QSqlQuery(db).exec(QStringLiteral("SET DATEFORMAT ymd; SET LANGUAGE us_english;"));
                return VoidResult::success();
            }
            lastError = db.lastError();
        }
        QSqlDatabase::removeDatabase(QLatin1String(kConnectionName));
        if (isAuthenticationError(lastError))
            return VoidResult::failure(SqlErrorMapper::message(lastError)); // wrong password => stop
        if (!isMissingDriverError(lastError) && !meaningfulError.isValid())
            meaningfulError = lastError; // other errors (network, TLS...) => still try the next driver
    }

    if (meaningfulError.isValid())
        return VoidResult::failure(SqlErrorMapper::message(meaningfulError));
    return VoidResult::failure(
        tr("No ODBC driver for SQL Server was found on this computer.\n"
           "Please install \"Microsoft ODBC Driver 18 for SQL Server\" and try again."));
}

void DatabaseManager::close() {
    if (QSqlDatabase::contains(QLatin1String(kConnectionName))) {
        {
            QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName), false);
            db.close();
        }
        QSqlDatabase::removeDatabase(QLatin1String(kConnectionName));
    }
    m_driver.clear();
}

bool DatabaseManager::isOpen() const {
    return QSqlDatabase::contains(QLatin1String(kConnectionName)) &&
           QSqlDatabase::database(QLatin1String(kConnectionName), false).isOpen();
}

QSqlDatabase DatabaseManager::db() const {
    return QSqlDatabase::database(QLatin1String(kConnectionName), false);
}
