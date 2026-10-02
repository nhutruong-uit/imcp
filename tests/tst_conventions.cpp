// Repository conventions checked from the files themselves (no database, no build output): SQL Server 2012
// syntax and script headers, Clean Architecture include directions, SQL only in the infrastructure layer,
// script format, and the numbers the docs quote about the database. Every failure lists file:line.
// The rules are described in .claude/rules/ (01-sql.md, 02-cpp-qt.md, 04-scripts-ci.md, 06-docs.md).
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QtTest>

namespace {
const QString kRoot = QStringLiteral(QLTTTA_SOURCE_DIR);

QByteArray readBytes(const QString& relativePath) {
    QFile file(kRoot + QLatin1Char('/') + relativePath);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return file.readAll();
}

QString readText(const QString& relativePath) {
    return QString::fromUtf8(readBytes(relativePath));
}

// Relative paths of the files under dir matching the filters, sorted
QStringList filesIn(const QString& dir, const QStringList& nameFilters, bool recursive = true) {
    QStringList files;
    QDirIterator it(kRoot + QLatin1Char('/') + dir, nameFilters, QDir::Files,
                    recursive ? QDirIterator::Subdirectories : QDirIterator::NoIteratorFlags);
    while (it.hasNext())
        files << QDir(kRoot).relativeFilePath(it.next());
    files.sort();
    return files;
}

// Comments replaced by spaces, line breaks kept (line numbers stay right); literals are kept.
// SQL: -- and nested /* */, 'literals' with ''. C++: // and /* */, "literals" and 'c' with \ escapes.
QString withoutComments(const QString& text, bool sql) {
    QString out = text;
    const qsizetype n = text.size();
    auto blank = [&](qsizetype i) {
        if (out.at(i) != u'\n')
            out[i] = u' ';
    };
    for (qsizetype i = 0; i < n; ++i) {
        const QChar c = text.at(i);
        const bool lineComment = sql ? (c == u'-' && i + 1 < n && text.at(i + 1) == u'-')
                                     : (c == u'/' && i + 1 < n && text.at(i + 1) == u'/');
        if (c == u'\'' || (!sql && c == u'"')) {
            for (++i; i < n; ++i) {
                if (!sql && text.at(i) == u'\\') {
                    ++i;
                } else if (text.at(i) == c) {
                    if (sql && i + 1 < n && text.at(i + 1) == c)
                        ++i;
                    else
                        break;
                } else if (!sql && text.at(i) == u'\n') {
                    break;
                }
            }
        } else if (lineComment) {
            for (; i < n && text.at(i) != u'\n'; ++i)
                blank(i);
        } else if (c == u'/' && i + 1 < n && text.at(i + 1) == u'*') {
            int depth = 0;
            for (; i < n; ++i) {
                if (text.at(i) == u'/' && i + 1 < n && text.at(i + 1) == u'*' && (sql || depth == 0)) {
                    ++depth;
                    blank(i);
                    blank(++i);
                } else if (text.at(i) == u'*' && i + 1 < n && text.at(i + 1) == u'/') {
                    blank(i);
                    blank(++i);
                    if (--depth == 0)
                        break;
                } else {
                    blank(i);
                }
            }
        }
    }
    return out;
}

int lineOf(const QString& text, qsizetype position) {
    return int(QStringView(text).left(position).count(u'\n')) + 1;
}

// "file:line: problem" for every match of pattern in text
QStringList findAll(const QString& file, const QString& text, const QRegularExpression& pattern,
                    const QString& problem) {
    QStringList found;
    auto it = pattern.globalMatch(text);
    while (it.hasNext()) {
        const auto m = it.next();
        found << QStringLiteral("%1:%2: %3 (%4)")
                     .arg(file)
                     .arg(lineOf(text, m.capturedStart()))
                     .arg(problem, m.captured().simplified());
    }
    return found;
}

int countOf(const QString& text, const QString& pattern) {
    const QRegularExpression re(pattern, QRegularExpression::CaseInsensitiveOption |
                                             QRegularExpression::MultilineOption);
    int n = 0;
    for (auto it = re.globalMatch(text); it.hasNext(); it.next())
        ++n;
    return n;
}

QString sqlCode(const QString& fileName) {
    return withoutComments(readText(QStringLiteral("database/") + fileName), true);
}

// Test case codes registered in #Expected: ('T01', N'%pattern%') or ('T15', NULL) - two values only
int expectedCases(const QString& fileName) {
    const QRegularExpression re(QStringLiteral("\\('([TPS]\\d{2})',\\s*(?:NULL|N'(?:[^']|'')*')\\s*\\)"));
    QSet<QString> codes;
    for (auto it = re.globalMatch(sqlCode(fileName)); it.hasNext();)
        codes.insert(it.next().captured(1));
    return int(codes.size());
}

// The number the docs write in front of a phrase, e.g. "(\\d+) procedures"; -1 if the phrase is missing
int numberIn(const QString& doc, const QString& pattern, int group = 1) {
    const auto m = QRegularExpression(pattern).match(readText(doc));
    return m.hasMatch() ? m.captured(group).toInt() : -1;
}

QString joined(const QStringList& problems) {
    return QStringLiteral("\n") + problems.join(QLatin1Char('\n'));
}
} // namespace

