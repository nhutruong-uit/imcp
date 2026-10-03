#include "domain/entities/Session.h"

namespace SessionValues {
QStringList statuses() {
    return {scheduled(), taught(), QStringLiteral("Cancelled")};
}
QString scheduled() {
    return QStringLiteral("Scheduled");
}
QString taught() {
    return QStringLiteral("Taught");
}
} // namespace SessionValues

namespace AttendanceValues {
QStringList statuses() {
    return {present(), QStringLiteral("Late"), QStringLiteral("Excused absence"),
            QStringLiteral("Unexcused absence")};
}
QString present() {
    return QStringLiteral("Present");
}
} // namespace AttendanceValues

QStringList SessionUpdate::validate(const QDate& today) const {
    QStringList errors;
    if (sessionId <= 0)
        errors << tr("No session is selected.");
    if (!SessionValues::statuses().contains(status))
        errors << tr("Invalid status.");
    else if (status == SessionValues::taught() && sessionDate.isValid() && sessionDate > today)
        errors << tr("A session can only be marked as taught on or after its date.");
    if (description.size() > SessionLimits::description)
        errors << tr("The description must be at most %1 characters.").arg(SessionLimits::description);
    return errors;
}
