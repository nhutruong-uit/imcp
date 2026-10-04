#include "presentation/tuition/CollectPaymentDialog.h"

#include "application/services/TuitionService.h"
#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/Format.h"

#include <QComboBox>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QVBoxLayout>
#include <cmath>

CollectPaymentDialog::CollectPaymentDialog(TuitionService& service, QWidget* parent)
    : FormDialog(tr("Collect a payment"), parent), m_service(service) {
    resize(820, 620);
    m_filter = Fields::text(this, 100);
    m_filter->setObjectName(QStringLiteral("enrollmentFilter"));
    m_filter->setPlaceholderText(tr("Filter by student, class or enrollment..."));
    m_enrollments = new DataTable(QStringLiteral("outstandingTable"), this);
    m_enrollments->setMinimumHeight(240);
    m_selected = new QLabel(this);
    m_selected->setObjectName(QStringLiteral("CardTitle"));
    m_selected->setWordWrap(true);
    m_amount = Fields::money(this, 0);
    m_amount->setObjectName(QStringLiteral("amountEdit"));
    m_method = Fields::values(this, ReceiptValues::paymentMethods());
    m_description = Fields::text(this, ReceiptLimits::description);
    m_description->setPlaceholderText(tr("Tuition payment"));

    body()->addWidget(m_filter);
    body()->addWidget(m_enrollments, 1);
    auto* details = new QFormLayout;
    details->addRow(tr("Enrollment"), m_selected);
    details->addRow(tr("Amount"), m_amount);
    details->addRow(tr("Payment method"), m_method);
    details->addRow(tr("Description"), m_description);
    body()->addLayout(details);
    setSaveText(tr("Collect"));

    const auto outstanding = m_service.outstanding();
    if (outstanding.ok())
        m_enrollments->setData(outstanding.value());
    else
        showError(outstanding.error());
    connect(m_filter, &QLineEdit::textChanged, m_enrollments, &DataTable::setFilterText);
    setSearchField(m_filter); // the list filters while typing; Return must not collect a payment
    connect(m_enrollments, &DataTable::selectionChanged, this, &CollectPaymentDialog::enrollmentChanged);
    enrollmentChanged();
}

qint64 CollectPaymentDialog::balance() const {
    if (!m_enrollments->hasSelection())
        return -1;
    return std::llround(m_enrollments->selectedValue(QStringLiteral("Balance")).toDouble());
}

// The amount starts at what the enrollment still owes and can never be above it
void CollectPaymentDialog::enrollmentChanged() {
    const qint64 owed = balance();
    if (owed < 0) {
        m_selected->setText(tr("Choose an enrollment in the list."));
        m_amount->setValue(0);
        return;
    }
    m_selected->setText(tr("%1 - %2, class %3: still owes %4")
                            .arg(m_enrollments->selectedValue(QStringLiteral("EnrollmentId")).toString(),
                                 m_enrollments->selectedValue(QStringLiteral("StudentName")).toString(),
                                 m_enrollments->selectedValue(QStringLiteral("ClassId")).toString(),
                                 Format::money(owed)));
    m_amount->setMaximum(double(owed));
    m_amount->setValue(double(owed));
}

bool CollectPaymentDialog::save() {
    ReceiptRequest r;
    r.enrollmentId = m_enrollments->selectedValue(QStringLiteral("EnrollmentId")).toString();
    r.amount = Fields::moneyValue(m_amount);
    r.paymentMethod = Fields::value(m_method);
    r.description = m_description->text();
    const auto result = m_service.collect(r, balance());
    if (!result.ok()) {
        showError(result.error());
        return false;
    }
    m_receiptId = result.value();
    return true;
}
