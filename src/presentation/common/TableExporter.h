#pragma once

#include "presentation/common/ReportDocument.h"

#include <QString>

class QAbstractItemModel;

// Exports the data shown in a table to a file:
// - CSV (UTF-8 with BOM, opens directly in Excel without garbling Vietnamese text)
// - PDF report: report title, author, detail table (optionally in groups with subtotals), totals row, page
// numbers
namespace TableExporter {
bool exportCsv(const QAbstractItemModel& model, const QString& filePath, QString* error = nullptr);
// The report of a list, laid out like a Crystal Report: Report Header (center, title, date, author) -> Page
// Header (column titles, repeated on every page) -> Details, optionally in groups of groupColumn (Group
// Header: the value and its row count; Group Footer: the subtotals of the money columns) -> Report Footer
// (grand totals, row count) -> Page Footer (page numbers, printed by QTextDocument). groupColumn = -1: no
// groups. The same document is previewed, printed (ReportPreviewDialog) or written to a PDF file.
ReportDocument report(const QAbstractItemModel& model, const QString& title, const QString& preparedBy,
                      int groupColumn = -1);
bool exportPdf(const QAbstractItemModel& model, const QString& title, const QString& preparedBy,
               const QString& filePath, QString* error = nullptr);
} // namespace TableExporter
