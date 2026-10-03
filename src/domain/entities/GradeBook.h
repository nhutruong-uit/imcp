#pragma once

#include <QHash>
#include <QList>
#include <QString>
#include <optional>

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
};

// A score to save with usp_Grade_Save
struct GradeEntry {
    QString enrollmentId;
    int componentId = 0;
    double score = 0;
};
