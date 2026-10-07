#include "presentation/common/ReportPreviewDialog.h"

#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QPrintDialog>
#include <QPrintPreviewWidget>
#include <QPushButton>
#include <QVBoxLayout>

ReportPreviewDialog::ReportPreviewDialog(Builder build, const QStringList& groupChoices, QWidget* parent)
    : QDialog(parent), m_build(std::move(build)) {
    resize(960, 720);
    auto* v = new QVBoxLayout(this);
    v->setSpacing(10);

    auto* top = new QHBoxLayout;
    m_groupBy = new QComboBox(this);
    m_groupBy->setObjectName(QStringLiteral("groupByCombo"));
    m_groupBy->addItem(tr("No groups"), -1);
    for (int c = 0; c < groupChoices.size(); ++c)
        m_groupBy->addItem(groupChoices.at(c), c); // item data = column index, never the title
    if (!groupChoices.isEmpty()) {
        top->addWidget(new QLabel(tr("Group by"), this));
        top->addWidget(m_groupBy);
    } else {
        m_groupBy->hide();
    }
    top->addStretch(1);
    auto* zoomOut = UiHelpers::secondaryButton(QStringLiteral("−"), QString(), this);
    zoomOut->setToolTip(tr("Zoom out"));
    auto* zoomIn = UiHelpers::secondaryButton(QStringLiteral("+"), QString(), this);
    zoomIn->setToolTip(tr("Zoom in"));
    m_pages = new QLabel(this);
    m_pages->setObjectName(QStringLiteral("Muted"));
    m_pages->setProperty("testId", QStringLiteral("pageCount"));
    top->addWidget(zoomOut);
    top->addWidget(zoomIn);
    top->addWidget(m_pages);
    v->addLayout(top);

    m_preview = new QPrintPreviewWidget(&m_printer, this);
    m_preview->setObjectName(QStringLiteral("reportPreview"));
    m_preview->fitToWidth();
    v->addWidget(m_preview, 1);

    auto* buttons = new QHBoxLayout;
    auto* pdfButton = UiHelpers::secondaryButton(tr("Save as PDF"), QStringLiteral("file"), this);
    pdfButton->setObjectName(QStringLiteral("savePdfButton"));
    auto* printButton = UiHelpers::primaryButton(tr("Print..."), QStringLiteral("printer"), this);
    printButton->setObjectName(QStringLiteral("printReportButton"));
    auto* closeButton = UiHelpers::secondaryButton(tr("Close"), QString(), this);
    buttons->addWidget(pdfButton);
    buttons->addStretch(1);
    buttons->addWidget(closeButton);
    buttons->addWidget(printButton);
    v->addLayout(buttons);

    // The preview asks for its pages whenever it needs them (first show, zoom, rebuild)
    connect(m_preview, &QPrintPreviewWidget::paintRequested, this,
            [this](QPrinter* printer) { m_document.print(printer); });
    connect(m_groupBy, &QComboBox::currentIndexChanged, this, &ReportPreviewDialog::rebuild);
    connect(zoomIn, &QPushButton::clicked, m_preview, [this] { m_preview->zoomIn(); });
    connect(zoomOut, &QPushButton::clicked, m_preview, [this] { m_preview->zoomOut(); });
    connect(pdfButton, &QPushButton::clicked, this, &ReportPreviewDialog::savePdf);
    connect(printButton, &QPushButton::clicked, this, &ReportPreviewDialog::print);
    connect(closeButton, &QPushButton::clicked, this, &QDialog::reject);
    rebuild();
}

int ReportPreviewDialog::pageCount() const {
    return m_preview->pageCount();
}

void ReportPreviewDialog::rebuild() {
    m_document = m_build(m_groupBy->currentData().toInt());
    setWindowTitle(tr("Print preview - %1").arg(m_document.title));
    m_printer.setDocName(m_document.title);
    m_printer.setPageLayout(m_document.pageLayout);
    m_preview->updatePreview();
    const int pages = m_preview->pageCount();
    m_pages->setText(pages == 1 ? tr("1 page") : tr("%1 pages").arg(pages));
}

// The system print dialog sets up m_printer (printer, copies, paper); the preview follows the paper chosen
void ReportPreviewDialog::print() {
    QPrintDialog dialog(&m_printer, this);
    dialog.setWindowTitle(tr("Print %1").arg(m_document.title));
    if (dialog.exec() != QDialog::Accepted)
        return;
    m_document.print(&m_printer);
    m_preview->updatePreview();
}

void ReportPreviewDialog::savePdf() {
    UiHelpers::savePdf(this, m_document);
}
