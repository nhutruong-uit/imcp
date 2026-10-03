#pragma once

#include "presentation/common/FormDialog.h"

class DataTable;
class TuitionService;
class QComboBox;
class QDoubleSpinBox;
class QLabel;
class QLineEdit;

// Collect a payment: choose an enrollment that still owes tuition (vw_OutstandingTuition), the amount (the
// balance by default, an installment is allowed), the method and a description. usp_Receipt_Create records it
// with the signed-in employee as collector; the triggers update ENROLLMENT.AmountPaid and refuse an
// overpayment.
class CollectPaymentDialog : public FormDialog {
    Q_OBJECT
public:
    explicit CollectPaymentDialog(TuitionService& service, QWidget* parent = nullptr);
    QString receiptId() const { return m_receiptId; }

protected:
    bool save() override;

private:
    void enrollmentChanged();
    qint64 balance() const;

    TuitionService& m_service;
    QString m_receiptId;
    QLineEdit* m_filter = nullptr;
    DataTable* m_enrollments = nullptr;
    QLabel* m_selected = nullptr;
    QDoubleSpinBox* m_amount = nullptr;
    QComboBox* m_method = nullptr;
    QLineEdit* m_description = nullptr;
};
