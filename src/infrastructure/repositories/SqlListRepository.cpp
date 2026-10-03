#include "infrastructure/repositories/SqlListRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

namespace {
// Each list = one SELECT on a view. The column keys are the column names/aliases (AS) of the result, so the
// SQL holds no display text; localized headers are chosen by the presentation layer (Columns).
QString queryFor(ListKind kind) {
    switch (kind) {
    case ListKind::OutstandingTuition:
        return QStringLiteral(
            "SELECT EnrollmentId, StudentId, StudentName, ContactPhone, ClassId, ClassName, "
            "EnrolledOn, TuitionDue, AmountPaid, Balance, DaysSinceEnrollment "
            "FROM dbo.vw_OutstandingTuition ORDER BY Balance DESC");
    case ListKind::LearningResults:
        return QStringLiteral(
            "SELECT ClassId, ClassName, StudentId, StudentName, FinalGrade, Classification, "
            "AttendanceRate, Result, Status FROM dbo.vw_LearningResults "
            "ORDER BY ClassId, StudentName");
    case ListKind::MonthlyRevenue:
        return QStringLiteral(
            "SELECT Year, Month, BranchName, ReceiptCount, Revenue FROM dbo.vw_MonthlyRevenue "
            "ORDER BY Year DESC, Month DESC, BranchName");
    case ListKind::MyClasses:
        return QStringLiteral(
            "SELECT ClassId, ClassName, CourseId, CourseName, RoomName, BranchName, StartDate, "
            "EndDate, EnrolledCount, Status FROM dbo.vw_Teacher_MyClasses "
            "ORDER BY StartDate DESC");
    case ListKind::MyPay:
        return QStringLiteral(
            "SELECT Year, Month, SessionCount, Hours, HourlyRate, Bonus, Deduction, TotalPay, "
            "Status FROM dbo.vw_Teacher_MyPay ORDER BY Year DESC, Month DESC");
    }
    return {};
}
} // namespace

SqlListRepository::SqlListRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlListRepository::fetch(ListKind kind) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, queryFor(kind), {}))
        return Result<TableData>::failure(errorOf(q));
    return Result<TableData>::success(readTable(q));
}
