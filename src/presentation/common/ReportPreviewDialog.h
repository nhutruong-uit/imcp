#pragma once

#include "presentation/common/ReportDocument.h"

#include <QDialog>
#include <QPrinter>
#include <QStringList>
#include <functional>

class QComboBox;
class QLabel;
class QPrintPreviewWidget;

// Print preview of a report, the role the Crystal Report Viewer plays in the course: the pages exactly as
// they will be printed, zoom, "Group by" for the report of a list, Print (the system print dialog) and Save
// as PDF. The caller's function rebuilds the document whenever the grouping changes, so the preview, the
// printout and the PDF are always the same document. Opened by UiHelpers::previewReport (lists) and
// TuitionPage (receipts).
class ReportPreviewDialog : public QDialog {
    Q_OBJECT
public:
    // build(groupColumn) returns the document grouped by that column (-1 = no groups)
    using Builder = std::function<ReportDocument(int groupColumn)>;
    // groupChoices: the titles of the columns the user may group by, in column order; empty = no "Group by"
    ReportPreviewDialog(Builder build, const QStringList& groupChoices, QWidget* parent = nullptr);

    const ReportDocument& document() const { return m_document; } // the document shown (tests)
    int pageCount() const;

private slots:
    void rebuild();
    void print();
    void savePdf();

private:
    Builder m_build;
    ReportDocument m_document;
    // The pages of the preview; the print dialog sets it up for the real printer
    QPrinter m_printer{QPrinter::HighResolution};
    QComboBox* m_groupBy = nullptr;
    QPrintPreviewWidget* m_preview = nullptr;
    QLabel* m_pages = nullptr;
};
