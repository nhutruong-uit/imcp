#include "infrastructure/repositories/SqlTuitionRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlTuitionRepository::SqlTuitionRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlTuitionRepository::receipts(const ReceiptFilter& filter) {
    return queryTable(m_db,
                      QStringLiteral("EXEC dbo.usp_Receipt_Search @Keyword = ?, @FromDate = ?, @ToDate = ?, "
                                     "@Status = ?"),
                      {stringOrNull(filter.keyword), dateOrNull(filter.from), dateOrNull(filter.to),
                       stringOrNull(filter.status)});
}

Result<TableData> SqlTuitionRepository::outstanding() {
    return queryTable(
        m_db,
        QStringLiteral("SELECT EnrollmentId, StudentId, StudentName, ClassId, ClassName, TuitionDue, "
                       "AmountPaid, Balance FROM dbo.vw_OutstandingTuition "
                       "ORDER BY StudentName, EnrollmentId"),
        {});
}

Result<QString> SqlTuitionRepository::collect(const ReceiptRequest& request) {
    // The collecting employee is the signed-in one (fn_CurrentEmployeeId inside the procedure)
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Receipt_Create @EnrollmentId = ?, @Amount = ?, @PaymentMethod = ?, @Description = ?, "
        "@ReceiptId = @NewId OUTPUT; SELECT @NewId;");
    if (!execPrepared(
            q, m_db, sql,
            {request.enrollmentId, request.amount, request.paymentMethod, stringOrNull(request.description)}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new receipt ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlTuitionRepository::cancel(const QString& receiptId, const QString& reason) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_Receipt_Cancel @ReceiptId = ?, @Reason = ?"),
                    {receiptId, reason});
}

Result<ReceiptPrint> SqlTuitionRepository::print(const QString& receiptId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Receipt_Print @ReceiptId = ?"), {receiptId}))
        return Result<ReceiptPrint>::failure(errorOf(q));
    if (!q.next())
        return Result<ReceiptPrint>::failure(tr("Receipt %1 was not found.").arg(receiptId));
    // Columns: ReceiptId, PaidAtUtc, Amount, PaymentMethod, Description, Status, StudentId, StudentName,
    // ClassId,
    //          ClassName, CourseName, TuitionDue, AmountPaid, Balance, CollectedBy, BranchName,
    //          BranchAddress, BranchPhone
    ReceiptPrint r;
    r.receiptId = field(q, "ReceiptId").toString();
    r.paidAtUtc = field(q, "PaidAtUtc").toDateTime();
    r.amount = field(q, "Amount").toLongLong();
    r.paymentMethod = field(q, "PaymentMethod").toString();
    r.description = field(q, "Description").toString();
    r.status = field(q, "Status").toString();
    r.studentId = field(q, "StudentId").toString();
    r.studentName = field(q, "StudentName").toString();
    r.classId = field(q, "ClassId").toString();
    r.className = field(q, "ClassName").toString();
    r.courseName = field(q, "CourseName").toString();
    r.tuitionDue = field(q, "TuitionDue").toLongLong();
    r.amountPaid = field(q, "AmountPaid").toLongLong();
    r.balance = field(q, "Balance").toLongLong();
    r.collectedBy = field(q, "CollectedBy").toString();
    r.branchName = field(q, "BranchName").toString();
    r.branchAddress = field(q, "BranchAddress").toString();
    r.branchPhone = field(q, "BranchPhone").toString();
    return Result<ReceiptPrint>::success(r);
}
