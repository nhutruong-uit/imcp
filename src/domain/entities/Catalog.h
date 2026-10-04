#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>
#include <optional>

// Reference data of the center (the catalogs maintained by the manager through the procedures of group J:
// usp_Branch_Add ... usp_Promotion_Update). Each struct has one field per column, and validate() repeats the
// CHECK constraints of database/01_tables.sql so the form can say what is wrong before the database refuses
// it. isNew: the code of a new row must be well formed (THROW 50092); the code of an existing row cannot
// change.

// Stored values of the CHECK ... IN (...) lists of the catalog tables
namespace CatalogValues {
QStringList branchStatuses();         // Active, Suspended
QStringList roomTypes();              // Lecture, Lab, Multi-purpose
QStringList roomStatuses();           // Available, Maintenance
QStringList levels();                 // A1 ... C2 (CEFR)
QStringList courseStatuses();         // Open, Discontinued
QStringList discountTypes();          // PERCENT, AMOUNT (codes, shown through the presentation layer)
inline constexpr int codeLength = 10; // every code column is VARCHAR(10)
} // namespace CatalogValues

// A branch (table BRANCH). The student screens only need id and name (active branches for the combo boxes).
struct Branch {
    QString id;
    QString name;
    QString address;
    QString phone;
    QString email;
    QDate foundedOn;
    QString status = QStringLiteral("Active");

    QStringList validate(bool isNew) const;

    Q_DECLARE_TR_FUNCTIONS(Branch)
};

// A classroom of a branch (table ROOM)
struct Room {
    QString id;
    QString branchId;
    QString name;
    int capacity = 20;
    QString type = QStringLiteral("Lecture");
    QString status = QStringLiteral("Available");

    QStringList validate(bool isNew) const;

    Q_DECLARE_TR_FUNCTIONS(Room)
};

// A training program (table PROGRAM): IELTS, TOEIC...
struct Program {
    QString id;
    QString name;
    QString targetLearners;
    QString description;

    QStringList validate(bool isNew) const;

    Q_DECLARE_TR_FUNCTIONS(Program)
};

// A course of a program (table COURSE); the syllabus (typed XML) is edited on its own
// (usp_Course_SetSyllabus)
struct Course {
    QString id;
    QString programId;
    QString name;
    QString level = QStringLiteral("A1");
    int sessionCount = 20;
    int sessionMinutes = 90;
    qint64 tuition = 0;
    std::optional<double> minPlacementScore; // empty = no entry score
    QString prerequisiteId;                  // empty = no prerequisite course
    QString status = QStringLiteral("Open");

    QStringList validate(bool isNew) const;

    Q_DECLARE_TR_FUNCTIONS(Course)
};

// A grade component of a course (table GRADE_COMPONENT); id 0 = a new component (IDENTITY)
struct GradeComponent {
    int id = 0;
    QString courseId;
    QString name;
    double weight = 0;

    QStringList validate() const;

    Q_DECLARE_TR_FUNCTIONS(GradeComponent)
};

// A tuition promotion (table PROMOTION): PERCENT (at most 50) or AMOUNT in VND
struct Promotion {
    QString id;
    QString name;
    QString discountType = QStringLiteral("PERCENT");
    double discountValue = 0;
    QDate startDate;
    QDate endDate;

    QStringList validate(bool isNew) const;

    Q_DECLARE_TR_FUNCTIONS(Promotion)
};
