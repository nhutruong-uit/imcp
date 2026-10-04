#include "domain/entities/Enrollment.h"

namespace EnrollmentValues {
QStringList statuses() {
    return {studying(), onHold(), left(), completed()};
}
QString studying() {
    return QStringLiteral("Studying");
}
QString onHold() {
    return QStringLiteral("On hold");
}
QString left() {
    return QStringLiteral("Left");
}
QString completed() {
    return QStringLiteral("Completed");
}
} // namespace EnrollmentValues

QStringList EnrollmentRequest::validate() const {
    QStringList errors;
    if (studentId.isEmpty())
        errors << tr("Please choose a student.");
    if (classId.isEmpty())
        errors << tr("Please choose a class.");
    return errors;
}
