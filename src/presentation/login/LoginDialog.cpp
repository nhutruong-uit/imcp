#include "presentation/login/LoginDialog.h"

#include "application/services/AuthService.h"
#include "presentation/common/Icons.h"
#include "presentation/common/UiHelpers.h"

#include <QApplication>
#include <QCheckBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QVBoxLayout>

LoginDialog::LoginDialog(AuthService& auth, QWidget* parent) : QDialog(parent), m_auth(auth) {
    setWindowTitle(QStringLiteral("Đăng nhập - Quản lý Trung tâm Tiếng Anh"));
    setObjectName(QStringLiteral("LoginDialog"));
    setMinimumSize(820, 500);

    auto* layout = new QHBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);
    layout->addWidget(taoPanelThuongHieu(), 5);
    layout->addWidget(taoPanelForm(), 6);

    const CauHinhMayChu cauHinh = m_auth.cauHinh();
    m_mayChu->setText(cauHinh.mayChu);
    m_csdl->setText(cauHinh.csdl);
    m_tinCay->setChecked(cauHinh.tinCayChungChi);
    m_tenDangNhap->setText(m_auth.tenDangNhapGanNhat());
    m_nhomCauHinh->setVisible(false);
    (m_tenDangNhap->text().isEmpty() ? m_tenDangNhap : m_matKhau)->setFocus();
}

QWidget* LoginDialog::taoPanelThuongHieu() {
    auto* panel = new QFrame(this);
    panel->setObjectName(QStringLiteral("BrandPanel"));
    auto* v = new QVBoxLayout(panel);
    v->setContentsMargins(40, 48, 40, 40);

    auto* logo = new QLabel(panel);
    logo->setPixmap(Icons::pixmap(QStringLiteral("logo"), QStringLiteral("#FFFFFF"), 56));
    auto* ten = new QLabel(QStringLiteral("English Center\nManager"), panel);
    ten->setObjectName(QStringLiteral("BrandTitle"));
    auto* moTa = new QLabel(QStringLiteral("Hệ thống quản lý trung tâm tiếng Anh: học viên, lớp học, "
                                           "ghi danh, học phí, điểm danh, kết quả học tập."),
                            panel);
    moTa->setObjectName(QStringLiteral("BrandText"));
    moTa->setWordWrap(true);
    auto* chan = new QLabel(QStringLiteral("Đồ án IE103 - Quản lý thông tin · UIT · Nhóm 1"), panel);
    chan->setObjectName(QStringLiteral("BrandFooter"));

    v->addWidget(logo);
    v->addSpacing(16);
    v->addWidget(ten);
    v->addSpacing(8);
    v->addWidget(moTa);
    v->addStretch();
    v->addWidget(chan);
    return panel;
}

