#pragma once

#include "domain/entities/Branch.h"
#include "domain/entities/Student.h"

#include <QDialog>
#include <memory>

class StudentService;

namespace Ui {
class StudentFormDialog;
}

// Add/edit student form. The layout is designed in Qt Designer (StudentFormDialog.ui)
class StudentFormDialog : public QDialog {
    Q_OBJECT
public:
    // An empty student (no id) => "add" mode
    StudentFormDialog(StudentService& service, const QList<Branch>& branches, const Student& student,
                      QWidget* parent = nullptr);
    ~StudentFormDialog() override;

    QString savedStudentId() const { return m_savedId; }

private slots:
    void save();
    void updateGuardianGroup();

private:
    Student readForm() const;
    void fillForm(const Student& s);

    std::unique_ptr<Ui::StudentFormDialog> ui;
    StudentService& m_service;
    Student m_original;
    QString m_savedId;
};
