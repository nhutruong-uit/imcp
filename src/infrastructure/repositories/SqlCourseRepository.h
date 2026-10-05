#pragma once

#include "application/ports/ICourseRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// ICourseRepository with SQL Server: COURSE, PROGRAM and GRADE_COMPONENT (granted to academic staff for
// reading), the XML procedures usp_Course_Syllabus / _FindBySkill / _SetSyllabus and the catalog procedures
// usp_Course_Add / _Update, usp_GradeComponent_Save / _Delete (manager).
class SqlCourseRepository : public ICourseRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlCourseRepository)
public:
    explicit SqlCourseRepository(DatabaseManager& db);
    Result<TableData> list() override;
    Result<QList<LookupItem>> options() override;
    Result<Course> findById(const QString& id) override;
    VoidResult add(const Course& c) override;
    VoidResult update(const Course& c) override;
    Result<TableData> syllabus(const QString& courseId) override;
    Result<QString> syllabusXml(const QString& courseId) override;
    VoidResult setSyllabus(const QString& courseId, const QString& xml) override;
    Result<TableData> findBySkill(const QString& skill) override;
    Result<TableData> components(const QString& courseId) override;
    VoidResult saveComponent(const GradeComponent& c) override;
    VoidResult removeComponent(int componentId) override;

private:
    DatabaseManager& m_db;
};
