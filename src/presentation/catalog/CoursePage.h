#pragma once

#include "presentation/common/DataPage.h"

class QLabel;
class QPushButton;

// Courses page: the courses with their program, level, sessions, tuition, entry requirement and the total of
// their grade weights; below them the grade components of the selected course. Academic staff read it
// (syllabus, search by skill); the manager also adds and changes courses (usp_Course_Add / _Update, with the
// recursive check of the prerequisite chain), their XML syllabus (usp_Course_SetSyllabus, validated by the
// XML schema), their grade components (usp_GradeComponent_Save / _Delete) and the programs (usp_Program_Add /
// _Update).
class CoursePage : public DataPage {
    Q_OBJECT
public:
    explicit CoursePage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;
    void dataLoaded() override;

private:
    QString selectedCourseId() const;
    void loadComponents();
    void editCourse(bool isNew);
    void showSyllabus();
    void findBySkill();
    void showPrograms();
    void editComponent(bool isNew);
    void removeComponent();

    QLabel* m_componentsTitle = nullptr;
    DataTable* m_components = nullptr;
    QPushButton* m_editComponent = nullptr;
    QPushButton* m_removeComponent = nullptr;
};
