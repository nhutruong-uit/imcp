#include "domain/entities/Student.h"

#include "domain/common/Validation.h"

namespace StudentValues {
QStringList genders() {
    return {QStringLiteral("Male"), QStringLiteral("Female"), QStringLiteral("Other")};
}
QStringList statuses() {
    return {QStringLiteral("Prospective"), QStringLiteral("Studying"), QStringLiteral("On hold"),
            QStringLiteral("Dropped out"), QStringLiteral("Completed")};
}
QString activeStatus() {
    return QStringLiteral("Studying");
}
} // namespace StudentValues

// Years between the two dates, minus one when the birthday has not come yet that year
int Student::age(const QDate& asOf) const {
    return Validation::age(dateOfBirth, asOf);
}

bool Student::needsGuardian(const QDate& asOf) const {
    return age(asOf) < 18;
}

// Collects EVERY broken rule (not only the first) so the form can show them all at once. Each rule mirrors a
// constraint of table STUDENT, so the user gets a clear message before the database would reject the row:
//   date of birth / at least 4 years old -> CK_STUDENT_DateOfBirth   gender -> CK_STUDENT_Gender
//   phone formats -> CK_STUDENT_Phone, CK_STUDENT_GuardianPhone       email -> CK_STUDENT_Email
//   under 18 needs a guardian -> CK_STUDENT_Guardian                  one contact phone -> CK_STUDENT_Contact
//   status -> CK_STUDENT_Status                                       branch -> FK_STUDENT_BRANCH (NOT NULL)
//   text lengths -> the column sizes (StudentLimits), which the procedure parameters would cut silently
QStringList Student::validate(const QDate& today) const {
    QStringList errors;
    // The database measures the age on the registration date (RegisteredOn); a new student has none yet,
    // so today's date is used - the date usp_Student_Add will store.
    const QDate ageReference = registeredOn.isValid() ? registeredOn : today;

    if (fullName.trimmed().isEmpty())
        errors << tr("Full name is required.");
    else if (fullName.trimmed().size() > StudentLimits::fullName)
        errors << tr("Full name must be at most 100 characters.");

    if (!dateOfBirth.isValid())
        errors << tr("Invalid date of birth.");
    else if (dateOfBirth <= QDate(1930, 1, 1) || age(ageReference) < 4)
        errors << tr("Students must be at least 4 years old.");

    if (!StudentValues::genders().contains(gender))
        errors << tr("Invalid gender.");

    if (!phone.isEmpty() && !Validation::isPhone(phone))
        errors << tr("Phone numbers contain 9-11 digits only.");
    if (!guardianPhone.isEmpty() && !Validation::isPhone(guardianPhone))
        errors << tr("Guardian phone numbers contain 9-11 digits only.");
    if (!email.isEmpty() && (email.size() > StudentLimits::email || !Validation::isEmail(email)))
        errors << tr("Invalid email address.");
    if (address.size() > StudentLimits::address)
        errors << tr("Address must be at most %1 characters.").arg(StudentLimits::address);
    if (occupation.size() > StudentLimits::occupation)
        errors << tr("Occupation must be at most %1 characters.").arg(StudentLimits::occupation);
    if (guardianName.size() > StudentLimits::guardianName)
        errors << tr("Guardian name must be at most %1 characters.").arg(StudentLimits::guardianName);
    if (notes.size() > StudentLimits::notes)
        errors << tr("Notes must be at most %1 characters.").arg(StudentLimits::notes);

    if (dateOfBirth.isValid() && needsGuardian(ageReference) &&
        (guardianName.trimmed().isEmpty() || guardianPhone.isEmpty()))
        errors << tr("Students under 18 need a guardian name and phone number.");

    if (phone.isEmpty() && guardianPhone.isEmpty())
        errors << tr("At least one contact phone number is required (student or guardian).");

    if (branchId.isEmpty())
        errors << tr("Please choose a branch.");

    if (!StudentValues::statuses().contains(status))
        errors << tr("Invalid status.");

    if (registeredOn.isValid() && registeredOn > today)
        errors << tr("The registration date cannot be in the future.");

    return errors;
}