class TestConventions : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        QVERIFY2(QFile::exists(kRoot + QStringLiteral("/database/01_tables.sql")), qPrintable(kRoot));
    }

    // AGENTS.md: SQL Server 2012+ only - none of the newer statements and functions
    void sqlScripts_sqlServer2012_useNoNewerSyntax() {
        const QList<QPair<QString, QString>> banned = {
            {QStringLiteral("\\bCREATE\\s+OR\\s+ALTER\\b"),
             QStringLiteral("CREATE OR ALTER is SQL Server 2016+")},
            {QStringLiteral("\\bDROP\\s+\\w+\\s+IF\\s+EXISTS\\b"),
             QStringLiteral("DROP ... IF EXISTS is 2016+")},
            {QStringLiteral("\\b(STRING_AGG|STRING_SPLIT|CONCAT_WS|TRANSLATE|DATEDIFF_BIG)\\s*\\("),
             QStringLiteral("function of SQL Server 2016+")},
            {QStringLiteral("(?<![\\w.])TRIM\\s*\\("),
             QStringLiteral("TRIM is 2017+ (use LTRIM(RTRIM(...)))")},
            {QStringLiteral("\\b(OPENJSON|JSON_VALUE|JSON_QUERY|JSON_MODIFY|ISJSON)\\b|\\bFOR\\s+JSON\\b"),
             QStringLiteral("JSON is 2016+")},
            {QStringLiteral("\\b(GREATEST|LEAST|GENERATE_SERIES|DATE_BUCKET|DATETRUNC)\\s*\\("),
             QStringLiteral("function of SQL Server 2022")},
            {QStringLiteral("\\bAT\\s+TIME\\s+ZONE\\b|\\bSECURITY\\s+POLICY\\b"),
             QStringLiteral("feature of SQL Server 2016+")},
        };
        QStringList problems;
        for (const QString& file : filesIn(QStringLiteral("database"), {QStringLiteral("*.sql")}, false)) {
            const QString code = withoutComments(readText(file), true);
            for (const auto& [pattern, problem] : banned)
                problems << findAll(file, code,
                                    QRegularExpression(pattern, QRegularExpression::CaseInsensitiveOption),
                                    problem);
        }
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // AGENTS.md: a script starts with USE QLTTTA; GO; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
    // (server-level scripts - create database, backup, distributed demo - start with USE master;)
    void sqlScripts_header_startsWithUseAndSetOptions() {
        QStringList problems;
        for (const QString& file : filesIn(QStringLiteral("database"), {QStringLiteral("*.sql")}, false)) {
            QStringList lines;
            for (const QString& line : withoutComments(readText(file), true).split(QLatin1Char('\n')))
                if (!line.trimmed().isEmpty())
                    lines << line.trimmed().toUpper();
            if (lines.value(0) == QStringLiteral("USE MASTER;"))
                continue;
            const QStringList header = lines.mid(0, 4);
            if (header.value(0) != QStringLiteral("USE QLTTTA;") || header.value(1) != QStringLiteral("GO") ||
                !header.contains(QStringLiteral("SET ANSI_NULLS ON;")) ||
                !header.contains(QStringLiteral("SET QUOTED_IDENTIFIER ON;")))
                problems << file +
                                QStringLiteral(": must start with USE QLTTTA; GO; SET ANSI_NULLS ON; "
                                               "SET QUOTED_IDENTIFIER ON; (or USE master; for a server-level "
                                               "script)");
        }
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // Dependency direction presentation -> application -> domain <- infrastructure; app wires everything
    void sourceFiles_layers_includeOnlyAllowedLayers() {
        const QHash<QString, QStringList> allowed = {
            {QStringLiteral("domain"), {QStringLiteral("domain")}},
            {QStringLiteral("application"), {QStringLiteral("application"), QStringLiteral("domain")}},
            {QStringLiteral("infrastructure"),
             {QStringLiteral("infrastructure"), QStringLiteral("application"), QStringLiteral("domain")}},
            {QStringLiteral("presentation"),
             {QStringLiteral("presentation"), QStringLiteral("application"), QStringLiteral("domain")}},
        };
        const QRegularExpression include(QStringLiteral("^\\s*#\\s*include\\s+\"(\\w+)/"),
                                         QRegularExpression::MultilineOption);
        QStringList problems;
        for (auto layer = allowed.cbegin(); layer != allowed.cend(); ++layer) {
            for (const QString& file : filesIn(QStringLiteral("src/") + layer.key(),
                                               {QStringLiteral("*.h"), QStringLiteral("*.cpp")})) {
                const QString code = withoutComments(readText(file), false);
                for (auto it = include.globalMatch(code); it.hasNext();) {
                    const auto m = it.next();
                    if (!layer.value().contains(m.captured(1)))
                        problems << QStringLiteral("%1:%2: the %3 layer must not include %4/")
                                        .arg(file)
                                        .arg(lineOf(code, m.capturedStart()))
                                        .arg(layer.key(), m.captured(1));
                }
            }
        }
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // domain and application only know Qt Core (no database driver, no widgets)
    void innerLayers_qtModules_onlyQtCore() {
        const QRegularExpression forbidden(
            QStringLiteral(
                "^\\s*#\\s*include\\s+<(Qt(Sql|Widgets|Gui|Network)\\b[^>]*|QSql\\w*|QWidget|"
                "QApplication|QGuiApplication|QMainWindow|QDialog\\w*|QLabel|QPushButton|QLineEdit|"
                "QMessageBox|QTableView|QComboBox|QPainter|QPixmap|QIcon|QColor|QFont|QImage)>"),
            QRegularExpression::MultilineOption);
        QStringList problems;
        for (const QString& layer : {QStringLiteral("domain"), QStringLiteral("application")})
            for (const QString& file :
                 filesIn(QStringLiteral("src/") + layer, {QStringLiteral("*.h"), QStringLiteral("*.cpp")}))
                problems << findAll(file, withoutComments(readText(file), false), forbidden,
                                    QStringLiteral("only Qt Core is allowed in the ") + layer +
                                        QStringLiteral(" layer"));
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // SQL lives only in src/infrastructure: no SQL text (dbo. objects) in a string literal elsewhere
    void sqlText_outsideInfrastructure_notPresent() {
        const QRegularExpression sqlLiteral(QStringLiteral("\"[^\"\\n]*\\bdbo\\.[^\"\\n]*\""));
        QStringList problems;
        for (const QString& dir : {QStringLiteral("src"), QStringLiteral("tools")})
            for (const QString& file : filesIn(dir, {QStringLiteral("*.h"), QStringLiteral("*.cpp")}))
                if (!file.startsWith(QStringLiteral("src/infrastructure/")))
                    problems << findAll(file, withoutComments(readText(file), false), sqlLiteral,
                                        QStringLiteral("SQL belongs in src/infrastructure/repositories"));
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // Statements with values go through SqlHelpers::execPrepared (keeps text Unicode with FreeTDS)
    void queries_parameters_goThroughExecPrepared() {
        const QRegularExpression direct(
            QStringLiteral("\\.prepare\\s*\\(|\\b(addBindValue|bindValue)\\s*\\("));
        QStringList problems;
        for (const QString& dir : {QStringLiteral("src"), QStringLiteral("tools")})
            for (const QString& file : filesIn(dir, {QStringLiteral("*.h"), QStringLiteral("*.cpp")}))
                if (file != QStringLiteral("src/infrastructure/db/SqlHelpers.cpp"))
                    problems << findAll(
                        file, withoutComments(readText(file), false), direct,
                        QStringLiteral("use SqlHelpers::execPrepared(q, m_db, sql, {values})"));
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // 04-scripts-ci.md: .sh = bash + set -euo pipefail; .ps1 = UTF-8 with BOM, CRLF, stop on errors
    void scripts_shellAndPowerShell_followFormat() {
        QStringList problems;
        for (const QString& file : filesIn(QStringLiteral("scripts"), {QStringLiteral("*.sh")}, false)) {
            const QString text = readText(file);
            if (!text.startsWith(QStringLiteral("#!/usr/bin/env bash\n")))
                problems << file + QStringLiteral(": first line must be #!/usr/bin/env bash");
            if (!text.contains(QStringLiteral("\nset -euo pipefail\n")))
                problems << file + QStringLiteral(": missing set -euo pipefail");
        }
        for (const QString& file : filesIn(QStringLiteral("scripts"), {QStringLiteral("*.ps1")}, false)) {
            const QByteArray bytes = readBytes(file);
            if (!bytes.startsWith("\xEF\xBB\xBF"))
                problems << file + QStringLiteral(": must be saved as UTF-8 with BOM");
            if (bytes.count('\n') != bytes.count("\r\n"))
                problems << file + QStringLiteral(": must use CRLF line endings");
            if (!bytes.contains("$ErrorActionPreference = \"Stop\""))
                problems << file + QStringLiteral(": missing $ErrorActionPreference = \"Stop\"");
        }
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // 04-scripts-ci.md: every script has a .sh and a .ps1 version (packaging is platform-specific)
    void scripts_everyScript_hasBothVersions() {
        const QSet<QString> platformSpecific = {QStringLiteral("package-macos.sh"),
                                                QStringLiteral("package-windows.ps1")};
        QStringList problems;
        for (const QString& file :
             filesIn(QStringLiteral("scripts"), {QStringLiteral("*.sh"), QStringLiteral("*.ps1")}, false)) {
            const QFileInfo info(file);
            if (platformSpecific.contains(info.fileName()))
                continue;
            const QString twin =
                info.completeBaseName() +
                (info.suffix() == QStringLiteral("sh") ? QStringLiteral(".ps1") : QStringLiteral(".sh"));
            if (!QFile::exists(kRoot + QStringLiteral("/scripts/") + twin))
                problems << file + QStringLiteral(": scripts/") + twin + QStringLiteral(" is missing");
        }
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // 06-docs.md: the numbers the docs quote are the real ones (update the docs with the scripts)
    void docs_databaseNumbers_matchScripts() {
        const QString functions = sqlCode(QStringLiteral("02_functions.sql"));
        const QString tables = sqlCode(QStringLiteral("01_tables.sql"));
        const int dbTests = expectedCases(QStringLiteral("12_tests.sql"));
        const int serverTests = expectedCases(QStringLiteral("13_server_tests.sql"));
        const QString database = QStringLiteral("docs/DATABASE.md");
        const QString setup = QStringLiteral("docs/SETUP.md");
        const QString constraints = QStringLiteral("(\\d+) PK, (\\d+) FK, (\\d+) CHECK, (\\d+) UNIQUE \\+ "
                                                   "(\\d+) filtered unique indexes, (\\d+) DEFAULT, "
                                                   "(\\d+) SEQUENCE");
        const QString functionKinds =
            QStringLiteral("(\\d+) scalar, (\\d+) inline table-valued, (\\d+) multi-statement table-valued");
        struct Check {
            QString doc;
            QString pattern;
            int group;
            int actual;
        };
        const QList<Check> checks = {
            {database, QStringLiteral("(\\d+) procedures"), 1,
             countOf(sqlCode(QStringLiteral("04_procedures.sql")),
                     QStringLiteral("^\\s*CREATE\\s+PROC(EDURE)?\\s"))},
            {database, QStringLiteral("(\\d+) triggers"), 1,
             countOf(sqlCode(QStringLiteral("05_triggers.sql")),
                     QStringLiteral("^\\s*CREATE\\s+TRIGGER\\s"))},
            {database, QStringLiteral("(\\d+) views"), 1,
             countOf(sqlCode(QStringLiteral("03_views.sql")), QStringLiteral("^\\s*CREATE\\s+VIEW\\s"))},
            {database, functionKinds, 1,
             countOf(functions, QStringLiteral("^\\s*CREATE\\s+FUNCTION\\s")) -
                 countOf(functions, QStringLiteral("\\bRETURNS\\s+(@\\w+\\s+)?TABLE\\b"))},
            {database, functionKinds, 2, countOf(functions, QStringLiteral("\\bRETURNS\\s+TABLE\\b"))},
            {database, functionKinds, 3,
             countOf(functions, QStringLiteral("\\bRETURNS\\s+@\\w+\\s+TABLE\\b"))},
            {database, constraints, 1, countOf(tables, QStringLiteral("\\bCONSTRAINT\\s+PK_"))},
            {database, constraints, 2, countOf(tables, QStringLiteral("\\bCONSTRAINT\\s+FK_"))},
            {database, constraints, 3, countOf(tables, QStringLiteral("\\bCONSTRAINT\\s+CK_"))},
            {database, constraints, 4, countOf(tables, QStringLiteral("\\bCONSTRAINT\\s+UQ_"))},
            {database, constraints, 5,
             countOf(tables, QStringLiteral("\\bCREATE\\s+UNIQUE\\s+(NONCLUSTERED\\s+)?INDEX\\s+UX_"))},
            {database, constraints, 6, countOf(tables, QStringLiteral("\\bCONSTRAINT\\s+DF_"))},
            {database, constraints, 7, countOf(tables, QStringLiteral("^\\s*CREATE\\s+SEQUENCE\\s"))},
            {database, QStringLiteral("\\| Automated database tests \\| (\\d+) cases"), 1, dbTests},
            {database, QStringLiteral("\\| Automated server-level tests \\| (\\d+) cases"), 1, serverTests},
            {setup, QStringLiteral("`database/12_tests.sql` \\((\\d+) cases"), 1, dbTests},
            {setup, QStringLiteral("\\((\\d+) server-level cases"), 1, serverTests},
            {setup, QStringLiteral("ALL TESTS PASSED: database (\\d+)/(\\d+) cases"), 1,
             dbTests + serverTests},
            {setup, QStringLiteral("ALL TESTS PASSED: database (\\d+)/(\\d+) cases"), 2,
             dbTests + serverTests},
        };
        QStringList problems;
        for (const Check& c : checks) {
            const int written = numberIn(c.doc, c.pattern, c.group);
            if (written != c.actual)
                problems << QStringLiteral("%1: \"%2\" (group %3) says %4, the scripts have %5%6")
                                .arg(c.doc, c.pattern)
                                .arg(c.group)
                                .arg(written)
                                .arg(c.actual)
                                .arg(written < 0 ? QStringLiteral(" - phrase not found, update the doc or "
                                                                  "this test")
                                                 : QString());
        }
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }
};

QTEST_APPLESS_MAIN(TestConventions)
#include "tst_conventions.moc"
