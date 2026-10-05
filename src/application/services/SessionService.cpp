#include "application/services/SessionService.h"

SessionService::SessionService(ISessionRepository& repository) : m_repository(repository) {}

QDate SessionService::weekStart(const QDate& day) {
    return day.addDays(1 - day.dayOfWeek());
}

Result<TableData> SessionService::week(const QDate& anyDayOfWeek, bool mineOnly) {
    if (!anyDayOfWeek.isValid())
        return Result<TableData>::failure(tr("Invalid date."));
    const QDate monday = weekStart(anyDayOfWeek);
    return m_repository.sessions(monday, monday.addDays(7), mineOnly);
}

VoidResult SessionService::update(const SessionUpdate& update, const QDate& today) {
    SessionUpdate u = update;
    u.description = u.description.trimmed();
    const QStringList errors = u.validate(today);
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return m_repository.update(u);
}

Result<QList<AttendanceMark>> SessionService::attendance(int sessionId) {
    if (sessionId <= 0)
        return Result<QList<AttendanceMark>>::failure(tr("No session is selected."));
    return m_repository.attendance(sessionId);
}

VoidResult SessionService::saveAttendance(int sessionId, const QList<AttendanceMark>& marks) {
    if (sessionId <= 0)
        return VoidResult::failure(tr("No session is selected."));
    QList<AttendanceMark> cleaned;
    for (AttendanceMark m : marks) {
        m.notes = m.notes.trimmed();
        if (!AttendanceValues::statuses().contains(m.status))
            return VoidResult::failure(tr("Invalid attendance status for %1.").arg(m.studentName));
        if (m.notes.size() > SessionLimits::attendanceNotes)
            return VoidResult::failure(tr("Notes must be at most %1 characters (%2).")
                                           .arg(SessionLimits::attendanceNotes)
                                           .arg(m.studentName));
        cleaned.append(m);
    }
    if (cleaned.isEmpty())
        return VoidResult::success();
    return m_repository.saveAttendance(sessionId, cleaned);
}
