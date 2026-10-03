#include "presentation/payroll/PayrollPage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/Format.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableDialog.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QLabel>
#include <QSpinBox>
#include <cmath>

PayrollPage::PayrollPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Payroll, parent) {
    const int thisYear = QDate::currentDate().year();
    m_year = new QComboBox(this);
    m_year->addItem(tr("All years"), 0);
    for (int y = thisYear; y >= thisYear - 5; --y)
        m_year->addItem(QString::number(y), y);
    m_month = new QComboBox(this);
    m_month->addItem(tr("All months"), 0);
    for (int m = 1; m <= 12; ++m)
        m_month->addItem(tr("Month %1").arg(m), m);
    addFilter(m_year);
    addFilter(m_month);
    table()->setHiddenColumns({QStringLiteral("PayrollId")});

    if (canEdit()) {
        addAction(tr("Finalize month"), QStringLiteral("calendar"), QStringLiteral("finalizeButton"), false,
                  [this] { finalizeMonth(); });
        addAction(tr("Deduction"), QStringLiteral("edit"), QStringLiteral("deductionButton"), true,
                  [this] { setDeduction(); });
        addAction(tr("Mark as paid"), QStringLiteral("check"), QStringLiteral("markPaidButton"), true,
                  [this] { markPaid(); });
    }
    connect(m_year, &QComboBox::currentIndexChanged, this, &PayrollPage::reload);
    connect(m_month, &QComboBox::currentIndexChanged, this, &PayrollPage::reload);
    reload();
}

Result<TableData> PayrollPage::fetch() {
    PayrollFilter filter;
    filter.year = m_year->currentData().toInt();
    filter.month = m_month->currentData().toInt();
    return m_services.payroll.list(filter);
}

// The previous month by default: a month is finalized once its sessions have been taught
void PayrollPage::finalizeMonth() {
    const QDate lastMonth = QDate::currentDate().addMonths(-1);
    FormDialog dialog(tr("Finalize the payroll of a month"), this);
    auto* month = Fields::integer(&dialog, 1, 12, lastMonth.month());
    auto* year = Fields::integer(&dialog, 2020, QDate::currentDate().year(), lastMonth.year());
    dialog.form()->addRow(tr("Month"), month);
    dialog.form()->addRow(tr("Year"), year);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("Counts the taught sessions of every teacher in that month. A month "
                                        "can be finalized again; paid rows never change."),
                                     &dialog));
    TableData result;
    dialog.setSaveText(tr("Finalize"));
    dialog.setSaveAction([&]() -> VoidResult {
        const auto payroll = m_services.payroll.finalize(month->value(), year->value(), QDate::currentDate());
        if (!payroll.ok())
            return VoidResult::failure(payroll.error());
        result = payroll.value();
        return VoidResult::success();
    });
    if (dialog.exec() != QDialog::Accepted)
        return;
    m_year->setCurrentIndex(qMax(0, m_year->findData(year->value())));
    m_month->setCurrentIndex(qMax(0, m_month->findData(month->value())));
    reload();
    TableDialog summary(tr("Payroll of %1/%2").arg(month->value()).arg(year->value()),
                        Labels::accountName(m_services.auth.account()), this);
    summary.setData(result);
    summary.exec();
}

void PayrollPage::setDeduction() {
    const int payrollId = selected(QStringLiteral("PayrollId")).toInt();
    const qint64 current = std::llround(selected(QStringLiteral("Deduction")).toDouble());
    FormDialog dialog(tr("Deduction - %1, %2/%3")
                          .arg(selected(QStringLiteral("TeacherName")).toString())
                          .arg(selected(QStringLiteral("Month")).toInt())
                          .arg(selected(QStringLiteral("Year")).toInt()),
                      this);
    auto* deduction = Fields::money(&dialog, current);
    deduction->setObjectName(QStringLiteral("deductionEdit"));
    dialog.form()->addRow(tr("Deduction"), deduction);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("The total pay is recomputed by the database: hours x rate + bonus "
                                        "- deduction."),
                                     &dialog));
    dialog.setSaveAction([&] { return m_services.payroll.adjust(payrollId, Fields::moneyValue(deduction)); });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("PayrollId"), payrollId);
}

void PayrollPage::markPaid() {
    const int payrollId = selected(QStringLiteral("PayrollId")).toInt();
    const qint64 total = std::llround(selected(QStringLiteral("TotalPay")).toDouble());
    if (!UiHelpers::confirm(this,
                            tr("Record that %1 has been paid %2 for %3/%4? A paid row can no longer change.")
                                .arg(selected(QStringLiteral("TeacherName")).toString(), Format::money(total))
                                .arg(selected(QStringLiteral("Month")).toInt())
                                .arg(selected(QStringLiteral("Year")).toInt())))
        return;
    const auto result = m_services.payroll.markPaid(payrollId);
    if (!result.ok())
        UiHelpers::showError(this, result.error());
    reloadAndSelect(QStringLiteral("PayrollId"), payrollId);
}
