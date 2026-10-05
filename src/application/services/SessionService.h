#pragma once

#include "application/ports/ISessionRepository.h"

#include <QCoreApplication>

// Timetable and attendance use case: the sessions of one week, mark a session taught or cancelled, take the
// attendance of a session. A teacher sees and changes only the sessions they teach (the teacher view and the
// row-level checks of usp_Session_Update / usp_Attendance_*, errors 50017 / 50040).
// Used by TimetablePage (academic staff and teachers).
class SessionService {
    Q_DECLARE_TR_FUNCTIONS(SessionService)
public:
    explicit SessionService(ISessionRepository& repository);

    static QDate weekStart(const QDate& day); // Monday of the week of that day
    Result<TableData> week(const QDate& anyDayOfWeek, bool mineOnly);
    VoidResult update(const SessionUpdate& update, const QDate& today);
    Result<QList<AttendanceMark>> attendance(int sessionId);
    VoidResult saveAttendance(int sessionId, const QList<AttendanceMark>& marks);

private:
    ISessionRepository& m_repository;
};
