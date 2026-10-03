#pragma once

#include "domain/entities/Receipt.h"

#include <QString>

// The printed receipt (PDF, A5): branch header, receipt number and time, student, class and course, the
// amount and method, the tuition due / paid / balance after the payment, who collected it. The data is the
// row of usp_Receipt_Print; the layout is HTML rendered by QTextDocument (the same technique as
// TableExporter).
namespace ReceiptPrinter {
QString html(const ReceiptPrint& receipt); // used by the PDF and by the tests
bool exportPdf(const ReceiptPrint& receipt, const QString& filePath, QString* error = nullptr);
} // namespace ReceiptPrinter
