#pragma once

#include "application/ports/IGradeRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IGradeRepository with SQL Server: the class lists (vw_ClassDetails, or vw_Teacher_MyClasses for a teacher),
// the grade book (usp_Grade_ByClass, or vw_Teacher_MyGrades for a teacher) and usp_Grade_Save.
class SqlGradeRepository : public IGradeRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlGradeRepository)
public:
    explicit SqlGradeRepository(DatabaseManager& db);
    Result<QList<ClassOption>> classes(bool mineOnly) override;
    Result<QList<GradeCell>> cells(const QString& classId, bool mineOnly) override;
    VoidResult save(const QList<GradeEntry>& entries) override;

private:
    DatabaseManager& m_db;
};
