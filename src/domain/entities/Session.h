#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>

// Stored values of CLASS_SESSION.Status (CK_CLASS_SESSION_Status) and ATTENDANCE.Status
// (CK_ATTENDANCE_Status)
namespace SessionValues {
QStringList statuses(); // Scheduled, Taught, Cancelled
QString scheduled();
QString taught();
} // namespace SessionValues

namespace AttendanceValues {
QStringList statuses(); // Present, Late, Excused absence, Unexcused absence
QString present();
} // namespace AttendanceValues

// CLASS_SESSION.Description and ATTENDANCE.Notes are NVARCHAR(200)
namespace SessionLimits {
inline constexpr int description = 200;
inline constexpr int attendanceNotes = 200;
} // namespace SessionLimits

// The change usp_Session_Update makes: the status of a session and the content of the lesson. The rules on
// the old status (a taught session stays taught) live in trg_CLASS_SESSION_LockTaught; validate() repeats the
// one rule the form can check alone: a session is taught on or after its date.
struct SessionUpdate {
    int sessionId = 0;
    QDate sessionDate;
    QString status;
    QString description;

    QStringList validate(const QDate& today) const;

    Q_DECLARE_TR_FUNCTIONS(SessionUpdate)
};

// One student on the attendance list of a session (usp_Attendance_BySession; saved = a mark exists already)
struct AttendanceMark {
    QString enrollmentId;
    QString studentId;
    QString studentName;
    QString status;
    QString notes;
    bool saved = false;
};
