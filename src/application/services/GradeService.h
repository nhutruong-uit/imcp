#pragma once

#include "application/ports/IGradeRepository.h"

#include <QCoreApplication>

// Grade book use case: read the grade book of a class as students x components (GradeBook::fromCells) and
// save the changed scores. The database checks the class (a teacher only grades their classes, 50041; nobody
// changes the grades of a finished class, 50042) and logs every change (trg_GRADE_Audit). Used by
// GradeBookPage.
class GradeService {
    Q_DECLARE_TR_FUNCTIONS(GradeService)
public:
    explicit GradeService(IGradeRepository& repository);

    Result<QList<ClassOption>> classes(bool mineOnly);
    Result<GradeBook> book(const QString& classId, bool mineOnly);
    VoidResult save(const QList<GradeEntry>& entries);

private:
    IGradeRepository& m_repository;
};
