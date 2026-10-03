// Repository conventions checked from the files themselves (no database, no build output): SQL Server 2012
// syntax and script headers, Clean Architecture include directions, SQL only in the infrastructure layer,
// script format, and the numbers the docs quote about the database. Every failure lists file:line.
// The rules are described in .claude/rules/ (01-sql.md, 02-cpp-qt.md, 04-scripts-ci.md, 06-docs.md).
// How it works: every test reads files of the repository as text, blanks out the comments (an example
// written in a comment must not count) and searches the rest with regular expressions. A new convention
// that can be read from the files gets a new slot here, with failure messages "file:line: what to do".
// Run only this suite:
//   ctest --preset macos-debug -R conventions --output-on-failure
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QtTest>

namespace {
// Repository root, compiled in by tests/CMakeLists.txt (target_compile_definitions QLTTTA_SOURCE_DIR)
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

// Test case codes registered in #Expected: ('T01', N'%pattern%') or ('T15', NULL) - two values only.
// The count is compared with the numbers of cases that docs/DATABASE.md and docs/SETUP.md quote.
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

// docs/data-map.html: the text of one JavaScript constant, from its start ("const TABLES = {") to its closing
// line ("\n};" or "\n];"); empty when it is missing
QString dataMapConstant(const QString& start, const QString& end) {
    const QString page = readText(QStringLiteral("docs/data-map.html"));
    const qsizetype from = page.indexOf(start);
    const qsizetype to = from < 0 ? -1 : page.indexOf(end, from);
    return to < 0 ? QString() : page.mid(from, to - from);
}
} // namespace

class TestConventions : public QObject {
    Q_OBJECT

private slots:
    // Runs once before the tests: stops early, printing the path, when kRoot is not the repository
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

