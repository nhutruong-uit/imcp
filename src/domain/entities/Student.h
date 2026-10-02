#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>

// Valid values - identical to the CHECK constraints of table STUDENT.
// These are the values STORED in the database (language-neutral codes, written in English);
// DbValues::label (presentation) turns them into display text in the UI language.
namespace StudentValues {
QStringList genders();  // Male, Female, Other
QStringList statuses(); // Prospective, Studying, On hold, Dropped out
QString activeStatus(); // "Studying"
} // namespace StudentValues

// Student entity (table STUDENT) plus a few aggregated fields shown in the list
struct Student {
    QString id;
    QString fullName;
    QDate dateOfBirth;
    QString gender = QStringLiteral("Male");
    QString phone;
    QString email;
    QString address;
    QString occupation;
    QString guardianName;
    QString guardianPhone;
    QString branchId;
    QDate registeredOn;
    QString status = QStringLiteral("Prospective");
    QString notes;

    // Display only (from view vw_StudentOverview)
    QString branchName;
    int activeClassCount = 0;
    qint64 outstandingBalance = 0;

    int age(const QDate& asOf) const;
    bool needsGuardian(const QDate& asOf) const;

    // Business rules checked in the application for fast feedback.
    // The database remains the final check (CHECK constraints, triggers, procedures).
    // Messages are translated into the UI language when created (tr() is Qt Core, no UI dependency).
    QStringList validate(const QDate& today) const;

    // Declares tr() with translation context "Student". The macro ends with "private:", so keep it last.
    Q_DECLARE_TR_FUNCTIONS(Student)
};

// Student search criteria
struct StudentFilter {
    QString keyword;
    QString branchId; // empty = all branches
    QString status;   // empty = all statuses
};
