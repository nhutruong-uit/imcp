#include "presentation/accounts/AccountPage.h"

#include "presentation/common/Fields.h"
#include "presentation/common/FormDialog.h"
#include "presentation/common/Labels.h"
#include "presentation/common/UiHelpers.h"

#include <QComboBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>

AccountPage::AccountPage(AppServices services, QWidget* parent)
    : DataPage(services, Feature::Accounts, parent) {
    if (canEdit()) {
        addAction(tr("New account"), QStringLiteral("plus"), QStringLiteral("addButton"), false,
                  [this] { createAccount(); });
        addAction(tr("Lock"), QStringLiteral("lock"), QStringLiteral("lockButton"), true,
                  [this] { setLocked(true); });
        addAction(tr("Unlock"), QStringLiteral("unlock"), QStringLiteral("unlockButton"), true,
                  [this] { setLocked(false); });
        addAction(tr("Reset password"), QStringLiteral("key"), QStringLiteral("resetPasswordButton"), true,
                  [this] { resetPassword(); });
    }
    reload();
}

Result<TableData> AccountPage::fetch() {
    return m_services.accounts.list();
}

void AccountPage::createAccount() {
    FormDialog dialog(tr("New account"), this);
    auto* role = new QComboBox(&dialog);
    for (Role r : {Role::AcademicStaff, Role::Accountant, Role::Teacher, Role::Manager})
        role->addItem(Labels::role(r), static_cast<int>(r));
    auto* person = new QComboBox(&dialog);
    person->setObjectName(QStringLiteral("personCombo"));
    auto* username = Fields::text(&dialog, AccountLimits::maxUsernameLength);
    username->setObjectName(QStringLiteral("usernameEdit"));
    username->setPlaceholderText(tr("e.g. gvu_hoa (letters without diacritics, digits, . and _)"));
    auto* password = Fields::text(&dialog, 128);
    auto* confirmation = Fields::text(&dialog, 128);
    for (QLineEdit* e : {password, confirmation})
        e->setEchoMode(QLineEdit::Password);
    dialog.form()->addRow(tr("Role"), role);
    dialog.form()->addRow(tr("Employee or teacher"), person);
    dialog.form()->addRow(tr("Username"), username);
    dialog.form()->addRow(tr("Password"), password);
    dialog.form()->addRow(tr("Confirm password"), confirmation);
    dialog.form()->addRow(QString(),
                          new QLabel(tr("SQL Server stores the password (hashed); the person signs in "
                                        "with this username and password."),
                                     &dialog));

    // A teacher account belongs to a teacher, the other roles to an employee (CK_ACCOUNT_Owner)
    auto loadPeople = [&] {
        const auto people =
            m_services.accounts.peopleWithoutAccount(static_cast<Role>(role->currentData().toInt()));
        Fields::fillLookup(person, people.ok() ? people.value() : QList<LookupItem>());
        if (!people.ok())
            dialog.showError(people.error());
    };
    loadPeople();
    connect(role, &QComboBox::currentIndexChanged, &dialog, loadPeople);

    QString created;
    dialog.setSaveAction([&] {
        NewAccount account;
        account.role = static_cast<Role>(role->currentData().toInt());
        account.personId = Fields::value(person);
        account.username = username->text();
        account.password = password->text();
        account.confirmation = confirmation->text();
        created = account.username.trimmed();
        return m_services.accounts.create(account);
    });
    if (dialog.exec() == QDialog::Accepted)
        reloadAndSelect(QStringLiteral("Username"), created);
}

void AccountPage::setLocked(bool locked) {
    const QString username = selected(QStringLiteral("Username")).toString();
    const QString question = locked ? tr("Lock account %1? The person can no longer sign in.").arg(username)
                                    : tr("Unlock account %1?").arg(username);
    if (!UiHelpers::confirm(this, question))
        return;
    const auto result = locked ? m_services.accounts.lock(username) : m_services.accounts.unlock(username);
    if (!result.ok())
        UiHelpers::showError(this, result.error());
    reloadAndSelect(QStringLiteral("Username"), username);
}

void AccountPage::resetPassword() {
    const QString username = selected(QStringLiteral("Username")).toString();
    FormDialog dialog(tr("Reset the password of %1").arg(username), this);
    auto* password = Fields::text(&dialog, 128);
    auto* confirmation = Fields::text(&dialog, 128);
    for (QLineEdit* e : {password, confirmation})
        e->setEchoMode(QLineEdit::Password);
    dialog.form()->addRow(tr("New password"), password);
    dialog.form()->addRow(tr("Confirm new password"), confirmation);
    dialog.setSaveAction(
        [&] { return m_services.accounts.resetPassword(username, password->text(), confirmation->text()); });
    dialog.exec();
}
