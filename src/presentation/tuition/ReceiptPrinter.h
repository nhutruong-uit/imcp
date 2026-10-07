#pragma once

#include "domain/entities/Receipt.h"
#include "presentation/common/ReportDocument.h"

#include <QString>

// The printed receipt (PDF, A5): branch header, receipt number and time, student, class and course, the
// amount and method, the tuition due / paid / balance after the payment, who collected it. The data is the
// row of usp_Receipt_Print; the layout is HTML rendered by QTextDocument (the same technique as
// TableExporter). The document is previewed and printed (ReportPreviewDialog) or written to a PDF file.
namespace ReceiptPrinter {
QString html(const ReceiptPrint& receipt);            // used by the document and by the tests
ReportDocument document(const ReceiptPrint& receipt); // A5 portrait
} // namespace ReceiptPrinter
