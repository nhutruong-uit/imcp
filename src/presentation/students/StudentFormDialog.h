#pragma once

#include "domain/entities/Catalog.h"
#include "domain/entities/Student.h"

#include <QDialog>
#include <memory>

class StudentService;

namespace Ui {
class StudentFormDialog;
}

// Add/edit student form. The layout is designed in Qt Designer (StudentFormDialog.ui)
// At build time Qt's uic tool turns the .ui file into ui_StudentFormDialog.h: a class Ui::StudentFormDialog
// with one pointer per widget (ui->fullNameEdit, ui->branchCombo...); setupUi() creates them.
// Save: readForm() -> StudentService::add/update (domain rules first, then usp_Student_Add/Update); an error
// is shown in the form and the dialog stays open, so nothing typed is lost.
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

    std::unique_ptr<Ui::StudentFormDialog> ui; // owns the generated form (deleted with the dialog)
    StudentService& m_service;
    Student m_original;
    QString m_savedId;
};
