#pragma once

#include "domain/entities/Catalog.h"
#include "presentation/common/DataPage.h"

class QComboBox;
class QDateEdit;

// Revenue page, two views of the valid receipts: per month and branch (vw_MonthlyRevenue) or per branch,
// program and course over a chosen period (usp_Report_Revenue, a parameterized report: dates and branch).
// Both export to Excel / PDF with the totals line.
class RevenuePage : public DataPage {
    Q_OBJECT
public:
    explicit RevenuePage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void viewChanged();

    QComboBox* m_view = nullptr;
    QDateEdit* m_from = nullptr;
    QDateEdit* m_to = nullptr;
    QComboBox* m_branch = nullptr;
};
