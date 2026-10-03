#include "presentation/students/StudentFormDialog.h"

#include "application/services/StudentService.h"
#include "presentation/common/DbValues.h"
#include "ui_StudentFormDialog.h"

#include <QPushButton>
#include <QRegularExpressionValidator>
#include <QStyle>

StudentFormDialog::StudentFormDialog(StudentService& service, const QList<Branch>& branches,
                                     const Student& student, QWidget* parent)
    : QDialog(parent), ui(std::make_unique<Ui::StudentFormDialog>()), m_service(service),
      m_original(student) {
    ui->setupUi(this); // texts of the .ui file are translated by uic's retranslateUi()
    ui->titleLabel->setObjectName(QStringLiteral("PageTitle"));
    ui->errorLabel->setObjectName(QStringLiteral("ErrorText"));
    ui->errorLabel->hide();
    QPushButton* saveButton = ui->buttonBox->button(QDialogButtonBox::Save);
    saveButton->setText(tr("Save"));
    saveButton->setProperty("variant", QStringLiteral("primary"));
    saveButton->style()->unpolish(saveButton); // re-apply the style sheet after changing the property
    saveButton->style()->polish(saveButton);
    ui->buttonBox->button(QDialogButtonBox::Cancel)->setText(tr("Cancel"));

    // Digits only in phone fields (matches constraint CK_STUDENT_Phone)
    auto* digitsOnly =
        new QRegularExpressionValidator(QRegularExpression(QStringLiteral("[0-9]{0,11}")), this);
    ui->phoneEdit->setValidator(digitsOnly);
    ui->guardianPhoneEdit->setValidator(digitsOnly);
    ui->dateOfBirthEdit->setMaximumDate(QDate::currentDate());
    // No more characters than the database columns hold (Student::validate checks the notes, a plain text
    // edit)
    ui->fullNameEdit->setMaxLength(StudentLimits::fullName);
    ui->emailEdit->setMaxLength(StudentLimits::email);
    ui->addressEdit->setMaxLength(StudentLimits::address);
    ui->occupationEdit->setMaxLength(StudentLimits::occupation);
    ui->guardianNameEdit->setMaxLength(StudentLimits::guardianName);

    // Combo boxes show translated labels but keep the value stored in the database as item data
    for (const QString& gender : StudentValues::genders())
        ui->genderCombo->addItem(DbValues::label(gender), gender);
    for (const QString& status : StudentValues::statuses())
        ui->statusCombo->addItem(DbValues::label(status), status);
    for (const Branch& b : branches)
        ui->branchCombo->addItem(b.name, b.id);

    const bool isNew = student.id.isEmpty();
    ui->titleLabel->setText(isNew ? tr("Add student") : tr("Edit student"));
    setWindowTitle(ui->titleLabel->text());
    ui->statusCombo->setEnabled(!isNew); // a new student always starts as "Prospective"
    fillForm(student);
    updateGuardianGroup();

    connect(ui->dateOfBirthEdit, &QDateEdit::dateChanged, this, &StudentFormDialog::updateGuardianGroup);
    connect(ui->buttonBox, &QDialogButtonBox::accepted, this, &StudentFormDialog::save);
    connect(ui->buttonBox, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

StudentFormDialog::~StudentFormDialog() = default;

void StudentFormDialog::fillForm(const Student& s) {
    ui->idEdit->setText(s.id);
    ui->fullNameEdit->setText(s.fullName);
    ui->dateOfBirthEdit->setDate(s.dateOfBirth.isValid() ? s.dateOfBirth
                                                         : QDate::currentDate().addYears(-18));
    ui->genderCombo->setCurrentIndex(qMax(0, ui->genderCombo->findData(s.gender)));
    ui->phoneEdit->setText(s.phone);
    ui->emailEdit->setText(s.email);
    ui->addressEdit->setText(s.address);
    ui->occupationEdit->setText(s.occupation);
    // The combo lists the Active branches only; a student of a suspended branch keeps it (index 0 would move
    // the student to another branch on Save)
    if (!s.branchId.isEmpty() && ui->branchCombo->findData(s.branchId) < 0)
        ui->branchCombo->addItem(s.branchName.isEmpty() ? s.branchId : s.branchName, s.branchId);
    ui->branchCombo->setCurrentIndex(qMax(0, ui->branchCombo->findData(s.branchId)));
    ui->statusCombo->setCurrentIndex(qMax(0, ui->statusCombo->findData(s.status)));
    ui->guardianNameEdit->setText(s.guardianName);
    ui->guardianPhoneEdit->setText(s.guardianPhone);
    ui->notesEdit->setPlainText(s.notes);
}

// Starts from the original student so fields the form does not show (registration date, ID) are kept
Student StudentFormDialog::readForm() const {
    Student s = m_original;
    s.fullName = ui->fullNameEdit->text();
    s.dateOfBirth = ui->dateOfBirthEdit->date();
    s.gender = ui->genderCombo->currentData().toString();
    s.phone = ui->phoneEdit->text();
    s.email = ui->emailEdit->text();
    s.address = ui->addressEdit->text();
    s.occupation = ui->occupationEdit->text();
    s.branchId = ui->branchCombo->currentData().toString();
    s.status = ui->statusCombo->currentData().toString();
    s.guardianName = ui->guardianNameEdit->text();
    s.guardianPhone = ui->guardianPhoneEdit->text();
    s.notes = ui->notesEdit->toPlainText();
    return s;
}

// Marks the guardian fields as required while the date of birth makes the student a minor (same age rule as
// Student::validate); the check itself happens on Save
void StudentFormDialog::updateGuardianGroup() {
    Student probe;
    probe.dateOfBirth = ui->dateOfBirthEdit->date();
    const bool required = probe.needsGuardian(m_original.registeredOn.isValid() ? m_original.registeredOn
                                                                                : QDate::currentDate());
    ui->guardianGroup->setTitle(required ? tr("Guardian information * (student under 18)")
                                         : tr("Guardian information (optional)"));
}

void StudentFormDialog::save() {
    const Student s = readForm();
    const QDate today = QDate::currentDate();
    if (s.id.isEmpty()) {
        const auto result = m_service.add(s, today);
        if (!result.ok()) {
            ui->errorLabel->setText(result.error());
            ui->errorLabel->show();
            return;
        }
        m_savedId = result.value();
    } else {
        const auto result = m_service.update(s, today);
        if (!result.ok()) {
            ui->errorLabel->setText(result.error());
            ui->errorLabel->show();
            return;
        }
        m_savedId = s.id;
    }
    accept();
}
