#include "presentation/tuition/TuitionPage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/DbValues.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/ReportPreviewDialog.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/tuition/CollectPaymentDialog.h"
#include "presentation/tuition/ReceiptPrinter.h"

#include <QComboBox>
#include <QDateEdit>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>

TuitionPage::TuitionPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Tuition, parent) {
    // The last three months by default: enough to find a recent payment without loading the whole history
    m_from = Fields::date(this, QDate::currentDate().addMonths(-3));
    m_to = Fields::date(this, QDate::currentDate());
    m_status = new QComboBox(this);
    m_status->addItem(tr("All receipts"), QString());
    for (const QString& status : ReceiptValues::statuses())
        m_status->addItem(DbValues::label(status), status);
    addFilter(new QLabel(tr("From"), this));
    addFilter(m_from);
    addFilter(new QLabel(tr("to"), this));
    addFilter(m_to);
    addFilter(m_status);
    table()->setHiddenColumns({QStringLiteral("EnrollmentId")});

    if (canEdit()) {
        addAction(tr("Collect payment"), QStringLiteral("plus"), QStringLiteral("collectButton"), false,
                  [this] { collect(); });
        addAction(tr("Cancel receipt"), QStringLiteral("x-circle"), QStringLiteral("cancelReceiptButton"),
                  true, [this] { cancelReceipt(); });
    }
    addAction(tr("Print receipt"), QStringLiteral("printer"), QStringLiteral("printButton"), true,
              [this] { printReceipt(selected(QStringLiteral("ReceiptId")).toString()); });

    connect(m_from, &QDateEdit::dateChanged, this, &TuitionPage::reload);
    connect(m_to, &QDateEdit::dateChanged, this, &TuitionPage::reload);
    connect(m_status, &QComboBox::currentIndexChanged, this, &TuitionPage::reload);
    reload();
}

Result<TableData> TuitionPage::fetch() {
    ReceiptFilter filter;
    filter.from = m_from->date();
    filter.to = m_to->date();
    filter.status = m_status->currentData().toString();
    return m_services.tuition.receipts(filter);
}

void TuitionPage::collect() {
    CollectPaymentDialog dialog(m_services.tuition, this);
    if (dialog.exec() != QDialog::Accepted)
        return;
    m_to->setDate(qMax(m_to->date(), QDate::currentDate())); // the new receipt is paid now
    reloadAndSelect(QStringLiteral("ReceiptId"), dialog.receiptId());
    if (UiHelpers::confirm(this, tr("Receipt %1 was recorded. Print it now?").arg(dialog.receiptId())))
        printReceipt(dialog.receiptId());
}

void TuitionPage::cancelReceipt() {
    const QString receiptId = selected(QStringLiteral("ReceiptId")).toString();
    FormDialog dialog(tr("Cancel receipt %1").arg(receiptId), this);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("The receipt stays in the history with the status Cancelled; the "
                                        "amount is no longer counted as paid."),
                                     &dialog));
    auto* reason = Fields::text(&dialog, ReceiptLimits::cancelReason);
    reason->setObjectName(QStringLiteral("reasonEdit"));
    dialog.form()->addRow(tr("Reason"), reason);
    dialog.setSaveText(tr("Cancel receipt"));
    dialog.setSaveAction([&] { return m_services.tuition.cancel(receiptId, reason->text()); });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("ReceiptId"), receiptId);
}

void TuitionPage::printReceipt(const QString& receiptId) {
    const auto receipt = m_services.tuition.print(receiptId);
    if (!receipt.ok()) {
        UiHelpers::showError(this, receipt.error());
        return;
    }
    // Print preview of the A5 receipt: print it, or save it as PDF (a receipt has no groups)
    const ReportDocument document = ReceiptPrinter::document(receipt.value());
    ReportPreviewDialog dialog([document](int) { return document; }, {}, this);
    dialog.exec();
}
