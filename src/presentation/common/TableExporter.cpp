#include "presentation/common/TableExporter.h"

#include "presentation/common/Columns.h"
#include "presentation/common/Format.h"
#include "presentation/common/Theme.h"

#include <QAbstractItemModel>
#include <QCoreApplication>
#include <QDateTime>
#include <QHash>
#include <QPageLayout>
#include <QPageSize>
#include <QRegularExpression>
#include <QSaveFile>
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

namespace {
// One row of totals (a Group Footer or the Report Footer): the label in the first column unless that column
// is summed itself, the sums under their money columns
QString totalsRow(const QString& label, const QVector<double>& sums, const QVector<bool>& summable,
                  const QString& cssClass) {
    QString html = QStringLiteral("<tr><td></td>");
    for (int c = 0; c < sums.size(); ++c) {
        if (summable[c])
            html += QStringLiteral("<td class='r %1'>%2</td>").arg(cssClass, Format::money(qint64(sums[c])));
        else if (c == 0)
            html += QStringLiteral("<td class='%1'>%2</td>").arg(cssClass, label.toHtmlEscaped());
        else
            html += QStringLiteral("<td></td>");
    }
    return html + QStringLiteral("</tr>");
}

// The rows of each group, groups in the order their value first appears in the list (sort the list on screen
// by that column to order them). The value compared is the raw one (Qt::UserRole of TableDataModel), or the
// displayed text for a model without raw values. No group column: one group with every row.
QList<QList<int>> groupRows(const QAbstractItemModel& model, int groupColumn) {
    QList<QList<int>> groups;
    QHash<QString, int> groupOfValue;
    for (int r = 0; r < model.rowCount(); ++r) {
        QString value;
        if (groupColumn >= 0) {
            const QModelIndex idx = model.index(r, groupColumn);
            const QVariant raw = idx.data(Qt::UserRole);
            value = raw.isValid() ? raw.toString() : idx.data(Qt::DisplayRole).toString();
        }
        const auto it = groupOfValue.constFind(value);
        if (it == groupOfValue.constEnd()) {
            groupOfValue.insert(value, int(groups.size()));
            groups.append({r});
        } else {
            groups[*it].append(r);
        }
    }
    return groups;
}

QString rowCount(int count) {
    return count == 1 ? ExporterText::tr("1 row") : ExporterText::tr("%1 rows").arg(count);
}
} // namespace

ReportDocument TableExporter::report(const QAbstractItemModel& model, const QString& title,
                                     const QString& preparedBy, int groupColumn) {
    const int columnCount = model.columnCount();
    if (groupColumn >= columnCount)
        groupColumn = -1;
    // Report Header
    QString html =
        QStringLiteral(
            "<html><head><style>"
            "body{font-family:'Segoe UI','Helvetica Neue',Arial;font-size:9pt;color:%1;}"
            "h1{color:%2;font-size:16pt;margin:0;} .sub{color:%3;margin-bottom:8px;}"
            "table{border-collapse:collapse;width:100%;} th{background:%2;color:white;padding:4px;}"
            "td{border-bottom:1px solid %4;padding:3px;} .r{text-align:right;} .total{font-weight:bold;}"
            ".group{background-color:%4;color:%2;font-weight:bold;padding-top:6px;}"
            ".subtotal{font-weight:bold;font-style:italic;}"
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
    const QString groupTitle =
        groupColumn >= 0 ? model.headerData(groupColumn, Qt::Horizontal).toString() : QString();
    if (groupColumn >= 0)
        html += QStringLiteral("<div class='sub'>%1</div>")
                    .arg(ExporterText::tr("Grouped by: %1").arg(groupTitle).toHtmlEscaped());

    // Page Header: <thead> is repeated at the top of every page
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
    const bool hasTotals = std::find(summable.begin(), summable.end(), true) != summable.end();

    // Details, group by group (one group of every row when the report is not grouped)
    int number = 0;
    for (const QList<int>& rows : groupRows(model, groupColumn)) {
        QVector<double> subtotals(columnCount, 0.0);
        if (groupColumn >= 0) { // Group Header
            QString value = model.index(rows.first(), groupColumn).data(Qt::DisplayRole).toString();
            if (value.isEmpty())
                value = ExporterText::tr("(empty)");
            html += QStringLiteral("<tr><td class='group' colspan='%1'>%2</td></tr>")
                        .arg(columnCount + 1)
                        .arg(QStringLiteral("%1: %2 (%3)")
                                 .arg(groupTitle, value, rowCount(rows.size()))
                                 .toHtmlEscaped());
        }
        for (int r : rows) {
            html += QStringLiteral("<tr><td class='r'>%1</td>").arg(++number);
            for (int c = 0; c < columnCount; ++c) {
                const QModelIndex idx = model.index(r, c);
                const bool alignRight = (idx.data(Qt::TextAlignmentRole).toInt() & Qt::AlignRight) != 0;
                html += QStringLiteral("<td%1>%2</td>")
                            .arg(alignRight ? QStringLiteral(" class='r'") : QString(),
                                 idx.data(Qt::DisplayRole).toString().toHtmlEscaped());
                if (summable[c]) {
                    subtotals[c] += idx.data(Qt::UserRole).toDouble();
                    totals[c] += idx.data(Qt::UserRole).toDouble();
                }
            }
            html += QStringLiteral("</tr>");
        }
        if (groupColumn >= 0 && hasTotals) // Group Footer: subtotals of the money columns
            html += totalsRow(ExporterText::tr("Subtotal"), subtotals, summable, QStringLiteral("subtotal"));
    }
    // Report Footer: totals row for the money columns
    if (hasTotals)
        html += totalsRow(ExporterText::tr("GRAND TOTAL"), totals, summable, QStringLiteral("total"));
    html += QStringLiteral("</tbody></table><p class='sub'>%1</p></body></html>")
                .arg(ExporterText::tr("Total rows: %1").arg(model.rowCount()).toHtmlEscaped());

    ReportDocument document;
    document.title = title;
    document.html = html;
    document.pageLayout = QPageLayout(QPageSize(QPageSize::A4),
                                      columnCount > 7 ? QPageLayout::Landscape : QPageLayout::Portrait,
                                      QMarginsF(12, 12, 12, 12), QPageLayout::Millimeter);
    return document;
}

bool TableExporter::exportPdf(const QAbstractItemModel& model, const QString& title,
                              const QString& preparedBy, const QString& filePath, QString* error) {
    return report(model, title, preparedBy).writePdf(filePath, error);
}
