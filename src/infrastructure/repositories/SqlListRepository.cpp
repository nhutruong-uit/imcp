#include "infrastructure/repositories/SqlListRepository.h"

#include "infrastructure/db/SqlHelpers.h"

#include <QSqlRecord>

using namespace SqlHelpers;

namespace {
// Each list = one SQL statement + parameters. The column keys are the column names/aliases (AS) of the
// result, so the SQL holds no display text; localized headers are chosen by the presentation layer (Columns).
struct ListQuery {
    QString sql;
    QVariantList parameters;
};

// Monday of the week that contains date d
QDate startOfWeek(const QDate& d) {
    return d.addDays(1 - d.dayOfWeek());
}

// Time as "HH:mm", keeping the original column name as alias (column keys StartTime / EndTime)
const QString kTime = QStringLiteral("LEFT(CONVERT(VARCHAR(8), %1, 108), 5) AS %1");

ListQuery queryFor(ListKind kind) {
    const QDate today = QDate::currentDate();
    const QString startTime = kTime.arg(QStringLiteral("StartTime"));
    const QString endTime = kTime.arg(QStringLiteral("EndTime"));
    switch (kind) {
    case ListKind::Classes:
        return {QStringLiteral(
                    "SELECT ClassId, ClassName, CourseName, BranchName, TeacherName, RoomName, Schedule, "
                    "StartDate, EndDate, EnrolledCount, MaxStudents, Tuition, Status "
                    "FROM dbo.vw_ClassDetails "
                    "ORDER BY CASE Status WHEN N'In progress' THEN 0 WHEN N'Enrolling' THEN 1 ELSE 2 END, "
                    "StartDate DESC"),
                {}};
    case ListKind::WeeklySchedule:
        // From Monday of this week (included) to Monday of next week (excluded); the dates are parameters
        return {QStringLiteral(
                    "SELECT SessionDate, %1, %2, ClassId, ClassName, SessionNo, RoomName, TeacherName, "
                    "Status FROM dbo.vw_SessionDetails WHERE SessionDate >= ? AND SessionDate < ? "
                    "ORDER BY SessionDate, StartTime")
                    .arg(startTime, endTime),
                {startOfWeek(today), startOfWeek(today).addDays(7)}};
    case ListKind::OutstandingTuition:
        return {
            QStringLiteral("SELECT EnrollmentId, StudentId, StudentName, ContactPhone, ClassId, ClassName, "
                           "EnrolledOn, TuitionDue, AmountPaid, Balance, DaysSinceEnrollment "
                           "FROM dbo.vw_OutstandingTuition ORDER BY Balance DESC"),
            {}};
    case ListKind::LearningResults:
        return {
            QStringLiteral("SELECT ClassId, ClassName, StudentId, StudentName, FinalGrade, Classification, "
                           "AttendanceRate, Result, Status FROM dbo.vw_LearningResults "
                           "ORDER BY ClassId, StudentName"),
            {}};
    case ListKind::MonthlyRevenue:
        return {
            QStringLiteral("SELECT Year, Month, BranchName, ReceiptCount, Revenue FROM dbo.vw_MonthlyRevenue "
                           "ORDER BY Year DESC, Month DESC, BranchName"),
            {}};
    case ListKind::Payroll:
        // Reads only TeacherId/FullName of TEACHER: accountants have a column-level GRANT on TEACHER that
        // includes these columns (06_security.sql)
        return {QStringLiteral(
                    "SELECT py.Year, py.Month, te.TeacherId, te.FullName AS TeacherName, py.SessionCount, "
                    "py.Hours, py.HourlyRate, py.Bonus, py.Deduction, py.TotalPay, py.Status "
                    "FROM dbo.PAYROLL py JOIN dbo.TEACHER te ON te.TeacherId = py.TeacherId "
                    "ORDER BY py.Year DESC, py.Month DESC, te.FullName"),
                {}};
    case ListKind::Accounts:
        return {QStringLiteral("EXEC dbo.usp_Account_List"), {}};
    case ListKind::MyClasses:
        return {
            QStringLiteral("SELECT ClassId, ClassName, CourseName, RoomName, BranchName, StartDate, EndDate, "
                           "EnrolledCount, Status FROM dbo.vw_Teacher_MyClasses ORDER BY StartDate DESC"),
            {}};
    case ListKind::MyTeachingSchedule:
        return {QStringLiteral(
                    "SELECT SessionDate, %1, %2, ClassId, ClassName, SessionNo, RoomName, Status "
                    "FROM dbo.vw_Teacher_MySchedule WHERE SessionDate >= ? ORDER BY SessionDate, StartTime")
                    .arg(startTime, endTime),
                {startOfWeek(today)}};
    case ListKind::MyPay:
        return {QStringLiteral(
                    "SELECT Year, Month, SessionCount, Hours, HourlyRate, Bonus, Deduction, TotalPay, Status "
                    "FROM dbo.vw_Teacher_MyPay ORDER BY Year DESC, Month DESC"),
                {}};
    }
    return {};
}
} // namespace

SqlListRepository::SqlListRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlListRepository::fetch(ListKind kind) {
    const ListQuery lq = queryFor(kind);
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, lq.sql, lq.parameters))
        return Result<TableData>::failure(errorOf(q));

    // The column names of the result become the column keys (record() describes the result columns)
    TableData table;
    const QSqlRecord record = q.record();
    const int columnCount = record.count();
    for (int i = 0; i < columnCount; ++i)
        table.columns.append(record.fieldName(i));
    while (q.next()) {
        QVariantList row;
        row.reserve(columnCount);
        for (int i = 0; i < columnCount; ++i)
            row.append(q.value(i));
        table.rows.append(row);
    }
    return Result<TableData>::success(table);
}
