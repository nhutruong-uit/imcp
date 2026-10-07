#include "presentation/common/ReportDocument.h"

#include <QCoreApplication>
#include <QFile>
#include <QPdfWriter>
#include <QTextDocument>

namespace {
// Provides tr() with translation context "ReportDocument"
struct ReportText {
    Q_DECLARE_TR_FUNCTIONS(ReportDocument)
};
} // namespace

void ReportDocument::print(QPagedPaintDevice* device) const {
    QTextDocument document;
    document.setHtml(html);
    document.print(device);
}

bool ReportDocument::writePdf(const QString& filePath, QString* error) const {
    // Open the file first: QPdfWriter would silently write nothing to a read-only or locked file
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error)
            *error = file.errorString();
        return false;
    }
    QPdfWriter writer(&file);
    if (!writer.setPageLayout(pageLayout)) {
        if (error)
            *error = ReportText::tr("Cannot set up the page size.");
        return false;
    }
    writer.setTitle(title);
    writer.setCreator(QStringLiteral("QLTTTA"));
    print(&writer);
    if (file.error() != QFileDevice::NoError) {
        if (error)
            *error = file.errorString();
        return false;
    }
    return true;
}
