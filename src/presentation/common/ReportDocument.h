#pragma once

#include <QPageLayout>
#include <QString>

class QPagedPaintDevice;

// A printable report: HTML that QTextDocument lays out on pages of the given size. The same document is
// written to a PDF file (QPdfWriter), shown in the print preview and sent to a printer (QPrinter) - like one
// Crystal Report that can be previewed, printed or exported. Built by TableExporter::report (lists) and
// ReceiptPrinter::document (tuition receipt).
struct ReportDocument {
    QString title; // PDF title and print job name
    QString html;
    QPageLayout pageLayout;

    // Lays the document out on the pages of device (a QPdfWriter or a QPrinter), whose page layout the caller
    // has set: pageLayout, or what the user chose in the print dialog
    void print(QPagedPaintDevice* device) const;
    bool writePdf(const QString& filePath, QString* error = nullptr) const;
};
