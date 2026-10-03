// Multi-language UI (i18n): the English source strings, the Vietnamese translation (resources/translations/
// qlttta_vi.ts, embedded as :/i18n/qlttta_vi.qm), the display catalogs of database values, columns and
// database messages. Runs without a database (it reads the SQL scripts as text), so CI checks all of this on
// every run.
#include "infrastructure/db/DbMessages.h"
#include "infrastructure/db/SqlErrorMapper.h"
#include "presentation/common/Columns.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/I18n.h"
#include "presentation/common/Labels.h"

#include <QFile>
#include <QRegularExpression>
#include <QXmlStreamReader>
#include <QtTest>

class TestI18n : public QObject {
    Q_OBJECT

private:
    static QString readDatabaseScript(const QString& fileName) {
        QFile file(QStringLiteral(QLTTTA_DATABASE_DIR "/") + fileName);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            qFatal("cannot read %s", qPrintable(file.fileName()));
        return QString::fromUtf8(file.readAll());
    }

    // Unicode string literals N'...' of a SQL text ('' inside a literal is one quote)
    static QStringList sqlLiterals(const QString& sql, const QRegularExpression& literal) {
        QStringList values;
        for (auto m = literal.globalMatch(sql); m.hasNext();)
            values << m.next().captured(1).replace(QStringLiteral("''"), QStringLiteral("'"));
        return values;
    }

    // Every text the UI shows for codes: menu entries, roles, column titles and totals
    static QStringList catalogTexts() {
        QStringList texts;
        for (int f = static_cast<int>(Feature::Dashboard); f <= static_cast<int>(Feature::MyPay); ++f) {
            const FeatureInfo info = Labels::feature(static_cast<Feature>(f));
            texts << info.name << info.group;
        }
        for (Role r : {Role::Manager, Role::AcademicStaff, Role::Accountant, Role::Teacher, Role::Unknown})
            texts << Labels::role(r);
        for (const QString& key : Columns::keys()) {
            texts << Columns::title(key);
            if (Columns::isSummable(key))
                texts << Columns::totalLabel(key);
        }
        return texts;
    }

private slots:
    void cleanup() { I18n::apply(Language::English); }

    void english_isTheSourceLanguage() {
        QVERIFY(I18n::apply(Language::English));
        QCOMPARE(I18n::current(), Language::English);
        QCOMPARE(Labels::feature(Feature::Students).name, QStringLiteral("Students"));
        QCOMPARE(Columns::title(QStringLiteral("Balance")), QStringLiteral("Outstanding"));
        QCOMPARE(Columns::totalLabel(QStringLiteral("Balance")), QStringLiteral("Total outstanding"));
        QCOMPARE(Format::money(6500000), QStringLiteral("6,500,000 ₫"));
        QCOMPARE(Format::moneyShort(12500000), QStringLiteral("12.5M"));
        QCOMPARE(Format::month(1), QStringLiteral("Jan"));
        QCOMPARE(Format::schedule(QStringLiteral("Mon 18:00-20:00, Sun 08:00-09:30")),
                 QStringLiteral("Mon 18:00-20:00, Sun 08:00-09:30"));
        QCOMPARE(Format::cell(QStringLiteral("ACADEMIC_STAFF"), QStringLiteral("Role")),
                 QStringLiteral("Academic staff"));
    }

    void vietnamese_translationIsLoaded() {
        QVERIFY2(I18n::apply(Language::Vietnamese), "cannot load :/i18n/qlttta_vi.qm");
        QCOMPARE(I18n::current(), Language::Vietnamese);
        QCOMPARE(Labels::feature(Feature::Students).name, QStringLiteral("Học viên"));
        QCOMPARE(Labels::role(Role::AcademicStaff), QStringLiteral("Giáo vụ"));
        QCOMPARE(Columns::title(QStringLiteral("Balance")), QStringLiteral("Còn nợ"));
        QCOMPARE(Columns::totalLabel(QStringLiteral("Balance")), QStringLiteral("Tổng còn nợ"));
        QCOMPARE(SqlErrorMapper::constraintMessage(QStringLiteral("CK_STUDENT_Guardian")),
                 QStringLiteral("Học viên dưới 18 tuổi phải có thông tin phụ huynh."));
        QCOMPARE(Format::money(6500000), QStringLiteral("6.500.000 ₫"));
        QCOMPARE(Format::moneyShort(12500000), QStringLiteral("12,5 tr"));
        QCOMPARE(Format::month(1), QStringLiteral("T1"));
        QCOMPARE(Format::schedule(QStringLiteral("Mon 18:00-20:00, Sun 08:00-09:30")),
                 QStringLiteral("T2 18:00-20:00, CN 08:00-09:30"));
        QCOMPARE(Format::cell(QStringLiteral("ACADEMIC_STAFF"), QStringLiteral("Role")),
                 QStringLiteral("Giáo vụ"));
    }

