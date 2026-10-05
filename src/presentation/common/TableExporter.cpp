#include "presentation/common/TableExporter.h"

#include "presentation/common/Columns.h"
#include "presentation/common/Format.h"
#include "presentation/common/Theme.h"

#include <QAbstractItemModel>
#include <QCoreApplication>
#include <QDateTime>
#include <QFile>
#include <QPageLayout>
#include <QPageSize>
#include <QPdfWriter>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTextDocument>
#include <algorithm>
#include <cmath>

namespace {
// Provides tr() with translation context "TableExporter" for the free functions of namespace TableExporter
struct ExporterText {
    Q_DECLARE_TR_FUNCTIONS(TableExporter)
};

QString csvField(QString s) {
    // Excel runs a cell that starts with = + - @ (or a tab / carriage return) as a formula: a leading
    // apostrophe keeps such a cell text (CSV injection). A negative number such as -500 stays a number.
    static const QRegularExpression negativeNumber(QStringLiteral("^-[0-9]"));
    if (!s.isEmpty() && (QStringLiteral("=+@\t\r").contains(s.front()) ||
                         (s.front() == QLatin1Char('-') && !negativeNumber.match(s).hasMatch())))
        s.prepend(QLatin1Char('\''));
    if (s.contains(QLatin1Char(',')) || s.contains(QLatin1Char('"')) || s.contains(QLatin1Char('\n')) ||
        s.contains(QLatin1Char('\r'))) {
        s.replace(QLatin1String("\""), QLatin1String("\"\""));
        return QLatin1Char('"') + s + QLatin1Char('"');
    }
    return s;
}

// A number is written as the plain number ("1500000", "7.5"), not its display text ("1.500.000 ₫"), so a
// spreadsheet can sum it whatever the UI language; codes shown as words (weekday, yes/no) and every other
// value keep the text the user sees. The raw value is Qt::UserRole of TableDataModel.
QString csvCell(const QAbstractItemModel& model, int row, int column) {
    const QModelIndex idx = model.index(row, column);
    const QVariant raw = idx.data(Qt::UserRole);
    const QString key = model.headerData(column, Qt::Horizontal, Columns::KeyRole).toString();
    if (!Columns::isWeekday(key) && !Columns::isYesNo(key)) {
        switch (raw.metaType().id()) {
        case QMetaType::Double:
        case QMetaType::Float:
            return Columns::isMoney(key) ? QString::number(std::llround(raw.toDouble()))
                                         : QString::number(raw.toDouble(), 'g', 15);
        case QMetaType::Int:
        case QMetaType::LongLong:
        case QMetaType::UInt:
        case QMetaType::ULongLong:
            return raw.toString();
        default:
            break;
        }
    }
    return idx.data(Qt::DisplayRole).toString();
}
} // namespace

bool TableExporter::exportCsv(const QAbstractItemModel& model, const QString& filePath, QString* error) {
    // QSaveFile writes a temporary file and replaces the old one only when everything was written (commit)
    QSaveFile f(filePath);
    if (!f.open(QIODevice::WriteOnly)) {
        if (error)
            *error = f.errorString();
        return false;
    }
    QByteArray out("\xEF\xBB\xBF"); // UTF-8 BOM for Excel
    QStringList fields;
    for (int c = 0; c < model.columnCount(); ++c)
        fields << csvField(model.headerData(c, Qt::Horizontal).toString());
    out += fields.join(QLatin1Char(',')).toUtf8() + "\r\n";
    for (int r = 0; r < model.rowCount(); ++r) {
        fields.clear();
        for (int c = 0; c < model.columnCount(); ++c)
            fields << csvField(csvCell(model, r, c));
        out += fields.join(QLatin1Char(',')).toUtf8() + "\r\n";
    }
    if (f.write(out) != out.size() || !f.commit()) {
        if (error)
            *error = f.errorString();
        return false;
    }
    return true;
}

