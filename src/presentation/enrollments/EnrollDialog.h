#pragma once

#include "domain/entities/ClassInfo.h"
#include "presentation/common/FormDialog.h"

class EnrollmentService;
class StudentService;
class QComboBox;
class QDateEdit;
class QLabel;
class QLineEdit;

// New enrollment: find the student (usp_Student_Search), choose an open class and an optional promotion valid
// on the enrollment date. usp_Enrollment_Create then checks the entry requirement (prerequisite course or
// placement score), the schedule clash, the free seats and the promotion, and answers with a clear message
// when one is not met.
class EnrollDialog : public FormDialog {
    Q_OBJECT
public:
    // studentId / classId: preselected (from the Students or Classes page); empty = choose
    EnrollDialog(EnrollmentService& enrollments, StudentService& students, const QString& studentId,
                 const QString& classId, QWidget* parent = nullptr);
    QString enrollmentId() const { return m_enrollmentId; }

protected:
    bool save() override;

private:
    void searchStudents();
    void loadPromotions();
    void showClassInfo();

    EnrollmentService& m_enrollments;
    StudentService& m_students;
    QList<ClassOption> m_classes;
    QString m_enrollmentId;
    QLineEdit* m_studentSearch = nullptr;
    QComboBox* m_student = nullptr;
    QComboBox* m_class = nullptr;
    QLabel* m_classInfo = nullptr;
    QDateEdit* m_enrolledOn = nullptr;
    QComboBox* m_promotion = nullptr;
};
