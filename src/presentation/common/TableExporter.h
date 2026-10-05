#pragma once

#include <QString>

class QAbstractItemModel;

// Exports the data shown in a table to a file:
// - CSV (UTF-8 with BOM, opens directly in Excel without garbling Vietnamese text)
// - PDF report: report title, author, detail table, totals row, page numbers
namespace TableExporter {
bool exportCsv(const QAbstractItemModel& model, const QString& filePath, QString* error = nullptr);
bool exportPdf(const QAbstractItemModel& model, const QString& title, const QString& preparedBy,
               const QString& filePath, QString* error = nullptr);
} // namespace TableExporter