    // DATETIME columns hold UTC: 17:30 UTC on 31 Jan is 00:30 on 1 Feb in Vietnam (UTC+07:00, no DST)
    void formatDateTime_utcFromDatabase_showsTimeOfZone() {
        const QDateTime fromDatabase(QDate(2026, 1, 31), QTime(17, 30)); // ODBC: date and time, no zone
        QCOMPARE(Format::dateTime(fromDatabase, QTimeZone(7 * 3600)), QStringLiteral("01/02/2026 00:30"));
        QCOMPARE(Format::dateTime(fromDatabase, QTimeZone::utc()), QStringLiteral("31/01/2026 17:30"));
        QCOMPARE(Format::dateTime(QDateTime()), QString());
    }

    // Each menu entry, role and column has a Vietnamese text that differs from the English one
    void everyCatalogTextIsTranslated() {
        I18n::apply(Language::English);
        const QStringList english = catalogTexts();
        QVERIFY(I18n::apply(Language::Vietnamese));
        const QStringList vietnamese = catalogTexts();
        QCOMPARE(vietnamese.size(), english.size());
        for (int i = 0; i < english.size(); ++i)
            QVERIFY2(vietnamese.at(i) != english.at(i),
                     qPrintable(QStringLiteral("not translated: ") + english.at(i)));
    }

    // The database stores English values: shown as they are in English, with a Vietnamese label in Vietnamese
    void dbValues_englishAsStored_vietnameseLabelled() {
        I18n::apply(Language::English);
        for (const QString& v : DbValues::all())
            QCOMPARE(DbValues::label(v), v);
        QVERIFY(I18n::apply(Language::Vietnamese));
        for (const QString& v : DbValues::all())
            QVERIFY2(DbValues::label(v) != v, qPrintable(QStringLiteral("no Vietnamese label: ") + v));
        QCOMPARE(DbValues::label(QStringLiteral("Studying")), QStringLiteral("Đang học"));
        QCOMPARE(DbValues::label(QStringLiteral("Nguyễn Văn An")),
                 QStringLiteral("Nguyễn Văn An")); // free text
    }

    // Every display value of a CHECK ... IN (N'...') constraint in the schema is registered in DbValues, so a
    // value added to the database cannot reach the Vietnamese UI untranslated (codes such as 'MANAGER' have
    // no N prefix)
    void dbValues_coverEveryCheckConstraintValue() {
        const QString schema = readDatabaseScript(QStringLiteral("01_tables.sql"));
        static const QRegularExpression checkIn(
            QStringLiteral("CHECK\\s*\\(\\s*\\w+\\s+IN\\s*\\(([^)]*)\\)"));
        // \b: the N prefix of a Unicode literal, not the last letter of a code such as 'PERCENT'
        static const QRegularExpression nString(QStringLiteral("\\bN'([^']*)'"));
        const QStringList registered = DbValues::all();
        int checked = 0;
        QStringList missing;
        for (auto m = checkIn.globalMatch(schema); m.hasNext();) {
            for (auto v = nString.globalMatch(m.next().captured(1)); v.hasNext();) {
                const QString value = v.next().captured(1);
                ++checked;
                if (!registered.contains(value))
                    missing << value;
            }
        }
        QVERIFY2(checked > 40,
                 qPrintable(QStringLiteral("only %1 values found - did the schema change?").arg(checked)));
        QVERIFY2(missing.isEmpty(),
                 qPrintable(QStringLiteral("not in DbValues: ") + missing.join(QStringLiteral(", "))));
    }

    // Highlighting comes from the stored value and the column key, never from translated text
    void highlighting_usesStoredValuesAndColumnKeys() {
        QVERIFY(I18n::apply(Language::Vietnamese));
        QCOMPARE(DbValues::tone(QStringLiteral("Passed")), DbValues::Tone::Positive);
        QCOMPARE(DbValues::tone(QStringLiteral("Failed")), DbValues::Tone::Negative);
        QCOMPARE(DbValues::tone(QStringLiteral("Đạt")), DbValues::Tone::Neutral); // a label is not a value
        QVERIFY(Columns::isDebt(QStringLiteral("Balance")));
        QVERIFY(Columns::isSummable(QStringLiteral("Balance")) &&
                Columns::isMoney(QStringLiteral("Balance")));
        QVERIFY(!Columns::isDebt(QStringLiteral("AmountPaid")));
        QVERIFY(!Columns::isMoney(QStringLiteral("Còn nợ"))); // a Vietnamese title is not a column key
    }

