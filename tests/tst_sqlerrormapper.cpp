#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/db/DbMessages.h"
#include "infrastructure/db/SqlErrorMapper.h"

#include <QtTest>

// No translator is installed here, so the messages are in the source language (English).
// The Vietnamese translations are checked in tst_i18n.
class TestSqlErrorMapper : public QObject {
    Q_OBJECT

private slots:
    void stripsOdbcPrefix() {
        const QString raw = QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]"
                                           "The student is already enrolled in this class.");
        QCOMPARE(SqlErrorMapper::cleanMessage(raw),
                 QStringLiteral("The student is already enrolled in this class."));
    }

    void stripsSqlStateSuffix() {
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
    void dbMessages_matchExactTextAndTemplates() {
        QVERIFY(DbMessages::isKnown(QStringLiteral("The current password is incorrect.")));
        QVERIFY(DbMessages::isKnown(QStringLiteral("Class CL0003 is full.")));
        QVERIFY(DbMessages::isKnown(QStringLiteral("Grades are still missing for 12 student(s).")));
        QVERIFY(!DbMessages::isKnown(QStringLiteral("Class is full.")));
        QVERIFY(!DbMessages::isKnown(QStringLiteral("The current password is incorrect. Extra")));
        QCOMPARE(DbMessages::translate(QStringLiteral("Class CL0003 is full.")),
                 QStringLiteral("Class CL0003 is full."));
        QCOMPARE(DbMessages::translate(QStringLiteral("Something else.")), QStringLiteral("Something else."));
    }

    void businessError_goesThroughTheCatalog() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to execute statement"),
            QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Class CL0008 is full."),
            QSqlError::StatementError, QStringLiteral("50000"));
        QCOMPARE(SqlErrorMapper::message(e), QStringLiteral("Class CL0008 is full."));
    }

    void loginFailure() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to connect"),
            QStringLiteral(
                "[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Login failed for user 'x'."),
            QSqlError::ConnectionError, QStringLiteral("18456"));
        QVERIFY(SqlErrorMapper::message(e).startsWith(QStringLiteral("Wrong username or password")));
    }

    void checkConstraintViolation() {
        const QSqlError e(
            QStringLiteral("QODBC: Unable to execute statement"),
            QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]The INSERT statement "
                           "conflicted with the CHECK constraint \"CK_STUDENT_Guardian\"."),
            QSqlError::StatementError, QStringLiteral("547"));
        QCOMPARE(SqlErrorMapper::message(e), QStringLiteral("Students under 18 need guardian information."));
    }

    void connectionString_escapesSpecialCharacters() {
        ServerConfig c;
        const QString s =
            DatabaseManager::connectionString(QStringLiteral("ODBC Driver 18 for SQL Server"), c,
                                              QStringLiteral("gvu_lan"), QStringLiteral("a;b}c"));
        QVERIFY(s.contains(QStringLiteral("PWD={a;b}}c};")));
        QVERIFY(s.contains(QStringLiteral("TrustServerCertificate=yes")));
    }
};

QTEST_APPLESS_MAIN(TestSqlErrorMapper)
#include "tst_sqlerrormapper.moc"
