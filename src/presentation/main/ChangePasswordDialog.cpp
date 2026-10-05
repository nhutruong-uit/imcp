#include "presentation/main/ChangePasswordDialog.h"

#include "application/services/AuthService.h"

#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QVBoxLayout>

ChangePasswordDialog::ChangePasswordDialog(AuthService& auth, QWidget* parent) : QDialog(parent), m_auth(auth) {
    setWindowTitle(tr("Change password"));
    setMinimumWidth(420);
    auto* v = new QVBoxLayout(this);
    auto* form = new QFormLayout;
    m_current = new QLineEdit(this);
    m_new = new QLineEdit(this);
    m_confirmation = new QLineEdit(this);
    for (QLineEdit* e : {m_current, m_new, m_confirmation})
        e->setEchoMode(QLineEdit::Password);
    form->addRow(tr("Current password"), m_current);
    form->addRow(tr("New password"), m_new);
    form->addRow(tr("Confirm new password"), m_confirmation);
    v->addLayout(form);

    m_error = new QLabel(this);
    m_error->setObjectName(QStringLiteral("ErrorText"));
    m_error->setWordWrap(true);
    m_error->hide();
    v->addWidget(m_error);

    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, this);
    buttons->button(QDialogButtonBox::Save)->setText(tr("Save"));
    buttons->button(QDialogButtonBox::Cancel)->setText(tr("Cancel"));
    v->addWidget(buttons);
    connect(buttons, &QDialogButtonBox::accepted, this, &ChangePasswordDialog::save);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void ChangePasswordDialog::save() {
    const auto result = m_auth.changePassword(m_current->text(), m_new->text(), m_confirmation->text());
    if (!result.ok()) {
        m_error->setText(result.error());
        m_error->show();
        return;
    }
    QMessageBox::information(this, tr("Success"), tr("Your password has been changed."));
    accept();
}
