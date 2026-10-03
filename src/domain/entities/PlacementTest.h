#pragma once

#include <QCoreApplication>
#include <QDate>
#include <QString>
#include <QStringList>

// A placement test before enrolling (table PLACEMENT_TEST): four skills scored 0-10
// (CK_PLACEMENT_TEST_Scores). The database computes OverallScore (the average) and recommends a course
// (trg_PLACEMENT_TEST_Recommend); usp_PlacementTest_Add returns both (PlacementResult).
struct PlacementTest {
    QString studentId;
    double listening = 0;
    double speaking = 0;
    double reading = 0;
    double writing = 0;
    QString teacherId; // who graded it, empty = not recorded
    QString notes;
    QDate testDate; // empty = today

    double overall() const; // the same average as the computed column OverallScore (2 decimals)
    QStringList validate(const QDate& today) const;

    Q_DECLARE_TR_FUNCTIONS(PlacementTest)
};

struct PlacementResult {
    QString testId;
    double overallScore = 0;
    QString recommendedCourseId; // empty: no open course matches the score
    QString recommendedCourse;
};

// PLACEMENT_TEST.Notes is NVARCHAR(200)
namespace PlacementLimits {
inline constexpr int notes = 200;
}
