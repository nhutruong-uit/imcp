#pragma once

#include "presentation/common/DataPage.h"

// My classes page (teachers): the classes the signed-in teacher teaches (vw_Teacher_MyClasses, a security
// view), the students of a class without contact data or money (vw_Teacher_MyStudents) and the syllabus of
// its course (usp_Course_Syllabus).
class MyClassesPage : public DataPage {
    Q_OBJECT
public:
    explicit MyClassesPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void showStudents();
    void showSyllabus();
};
