#include "infrastructure/repositories/SqlClassRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlClassRepository::SqlClassRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlClassRepository::search(const ClassFilter& filter) {
    // Active classes first, then the newest; NULL filters mean "all" (the same optional-filter pattern as A4)
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql =
        QStringLiteral("SELECT ClassId, ClassName, CourseName, BranchName, TeacherName, RoomName, Schedule, "
                       "StartDate, EndDate, "
                       "EnrolledCount, MaxStudents, SeatsLeft, Tuition, Status FROM dbo.vw_ClassDetails "
                       "WHERE (? IS NULL OR BranchId = ?) AND (? IS NULL OR Status = ?) "
                       "ORDER BY CASE Status WHEN N'In progress' THEN 0 WHEN N'Enrolling' THEN 1 ELSE 2 END, "
                       "StartDate DESC");
    const QVariant branch = stringOrNull(filter.branchId);
    const QVariant status = stringOrNull(filter.status);
    if (!execPrepared(q, m_db, sql, {branch, branch, status, status}))
        return Result<TableData>::failure(errorOf(q));
    return Result<TableData>::success(readTable(q));
}

Result<ClassInfo> SqlClassRepository::findById(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT ClassId, ClassName, CourseId, BranchId, TeacherId, RoomId, StartDate, "
                           "MaxStudents, Tuition, Status FROM dbo.vw_ClassDetails WHERE ClassId = ?"),
            {id}))
        return Result<ClassInfo>::failure(errorOf(q));
    if (!q.next())
        return Result<ClassInfo>::failure(tr("Class %1 was not found.").arg(id));
    ClassInfo c;
    c.id = q.value(0).toString();
    c.name = q.value(1).toString();
    c.courseId = q.value(2).toString();
    c.branchId = q.value(3).toString();
    c.teacherId = q.value(4).toString();
    c.roomId = q.value(5).toString();
    c.startDate = q.value(6).toDate();
    c.maxStudents = q.value(7).toInt();
    c.tuition = q.value(8).toLongLong();
    c.status = q.value(9).toString();
    return Result<ClassInfo>::success(c);
}

Result<QString> SqlClassRepository::add(const ClassInfo& c) {
    QSqlQuery q = makeQuery(m_db.db());
    const QString sql = QStringLiteral(
        "SET NOCOUNT ON; DECLARE @NewId VARCHAR(10); "
        "EXEC dbo.usp_Class_Create @ClassName = ?, @CourseId = ?, @BranchId = ?, @TeacherId = ?, @RoomId = "
        "?, "
        "@StartDate = ?, @MaxStudents = ?, @Tuition = ?, @ClassId = @NewId OUTPUT; SELECT @NewId;");
    if (!execPrepared(
            q, m_db, sql,
            {c.name, c.courseId, c.branchId, c.teacherId, c.roomId, c.startDate, c.maxStudents, c.tuition}))
        return Result<QString>::failure(errorOf(q));
    if (!q.next())
        return Result<QString>::failure(tr("The new class ID was not returned."));
    return Result<QString>::success(q.value(0).toString());
}

VoidResult SqlClassRepository::update(const ClassInfo& c) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Class_Update @ClassId = ?, @ClassName = ?, @TeacherId = ?, @RoomId = ?, "
                       "@StartDate = ?, @MaxStudents = ?, @Tuition = ?"),
        {c.id, c.name, c.teacherId, c.roomId, c.startDate, c.maxStudents, c.tuition});
}

Result<QList<ScheduleSlot>> SqlClassRepository::schedule(const QString& classId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_ClassSchedule_ByClass @ClassId = ?"), {classId}))
        return Result<QList<ScheduleSlot>>::failure(errorOf(q));
    QList<ScheduleSlot> timetable;
    while (q.next()) {
        ScheduleSlot slot;
        slot.weekday = q.value(0).toInt();
        slot.start = QTime::fromString(q.value(1).toString(), QStringLiteral("HH:mm"));
        slot.end = QTime::fromString(q.value(2).toString(), QStringLiteral("HH:mm"));
        timetable.append(slot);
    }
    return Result<QList<ScheduleSlot>>::success(timetable);
}

