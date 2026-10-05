#include "infrastructure/repositories/SqlEnrollmentRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlEnrollmentRepository::SqlEnrollmentRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlEnrollmentRepository::search(const EnrollmentFilter& filter) {
    return queryTable(
        m_db,
        QStringLiteral("EXEC dbo.usp_Enrollment_Search @Keyword = ?, @ClassId = ?, @StudentId = ?, "
                       "@Status = ?"),
        {stringOrNull(filter.keyword), stringOrNull(filter.classId), stringOrNull(filter.studentId),
         stringOrNull(filter.status)});
}

Result<QString> SqlEnrollmentRepository::enroll(const EnrollmentRequest& request) {
    // OUTPUT parameter: the batch declares a variable, passes it and SELECTs it (the A1 pattern)
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Enrollment_Create @StudentId = ?, @ClassId = ?, @PromotionId = ?, @EnrolledOn = ?, "
        "@EnrollmentId = @NewId OUTPUT; SELECT @NewId;");
    if (!execPrepared(q, m_db, sql,
                      {request.studentId, request.classId, stringOrNull(request.promotionId),
                       dateOrNull(request.enrolledOn)}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new enrollment ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlEnrollmentRepository::transfer(const QString& enrollmentId, const QString& newClassId) {
    return execCall(
        m_db, QStringLiteral("EXEC dbo.usp_Enrollment_TransferClass @EnrollmentId = ?, @NewClassId = ?"),
        {enrollmentId, newClassId});
}

VoidResult SqlEnrollmentRepository::changeStatus(const QString& enrollmentId, const QString& status) {
    return execCall(m_db,
                    QStringLiteral("EXEC dbo.usp_Enrollment_UpdateStatus @EnrollmentId = ?, @Status = ?"),
                    {enrollmentId, status});
}

Result<QList<ClassOption>> SqlEnrollmentRepository::openClasses() {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT ClassId, ClassName, CourseId, CourseName, BranchId, BranchName, Status, "
                           "Tuition, SeatsLeft FROM dbo.vw_ClassDetails "
                           "WHERE Status IN (N'Enrolling', N'In progress') ORDER BY ClassId"),
            {}))
        return Result<QList<ClassOption>>::failure(errorOf(q));
    QList<ClassOption> classes;
    while (q.next())
        classes.append({field(q, "ClassId").toString(), field(q, "ClassName").toString(),
                        field(q, "CourseId").toString(), field(q, "CourseName").toString(),
                        field(q, "BranchId").toString(), field(q, "BranchName").toString(),
                        field(q, "Status").toString(), field(q, "Tuition").toLongLong(),
                        field(q, "SeatsLeft").toInt()});
    return Result<QList<ClassOption>>::success(classes);
}

Result<QList<LookupItem>> SqlEnrollmentRepository::promotionOptions(const QDate& date) {
    return queryLookup(
        m_db,
        QStringLiteral("SELECT PromotionId, PromotionId + N' - ' + PromotionName FROM dbo.PROMOTION "
                       "WHERE ? BETWEEN StartDate AND EndDate ORDER BY PromotionId"),
        {date});
}
