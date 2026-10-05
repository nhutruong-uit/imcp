#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/Catalog.h"

#include <QList>

// Port of the Courses screen: courses, their grade components and XML syllabus. Implemented by
// SqlCourseRepository (COURSE, GRADE_COMPONENT, usp_Course_*, usp_GradeComponent_*), used by CourseService.
class ICourseRepository {
public:
    virtual ~ICourseRepository() = default;
    virtual Result<TableData> list() = 0; // every course with its program, prerequisite and total weight
    virtual Result<QList<LookupItem>> options() = 0; // every course (prerequisite picker)
    virtual Result<Course> findById(const QString& id) = 0;
    virtual VoidResult add(const Course& c) = 0;    // usp_Course_Add
    virtual VoidResult update(const Course& c) = 0; // usp_Course_Update

    virtual Result<TableData> syllabus(const QString& courseId) = 0;  // usp_Course_Syllabus (units)
    virtual Result<QString> syllabusXml(const QString& courseId) = 0; // the XML document itself
    virtual VoidResult setSyllabus(const QString& courseId, const QString& xml) = 0; // empty = remove
    virtual Result<TableData> findBySkill(const QString& skill) = 0;                 // usp_Course_FindBySkill

    virtual Result<TableData> components(const QString& courseId) = 0;
    virtual VoidResult saveComponent(const GradeComponent& c) = 0; // usp_GradeComponent_Save
    virtual VoidResult removeComponent(int componentId) = 0;       // usp_GradeComponent_Delete
};
