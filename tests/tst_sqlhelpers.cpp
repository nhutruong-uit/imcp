#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/db/SqlHelpers.h"

#include <QtTest>

// SqlHelpers::withUnicodeText is the FreeTDS workaround (Qt sends text parameters as VARCHAR with FreeTDS):
// pure string/value rewriting, so it is tested without a database.
namespace {
const QString kDeclaration = QStringLiteral(
    "DECLARE @UnicodeText%1 NVARCHAR(MAX) = CAST(CAST(? AS VARBINARY(MAX)) AS NVARCHAR(MAX)); ");

QByteArray bytes(std::initializer_list<unsigned char> list) {
    QByteArray b;
    for (unsigned char c : list)
        b.append(char(c));
    return b;
}
} // namespace

class TestSqlHelpers : public QObject {
    Q_OBJECT

private slots:
    void withUnicodeText_asciiOnly_returnsStatementUnchanged() {
        const QString sql =
            QStringLiteral("EXEC dbo.usp_Student_Search @Keyword = ?, @BranchId = ?, @Status = ?");
        const QVariantList values{QStringLiteral("ST00010"), QStringLiteral("BR01"), QVariant()};
        const SqlHelpers::BoundStatement s = SqlHelpers::withUnicodeText(sql, values);
        QCOMPARE(s.sql, sql);
        QCOMPARE(s.values, values);
    }

    void withUnicodeText_vietnameseText_movesValueIntoNvarcharVariable() {
        const SqlHelpers::BoundStatement s =
            SqlHelpers::withUnicodeText(QStringLiteral("EXEC dbo.usp_X @Id = ?, @Address = ?"),
                                        {QStringLiteral("ST00010"), QStringLiteral("Số 1")});
        QCOMPARE(s.sql,
                 kDeclaration.arg(1) + QStringLiteral("EXEC dbo.usp_X @Id = ?, @Address = @UnicodeText1"));
        // Declaration values first (UTF-16LE bytes), then the remaining markers in their order
        QCOMPARE(s.values.size(), 2);
        QCOMPARE(s.values.at(0).typeId(), QMetaType::QByteArray);
        QCOMPARE(s.values.at(0).toByteArray(), bytes({'S', 0, 0xD1, 0x1E, ' ', 0, '1', 0}));
        QCOMPARE(s.values.at(1), QVariant(QStringLiteral("ST00010")));
    }

    void withUnicodeText_severalTexts_numbersVariablesInOrder() {
        const QDate dob(2004, 6, 26);
        const SqlHelpers::BoundStatement s = SqlHelpers::withUnicodeText(
            QStringLiteral("SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
                           "EXEC dbo.usp_Student_Add @FullName = ?, @DateOfBirth = ?, @Address = ?, "
                           "@StudentId = @NewId OUTPUT; SELECT @NewId;"),
            {QStringLiteral("Hồ Minh Quân"), dob, QStringLiteral("Quận 3")});
        QCOMPARE(s.sql,
                 kDeclaration.arg(1) + kDeclaration.arg(2) +
                     QStringLiteral("SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
                                    "EXEC dbo.usp_Student_Add @FullName = @UnicodeText1, @DateOfBirth = ?, "
                                    "@Address = @UnicodeText2, @StudentId = @NewId OUTPUT; SELECT @NewId;"));
        QCOMPARE(s.values.size(), 3);
        QCOMPARE(
            QString::fromUtf16(reinterpret_cast<const char16_t*>(s.values.at(0).toByteArray().constData()),
                               s.values.at(0).toByteArray().size() / 2),
            QStringLiteral("Hồ Minh Quân"));
        QCOMPARE(s.values.at(2), QVariant(dob));
    }

    // Characters outside code page 1258 (here an emoji = UTF-16 surrogate pair) keep all their code units
    void withUnicodeText_surrogatePair_keepsBothCodeUnits() {
        const SqlHelpers::BoundStatement s =
            SqlHelpers::withUnicodeText(QStringLiteral("SELECT ?"), {QString::fromUtf8("\xF0\x9F\x98\x80")});
        QCOMPARE(s.values.at(0).toByteArray(), bytes({0x3D, 0xD8, 0x00, 0xDE}));
    }

    void withUnicodeText_markersInLiteralsAndComments_areIgnored() {
        const QString sql = QStringLiteral("SELECT '?' AS A, N'it''s ?' AS B, [col?] AS C, \"x?\" AS D -- ?\n"
                                           "/* ? /* nested ? */ ? */ FROM dbo.T WHERE Name = ?");
        const SqlHelpers::BoundStatement s = SqlHelpers::withUnicodeText(sql, {QStringLiteral("Đức")});
        QString expected = sql;
        expected.chop(1);
        QCOMPARE(s.sql, kDeclaration.arg(1) + expected + QStringLiteral("@UnicodeText1"));
        QCOMPARE(s.values.size(), 1);
    }

    void withUnicodeText_nullsAndOtherTypes_stayParameters() {
        const QVariantList values{QVariant(QMetaType::fromType<QString>()), 2026, QDate(2026, 1, 1),
                                  QVariant(QMetaType::fromType<QDate>())};
        const QString sql = QStringLiteral("EXEC dbo.usp_X @A = ?, @B = ?, @C = ?, @D = ?");
        const SqlHelpers::BoundStatement s = SqlHelpers::withUnicodeText(sql, values);
        QCOMPARE(s.sql, sql);
        QCOMPARE(s.values, values);
    }

    void withUnicodeText_markerCountMismatch_returnsStatementUnchanged() {
        const QString sql = QStringLiteral("EXEC dbo.usp_X @A = ?, @B = ?");
        const QVariantList values{QStringLiteral("Số")};
        const SqlHelpers::BoundStatement s = SqlHelpers::withUnicodeText(sql, values);
        QCOMPARE(s.sql, sql);
        QCOMPARE(s.values, values);
    }

    void isFreeTds_detectsTheFreeTdsLibraryOnly() {
        QVERIFY(DatabaseManager::isFreeTds(QStringLiteral("/opt/homebrew/opt/freetds/lib/libtdsodbc.so")));
        QVERIFY(DatabaseManager::isFreeTds(QStringLiteral("/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so")));
        QVERIFY(!DatabaseManager::isFreeTds(QStringLiteral("ODBC Driver 18 for SQL Server")));
        QVERIFY(!DatabaseManager::isFreeTds(QStringLiteral("SQL Server")));
    }
};

QTEST_APPLESS_MAIN(TestSqlHelpers)
#include "tst_sqlhelpers.moc"