QWidget* LoginDialog::taoPanelForm() {
    auto* panel = new QWidget(this);
    auto* v = new QVBoxLayout(panel);
    v->setContentsMargins(48, 48, 48, 32);
    v->setSpacing(10);

    auto* tieuDe = new QLabel(QStringLiteral("Đăng nhập"), panel);
    tieuDe->setObjectName(QStringLiteral("LoginTitle"));
    auto* goiY = new QLabel(QStringLiteral("Dùng tài khoản được quản lý cấp (tài khoản SQL Server)."), panel);
    goiY->setObjectName(QStringLiteral("Muted"));
    v->addWidget(tieuDe);
    v->addWidget(goiY);
    v->addSpacing(12);

    m_tenDangNhap = new QLineEdit(panel);
    m_tenDangNhap->setObjectName(QStringLiteral("tenDangNhap"));
    m_tenDangNhap->setPlaceholderText(QStringLiteral("Tên đăng nhập"));
    m_tenDangNhap->addAction(Icons::get(QStringLiteral("user"), QStringLiteral("#94A3B8"), 16), QLineEdit::LeadingPosition);
    m_matKhau = new QLineEdit(panel);
    m_matKhau->setObjectName(QStringLiteral("matKhau"));
    m_matKhau->setPlaceholderText(QStringLiteral("Mật khẩu"));
    m_matKhau->setEchoMode(QLineEdit::Password);
    m_matKhau->addAction(Icons::get(QStringLiteral("key"), QStringLiteral("#94A3B8"), 16), QLineEdit::LeadingPosition);
    v->addWidget(m_tenDangNhap);
    v->addWidget(m_matKhau);

    m_loi = new QLabel(panel);
    m_loi->setObjectName(QStringLiteral("ErrorText"));
    m_loi->setProperty("vaiTro", QStringLiteral("loiDangNhap"));
    m_loi->setWordWrap(true);
    m_loi->hide();
    v->addWidget(m_loi);

    m_nutDangNhap = UiHelpers::nutChinh(QStringLiteral("Đăng nhập"), QString(), panel);
    m_nutDangNhap->setObjectName(QStringLiteral("nutDangNhap"));
    m_nutDangNhap->setDefault(true);
    m_nutDangNhap->setMinimumHeight(38);
    v->addWidget(m_nutDangNhap);

    m_nutCauHinh = new QPushButton(QStringLiteral("Cấu hình máy chủ ▸"), panel);
    m_nutCauHinh->setFlat(true);
    m_nutCauHinh->setObjectName(QStringLiteral("LinkButton"));
    m_nutCauHinh->setCursor(Qt::PointingHandCursor);
    v->addWidget(m_nutCauHinh, 0, Qt::AlignLeft);

    m_nhomCauHinh = new QGroupBox(QStringLiteral("Máy chủ SQL Server"), panel);
    auto* form = new QFormLayout(m_nhomCauHinh);
    m_mayChu = new QLineEdit(m_nhomCauHinh);
    m_mayChu->setObjectName(QStringLiteral("mayChu"));
    m_mayChu->setPlaceholderText(QStringLiteral("localhost,1433 hoặc TEN-MAY\\SQLEXPRESS"));
    m_csdl = new QLineEdit(m_nhomCauHinh);
    m_tinCay = new QCheckBox(QStringLiteral("Tin cậy chứng chỉ máy chủ (TrustServerCertificate)"), m_nhomCauHinh);
    form->addRow(QStringLiteral("Máy chủ"), m_mayChu);
    form->addRow(QStringLiteral("CSDL"), m_csdl);
    form->addRow(QString(), m_tinCay);
    v->addWidget(m_nhomCauHinh);
    v->addStretch();

    auto* phienBan = new QLabel(QStringLiteral("Phiên bản %1").arg(QApplication::applicationVersion()), panel);
    phienBan->setObjectName(QStringLiteral("Muted"));
    v->addWidget(phienBan, 0, Qt::AlignRight);

    connect(m_nutDangNhap, &QPushButton::clicked, this, &LoginDialog::dangNhap);
    connect(m_nutCauHinh, &QPushButton::clicked, this, &LoginDialog::anHienCauHinh);
    return panel;
}

void LoginDialog::anHienCauHinh() {
    const bool hien = !m_nhomCauHinh->isVisible();
    m_nhomCauHinh->setVisible(hien);
    m_nutCauHinh->setText(hien ? QStringLiteral("Cấu hình máy chủ ▾") : QStringLiteral("Cấu hình máy chủ ▸"));
}

void LoginDialog::dangNhap() {
    CauHinhMayChu cauHinh;
    cauHinh.mayChu = m_mayChu->text().trimmed();
    cauHinh.csdl = m_csdl->text().trimmed();
    cauHinh.tinCayChungChi = m_tinCay->isChecked();
    m_auth.luuCauHinh(cauHinh);

    m_loi->hide();
    m_nutDangNhap->setEnabled(false);
    m_nutDangNhap->setText(QStringLiteral("Đang kết nối..."));
    QApplication::setOverrideCursor(Qt::WaitCursor);
    QApplication::processEvents();

    const auto ketQua = m_auth.dangNhap(m_tenDangNhap->text(), m_matKhau->text());

    QApplication::restoreOverrideCursor();
    m_nutDangNhap->setEnabled(true);
    m_nutDangNhap->setText(QStringLiteral("Đăng nhập"));

    if (ketQua.ok()) {
        accept();
        return;
    }
    m_loi->setText(ketQua.error());
    m_loi->show();
    m_matKhau->selectAll();
    m_matKhau->setFocus();
}