VoidResult SqlClassRepository::saveSlot(const QString& classId, const ScheduleSlot& slot) {
    // The times travel as text hh:mm:ss, converted to TIME(0) by SQL Server
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_ClassSchedule_Add @ClassId = ?, @Weekday = ?, @StartTime = ?, "
                       "@EndTime = ?"),
        {classId, slot.weekday, slot.start.toString(QStringLiteral("HH:mm:ss")),
         slot.end.toString(QStringLiteral("HH:mm:ss"))});
}

VoidResult SqlClassRepository::removeSlot(const QString& classId, int weekday) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_ClassSchedule_Remove @ClassId = ?, @Weekday = ?"),
                    {classId, weekday});
}

Result<SessionsGenerated> SqlClassRepository::generateSessions(const QString& classId) {
    QSqlQuery q = makeQuery(m_db.db());
    // The procedure ends with SELECT SessionsCreated, EndDate
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Class_GenerateSessions @ClassId = ?"), {classId}))
        return Result<SessionsGenerated>::failure(errorOf(q));
    SessionsGenerated result;
    if (q.next()) {
        result.count = q.value(0).toInt();
        result.endDate = q.value(1).toDate();
    }
    return Result<SessionsGenerated>::success(result);
}

VoidResult SqlClassRepository::changeStatus(const QString& classId, const QString& status) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_Class_UpdateStatus @ClassId = ?, @Status = ?"),
                    {classId, status});
}

Result<EvaluationResult> SqlClassRepository::evaluate(const QString& classId) {
    QSqlQuery q = makeQuery(m_db.db());
    // The cursor procedure ends with SELECT PassedCount, FailedCount
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Class_EvaluateResults @ClassId = ?"), {classId}))
        return Result<EvaluationResult>::failure(errorOf(q));
    EvaluationResult result;
    if (q.next()) {
        result.passed = q.value(0).toInt();
        result.failed = q.value(1).toInt();
    }
    return Result<EvaluationResult>::success(result);
}

Result<TableData> SqlClassRepository::students(const QString& classId, bool mineOnly) {
    QSqlQuery q = makeQuery(m_db.db());
    // A teacher reads the security view of their own classes (no phone, no money); the other roles the
    // procedure
    const QString sql =
        mineOnly ? QStringLiteral("SELECT EnrollmentId, StudentId, StudentName, Gender, Status, "
                                  "AttendanceRate FROM dbo.vw_Teacher_MyStudents WHERE ClassId = ? "
                                  "ORDER BY StudentName")
                 : QStringLiteral("EXEC dbo.usp_Enrollment_ByClass @ClassId = ?");
    if (!execPrepared(q, m_db, sql, {classId}))
        return Result<TableData>::failure(errorOf(q));
    return Result<TableData>::success(readTable(q));
}

Result<TableData> SqlClassRepository::results(const QString& classId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Report_ClassResults @ClassId = ?"), {classId}))
        return Result<TableData>::failure(errorOf(q));
    return Result<TableData>::success(readTable(q));
}

Result<QList<LookupItem>> SqlClassRepository::courseOptions() {
    return queryLookup(m_db,
                       QStringLiteral("SELECT CourseId, CourseId + N' - ' + CourseName FROM dbo.COURSE "
                                      "WHERE Status = N'Open' ORDER BY ProgramId, CourseId"),
                       {});
}

Result<QList<LookupItem>> SqlClassRepository::teacherOptions() {
    // Only columns of the column-level GRANT on TEACHER for academic staff (06_security.sql)
    return queryLookup(m_db,
                       QStringLiteral("SELECT TeacherId, TeacherId + N' - ' + FullName FROM dbo.TEACHER "
                                      "WHERE Status = N'Teaching' ORDER BY FullName"),
                       {});
}

Result<QList<LookupItem>> SqlClassRepository::roomOptions(const QString& branchId) {
    return queryLookup(
        m_db,
        QStringLiteral("SELECT RoomId, RoomName + N' (' + CAST(Capacity AS NVARCHAR(10)) + N')' "
                       "FROM dbo.ROOM WHERE BranchId = ? AND Status = N'Available' ORDER BY RoomId"),
        {branchId});
}

Result<qint64> SqlClassRepository::courseTuition(const QString& courseId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("SELECT Tuition FROM dbo.COURSE WHERE CourseId = ?"),
                      {courseId}))
        return Result<qint64>::failure(errorOf(q));
    return Result<qint64>::success(q.next() ? q.value(0).toLongLong() : 0);
}