bool TableExporter::exportPdf(const QAbstractItemModel& model, const QString& title,
                              const QString& preparedBy, const QString& filePath, QString* error) {
    // Layout like a Crystal Report: Report Header -> Page Header (column titles repeated on every page)
    // -> Details -> Report Footer (totals); QTextDocument prints the page numbers in the footer.
    QString html =
        QStringLiteral(
            "<html><head><style>"
            "body{font-family:'Segoe UI','Helvetica Neue',Arial;font-size:9pt;color:%1;}"
            "h1{color:%2;font-size:16pt;margin:0;} .sub{color:%3;margin-bottom:8px;}"
            "table{border-collapse:collapse;width:100%;} th{background:%2;color:white;padding:4px;}"
            "td{border-bottom:1px solid %4;padding:3px;} .r{text-align:right;} .total{font-weight:bold;}"
            "</style></head><body>")
            .arg(QLatin1String(Theme::kText), QLatin1String(Theme::kPrimary), QLatin1String(Theme::kMuted),
                 QLatin1String(Theme::kBorder));
    html += QStringLiteral("<div class='sub'>%1</div>")
                .arg(ExporterText::tr("ENGLISH CENTER — QLTTTA MANAGEMENT SYSTEM").toHtmlEscaped());
    html += QStringLiteral("<h1>%1</h1>").arg(title.toHtmlEscaped());
    const QString createdOn = QDateTime::currentDateTime().toString(QStringLiteral("dd/MM/yyyy HH:mm"));
    html += QStringLiteral("<div class='sub'>%1 &nbsp;|&nbsp; %2</div>")
                .arg(ExporterText::tr("Created on: %1").arg(createdOn).toHtmlEscaped(),
                     ExporterText::tr("Prepared by: %1").arg(preparedBy).toHtmlEscaped());

    const int columnCount = model.columnCount();
    QVector<double> totals(columnCount, 0.0);
    QVector<bool> summable(columnCount, false);
    html += QStringLiteral("<table><thead><tr><th>%1</th>").arg(ExporterText::tr("No.").toHtmlEscaped());
    for (int c = 0; c < columnCount; ++c) {
        // Columns to sum are recognized by their KEY (never by the translated title)
        summable[c] = Columns::isSummable(model.headerData(c, Qt::Horizontal, Columns::KeyRole).toString());
        html +=
            QStringLiteral("<th>%1</th>").arg(model.headerData(c, Qt::Horizontal).toString().toHtmlEscaped());
    }
    html += QStringLiteral("</tr></thead><tbody>");
    for (int r = 0; r < model.rowCount(); ++r) {
        html += QStringLiteral("<tr><td class='r'>%1</td>").arg(r + 1);
        for (int c = 0; c < columnCount; ++c) {
            const QModelIndex idx = model.index(r, c);
            const bool alignRight = (idx.data(Qt::TextAlignmentRole).toInt() & Qt::AlignRight) != 0;
            html += QStringLiteral("<td%1>%2</td>")
                        .arg(alignRight ? QStringLiteral(" class='r'") : QString(),
                             idx.data(Qt::DisplayRole).toString().toHtmlEscaped());
            if (summable[c])
                totals[c] += idx.data(Qt::UserRole).toDouble();
        }
        html += QStringLiteral("</tr>");
    }
    // Report Footer: totals row for the money columns
    if (std::find(summable.begin(), summable.end(), true) != summable.end()) {
        html += QStringLiteral("<tr class='total'><td></td>");
        for (int c = 0; c < columnCount; ++c) {
            if (summable[c])
                html += QStringLiteral("<td class='r total'>%1</td>").arg(Format::money(qint64(totals[c])));
            else if (c == 0)
                html += QStringLiteral("<td class='total'>%1</td>")
                            .arg(ExporterText::tr("GRAND TOTAL").toHtmlEscaped());
            else
                html += QStringLiteral("<td></td>");
        }
        html += QStringLiteral("</tr>");
    }
    html += QStringLiteral("</tbody></table><p class='sub'>%1</p></body></html>")
                .arg(ExporterText::tr("Total rows: %1").arg(model.rowCount()).toHtmlEscaped());

    // Open the file first: QPdfWriter would silently write nothing to a read-only or locked file
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error)
            *error = file.errorString();
        return false;
    }
    QPdfWriter writer(&file);
    if (!writer.setPageLayout(QPageLayout(QPageSize(QPageSize::A4),
                                          columnCount > 7 ? QPageLayout::Landscape : QPageLayout::Portrait,
                                          QMarginsF(12, 12, 12, 12), QPageLayout::Millimeter))) {
        if (error)
            *error = ExporterText::tr("Cannot set up the page size.");
        return false;
    }
    writer.setTitle(title);
    writer.setCreator(QStringLiteral("QLTTTA"));

    QTextDocument doc;
    doc.setHtml(html);
    doc.print(&writer);
    if (file.error() != QFileDevice::NoError) {
        if (error)
            *error = file.errorString();
        return false;
    }
    return true;
}
