#pragma once

#include "presentation/common/DataPage.h"

class QComboBox;
class QDateEdit;

// Tuition page: the receipts of a period (usp_Receipt_Search), collect a payment (usp_Receipt_Create), cancel
// a receipt with a reason (usp_Receipt_Cancel - receipts are never deleted) and print a receipt or save it as
// PDF from its print preview (usp_Receipt_Print). For the manager and the accountant; academic staff do not
// handle money.
class TuitionPage : public DataPage {
    Q_OBJECT
public:
    explicit TuitionPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void collect();
    void cancelReceipt();
    void printReceipt(const QString& receiptId);

    QDateEdit* m_from = nullptr;
    QDateEdit* m_to = nullptr;
    QComboBox* m_status = nullptr;
};
