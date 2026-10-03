#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QString>
#include <QStringList>

// Stored values of RECEIPT (CK_RECEIPT_PaymentMethod, CK_RECEIPT_Status)
namespace ReceiptValues {
QStringList paymentMethods(); // Cash, Bank transfer, Card
QStringList statuses();       // Valid, Cancelled
} // namespace ReceiptValues

// RECEIPT.Description and CancelReason are NVARCHAR(200)
namespace ReceiptLimits {
inline constexpr int description = 200;
inline constexpr int cancelReason = 200;
} // namespace ReceiptLimits

// A payment to record with usp_Receipt_Create. The triggers keep ENROLLMENT.AmountPaid and refuse a payment
// above the tuition still owed; validate() gives that message before the database is asked.
struct ReceiptRequest {
    QString enrollmentId;
    qint64 amount = 0;
    QString paymentMethod = QStringLiteral("Cash");
    QString description;

    // balance = what the enrollment still owes (a negative value skips that check)
    QStringList validate(qint64 balance) const;

    Q_DECLARE_TR_FUNCTIONS(ReceiptRequest)
};

// Filter of usp_Receipt_Search (empty / invalid = no filter); dates are days of the center
struct ReceiptFilter {
    QString keyword;
    QDate from;
    QDate to;
    QString status;
};

// The row of usp_Receipt_Print: everything a printed receipt shows
struct ReceiptPrint {
    QString receiptId;
    QDateTime paidAtUtc;
    qint64 amount = 0;
    QString paymentMethod;
    QString description;
    QString status;
    QString studentId;
    QString studentName;
    QString classId;
    QString className;
    QString courseName;
    qint64 tuitionDue = 0;
    qint64 amountPaid = 0;
    qint64 balance = 0;
    QString collectedBy;
    QString branchName;
    QString branchAddress;
    QString branchPhone;
};
