#pragma once

#include "application/ports/ICourseRepository.h"

#include <QCoreApplication>

// Courses use case: the course catalog, its grade components (the weights must add up to 100 before a class
// can be evaluated) and its XML syllabus (typed XML validated by the database). Academic staff only read it;
// the manager changes it. Used by CoursePage.
class CourseService {
    Q_DECLARE_TR_FUNCTIONS(CourseService)
public:
    explicit CourseService(ICourseRepository& repository);

    Result<TableData> list();
    Result<QList<LookupItem>> options();
    Result<Course> details(const QString& id);
    VoidResult save(const Course& c, bool isNew);
    Result<TableData> syllabus(const QString& courseId);
    Result<QString> syllabusXml(const QString& courseId);
    VoidResult setSyllabus(const QString& courseId, const QString& xml);
    Result<TableData> findBySkill(const QString& skill);
    Result<TableData> components(const QString& courseId);
    VoidResult saveComponent(const GradeComponent& c);
    VoidResult removeComponent(int componentId);

private:
    ICourseRepository& m_repository;
};
