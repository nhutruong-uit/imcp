#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/Session.h"

#include <QDate>
#include <QList>

// Port of the timetable and attendance screens: implemented by SqlSessionRepository (vw_SessionDetails,
// vw_Teacher_MySchedule, usp_Session_Update, usp_Attendance_*), used by SessionService.
class ISessionRepository {
public:
    virtual ~ISessionRepository() = default;
    // Sessions from `from` (included) to `to` (excluded); mineOnly = the signed-in teacher's (teacher view)
    virtual Result<TableData> sessions(const QDate& from, const QDate& to, bool mineOnly) = 0;
    virtual VoidResult update(const SessionUpdate& update) = 0;          // usp_Session_Update
    virtual Result<QList<AttendanceMark>> attendance(int sessionId) = 0; // usp_Attendance_BySession
    virtual VoidResult saveAttendance(int sessionId,
                                      const QList<AttendanceMark>& marks) = 0; // in one transaction
};