    // Business messages of the database (English) are shown in Vietnamese, values included
    void dbMessages_areTranslated() {
        QVERIFY(I18n::apply(Language::Vietnamese));
        QCOMPARE(DbMessages::translate(QStringLiteral("The current password is incorrect.")),
                 QStringLiteral("Mật khẩu hiện tại không đúng."));
        QCOMPARE(DbMessages::translate(QStringLiteral("Class CL0003 is full.")),
                 QStringLiteral("Lớp CL0003 đã đủ sĩ số tối đa."));
        QCOMPARE(
            DbMessages::translate(QStringLiteral("Schedule conflict with class CL0004 (same room D1-102).")),
            QStringLiteral("Trùng lịch với lớp CL0004 (cùng phòng D1-102)."));
        for (const QString& source : DbMessages::templates()) {
            const QString vietnamese = QCoreApplication::translate("DbMessages", source.toUtf8().constData());
            QVERIFY2(vietnamese != source, qPrintable(QStringLiteral("not translated: ") + source));
            for (const QString& placeholder : {QStringLiteral("%1"), QStringLiteral("%2")})
                QVERIFY2(source.contains(placeholder) == vietnamese.contains(placeholder),
                         qPrintable(QStringLiteral("placeholder %1 lost: ").arg(placeholder) + vietnamese));
        }
    }

    // Every THROW/RAISERROR message of the procedures and triggers is in the DbMessages catalog, and the
    // fixed parts of the templates (messages built from values) exist in the SQL scripts
    void dbMessages_coverEveryDatabaseMessage() {
        const QString sql = readDatabaseScript(QStringLiteral("04_procedures.sql")) +
                            readDatabaseScript(QStringLiteral("05_triggers.sql"));
        static const QRegularExpression raised(
            QStringLiteral("(?:THROW\\s+5\\d{4}\\s*,|RAISERROR\\s*\\()\\s*N'((?:[^']|'')*)'"));
        static const QRegularExpression anyLiteral(QStringLiteral("\\bN'((?:[^']|'')*)'"));
        const QStringList messages = sqlLiterals(sql, raised);
        QVERIFY2(messages.size() > 50,
                 qPrintable(QStringLiteral("only %1 messages found").arg(messages.size())));
        QStringList missing;
        for (const QString& message : messages)
            if (!DbMessages::isKnown(message))
                missing << message;
        QVERIFY2(missing.isEmpty(),
                 qPrintable(QStringLiteral("not in DbMessages: ") + missing.join(QStringLiteral(" | "))));

        const QString literals = sqlLiterals(sql, anyLiteral).join(QLatin1Char('\n'));
        static const QRegularExpression placeholder(QStringLiteral("%[1-9]"));
        for (const QString& source : DbMessages::templates()) {
            if (!source.contains(placeholder))
                continue;
            for (const QString& part : source.split(placeholder, Qt::SkipEmptyParts))
                QVERIFY2(literals.contains(part),
                         qPrintable(QStringLiteral("not in the SQL scripts: ") + part));
        }
    }

    void languageNames_areNeverTranslated() {
        QVERIFY(I18n::apply(Language::Vietnamese));
        QCOMPARE(Labels::language(Language::English), QStringLiteral("English"));
        I18n::apply(Language::English);
        QCOMPARE(Labels::language(Language::Vietnamese), QStringLiteral("Tiếng Việt"));
    }

    // Guard for new strings: after `update_translations`, every entry of the .ts file must be translated
    void tsFile_hasNoUnfinishedTranslations() {
        QFile file(QStringLiteral(QLTTTA_TS_FILE));
        QVERIFY2(file.open(QIODevice::ReadOnly), qPrintable(file.fileName()));
        QXmlStreamReader xml(&file);
        QString source;
        QStringList unfinished;
        int messages = 0;
        while (!xml.atEnd()) {
            xml.readNext();
            if (!xml.isStartElement())
                continue;
            if (xml.name() == QLatin1String("message")) {
                ++messages;
            } else if (xml.name() == QLatin1String("source")) {
                source = xml.readElementText();
            } else if (xml.name() == QLatin1String("translation")) {
                const QString type = xml.attributes().value(QLatin1String("type")).toString();
                const QString text = xml.readElementText(QXmlStreamReader::IncludeChildElements);
                if (!type.isEmpty() || text.trimmed().isEmpty())
                    unfinished << source;
            }
        }
        QVERIFY2(!xml.hasError(), qPrintable(xml.errorString()));
        QVERIFY(messages > 100);
        QVERIFY2(unfinished.isEmpty(),
                 qPrintable(QStringLiteral("untranslated: ") + unfinished.join(QStringLiteral(" | "))));
    }
};

QTEST_GUILESS_MAIN(TestI18n)
#include "tst_i18n.moc"
