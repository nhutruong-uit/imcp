#pragma once

#include "presentation/common/DataPage.h"

class QComboBox;

// Enrollments page: every enrollment (usp_Enrollment_Search) with its tuition, payments and result, filtered
// by status; academic staff enroll students, transfer them to another class of the same course and branch,
// put an enrollment on hold, resume it or end it (usp_Enrollment_Create / _TransferClass / _UpdateStatus).
class EnrollmentPage : public DataPage {
    Q_OBJECT
public:
    explicit EnrollmentPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void enroll();
    void transfer();
    void changeStatus(const QString& status);

    QComboBox* m_statusFilter = nullptr;
};
