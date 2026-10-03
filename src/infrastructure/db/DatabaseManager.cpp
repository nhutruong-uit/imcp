#include "infrastructure/db/DatabaseManager.h"

#include "infrastructure/db/SqlErrorMapper.h"

#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>

namespace {
// Qt keeps connections in a global list by name; the application uses a single named connection
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

// The driver is not installed on this machine => try the next one (IM002 = ODBC "data source not found")
bool isMissingDriverError(const QSqlError& error) {
    const QString t = error.databaseText() + QLatin1Char(' ') + error.driverText() + QLatin1Char(' ') +
                      error.nativeErrorCode();
    return t.contains(QLatin1String("IM002")) || t.contains(QLatin1String("Can't open lib")) ||
           t.contains(QLatin1String("Data source name not found"), Qt::CaseInsensitive) ||
           t.contains(QLatin1String("file not found"), Qt::CaseInsensitive);
}

// The server answered but rejected the login => trying another driver is pointless
// (18456 = SQL Server "Login failed"; "Cannot open database" = the database name is wrong or not accessible)
bool isAuthenticationError(const QSqlError& error) {
    const QString t = error.databaseText() + QLatin1Char(' ') + error.nativeErrorCode();
    return t.contains(QLatin1String("18456")) || t.contains(QLatin1String("Login failed"), Qt::CaseInsensitive) ||
           t.contains(QLatin1String("Cannot open database"), Qt::CaseInsensitive);
}

// The driver rejected the server's certificate ("Trust server certificate" is off) => stop: the next drivers
// (FreeTDS, the legacy Windows driver) do not check certificates, so trying them would get around the check
bool isCertificateError(const QSqlError& error) {
    const QString t = error.databaseText() + QLatin1Char(' ') + error.driverText();
    return t.contains(QLatin1String("certificate"), Qt::CaseInsensitive);
}

// The server did not answer in time (HYT00 = ODBC "login timeout expired"): another driver would wait as long
bool isTimeoutError(const QSqlError& error) {
    const QString t = error.databaseText() + QLatin1Char(' ') + error.nativeErrorCode();
    return t.contains(QLatin1String("HYT00")) ||
           t.contains(QLatin1String("Login timeout expired"), Qt::CaseInsensitive);
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

bool DatabaseManager::isFreeTds(const QString& driver) {
    return driver.contains(QLatin1String("tdsodbc")); // libtdsodbc.so, the name Qt checks too
}

// The ODBC connection string = "KEY=value;" pairs the driver understands. Values that come from the user
// go through odbcValue() so a ';' in a password cannot inject another key.
QString DatabaseManager::connectionString(const QString& driver, const ServerConfig& config,
                                          const QString& username, const QString& password) {
    if (isFreeTds(driver)) {
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
            s += QStringLiteral("PORT=%1;").arg(odbcValue(port)); // "1433;Encryption=off" stays one value
        return s;
    }

    // Microsoft drivers: encrypted connection; TrustServerCertificate is the option of the login dialog
    // (needed for the self-signed certificate of the Docker image). The legacy Windows driver "SQL Server"
    // does not know these keywords.
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
        // Inner block: the QSqlDatabase handle must be destroyed before removeDatabase() below (Qt rule)
        {
            QSqlDatabase db =
                QSqlDatabase::addDatabase(QStringLiteral("QODBC"), QLatin1String(kConnectionName));
            db.setDatabaseName(connectionString(driver, config, username, password));
            db.setConnectOptions(QStringLiteral("SQL_ATTR_LOGIN_TIMEOUT=8"));
            if (db.open()) {
                m_driver = driver;
                // Same session settings whatever the default language of the login: dates are read as
                // year-month-day and SQL Server's own messages stay English, which SqlErrorMapper recognizes
                QSqlQuery(db).exec(QStringLiteral("SET DATEFORMAT ymd; SET LANGUAGE us_english;"));
                return VoidResult::success();
            }
            lastError = db.lastError();
        }
        QSqlDatabase::removeDatabase(QLatin1String(kConnectionName));
        // Wrong password, rejected certificate or no answer => stop, another driver would not do better
        if (isAuthenticationError(lastError) || isCertificateError(lastError) || isTimeoutError(lastError))
            return VoidResult::failure(SqlErrorMapper::message(lastError));
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

QSqlDatabase DatabaseManager::db() const {
    return QSqlDatabase::database(QLatin1String(kConnectionName), false);
}
