#include "domain/entities/ClassInfo.h"

namespace ClassValues {
QStringList statuses() {
    return {enrolling(), inProgress(), finished(), cancelled()};
}
QString enrolling() {
    return QStringLiteral("Enrolling");
}
QString inProgress() {
    return QStringLiteral("In progress");
}
QString finished() {
    return QStringLiteral("Finished");
}
QString cancelled() {
    return QStringLiteral("Cancelled");
}
} // namespace ClassValues

QStringList ClassInfo::validate() const {
    QStringList errors;
    if (name.trimmed().isEmpty())
        errors << tr("The class name is required.");
    else if (name.trimmed().size() > ClassLimits::name)
        errors << tr("The class name must be at most %1 characters.").arg(ClassLimits::name);
    if (courseId.isEmpty())
        errors << tr("Please choose a course.");
    if (branchId.isEmpty())
        errors << tr("Please choose a branch.");
    if (teacherId.isEmpty())
        errors << tr("Please choose a teacher.");
    if (roomId.isEmpty())
        errors << tr("Please choose a room.");
    if (!startDate.isValid())
        errors << tr("Invalid start date.");
    if (maxStudents < ClassLimits::minStudents || maxStudents > ClassLimits::maxStudents)
        errors << tr("The class size must be between %1 and %2.")
                      .arg(ClassLimits::minStudents)
                      .arg(ClassLimits::maxStudents);
    if (tuition < 0)
        errors << tr("The tuition cannot be negative.");
    return errors;
}

QStringList ScheduleSlot::validate() const {
    QStringList errors;
    if (weekday < 1 || weekday > 7)
        errors << tr("Invalid weekday.");
    if (!start.isValid() || !end.isValid() || end <= start)
        errors << tr("The end time must be after the start time.");
    else if (start < QTime(7, 0) || end > QTime(22, 0))
        errors << tr("Classes take place between 07:00 and 22:00.");
    return errors;
}
