#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>

// Stored values of the CHECK ... IN (...) lists of EMPLOYEE and TEACHER
namespace StaffValues {
QStringList positions();        // Manager, Academic staff, Accountant, Consultant
QStringList employeeStatuses(); // Working, Left
QStringList degrees();          // Bachelor, Master, PhD
QStringList teacherTypes();     // Vietnamese, Native
QStringList teacherStatuses();  // Teaching, On leave, Left
} // namespace StaffValues

// Text sizes of EMPLOYEE / TEACHER
namespace StaffLimits {
inline constexpr int fullName = 100;
inline constexpr int email = 100;
inline constexpr int address = 200;
inline constexpr int nationality = 50;
} // namespace StaffLimits

// An office employee (table EMPLOYEE); id EM0001... comes from the database (usp_Employee_Add)
struct Employee {
    QString id;
    QString fullName;
    QDate dateOfBirth;
    QString gender = QStringLiteral("Female");
    QString phone;
    QString email;
    QString address;
    QString position = QStringLiteral("Consultant");
    QString branchId;
    QDate hireDate; // empty for a new employee = today
    qint64 baseSalary = 0;
    QString status = QStringLiteral("Working");

    // CK_EMPLOYEE_*: phone 9-11 digits (required), email format, gender, position, salary >= 0, at least 18
    // years old on the hire date
    QStringList validate(const QDate& today) const;

    Q_DECLARE_TR_FUNCTIONS(Employee)
};

// A teacher (table TEACHER); id TE0001... comes from the database (usp_Teacher_Add). profileXml is the
// untyped XML profile (certificates, experience) read by usp_Teacher_FindByCertificate.
struct Teacher {
    QString id;
    QString fullName;
    QDate dateOfBirth;
    QString gender = QStringLiteral("Female");
    QString nationality = QStringLiteral("Vietnam");
    QString phone;
    QString email;
    QString degree = QStringLiteral("Bachelor");
    QString teacherType = QStringLiteral("Vietnamese");
    qint64 hourlyRate = 0;
    QString branchId;
    QDate hireDate;
    QString profileXml;
    QString status = QStringLiteral("Teaching");

    // CK_TEACHER_*: phone and email required, degree, type, hourly rate > 0, a native speaker is not of
    // Vietnamese nationality, at least 18 years old on the hire date
    QStringList validate(const QDate& today) const;

    Q_DECLARE_TR_FUNCTIONS(Teacher)
};
