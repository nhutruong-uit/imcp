#include "presentation/login/LoginDialog.h"

#include "application/services/AuthService.h"
#include "application/services/LanguageService.h"
#include "presentation/common/I18n.h"
#include "presentation/common/Icons.h"
#include "presentation/common/UiHelpers.h"

#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QVBoxLayout>

LoginDialog::LoginDialog(AuthService& auth, LanguageService& language, QWidget* parent)
    : QDialog(parent), m_auth(auth), m_language(language) {
    setWindowTitle(tr("Sign in - English Center Management"));
    setObjectName(QStringLiteral("LoginDialog"));
    setMinimumSize(820, 500);

    auto* layout = new QHBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);
    layout->addWidget(buildBrandPanel(), 5);
    layout->addWidget(buildFormPanel(), 6);

    const ServerConfig config = m_auth.serverConfig();
    m_server->setText(config.host);
    m_database->setText(config.database);
    m_trustCertificate->setChecked(config.trustServerCertificate);
    m_username->setText(m_auth.lastUsername());
    m_serverGroup->setVisible(false);
    (m_username->text().isEmpty() ? m_username : m_password)->setFocus();
}

QWidget* LoginDialog::buildBrandPanel() {
    auto* panel = new QFrame(this);
    panel->setObjectName(QStringLiteral("BrandPanel"));
    auto* v = new QVBoxLayout(panel);
    v->setContentsMargins(40, 48, 40, 40);

    auto* logo = new QLabel(panel);
    logo->setPixmap(Icons::pixmap(QStringLiteral("logo"), QStringLiteral("#FFFFFF"), 56));
    auto* brand =
        new QLabel(QStringLiteral("English Center\nManager"), panel); // product name, not translated
    brand->setObjectName(QStringLiteral("BrandTitle"));
    auto* description =
        new QLabel(tr("English center management system: students, classes, enrollment, tuition, "
                      "attendance and learning results."),
                   panel);
    description->setObjectName(QStringLiteral("BrandText"));
    description->setWordWrap(true);
    auto* footer = new QLabel(tr("IE103 project - Information Management · UIT · Group 1"), panel);
    footer->setObjectName(QStringLiteral("BrandFooter"));

    v->addWidget(logo);
    v->addSpacing(16);
    v->addWidget(brand);
    v->addSpacing(8);
    v->addWidget(description);
    v->addStretch();
    v->addWidget(footer);
    return panel;
}

