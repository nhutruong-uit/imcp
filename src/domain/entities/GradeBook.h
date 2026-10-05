#pragma once

#include <QHash>
#include <QList>
#include <QString>
#include <optional>

/// GRADE.Score is 0-10 with 2 decimals (CK_GRADE_Score, DECIMAL(4,2)). Below passMark a student fails
// whatever the attendance; at passMark or above the result also needs 80% attendance
// (usp_Class_EvaluateResults).
namespace GradeLimits {
inline constexpr double minScore = 0;
inline constexpr double maxScore = 10;
inline constexpr int decimals = 2;
inline constexpr double passMark = 5;
} // namespace GradeLimits

// One grade component of a course (GRADE_COMPONENT): its weight in percent
struct GradeComponentInfo {
    int id = 0;
    QString name;
    double weight = 0;
};

// One row of usp_Grade_ByClass / vw_Teacher_MyGrades: one student and one component, the score when entered
struct GradeCell {
    QString enrollmentId;
    QString studentId;
    QString studentName;
    int componentId = 0;
    QString componentName;
    double weight = 0;
    std::optional<double> score;
};

// One student of the grade book: the score of every component (no entry / nullopt = not entered yet)
struct GradeBookRow {
    QString enrollmentId;
    QString studentId;
    QString studentName;
    QHash<int, std::optional<double>> scores; // key = ComponentId
};

// The grade book of a class: the database returns one row per student and component ("long" form); the screen
// shows one row per student with one column per component ("wide" form). fromCells() makes that pivot.
struct GradeBook {
    QList<GradeComponentInfo> components; // in the order of the database (ComponentId)
    QList<GradeBookRow> rows;             // in the order of the database (student name)

    static GradeBook fromCells(const QList<GradeCell>& cells);
    // The same formula as dbo.fn_FinalGrade: SUM(score x weight) / 100, rounded once to 2 decimals;
    // nullopt while a component has no score (or the course has no component)
    std::optional<double> finalGrade(int row) const;
    double totalWeight() const; // must be 100 before the class can be evaluated (vw_CourseInvalidWeights)
    // The weights add up to 100 (to 0.001: 99.99 is not complete); vw_CourseInvalidWeights lists the courses
    // where they do not, and usp_Class_EvaluateResults refuses their classes
    bool weightsComplete() const;
};

// A score to save with usp_Grade_Save
struct GradeEntry {
    QString enrollmentId;
    int componentId = 0;
    double score = 0;
};
