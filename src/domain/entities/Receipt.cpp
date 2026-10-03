#include "domain/entities/Receipt.h"

namespace ReceiptValues {
QStringList paymentMethods() {
    return {QStringLiteral("Cash"), QStringLiteral("Bank transfer"), QStringLiteral("Card")};
}
QStringList statuses() {
    return {QStringLiteral("Valid"), QStringLiteral("Cancelled")};
}
} // namespace ReceiptValues

QStringList ReceiptRequest::validate(qint64 balance) const {
    QStringList errors;
    if (enrollmentId.isEmpty())
        errors << tr("Please choose an enrollment.");
    if (amount <= 0)
        errors << tr("The amount must be greater than 0.");
    else if (balance >= 0 && amount > balance)
        errors << tr("The amount is larger than the tuition still owed.");
    if (!ReceiptValues::paymentMethods().contains(paymentMethod))
        errors << tr("Invalid payment method.");
    if (description.size() > ReceiptLimits::description)
        errors << tr("The description must be at most %1 characters.").arg(ReceiptLimits::description);
    return errors;
}
