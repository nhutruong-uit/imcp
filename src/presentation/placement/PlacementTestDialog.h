#pragma once

#include "domain/entities/PlacementTest.h"
#include "presentation/common/FormDialog.h"

class PlacementService;
class StudentService;
class QComboBox;
class QDateEdit;
class QDoubleSpinBox;
class QLabel;
class QLineEdit;
class QPlainTextEdit;

// New placement test: the four skill scores (0-10), the grader and the date. The database computes the
// overall score and recommends the open course that matches it (trg_PLACEMENT_TEST_Recommend); result() gives
// both.
class PlacementTestDialog : public FormDialog {
    Q_OBJECT
public:
    PlacementTestDialog(PlacementService& placement, StudentService& students, const QString& studentId,
                        QWidget* parent = nullptr);
    PlacementResult result() const { return m_result; }

protected:
    bool save() override;

private:
    void searchStudents();
    void updateOverall();

    PlacementService& m_placement;
    StudentService& m_students;
    PlacementResult m_result;
    QLineEdit* m_studentSearch = nullptr;
    QComboBox* m_student = nullptr;
    QDoubleSpinBox* m_listening = nullptr;
    QDoubleSpinBox* m_speaking = nullptr;
    QDoubleSpinBox* m_reading = nullptr;
    QDoubleSpinBox* m_writing = nullptr;
    QLabel* m_overall = nullptr;
    QComboBox* m_grader = nullptr;
    QDateEdit* m_testDate = nullptr;
    QPlainTextEdit* m_notes = nullptr;
};
