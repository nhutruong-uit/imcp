#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>
#include <QTime>

// Stored values of CLASS.Status (CK_CLASS_Status) and the life cycle usp_Class_UpdateStatus allows:
// Enrolling -> In progress -> Finished (by usp_Class_EvaluateResults), or Enrolling / In progress ->
// Cancelled
namespace ClassValues {
QStringList statuses(); // Enrolling, In progress, Finished, Cancelled
QString enrolling();
QString inProgress();
QString finished();
QString cancelled();
} // namespace ClassValues

// Sizes and ranges of table CLASS (ClassName NVARCHAR(100), CK_CLASS_MaxStudents 1-50)
namespace ClassLimits {
inline constexpr int name = 100;
inline constexpr int minStudents = 1;
inline constexpr int maxStudents = 50;
} // namespace ClassLimits

// A class (table CLASS): one run of a course at a branch, with its main teacher and room.
// Written by usp_Class_Create (new, id empty) and usp_Class_Update (existing); the ID CL0001... comes from
// the database. "ClassInfo" because "class" is a C++ keyword.
struct ClassInfo {
    QString id;
    QString name;
    QString courseId;
    QString branchId;
    QString teacherId;
    QString roomId;
    QDate startDate;
    int maxStudents = 20;
    qint64 tuition = 0; // the price of this class (copied from the course when the class is opened)
    QString status;     // empty for a new class: the database starts it as Enrolling

    // Rules checked before the database: required references, sizes and ranges of CLASS. The room/branch,
    // room capacity and schedule clash rules need other tables and stay with the triggers.
    QStringList validate() const;

    Q_DECLARE_TR_FUNCTIONS(ClassInfo)
};

// Filter of the class list (empty = all)
struct ClassFilter {
    QString branchId;
    QString status;
};

// One weekly time slot of a class (table CLASS_SCHEDULE): ISO weekday 1 = Monday ... 7 = Sunday
struct ScheduleSlot {
    int weekday = 1;
    QTime start;
    QTime end;

    // CK_CLASS_SCHEDULE_Weekday and CK_CLASS_SCHEDULE_Time: 1-7, ends after it starts, within 07:00-22:00
    QStringList validate() const;

    Q_DECLARE_TR_FUNCTIONS(ScheduleSlot)
};

// A class as offered in a picker (enrollment, transfer, grade book): from vw_ClassDetails
struct ClassOption {
    QString id;
    QString name;
    QString courseId;
    QString courseName;
    QString branchId;
    QString branchName;
    QString status;
    qint64 tuition = 0;
    int seatsLeft = 0;
};

// What usp_Class_GenerateSessions and usp_Class_EvaluateResults return
struct SessionsGenerated {
    int count = 0;
    QDate endDate;
};
struct EvaluationResult {
    int passed = 0;
    int failed = 0;
};