    // 01-sql.md: instants are UTC (GETUTCDATE) and dates follow the center (dbo.fn_Today) - the scripts never
    // read the server's local clock, whose time zone depends on the machine (T32 checks the same in the
    // catalog)
    void sqlScripts_serverLocalClock_notUsed() {
        const QRegularExpression clock(
            QStringLiteral("\\b(GETDATE|SYSDATETIME)\\s*\\(|\\bCURRENT_TIMESTAMP\\b"),
            QRegularExpression::CaseInsensitiveOption);
        QStringList problems;
        for (const QString& file : filesIn(QStringLiteral("database"), {QStringLiteral("*.sql")}, false))
            problems << findAll(
                file, withoutComments(readText(file), true), clock,
                QStringLiteral("use GETUTCDATE() for an instant or dbo.fn_Today() for a date"));
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
        // One check = the doc, the regex holding the number, its capture group, the real count
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

    // 06-docs.md: docs/data-map.html (the interactive table map) keeps a copy of the schema in its constants
    // TABLES, FKS and TRIGGERS - the tables, columns, foreign keys and triggers must be the ones of the
    // scripts. Both sides become texts "TABLE", "TABLE.Column", "CHILD.Column -> PARENT.Column", "TABLE:
    // trg_..." that are compared as sets.
    void docs_dataMap_matchesScripts() {
        QSet<QString> scripts;
        const QRegularExpression table(
            QStringLiteral("\\bCREATE\\s+TABLE\\s+dbo\\.(\\w+)\\s*\\((.*?)\\n\\);"),
            QRegularExpression::DotMatchesEverythingOption);
        // A column line: a name followed by a data type or by AS (computed column); CONSTRAINT/DEFAULT lines
        // are not followed by a type
        const QRegularExpression column(
            QStringLiteral("^\\s+(\\w+)\\s+(?:AS\\b|(?:BIGINT|INT|SMALLINT|TINYINT|BIT|DECIMAL|NUMERIC|MONEY|"
                           "N?VARCHAR|N?CHAR|DATE|DATETIME2?|TIME|XML|FLOAT|UNIQUEIDENTIFIER|VARBINARY)\\b)"),
            QRegularExpression::MultilineOption);
        const QRegularExpression foreignKey(QStringLiteral(
            "\\bFOREIGN\\s+KEY\\s*\\((\\w+)\\)\\s*REFERENCES\\s+dbo\\.(\\w+)\\s*\\((\\w+)\\)"));
        for (auto t = table.globalMatch(sqlCode(QStringLiteral("01_tables.sql"))); t.hasNext();) {
            const auto m = t.next();
            const QString name = m.captured(1);
            scripts << name;
            for (auto c = column.globalMatch(m.captured(2)); c.hasNext();)
                scripts << name + QLatin1Char('.') + c.next().captured(1);
            for (auto f = foreignKey.globalMatch(m.captured(2)); f.hasNext();) {
                const auto k = f.next();
                scripts << QStringLiteral("%1.%2 -> %3.%4")
                               .arg(name, k.captured(1), k.captured(2), k.captured(3));
            }
        }
        const QRegularExpression trigger(
            QStringLiteral("\\bCREATE\\s+TRIGGER\\s+dbo\\.(\\w+)\\s+ON\\s+dbo\\.(\\w+)"));
        for (auto t = trigger.globalMatch(sqlCode(QStringLiteral("05_triggers.sql"))); t.hasNext();) {
            const auto m = t.next();
            scripts << m.captured(2) + QStringLiteral(": ") + m.captured(1);
        }

        QSet<QString> mapped;
        // TABLES: NAME: { g: '...', ..., cols: ['Column|TYPE|...', ...]
        const QRegularExpression pageTable(QStringLiteral("\\b([A-Z_]+): \\{ g: '\\w+',.*?cols: \\[(.*?)\\]"),
                                           QRegularExpression::DotMatchesEverythingOption);
        const QRegularExpression pageColumn(QStringLiteral("'(\\w+)\\|"));
        for (auto t = pageTable.globalMatch(
                 dataMapConstant(QStringLiteral("const TABLES = {"), QStringLiteral("\n};")));
             t.hasNext();) {
            const auto m = t.next();
            mapped << m.captured(1);
            for (auto c = pageColumn.globalMatch(m.captured(2)); c.hasNext();)
                mapped << m.captured(1) + QLatin1Char('.') + c.next().captured(1);
        }
        // FKS: ['CHILD', 'Column', 'PARENT', 'Column', ...]
        const QRegularExpression pageKey(QStringLiteral("\\['([A-Z_]+)', '(\\w+)', '([A-Z_]+)', '(\\w+)'"));
        for (auto f = pageKey.globalMatch(
                 dataMapConstant(QStringLiteral("const FKS = ["), QStringLiteral("\n];")));
             f.hasNext();) {
            const auto k = f.next();
            mapped << QStringLiteral("%1.%2 -> %3.%4")
                          .arg(k.captured(1), k.captured(2), k.captured(3), k.captured(4));
        }
        // TRIGGERS: TABLE: [['trg_...', '...'], ...] - a trigger belongs to the last table name read
        const QRegularExpression pageTrigger(QStringLiteral("\\b([A-Z_]+): \\[|\\['(trg_\\w+)'"));
        QString owner;
        for (auto t = pageTrigger.globalMatch(
                 dataMapConstant(QStringLiteral("const TRIGGERS = {"), QStringLiteral("\n};")));
             t.hasNext();) {
            const auto m = t.next();
            if (!m.captured(1).isEmpty())
                owner = m.captured(1);
            else
                mapped << owner + QStringLiteral(": ") + m.captured(2);
        }

        QStringList missing = (scripts - mapped).values(), extra = (mapped - scripts).values();
        missing.sort();
        extra.sort();
        QStringList problems;
        for (const QString& item : missing)
            problems << QStringLiteral(
                            "docs/data-map.html: %1 is in the scripts but not in the page - add it to "
                            "TABLES, FKS or TRIGGERS")
                            .arg(item);
        for (const QString& item : extra)
            problems << QStringLiteral(
                            "docs/data-map.html: %1 is in the page but not in the scripts - rename or "
                            "remove it")
                            .arg(item);
        QVERIFY2(!scripts.isEmpty(), "no CREATE TABLE found in database/01_tables.sql");
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // 06-docs.md: every database object that docs/data-map.html names in its explanations (procedures, views,
    // functions, triggers, sequences, the XML schema, constraints, indexes) exists in database/01-05, so
    // renaming or dropping one also updates the business flow and the app flow of the page. Wildcards
    // ("usp_Student_*") are not names.
    void docs_dataMapNames_existInScripts() {
        QSet<QString> defined;
        const QRegularExpression definition(
            QStringLiteral("\\b(?:PROCEDURE|VIEW|FUNCTION|TRIGGER|SEQUENCE|COLLECTION)\\s+dbo\\.(\\w+)|"
                           "\\bCONSTRAINT\\s+(\\w+)|\\bINDEX\\s+(\\w+)"),
            QRegularExpression::CaseInsensitiveOption);
        for (const QString& script : {QStringLiteral("01_tables.sql"), QStringLiteral("02_functions.sql"),
                                      QStringLiteral("03_views.sql"), QStringLiteral("04_procedures.sql"),
                                      QStringLiteral("05_triggers.sql")}) {
            for (auto it = definition.globalMatch(sqlCode(script)); it.hasNext();) {
                const auto m = it.next();
                for (int group = 1; group <= 3; ++group)
                    if (!m.captured(group).isEmpty())
                        defined << m.captured(group);
            }
        }
        const QString file = QStringLiteral("docs/data-map.html");
        const QString page = readText(file);
        const QRegularExpression name(QStringLiteral("\\b(?:usp|vw|fn|trg|seq|xsc|CK|UQ|UX|IX)_\\w+"));
        QStringList problems;
        for (auto it = name.globalMatch(page); it.hasNext();) {
            const auto m = it.next();
            if (!m.captured().endsWith(QLatin1Char('_')) && !defined.contains(m.captured()))
                problems << QStringLiteral(
                                "%1:%2: %3 is not created in database/01-05 - use its current name or "
                                "remove it")
                                .arg(file)
                                .arg(lineOf(page, m.capturedStart()))
                                .arg(m.captured());
        }
        QVERIFY2(!page.isEmpty() && !defined.isEmpty(),
                 "docs/data-map.html or the database scripts not found");
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }

    // 06-docs.md: the roles x screens table of docs/data-map.html (SCREENS) is the menu of
    // Permissions::allowedFeatures, with the screen names of Labels::feature (English source texts). Role
    // codes of the page: M = Manager, S = AcademicStaff, A = Accountant, T = Teacher.
    void docs_dataMapScreens_matchPermissions() {
        QHash<QString, QString> nameOf; // "Dashboard" -> "Overview"
        const QRegularExpression label(QStringLiteral(
            "case\\s+Feature::(\\w+)\\s*:\\s*return\\s*\\{\\s*f\\s*,\\s*LabelsText::tr\\(\"([^\"]+)\"\\)"));
        for (auto it = label.globalMatch(
                 withoutComments(readText(QStringLiteral("src/presentation/common/Labels.cpp")), false));
             it.hasNext();) {
            const auto m = it.next();
            nameOf.insert(m.captured(1), m.captured(2));
        }
        // "Role: Screen" for every menu entry of the application...
        QSet<QString> app;
        const QRegularExpression roleMenu(
            QStringLiteral("case\\s+Role::(\\w+)\\s*:\\s*return\\s*\\{([^}]*)\\}"));
        const QRegularExpression feature(QStringLiteral("Feature::(\\w+)"));
        for (auto r = roleMenu.globalMatch(withoutComments(
                 readText(QStringLiteral("src/application/services/Permissions.cpp")), false));
             r.hasNext();) {
            const auto m = r.next();
            for (auto f = feature.globalMatch(m.captured(2)); f.hasNext();) {
                const QString id = f.next().captured(1);
                app << QStringLiteral("%1: %2").arg(m.captured(1),
                                                    nameOf.value(id, QStringLiteral("Feature::") + id));
            }
        }
        // ...and of the page: { grp: '...', name: '...', roles: 'MSA', ... }
        const QHash<QChar, QString> roleOf = {{u'M', QStringLiteral("Manager")},
                                              {u'S', QStringLiteral("AcademicStaff")},
                                              {u'A', QStringLiteral("Accountant")},
                                              {u'T', QStringLiteral("Teacher")}};
        QSet<QString> mapped;
        const QRegularExpression screen(QStringLiteral("name: (['\"])(.*?)\\1, roles: '([A-Z]*)'"));
        for (auto it = screen.globalMatch(
                 dataMapConstant(QStringLiteral("const SCREENS = ["), QStringLiteral("\n];")));
             it.hasNext();) {
            const auto m = it.next();
            for (const QChar code : m.captured(3))
                mapped << QStringLiteral("%1: %2").arg(
                    roleOf.value(code, QStringLiteral("role code ") + code), m.captured(2));
        }

        QStringList missing = (app - mapped).values(), extra = (mapped - app).values();
        missing.sort();
        extra.sort();
        QStringList problems;
        for (const QString& item : missing)
            problems << QStringLiteral(
                            "docs/data-map.html: SCREENS lacks \"%1\" of Permissions::allowedFeatures - "
                            "add the screen or its role code")
                            .arg(item);
        for (const QString& item : extra)
            problems << QStringLiteral(
                            "docs/data-map.html: SCREENS has \"%1\", Permissions::allowedFeatures does "
                            "not - fix the name or the role codes")
                            .arg(item);
        QVERIFY2(!app.isEmpty(), "no menu found in src/application/services/Permissions.cpp");
        QVERIFY2(problems.isEmpty(), qPrintable(joined(problems)));
    }
};

// main() without a Qt application object: the tests only read files
QTEST_APPLESS_MAIN(TestConventions)
#include "tst_conventions.moc"
