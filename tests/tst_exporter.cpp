// Unit tests of TableExporter (presentation layer): the CSV and PDF files written from a table model.
// A QStandardItemModel stands in for the lists of the application; no database is needed.
// Run only this suite:
//   ctest --preset macos-debug -R tst_exporter --output-on-failure
#include "presentation/common/TableExporter.h"

#include <QFile>
#include <QStandardItemModel>
#include <QTemporaryDir>
#include <QtTest>

class TestExporter : public QObject {
    Q_OBJECT

private:
    // One column, one row per text
    static void fill(QStandardItemModel& model, const QStringList& texts) {
        model.setColumnCount(1);
        model.setHorizontalHeaderLabels({QStringLiteral("Name")});
        for (const QString& t : texts)
            model.appendRow(new QStandardItem(t));
    }

private slots:
    // A cell that starts with = + @ would run as a formula in Excel: it is kept as text with a leading
    // apostrophe; a negative number stays a number and a comma is quoted
    void exportCsv_formulaCells_areWrittenAsText() {
        QStandardItemModel model;
        fill(model, {QStringLiteral("=HYPERLINK(\"x\")"), QStringLiteral("@SUM(A1)"), QStringLiteral("-500"),
                     QStringLiteral("Nguyễn, An")});
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("list.csv"));
        QString error;
        QVERIFY2(TableExporter::exportCsv(model, path, &error), qPrintable(error));
        QFile f(path);
        QVERIFY(f.open(QIODevice::ReadOnly));
        const QString text = QString::fromUtf8(f.readAll());
        QVERIFY(text.contains(QStringLiteral("\"'=HYPERLINK(\"\"x\"\")\"\r\n")));
        QVERIFY(text.contains(QStringLiteral("\r\n'@SUM(A1)\r\n")));
        QVERIFY(text.contains(QStringLiteral("\r\n-500\r\n")));
        QVERIFY(text.contains(QStringLiteral("\"Nguyễn, An\"")));
    }

    // A file that cannot be written is reported as an error (the old version answered "done" without a file)
    void export_unwritablePath_fails() {
        QStandardItemModel model;
        fill(model, {QStringLiteral("An")});
        QTemporaryDir dir;
        const QString missingFolder = dir.filePath(QStringLiteral("missing/list"));
        QString error;
        QVERIFY(!TableExporter::exportCsv(model, missingFolder + QStringLiteral(".csv"), &error));
        QVERIFY(!error.isEmpty());
        error.clear();
        QVERIFY(!TableExporter::exportPdf(model, QStringLiteral("List"), QStringLiteral("Tester"),
                                          missingFolder + QStringLiteral(".pdf"), &error));
        QVERIFY(!error.isEmpty());
    }

    // The PDF report is written to the file
    void exportPdf_validPath_writesAPdf() {
        QStandardItemModel model;
        fill(model, {QStringLiteral("An"), QStringLiteral("Bình")});
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("list.pdf"));
        QString error;
        QVERIFY2(
            TableExporter::exportPdf(model, QStringLiteral("List"), QStringLiteral("Tester"), path, &error),
            qPrintable(error));
        QFile f(path);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QVERIFY(f.read(5) == "%PDF-");
    }
};

QTEST_MAIN(TestExporter)
#include "tst_exporter.moc"
