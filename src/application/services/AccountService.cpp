#include "application/services/AccountService.h"

AccountService::AccountService(IAccountRepository& repository) : m_repository(repository) {}

Result<TableData> AccountService::list() {
    return m_repository.list();
}

VoidResult AccountService::create(const NewAccount& account) {
    NewAccount a = account;
    a.username = a.username.trimmed();
    const QStringList errors = a.validate();
    if (!errors.isEmpty())
        return VoidResult::failure(errors.join(QLatin1Char('\n')));
    return m_repository.create(a);
}

VoidResult AccountService::lock(const QString& username) {
    if (username.isEmpty())
        return VoidResult::failure(tr("No account is selected."));
    return m_repository.setLocked(username, true);
}

VoidResult AccountService::unlock(const QString& username) {
    if (username.isEmpty())
        return VoidResult::failure(tr("No account is selected."));
    return m_repository.setLocked(username, false);
}

VoidResult AccountService::resetPassword(const QString& username, const QString& newPassword,
                                         const QString& confirmation) {
    if (username.isEmpty())
        return VoidResult::failure(tr("No account is selected."));
    if (newPassword.size() < AccountLimits::minPasswordLength)
        return VoidResult::failure(
            tr("The password must be at least %1 characters long.").arg(AccountLimits::minPasswordLength));
    if (newPassword != confirmation)
        return VoidResult::failure(tr("The password and its confirmation do not match."));
    return m_repository.resetPassword(username, newPassword);
}

Result<QList<LookupItem>> AccountService::peopleWithoutAccount(Role role) {
    if (role == Role::Unknown)
        return Result<QList<LookupItem>>::success({});
    return m_repository.peopleWithoutAccount(role);
}
