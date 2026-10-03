#pragma once

#include "presentation/main/AppServices.h"

#include <QDialog>

// Profile of one student: the identity, every enrollment with its tuition, payments, status and result
// (usp_Enrollment_Search for the student) and, for the roles that handle admissions, the placement tests
// (usp_PlacementTest_Search for the student).
class StudentProfileDialog : public QDialog {
    Q_OBJECT
public:
    StudentProfileDialog(AppServices services, const QString& studentId, QWidget* parent = nullptr);
};
