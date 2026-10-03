#include "application/services/CourseService.h"

#include "domain/common/Validation.h"

CourseService::CourseService(ICourseRepository& repository) : m_repository(repository) {}

Result<TableData> CourseService::list() {
    return m_repository.list();
}

Result<QList<LookupItem>> CourseService::options() {
    return m_repository.options();
}

Result<Course> CourseService::details(const QString& id) {
    if (id.isEmpty())
        return Result<Course>::failure(tr("No course is selected."));
    return m_repository.findById(id);
}

VoidResult CourseService::save(const Course& c, bool isNew) {
    Course course = c;
    course.id = course.id.trimmed().toUpper();
    course.name = course.name.simplified();
    const QStringList errors = course.validate(isNew);
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return isNew ? m_repository.add(course) : m_repository.update(course);
}

Result<TableData> CourseService::syllabus(const QString& courseId) {
    if (courseId.isEmpty())
        return Result<TableData>::failure(tr("No course is selected."));
    return m_repository.syllabus(courseId);
}

Result<QString> CourseService::syllabusXml(const QString& courseId) {
    if (courseId.isEmpty())
        return Result<QString>::failure(tr("No course is selected."));
    return m_repository.syllabusXml(courseId);
}

VoidResult CourseService::setSyllabus(const QString& courseId, const QString& xml) {
    if (courseId.isEmpty())
        return VoidResult::failure(tr("No course is selected."));
    return m_repository.setSyllabus(courseId, Validation::withoutXmlDeclaration(xml));
}

Result<TableData> CourseService::findBySkill(const QString& skill) {
    if (skill.trimmed().isEmpty())
        return Result<TableData>::failure(tr("Please enter a skill, for example Speaking."));
    return m_repository.findBySkill(skill.trimmed());
}

Result<TableData> CourseService::components(const QString& courseId) {
    return m_repository.components(courseId);
}

VoidResult CourseService::saveComponent(const GradeComponent& c) {
    GradeComponent component = c;
    component.name = component.name.simplified();
    const QStringList errors = component.validate();
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return m_repository.saveComponent(component);
}

VoidResult CourseService::removeComponent(int componentId) {
    if (componentId <= 0)
        return VoidResult::failure(tr("No grade component is selected."));
    return m_repository.removeComponent(componentId);
}
