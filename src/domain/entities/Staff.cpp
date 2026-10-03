#include "domain/entities/Staff.h"

#include "domain/common/Validation.h"
#include "domain/entities/Student.h"

namespace StaffValues {
QStringList positions() {
    return {QStringLiteral("Manager"), QStringLiteral("Academic staff"), QStringLiteral("Accountant"),
            QStringLiteral("Consultant")};
}
QStringList employeeStatuses() {
    return {QStringLiteral("Working"), QStringLiteral("Left")};
}
QStringList degrees() {
    return {QStringLiteral("Bachelor"), QStringLiteral("Master"), QStringLiteral("PhD")};
}
QStringList teacherTypes() {
    return {QStringLiteral("Vietnamese"), QStringLiteral("Native")};
}
QStringList teacherStatuses() {
    return {QStringLiteral("Teaching"), QStringLiteral("On leave"), QStringLiteral("Left")};
}
} // namespace StaffValues

namespace {
// The rules EMPLOYEE and TEACHER share: name, birth date, gender, at least 18 on the hire date (CK_..._Age)
void checkPerson(const QString& fullName, const QDate& dateOfBirth, const QString& gender,
                 const QDate& hireDate, const QDate& today, QStringList* errors) {
    if (fullName.trimmed().isEmpty())
        *errors << Employee::tr("Full name is required.");
    else if (fullName.trimmed().size() > StaffLimits::fullName)
        *errors << Employee::tr("Full name must be at most %1 characters.").arg(StaffLimits::fullName);
    if (!dateOfBirth.isValid())
        *errors << Employee::tr("Invalid date of birth.");
    else if (Validation::age(dateOfBirth, hireDate.isValid() ? hireDate : today) < 18)
        *errors << Employee::tr("Staff must be at least 18 years old on the hire date.");
    if (!StudentValues::genders().contains(gender))
        *errors << Employee::tr("Invalid gender.");
}
} // namespace

QStringList Employee::validate(const QDate& today) const {
    QStringList errors;
    checkPerson(fullName, dateOfBirth, gender, hireDate, today, &errors);
    if (!Validation::isPhone(phone))
        errors << tr("Phone numbers contain 9-11 digits only.");
    if (!email.isEmpty() && (email.size() > StaffLimits::email || !Validation::isEmail(email)))
        errors << tr("Invalid email address.");
    if (address.size() > StaffLimits::address)
        errors << tr("Address must be at most %1 characters.").arg(StaffLimits::address);
    if (!StaffValues::positions().contains(position))
        errors << tr("Invalid position.");
    if (branchId.isEmpty())
        errors << tr("Please choose a branch.");
    if (baseSalary < 0)
        errors << tr("The salary cannot be negative.");
    if (!StaffValues::employeeStatuses().contains(status))
        errors << tr("Invalid status.");
    return errors;
}

QStringList Teacher::validate(const QDate& today) const {
    QStringList errors;
    checkPerson(fullName, dateOfBirth, gender, hireDate, today, &errors);
    if (!Validation::isPhone(phone))
        errors << tr("Phone numbers contain 9-11 digits only.");
    if (email.isEmpty() || email.size() > StaffLimits::email || !Validation::isEmail(email))
        errors << tr("A valid email address is required.");
    if (nationality.trimmed().isEmpty() || nationality.size() > StaffLimits::nationality)
        errors << tr("The nationality is required.");
    else if (teacherType == QLatin1String("Native") && nationality.trimmed() == QLatin1String("Vietnam"))
        errors << tr("A native-speaker teacher cannot have Vietnamese nationality.");
    if (!StaffValues::degrees().contains(degree))
        errors << tr("Invalid degree.");
    if (!StaffValues::teacherTypes().contains(teacherType))
        errors << tr("Invalid teacher type.");
    if (hourlyRate <= 0)
        errors << tr("The hourly rate must be greater than 0.");
    if (branchId.isEmpty())
        errors << tr("Please choose a branch.");
    if (!StaffValues::teacherStatuses().contains(status))
        errors << tr("Invalid status.");
    return errors;
}
