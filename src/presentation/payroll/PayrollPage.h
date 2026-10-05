#pragma once

#include "presentation/common/DataPage.h"

class QComboBox;

// Teacher payroll page: the payroll rows (PAYROLL joined with TEACHER) filtered by year and month; the
// manager and the accountant finalize a month (usp_Payroll_Finalize, a cursor over the taught sessions), set
// a deduction (usp_Payroll_Adjust) and record a payment (usp_Payroll_MarkPaid). TotalPay is computed by the
// database.
class PayrollPage : public DataPage {
    Q_OBJECT
public:
    explicit PayrollPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void finalizeMonth();
    void setDeduction();
    void markPaid();

    QComboBox* m_year = nullptr;
    QComboBox* m_month = nullptr;
};
