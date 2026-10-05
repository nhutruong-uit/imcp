#include "application/services/TuitionService.h"

TuitionService::TuitionService(ITuitionRepository& repository) : m_repository(repository) {}

Result<TableData> TuitionService::receipts(const ReceiptFilter& filter) {
    if (filter.from.isValid() && filter.to.isValid() && filter.from > filter.to)
        return Result<TableData>::failure(tr("The start date must not be after the end date."));
    ReceiptFilter f = filter;
    f.keyword = f.keyword.trimmed();
    return m_repository.receipts(f);
}

Result<TableData> TuitionService::outstanding() {
    return m_repository.outstanding();
}

Result<QString> TuitionService::collect(const ReceiptRequest& request, qint64 balance) {
    ReceiptRequest r = request;
    r.description = r.description.trimmed();
    const QStringList errors = r.validate(balance);
    if (!errors.isEmpty())
        return Result<QString>::failure(errors.join(QLatin1Char('\n')));
    return m_repository.collect(r);
}

VoidResult TuitionService::cancel(const QString& receiptId, const QString& reason) {
    if (receiptId.isEmpty())
        return VoidResult::failure(tr("No receipt is selected."));
    const QString r = reason.trimmed();
    if (r.isEmpty())
        return VoidResult::failure(tr("A reason is required to cancel a receipt."));
    if (r.size() > ReceiptLimits::cancelReason)
        return VoidResult::failure(
            tr("The reason must be at most %1 characters.").arg(ReceiptLimits::cancelReason));
    return m_repository.cancel(receiptId, r);
}

Result<ReceiptPrint> TuitionService::print(const QString& receiptId) {
    if (receiptId.isEmpty())
        return Result<ReceiptPrint>::failure(tr("No receipt is selected."));
    return m_repository.print(receiptId);
}
