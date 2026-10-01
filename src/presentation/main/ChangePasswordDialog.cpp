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
    setWindowTitle(QStringLiteral("Đổi mật khẩu"));
    setMinimumWidth(420);
    auto* v = new QVBoxLayout(this);
    auto* form = new QFormLayout;
    m_cu = new QLineEdit(this);
    m_moi = new QLineEdit(this);
    m_nhapLai = new QLineEdit(this);
    for (QLineEdit* e : {m_cu, m_moi, m_nhapLai})
        e->setEchoMode(QLineEdit::Password);
    form->addRow(QStringLiteral("Mật khẩu hiện tại"), m_cu);
    form->addRow(QStringLiteral("Mật khẩu mới"), m_moi);
    form->addRow(QStringLiteral("Nhập lại mật khẩu mới"), m_nhapLai);
    v->addLayout(form);

    m_loi = new QLabel(this);
    m_loi->setObjectName(QStringLiteral("ErrorText"));
    m_loi->setWordWrap(true);
    m_loi->hide();
    v->addWidget(m_loi);

    auto* nut = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, this);
    nut->button(QDialogButtonBox::Save)->setText(QStringLiteral("Lưu"));
    nut->button(QDialogButtonBox::Cancel)->setText(QStringLiteral("Hủy"));
    v->addWidget(nut);
    connect(nut, &QDialogButtonBox::accepted, this, &ChangePasswordDialog::luu);
    connect(nut, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void ChangePasswordDialog::luu() {
    const auto kq = m_auth.doiMatKhau(m_cu->text(), m_moi->text(), m_nhapLai->text());
    if (!kq.ok()) {
        m_loi->setText(kq.error());
        m_loi->show();
        return;
    }
    QMessageBox::information(this, QStringLiteral("Thành công"), QStringLiteral("Đã đổi mật khẩu."));
    accept();
}