QWidget* LoginDialog::buildFormPanel() {
    auto* panel = new QWidget(this);
    auto* v = new QVBoxLayout(panel);
    v->setContentsMargins(48, 48, 48, 32);
    v->setSpacing(10);

    auto* title = new QLabel(tr("Sign in"), panel);
    title->setObjectName(QStringLiteral("LoginTitle"));
    auto* hint = new QLabel(tr("Use the account issued by your manager (a SQL Server account)."), panel);
    hint->setObjectName(QStringLiteral("Muted"));
    hint->setWordWrap(true); // translations may be longer than the original text
    v->addWidget(title);
    v->addWidget(hint);
    v->addSpacing(12);

    m_username = new QLineEdit(panel);
    m_username->setObjectName(QStringLiteral("usernameEdit"));
    m_username->setPlaceholderText(tr("Username"));
    m_username->addAction(Icons::get(QStringLiteral("user"), QStringLiteral("#94A3B8"), 16),
                          QLineEdit::LeadingPosition);
    m_password = new QLineEdit(panel);
    m_password->setObjectName(QStringLiteral("passwordEdit"));
    m_password->setPlaceholderText(tr("Password"));
    m_password->setEchoMode(QLineEdit::Password);
    m_password->addAction(Icons::get(QStringLiteral("key"), QStringLiteral("#94A3B8"), 16),
                          QLineEdit::LeadingPosition);
    v->addWidget(m_username);
    v->addWidget(m_password);

    m_error = new QLabel(panel);
    m_error->setObjectName(QStringLiteral("ErrorText"));
    m_error->setProperty("testId", QStringLiteral("loginError"));
    m_error->setWordWrap(true);
    m_error->hide();
    v->addWidget(m_error);

    m_loginButton = UiHelpers::primaryButton(tr("Sign in"), QString(), panel);
    m_loginButton->setObjectName(QStringLiteral("loginButton"));
    m_loginButton->setDefault(true);
    m_loginButton->setMinimumHeight(38);
    v->addWidget(m_loginButton);

    m_serverToggle = new QPushButton(tr("Server settings") + QStringLiteral(" ▸"), panel);
    m_serverToggle->setFlat(true);
    m_serverToggle->setObjectName(QStringLiteral("LinkButton"));
    m_serverToggle->setCursor(Qt::PointingHandCursor);
    v->addWidget(m_serverToggle, 0, Qt::AlignLeft);

    m_serverGroup = new QGroupBox(tr("SQL Server"), panel);
    auto* form = new QFormLayout(m_serverGroup);
    m_server = new QLineEdit(m_serverGroup);
    m_server->setObjectName(QStringLiteral("serverEdit"));
    m_server->setPlaceholderText(tr("localhost,1433 or PC-NAME\\SQLEXPRESS"));
    m_database = new QLineEdit(m_serverGroup);
    m_trustCertificate =
        new QCheckBox(tr("Trust server certificate (TrustServerCertificate)"), m_serverGroup);
    form->addRow(tr("Server"), m_server);
    form->addRow(tr("Database"), m_database);
    form->addRow(QString(), m_trustCertificate);
    v->addWidget(m_serverGroup);
    v->addStretch();

    auto* bottom = new QHBoxLayout;
    m_languageCombo = UiHelpers::languageSelector(I18n::current(), panel); // the language actually displayed
    auto* version = new QLabel(tr("Version %1").arg(QApplication::applicationVersion()), panel);
    version->setObjectName(QStringLiteral("Muted"));
    bottom->addWidget(m_languageCombo);
    bottom->addStretch();
    bottom->addWidget(version);
    v->addLayout(bottom);

    connect(m_loginButton, &QPushButton::clicked, this, &LoginDialog::login);
    connect(m_serverToggle, &QPushButton::clicked, this, &LoginDialog::toggleServerSettings);
    connect(m_languageCombo, &QComboBox::currentIndexChanged, this, &LoginDialog::changeLanguage);
    return panel;
}

void LoginDialog::toggleServerSettings() {
    const bool show = !m_serverGroup->isVisible();
    m_serverGroup->setVisible(show);
    m_serverToggle->setText(tr("Server settings") + (show ? QStringLiteral(" ▾") : QStringLiteral(" ▸")));
}

void LoginDialog::changeLanguage() {
    const Language selected = languageFromCode(m_languageCombo->currentData().toString());
    if (selected == I18n::current())
        return;
    I18n::switchTo(m_language, selected);
    done(LanguageChanged); // the caller shows a new login dialog, built in the new language
}

// The server settings are saved first (also when the login fails), so the user does not type them again
void LoginDialog::login() {
    ServerConfig config;
    config.host = m_server->text().trimmed();
    config.database = m_database->text().trimmed();
    config.trustServerCertificate = m_trustCertificate->isChecked();
    m_auth.saveServerConfig(config);

    m_error->hide();
    m_loginButton->setEnabled(false);
    m_loginButton->setText(tr("Connecting..."));
    QApplication::setOverrideCursor(Qt::WaitCursor);
    // Let Qt paint "Connecting..." now: the login call below blocks the UI until SQL Server answers
    QApplication::processEvents();

    const auto result = m_auth.login(m_username->text(), m_password->text());

    QApplication::restoreOverrideCursor();
    m_loginButton->setEnabled(true);
    m_loginButton->setText(tr("Sign in"));

    if (result.ok()) {
        accept();
        return;
    }
    m_error->setText(result.error());
    m_error->show();
    m_password->selectAll();
    m_password->setFocus();
}
