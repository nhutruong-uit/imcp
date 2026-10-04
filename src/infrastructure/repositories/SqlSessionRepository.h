#pragma once

#include "application/ports/ISessionRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// ISessionRepository with SQL Server: vw_SessionDetails (academic staff, manager) or vw_Teacher_MySchedule
// (the signed-in teacher), usp_Session_Update, usp_Attendance_BySession and usp_Attendance_Save.
class SqlSessionRepository : public ISessionRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlSessionRepository)
public:
    explicit SqlSessionRepository(DatabaseManager& db);
    Result<TableData> sessions(const QDate& from, const QDate& to, bool mineOnly) override;
    VoidResult update(const SessionUpdate& update) override;
    Result<QList<AttendanceMark>> attendance(int sessionId) override;
    VoidResult saveAttendance(int sessionId, const QList<AttendanceMark>& marks) override;

private:
    DatabaseManager& m_db;
};
