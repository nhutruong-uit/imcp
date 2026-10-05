#include "presentation/teaching/MyClassesPage.h"

#include "presentation/common/DataTable.h"
#include "presentation/common/Labels.h"
#include "presentation/common/TableDialog.h"
#include "presentation/common/UiHelpers.h"

MyClassesPage::MyClassesPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::MyClasses, parent) {
    table()->setHiddenColumns({QStringLiteral("CourseId")});
    addAction(tr("Students"), QStringLiteral("users"), QStringLiteral("studentsButton"), true,
              [this] { showStudents(); });
    addAction(tr("Syllabus"), QStringLiteral("book-open"), QStringLiteral("syllabusButton"), true,
              [this] { showSyllabus(); });
    connect(table(), &DataTable::activated, this, &MyClassesPage::showStudents);
    reload();
}

Result<TableData> MyClassesPage::fetch() {
    return m_services.lists.fetch(Feature::MyClasses);
}

void MyClassesPage::showStudents() {
    const QString classId = selected(QStringLiteral("ClassId")).toString();
    const auto students = m_services.classes.students(classId, true);
    if (!students.ok()) {
        UiHelpers::showError(this, students.error());
        return;
    }
    TableDialog dialog(
        tr("Students of class %1 - %2").arg(classId, selected(QStringLiteral("ClassName")).toString()),
        Labels::accountName(m_services.auth.account()), this);
    dialog.setData(students.value());
    dialog.exec();
}

void MyClassesPage::showSyllabus() {
    const QString courseId = selected(QStringLiteral("CourseId")).toString();
    const auto units = m_services.courses.syllabus(courseId);
    if (!units.ok()) {
        UiHelpers::showError(this, units.error());
        return;
    }
    TableDialog dialog(tr("Syllabus of %1").arg(selected(QStringLiteral("CourseName")).toString()),
                       Labels::accountName(m_services.auth.account()), this);
    dialog.setSubtitle(units.value().rows.isEmpty() ? tr("This course has no syllabus yet.") : QString());
    dialog.setData(units.value());
    dialog.exec();
}
