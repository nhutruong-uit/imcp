// Unit tests of SqlErrorMapper and DbMessages (infrastructure): how a raw ODBC error from SQL Server
// becomes the short message the UI shows - driver prefixes and SQLSTATE suffixes removed, business messages
// looked up in the DbMessages catalog, login failures and constraint names turned into readable text - plus
// the escaping of the ODBC connection string and the "Trust server certificate" option (which drivers may
// connect, the default per host). The QSqlError objects are built by hand: no database needed.
// Run only this suite:
//   ctest --preset macos-debug -R tst_sqlerrormapper --output-on-failure
#include "infrastructure/config/QSettingsStore.h"
#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/db/DbMessages.h"
#include "infrastructure/db/SqlErrorMapper.h"

#include <QSettings>
#include <QTemporaryDir>
#include <QtTest>

// No translator is installed here, so the messages are in the source language (English).
// The Vietnamese translations are checked in tst_i18n.
class TestSqlErrorMapper : public QObject {
    Q_OBJECT

private:
    QTemporaryDir m_settingsDir; // the QSettings of QSettingsStore are written here, never to the real ones

private slots:
    void initTestCase() {
        QVERIFY(m_settingsDir.isValid());
        QCoreApplication::setOrganizationName(QStringLiteral("UIT-IE103-UnitTest"));
        QCoreApplication::setApplicationName(QStringLiteral("tst_sqlerrormapper"));
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_settingsDir.path());
    }

    void init() {
        QSettings().clear(); // every test starts with nothing saved
    }

    // The [vendor][driver][server] prefixes in front of the database message are removed
    void cleanMessage_odbcPrefix_isRemoved() {
        const QString raw = QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]"
                                           "The student is already enrolled in this class.");
        QCOMPARE(SqlErrorMapper::cleanMessage(raw),
                 QStringLiteral("The student is already enrolled in this class."));
    }

    void cleanMessage_sqlStateSuffix_isRemoved() {
        QCOMPARE(SqlErrorMapper::cleanMessage(QStringLiteral("The current password is incorrect., 37000")),
                 QStringLiteral("The current password is incorrect."));
        QCOMPARE(SqlErrorMapper::cleanMessage(
                     QStringLiteral("[FreeTDS][SQL Server]Class CL0001 is full., 42000;01000")),
                 QStringLiteral("Class CL0001 is full."));
        // A normal comma inside the sentence is not cut
        QCOMPARE(SqlErrorMapper::cleanMessage(
                     QStringLiteral("Schedule conflict with class CL0004 (same room D1-102).")),
                 QStringLiteral("Schedule conflict with class CL0004 (same room D1-102)."));
    }

    // Business messages: exact text or template with values; unknown messages pass through unchanged
    void isKnown_exactTextOrTemplate_matches() {
        QVERIFY(DbMessages::isKnown(QStringLiteral("The current password is incorrect.")));
        QVERIFY(DbMessages::isKnown(QStringLiteral("Class CL0003 is full.")));
        QVERIFY(DbMessages::isKnown(QStringLiteral("Grades are still missing for 12 student(s).")));
        QVERIFY(!DbMessages::isKnown(QStringLiteral("Class is full.")));
        QVERIFY(!DbMessages::isKnown(QStringLiteral("The current password is incorrect. Extra")));
        QCOMPARE(DbMessages::translate(QStringLiteral("Class CL0003 is full.")),
                 QStringLiteral("Class CL0003 is full."));
        QCOMPARE(DbMessages::translate(QStringLiteral("Something else.")), QStringLiteral("Something else."));
    }

    // A business message of a procedure/trigger (THROW/RAISERROR) is cleaned, then looked up in DbMessages
    void message_businessError_goesThroughCatalog() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to execute statement"),
            QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Class CL0008 is full."),
            QSqlError::StatementError, QStringLiteral("50000"));
        QCOMPARE(SqlErrorMapper::message(e), QStringLiteral("Class CL0008 is full."));
    }

    // Error 18456 (login failed) becomes a readable text instead of the raw ODBC message
    void message_loginFailed_isReadable() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to connect"),
            QStringLiteral(
                "[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Login failed for user 'x'."),
            QSqlError::ConnectionError, QStringLiteral("18456"));
        QVERIFY(SqlErrorMapper::message(e).startsWith(QStringLiteral("Wrong username or password")));
    }

    // Legacy Windows driver "SQL Server" with no server listening at the address (also: TCP/IP disabled) -
    // the raw text of that driver, as seen on Windows 11
    void message_legacyWindowsDriverCannotConnect_asksToCheckTheServer() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to connect"),
            QStringLiteral("[Microsoft][ODBC SQL Server Driver][DBNETLIB]SQL Server does not exist "
                           "or access denied. [Microsoft][ODBC SQL Server Driver][DBNETLIB]"
                           "ConnectionOpen (Connect())."),
            QSqlError::ConnectionError, QStringLiteral("17;53"));
        QVERIFY(SqlErrorMapper::message(e).startsWith(QStringLiteral("Cannot connect to SQL Server.")));
    }

    // The legacy Windows driver got no answer (it cannot sign in to SQL Server 2025 on Windows 11): the
    // message adds the fix, installing ODBC Driver 18; the same error through ODBC Driver 18 does not
    void connectionFailure_legacyWindowsDriverTimesOut_suggestsOdbcDriver18() {
        const QSqlError e(QStringLiteral("QODBC: Unable to connect"),
                          QStringLiteral("[Microsoft][ODBC SQL Server Driver]Login timeout expired"),
                          QSqlError::ConnectionError, QStringLiteral("0"));
        const QString legacy = DatabaseManager::connectionFailure(e, QStringLiteral("SQL Server"));
        QVERIFY(legacy.startsWith(QStringLiteral("Cannot connect to SQL Server.")));
        QVERIFY(legacy.contains(QStringLiteral("Install \"Microsoft ODBC Driver 18 for SQL Server\"")));
        QCOMPARE(DatabaseManager::connectionFailure(e, QStringLiteral("ODBC Driver 18 for SQL Server")),
                 SqlErrorMapper::message(e));
    }

    // A rejected password is the user's mistake, whatever the driver: no driver hint
    void connectionFailure_legacyWindowsDriverLoginFailed_hasNoDriverHint() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to connect"),
            QStringLiteral("[Microsoft][ODBC SQL Server Driver][SQL Server]Login failed for user 'x'."),
            QSqlError::ConnectionError, QStringLiteral("18456"));
        QCOMPARE(DatabaseManager::connectionFailure(e, QStringLiteral("SQL Server")),
                 SqlErrorMapper::message(e));
    }

    // Error 547 (CHECK constraint): the constraint name is read from the message and mapped to its own text
    void message_checkConstraint_usesConstraintText() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to execute statement"),
            QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]The INSERT statement "
                           "conflicted with the CHECK constraint \"CK_STUDENT_Guardian\"."),
            QSqlError::StatementError, QStringLiteral("547"));
        QCOMPARE(SqlErrorMapper::message(e), QStringLiteral("Students under 18 need guardian information."));
    }

    // Finalizing a month again with a lower rate under a deduction (usp_Payroll_Finalize,
    // CK_PAYROLL_Deduction)
    void message_payrollDeductionAbovePay_asksToLowerTheDeduction() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to execute statement"),
            QStringLiteral(
                "[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]The UPDATE statement conflicted "
                "with the CHECK constraint \"CK_PAYROLL_Deduction\". The conflict occurred in database "
                "\"QLTTTA\", table \"dbo.PAYROLL\"."),
            QSqlError::StatementError, QStringLiteral("547"));
        QCOMPARE(SqlErrorMapper::message(e),
                 QStringLiteral(
                     "The pay of the month would fall below its deduction: lower the deduction first."));
    }

    // A value with ; or } is wrapped in {...} with } doubled, so a password cannot add another ODBC keyword
    void connectionString_passwordWithSemicolon_isEscaped() {
        ServerConfig c;
        const QString s =
            DatabaseManager::connectionString(QStringLiteral("ODBC Driver 18 for SQL Server"), c,
                                              QStringLiteral("gvu_lan"), QStringLiteral("a;b}c"));
        QVERIFY(s.contains(QStringLiteral("PWD={a;b}}c};")));
        QVERIFY(s.contains(QStringLiteral("TrustServerCertificate=yes")));
    }

    // FreeTDS: the port typed after the comma of the server name is one value too, it cannot add a keyword
    void connectionString_freeTdsPort_cannotAddKeywords() {
        ServerConfig c;
        c.host = QStringLiteral("db.example.com,1433;Encryption=off");
        const QString s =
            DatabaseManager::connectionString(QStringLiteral("/opt/freetds/lib/libtdsodbc.so"), c,
                                              QStringLiteral("gvu_lan"), QStringLiteral("x"));
        QVERIFY(s.contains(QStringLiteral("PORT={1433;Encryption=off};")));
        QVERIFY(s.contains(QStringLiteral("Encryption=require;")));
    }

    // "Trust server certificate" off: the Microsoft drivers get TrustServerCertificate=no, so they check it
    void connectionString_microsoftDriverTrustOff_asksForCertificateCheck() {
        ServerConfig c;
        c.trustServerCertificate = false;
        const QString s =
            DatabaseManager::connectionString(QStringLiteral("ODBC Driver 18 for SQL Server"), c,
                                              QStringLiteral("gvu_lan"), QStringLiteral("x"));
        QVERIFY(s.contains(QStringLiteral("Encrypt=yes;TrustServerCertificate=no;")));
        QVERIFY(!s.contains(QStringLiteral("TrustServerCertificate=yes")));
    }

    // Only the Microsoft drivers check a certificate: FreeTDS accepts a self-signed one even with a CA file
    // (checked against SQL Server 2025 with FreeTDS 1.5), the legacy Windows driver has no TLS keywords at
    // all
    void canVerifyCertificate_drivers_onlyMicrosoftOdbcDriversCheck() {
        QVERIFY(DatabaseManager::canVerifyCertificate(QStringLiteral("ODBC Driver 18 for SQL Server")));
        QVERIFY(DatabaseManager::canVerifyCertificate(QStringLiteral("ODBC Driver 17 for SQL Server")));
        QVERIFY(!DatabaseManager::canVerifyCertificate(QStringLiteral("/opt/freetds/lib/libtdsodbc.so")));
        QVERIFY(!DatabaseManager::canVerifyCertificate(QStringLiteral("SQL Server")));
    }

    // "Trust server certificate" off: the drivers that cannot check the certificate are never tried (they
    // would connect without the check); on: every candidate stays, in the same order
    void driversToTry_trustOff_dropsTheDriversThatCannotCheck() {
        const QStringList candidates = {
            QStringLiteral("/app/Frameworks/libtdsodbc.so"), QStringLiteral("ODBC Driver 18 for SQL Server"),
            QStringLiteral("ODBC Driver 17 for SQL Server"), QStringLiteral("SQL Server")};
        QCOMPARE(DatabaseManager::driversToTry(candidates, true), candidates);
        QCOMPARE(DatabaseManager::driversToTry(candidates, false),
                 (QStringList{QStringLiteral("ODBC Driver 18 for SQL Server"),
                              QStringLiteral("ODBC Driver 17 for SQL Server")}));
        // The .dmg without the Microsoft driver: nothing is left, so open() reports it instead of connecting
        QVERIFY(DatabaseManager::driversToTry({QStringLiteral("/app/Frameworks/libtdsodbc.so")}, false)
                    .isEmpty());
    }

    // Nothing saved yet: the default host is this computer, so its certificate is trusted (Docker)
    void serverConfig_nothingSaved_trustsTheLocalDefaultHost() {
        const ServerConfig c = QSettingsStore().serverConfig();
        QCOMPARE(c.host, QStringLiteral("localhost,1433"));
        QVERIFY(c.trustServerCertificate);
    }

    // A server that is not this computer starts with its certificate checked, until the user chooses
    void serverConfig_remoteHostWithoutChoice_doesNotTrustCertificate() {
        QSettings().setValue(QStringLiteral("server/host"), QStringLiteral("db.example.com,1433"));
        QVERIFY(!QSettingsStore().serverConfig().trustServerCertificate);
    }

    // What the user chose is kept, for a local and for a remote host alike
    void serverConfig_savedChoice_isKeptWhateverTheHost() {
        QSettingsStore store;
        ServerConfig remote;
        remote.host = QStringLiteral("db.example.com,1433");
        remote.trustServerCertificate = true;
        store.saveServerConfig(remote);
        QVERIFY(store.serverConfig().trustServerCertificate);

        ServerConfig local;
        local.trustServerCertificate = false;
        store.saveServerConfig(local);
        QVERIFY(!store.serverConfig().trustServerCertificate);
    }
};

QTEST_APPLESS_MAIN(TestSqlErrorMapper)
#include "tst_sqlerrormapper.moc"
