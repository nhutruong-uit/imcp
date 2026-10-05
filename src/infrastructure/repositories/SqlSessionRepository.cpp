#include "infrastructure/repositories/SqlSessionRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlSessionRepository::SqlSessionRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlSessionRepository::sessions(const QDate& from, const QDate& to, bool mineOnly) {
    // Times as "HH:mm" text with the original column name as alias (column keys StartTime / EndTime); a
    // teacher reads the security view that keeps only the sessions they teach
    const QString view =
        mineOnly ? QStringLiteral("dbo.vw_Teacher_MySchedule") : QStringLiteral("dbo.vw_SessionDetails");
    const QString teacher = mineOnly ? QString() : QStringLiteral("TeacherName, ");
    const QString sql =
        QStringLiteral("SELECT SessionId, SessionDate, LEFT(CONVERT(VARCHAR(8), StartTime, 108), 5) "
                       "AS StartTime, LEFT(CONVERT(VARCHAR(8), EndTime, 108), 5) AS EndTime, "
                       "ClassId, ClassName, SessionNo, RoomName, %1Description, Status FROM %2 "
                       "WHERE SessionDate >= ? AND SessionDate < ? ORDER BY SessionDate, StartTime")
            .arg(teacher, view);
    return queryTable(m_db, sql, {from, to});
}

VoidResult SqlSessionRepository::update(const SessionUpdate& update) {
    // The text of the field as it is: the procedure keeps the content for NULL and removes it for an empty
    // text, so stringOrNull (empty => NULL) would make a cleared field keep the old content
    const QString description = update.description.isNull() ? QStringLiteral("") : update.description;
    return execCall(
        m_db, QStringLiteral("EXEC dbo.usp_Session_Update @SessionId = ?, @Status = ?, @Description = ?"),
        {update.sessionId, update.status, description});
}

Result<QList<AttendanceMark>> SqlSessionRepository::attendance(int sessionId) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db, QStringLiteral("EXEC dbo.usp_Attendance_BySession @SessionId = ?"),
                      {sessionId}))
        return Result<QList<AttendanceMark>>::failure(errorOf(q));
    // Columns: EnrollmentId, StudentId, StudentName, Status, Notes, IsSaved
    QList<AttendanceMark> marks;
    while (q.next())
        marks.append({field(q, "EnrollmentId").toString(), field(q, "StudentId").toString(),
                      field(q, "StudentName").toString(), field(q, "Status").toString(),
                      field(q, "Notes").toString(), field(q, "IsSaved").toInt() == 1});
    return afterRead(q, marks);
}

// One usp_Attendance_Save call per student, all in one transaction: either the whole list is saved or none of
// it (a refused row - e.g. a finished class, 50046 - must not leave half a session marked)
VoidResult SqlSessionRepository::saveAttendance(int sessionId, const QList<AttendanceMark>& marks) {
    QSqlDatabase db = m_db.db();
    if (!db.transaction())
        return VoidResult::failure(SqlErrorMapper::message(db.lastError()));
    for (const AttendanceMark& m : marks) {
        QSqlQuery q = makeQuery(db);
        if (!execPrepared(
                q, m_db,
                QStringLiteral("EXEC dbo.usp_Attendance_Save @SessionId = ?, @EnrollmentId = ?, @Status = ?, "
                               "@Notes = ?"),
                {sessionId, m.enrollmentId, m.status, stringOrNull(m.notes)})) {
            const QString error = errorOf(q);
            db.rollback();
            return VoidResult::failure(error);
        }
    }
    if (!db.commit())
        return VoidResult::failure(SqlErrorMapper::message(db.lastError()));
    return VoidResult::success();
}
