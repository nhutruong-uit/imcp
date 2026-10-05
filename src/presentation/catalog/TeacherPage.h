#pragma once

#include "presentation/common/DataPage.h"

// Teachers page: the teachers with their type, degree, branch and number of active classes (only the columns
// that academic staff may read - column-level GRANT on TEACHER). Everyone here may search teachers by
// certificate (usp_Teacher_FindByCertificate, XQuery on the XML profile); the manager adds and changes
// teachers, their hourly rate and XML profile (usp_Teacher_Add / _Update).
class TeacherPage : public DataPage {
    Q_OBJECT
public:
    explicit TeacherPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void editTeacher(bool isNew);
    void findByCertificate();
};
