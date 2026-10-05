#include "domain/entities/Catalog.h"

#include "domain/common/Validation.h"

namespace CatalogValues {
QStringList branchStatuses() {
    return {QStringLiteral("Active"), QStringLiteral("Suspended")};
}
QStringList roomTypes() {
    return {QStringLiteral("Lecture"), QStringLiteral("Lab"), QStringLiteral("Multi-purpose")};
}
QStringList roomStatuses() {
    return {QStringLiteral("Available"), QStringLiteral("Maintenance")};
}
QStringList levels() {
    return {QStringLiteral("A1"), QStringLiteral("A2"), QStringLiteral("B1"),
            QStringLiteral("B2"), QStringLiteral("C1"), QStringLiteral("C2")};
}
QStringList courseStatuses() {
    return {QStringLiteral("Open"), QStringLiteral("Discontinued")};
}
QStringList discountTypes() {
    return {QStringLiteral("PERCENT"), QStringLiteral("AMOUNT")};
}
} // namespace CatalogValues

namespace {
// The code rule of the catalog procedures (THROW 50092); only a new row has a code to check
void checkCode(const QString& code, bool isNew, QStringList* errors, const QString& message) {
    if (isNew && !Validation::isCode(code, CatalogValues::codeLength))
        *errors << message;
}
} // namespace

QStringList Branch::validate(bool isNew) const {
    QStringList errors;
    checkCode(id, isNew, &errors,
              tr("The branch code may only contain letters, digits, dashes and underscores (at most 10)."));
    if (name.trimmed().isEmpty())
        errors << tr("The branch name is required.");
    if (address.trimmed().isEmpty())
        errors << tr("The address is required.");
    if (!phone.isEmpty() && !Validation::isPhone(phone))
        errors << tr("Phone numbers contain 9-11 digits only.");
    if (!email.isEmpty() && !Validation::isEmail(email))
        errors << tr("Invalid email address.");
    if (!CatalogValues::branchStatuses().contains(status))
        errors << tr("Invalid status.");
    return errors;
}

QStringList Room::validate(bool isNew) const {
    QStringList errors;
    checkCode(id, isNew, &errors,
              tr("The room code may only contain letters, digits, dashes and underscores (at most 10)."));
    if (branchId.isEmpty())
        errors << tr("Please choose a branch.");
    if (name.trimmed().isEmpty())
        errors << tr("The room name is required.");
    if (capacity < CatalogLimits::minRoomCapacity || capacity > CatalogLimits::maxRoomCapacity)
        errors << tr("The capacity must be between %1 and %2.")
                      .arg(CatalogLimits::minRoomCapacity)
                      .arg(CatalogLimits::maxRoomCapacity);
    if (!CatalogValues::roomTypes().contains(type))
        errors << tr("Invalid room type.");
    if (!CatalogValues::roomStatuses().contains(status))
        errors << tr("Invalid status.");
    return errors;
}

QStringList Program::validate(bool isNew) const {
    QStringList errors;
    checkCode(id, isNew, &errors,
              tr("The program code may only contain letters, digits, dashes and underscores (at most 10)."));
    if (name.trimmed().isEmpty())
        errors << tr("The program name is required.");
    return errors;
}

QStringList Course::validate(bool isNew) const {
    QStringList errors;
    checkCode(id, isNew, &errors,
              tr("The course code may only contain letters, digits, dashes and underscores (at most 10)."));
    if (programId.isEmpty())
        errors << tr("Please choose a program.");
    if (name.trimmed().isEmpty())
        errors << tr("The course name is required.");
    if (!CatalogValues::levels().contains(level))
        errors << tr("Invalid level.");
    if (sessionCount < CatalogLimits::minSessionCount || sessionCount > CatalogLimits::maxSessionCount)
        errors << tr("A course has %1 to %2 sessions.")
                      .arg(CatalogLimits::minSessionCount)
                      .arg(CatalogLimits::maxSessionCount);
    if (sessionMinutes < CatalogLimits::minSessionMinutes ||
        sessionMinutes > CatalogLimits::maxSessionMinutes)
        errors << tr("A session lasts %1 to %2 minutes.")
                      .arg(CatalogLimits::minSessionMinutes)
                      .arg(CatalogLimits::maxSessionMinutes);
    if (tuition < 0)
        errors << tr("The tuition cannot be negative.");
    if (minPlacementScore &&
        (*minPlacementScore < 0 || *minPlacementScore > CatalogLimits::maxPlacementScore))
        errors << tr("The minimum placement score must be between 0 and %1.")
                      .arg(CatalogLimits::maxPlacementScore);
    if (!prerequisiteId.isEmpty() && prerequisiteId == id)
        errors << tr("A course cannot be its own prerequisite.");
    if (!CatalogValues::courseStatuses().contains(status))
        errors << tr("Invalid status.");
    return errors;
}

QStringList GradeComponent::validate() const {
    QStringList errors;
    if (courseId.isEmpty())
        errors << tr("Please choose a course.");
    if (name.trimmed().isEmpty())
        errors << tr("The component name is required.");
    if (weight <= 0 || weight > CatalogLimits::maxWeight)
        errors << tr("The weight must be above 0 and at most %1.").arg(CatalogLimits::maxWeight);
    return errors;
}

QStringList Promotion::validate(bool isNew) const {
    QStringList errors;
    checkCode(
        id, isNew, &errors,
        tr("The promotion code may only contain letters, digits, dashes and underscores (at most 10)."));
    if (name.trimmed().isEmpty())
        errors << tr("The promotion name is required.");
    if (!CatalogValues::discountTypes().contains(discountType))
        errors << tr("Invalid discount type.");
    if (discountValue <= 0)
        errors << tr("The discount must be greater than 0.");
    else if (discountType == QLatin1String("PERCENT") && discountValue > CatalogLimits::maxPercentDiscount)
        errors << tr("A percentage discount is at most %1%.").arg(CatalogLimits::maxPercentDiscount);
    if (!startDate.isValid() || !endDate.isValid())
        errors << tr("Invalid dates.");
    else if (endDate < startDate)
        errors << tr("The end date cannot be before the start date.");
    return errors;
}
