// Unit tests of TableExporter (presentation layer): the CSV and PDF files written from a table model, the
// grouped report, its print preview (ReportPreviewDialog), and the model DataTable gives the exports. A
// QStandardItemModel stands in for the lists of the application; no database is needed.
// Run only this suite:
//   ctest --preset macos-debug -R tst_exporter --output-on-failure
#include "presentation/common/DataTable.h"
#include "presentation/common/Format.h"
#include "presentation/common/ReportPreviewDialog.h"
#include "presentation/common/TableExporter.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
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

    // Balances of three enrollments in two branches; Q1 comes first and twice (100 + 200), Q3 once (50)
    static TableData balancesByBranch() {
        TableData data;
        data.columns = {QStringLiteral("BranchName"), QStringLiteral("TotalBalance")};
        data.rows = {{QStringLiteral("Q1"), 100000.0},
                     {QStringLiteral("Q3"), 50000.0},
                     {QStringLiteral("Q1"), 200000.0}};
        return data;
    }

private slots:
    // A hidden technical column (PayrollId) is not exported, and the quick filter does not search it: typing
    // 12 must not keep a row only because its hidden ID is 12
    void dataTable_hiddenColumns_notExportedNorFiltered() {
        DataTable table(QStringLiteral("listTable"));
        TableData data;
        data.columns = {QStringLiteral("PayrollId"), QStringLiteral("TeacherName")};
        data.rows = {{12, QStringLiteral("Lan")}, {7, QStringLiteral("Room 12")}};
        table.setData(data);
        table.setHiddenColumns({QStringLiteral("PayrollId")});
        QCOMPARE(table.visibleModel().columnCount(), 1);
        table.setFilterText(QStringLiteral("12"));
        QCOMPARE(table.rowCount(), 1);
        QCOMPARE(table.valueAt(0, QStringLiteral("TeacherName")).toString(), QStringLiteral("Room 12"));
        QCOMPARE(table.visibleModel().rowCount(), 1);
    }

    // The suggested export name comes from a title: a "/" would point into a folder that does not exist
    void fileName_titleWithSlash_becomesOneName() {
        QCOMPARE(UiHelpers::fileName(QStringLiteral("Payroll of 9/2026")),
                 QStringLiteral("Payroll of 9-2026"));
        QCOMPARE(UiHelpers::fileName(QStringLiteral("Class CL0003: A\\B? \"x\" <y>|*")),
                 QStringLiteral("Class CL0003- A-B- -x- -y---"));
        QCOMPARE(UiHelpers::fileName(QStringLiteral("Lớp Kiểm Thử")), QStringLiteral("Lớp Kiểm Thử"));
    }

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

    // A money amount is written as the plain number, not "1.500.000 ₫", so a spreadsheet can sum it; a
    // weekday stays the day name the user sees and a text stays a text
    void exportCsv_numberColumns_writePlainNumbers() {
        DataTable table(QStringLiteral("listTable"));
        TableData data;
        data.columns = {QStringLiteral("TotalBalance"), QStringLiteral("Weekday"), QStringLiteral("Hours"),
                        QStringLiteral("TeacherName")};
        data.rows = {{1500000.0, 2, 7.5, QStringLiteral("Lan")}};
        table.setData(data);
        QCOMPARE(table.totalsText().left(5), QStringLiteral("1 row"));
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("list.csv"));
        QString error;
        QVERIFY2(TableExporter::exportCsv(table.visibleModel(), path, &error), qPrintable(error));
        QFile f(path);
        QVERIFY(f.open(QIODevice::ReadOnly));
        const QStringList lines = QString::fromUtf8(f.readAll()).split(QStringLiteral("\r\n"));
        QCOMPARE(lines.value(1), QStringLiteral("1500000,%1,7.5,Lan").arg(Format::weekday(2)));
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

    // Grouped report (Crystal Report "Group"): one Group Header per branch in the order of the list, the rows
    // of a branch together, a Subtotal per branch and the grand total of every row
    void report_groupColumn_addsGroupHeadersAndSubtotals() {
        DataTable table(QStringLiteral("listTable"));
        table.setData(balancesByBranch());
        const QString html = TableExporter::report(table.visibleModel(), QStringLiteral("Balances"),
                                                   QStringLiteral("Tester"), 0)
                                 .html;
        const QString branch = table.visibleModel().headerData(0, Qt::Horizontal).toString();
        const qsizetype q1 = html.indexOf(QStringLiteral("%1: Q1 (2 rows)").arg(branch));
        const qsizetype q3 = html.indexOf(QStringLiteral("%1: Q3 (1 row)").arg(branch));
        QVERIFY2(q1 > 0 && q3 > q1, qPrintable(html));
        QCOMPARE(html.count(QStringLiteral("Subtotal")), 2);
        QVERIFY(html.indexOf(Format::money(300000)) > q1 && html.indexOf(Format::money(300000)) < q3);
        QVERIFY(html.indexOf(Format::money(50000), q3) > q3);
        QVERIFY(html.contains(Format::money(350000)));
        QVERIFY(html.contains(QStringLiteral("Grouped by: %1").arg(branch)));
    }

    // Without a group column the report keeps one list and one grand total, as the PDF export always did
    void report_noGroupColumn_hasNoGroupRows() {
        DataTable table(QStringLiteral("listTable"));
        table.setData(balancesByBranch());
        const QString html =
            TableExporter::report(table.visibleModel(), QStringLiteral("Balances"), QStringLiteral("Tester"))
                .html;
        QVERIFY(!html.contains(QStringLiteral("Subtotal")));
        QVERIFY(!html.contains(QStringLiteral("Grouped by")));
        QCOMPARE(html.count(QStringLiteral("GRAND TOTAL")), 1);
        QVERIFY(html.contains(Format::money(350000)));
    }

    // The print preview rebuilds the document when another "Group by" column is chosen, and shows its pages
    void reportPreview_groupByChoice_rebuildsTheDocument() {
        DataTable table(QStringLiteral("listTable"));
        table.setData(balancesByBranch());
        const QAbstractItemModel& model = table.visibleModel();
        ReportPreviewDialog dialog(
            [&](int groupColumn) {
                return TableExporter::report(model, QStringLiteral("Balances"), QStringLiteral("Tester"),
                                             groupColumn);
            },
            {model.headerData(0, Qt::Horizontal).toString(), model.headerData(1, Qt::Horizontal).toString()});
        QVERIFY(!dialog.document().html.contains(QStringLiteral("Subtotal")));
        QVERIFY(dialog.pageCount() >= 1);
        auto* groupBy = dialog.findChild<QComboBox*>(QStringLiteral("groupByCombo"));
        QVERIFY(groupBy);
        QCOMPARE(groupBy->count(), 3); // "No groups" + the two columns
        groupBy->setCurrentIndex(1);
        QCOMPARE(dialog.document().html.count(QStringLiteral("Subtotal")), 2);
        QVERIFY(dialog.pageCount() >= 1);
    }

    // A receipt has nothing to group by: the preview hides the "Group by" choice
    void reportPreview_noGroupChoices_hidesGroupBy() {
        ReportDocument receipt;
        receipt.title = QStringLiteral("Receipt PT0001");
        receipt.html = QStringLiteral("<p>Receipt</p>");
        receipt.pageLayout = QPageLayout(QPageSize(QPageSize::A5), QPageLayout::Portrait, QMarginsF());
        ReportPreviewDialog dialog([receipt](int) { return receipt; }, {});
        auto* groupBy = dialog.findChild<QComboBox*>(QStringLiteral("groupByCombo"));
        QVERIFY(groupBy && groupBy->isHidden());
        QCOMPARE(dialog.pageCount(), 1);
        QCOMPARE(dialog.document().title, receipt.title);
    }
};

QTEST_MAIN(TestExporter)
#include "tst_exporter.moc"
