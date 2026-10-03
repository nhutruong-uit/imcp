#pragma once

#include "application/ports/ITuitionRepository.h"

#include <QCoreApplication>

// Tuition use case: list receipts, collect a payment, cancel a receipt with a reason, print a receipt.
// The triggers keep ENROLLMENT.AmountPaid and refuse an overpayment; the service gives the same message
// first. Used by TuitionPage; tested in tests/tst_application.cpp.
class TuitionService {
    Q_DECLARE_TR_FUNCTIONS(TuitionService)
public:
    explicit TuitionService(ITuitionRepository& repository);

    Result<TableData> receipts(const ReceiptFilter& filter);
    Result<TableData> outstanding();
    // balance = what the enrollment still owes (shown in the payment form); the new ReceiptId on success
    Result<QString> collect(const ReceiptRequest& request, qint64 balance);
    VoidResult cancel(const QString& receiptId, const QString& reason);
    Result<ReceiptPrint> print(const QString& receiptId);

private:
    ITuitionRepository& m_repository;
};
