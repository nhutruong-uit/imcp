#pragma once

#include "domain/common/Result.h"
#include "domain/entities/ClassInfo.h"
#include "domain/entities/GradeBook.h"

#include <QList>

// Port of the grade book screens: implemented by SqlGradeRepository (usp_Grade_ByClass / vw_Teacher_MyGrades,
// usp_Grade_Save), used by GradeService. mineOnly = the signed-in teacher's classes (teacher views).
class IGradeRepository {
public:
    virtual ~IGradeRepository() = default;
    virtual Result<QList<ClassOption>> classes(bool mineOnly) = 0;
    virtual Result<QList<GradeCell>> cells(const QString& classId, bool mineOnly) = 0;
    virtual VoidResult save(const QList<GradeEntry>& entries) = 0; // usp_Grade_Save, all in one transaction
};
