#include "domain/entities/Student.h"

#include <QRegularExpression>

namespace StudentValues {
QStringList genders() {
    return {QStringLiteral("Male"), QStringLiteral("Female"), QStringLiteral("Other")};
}
QStringList statuses() {
    return {QStringLiteral("Prospective"), QStringLiteral("Studying"), QStringLiteral("On hold"),
            QStringLiteral("Dropped out")};
}
QString activeStatus() {
    return QStringLiteral("Studying");
}
} // namespace StudentValues

namespace {
bool isValidPhone(const QString& phone) {
    static const QRegularExpression pattern(QStringLiteral("^[0-9]{9,11}$"));
    return pattern.match(phone).hasMatch();
}

bool isValidEmail(const QString& email) {
    static const QRegularExpression pattern(QStringLiteral("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"));
    return pattern.match(email).hasMatch();
}
} // namespace

int Student::age(const QDate& asOf) const {
    if (!dateOfBirth.isValid() || !asOf.isValid())
        return 0;
    int years = asOf.year() - dateOfBirth.year();
    if (asOf.month() < dateOfBirth.month() ||
        (asOf.month() == dateOfBirth.month() && asOf.day() < dateOfBirth.day()))
        --years;
    return years;
}

bool Student::needsGuardian(const QDate& asOf) const {
    return age(asOf) < 18;
}

QStringList Student::validate(const QDate& today) const {
    QStringList errors;
    const QDate ageReference = registeredOn.isValid() ? registeredOn : today;

    if (fullName.trimmed().isEmpty())
        errors << tr("Full name is required.");
    else if (fullName.trimmed().size() > 100)
        errors << tr("Full name must be at most 100 characters.");

    if (!dateOfBirth.isValid())
        errors << tr("Invalid date of birth.");
    else if (dateOfBirth <= QDate(1930, 1, 1) || age(ageReference) < 4)
        errors << tr("Students must be at least 4 years old.");

    if (!StudentValues::genders().contains(gender))
        errors << tr("Invalid gender.");

    if (!phone.isEmpty() && !isValidPhone(phone))
        errors << tr("Phone numbers contain 9-11 digits only.");
    if (!guardianPhone.isEmpty() && !isValidPhone(guardianPhone))
        errors << tr("Guardian phone numbers contain 9-11 digits only.");
    if (!email.isEmpty() && !isValidEmail(email))
        errors << tr("Invalid email address.");

    if (dateOfBirth.isValid() && needsGuardian(ageReference) &&
        (guardianName.trimmed().isEmpty() || guardianPhone.isEmpty()))
        errors << tr("Students under 18 need a guardian name and phone number.");

    if (phone.isEmpty() && guardianPhone.isEmpty())
        errors << tr("At least one contact phone number is required (student or guardian).");

    if (branchId.isEmpty())
        errors << tr("Please choose a branch.");

    if (!StudentValues::statuses().contains(status))
        errors << tr("Invalid status.");

    return errors;
}
