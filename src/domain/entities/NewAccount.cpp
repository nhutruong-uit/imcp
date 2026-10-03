#include "domain/entities/NewAccount.h"

#include <QRegularExpression>

// Letters without diacritics, digits, dot and underscore, at least 3 characters: the LIKE pattern of
// usp_Account_Create (compared there in a binary collation, so "đ" or "ấ" are refused too)
bool NewAccount::isValidUsername(const QString& username) {
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9_.]{3,50}$"));
    return pattern.match(username).hasMatch();
}

QStringList NewAccount::validate() const {
    QStringList errors;
    if (!isValidUsername(username))
        errors << tr("A username may only contain letters without diacritics, digits, dots and underscores "
                     "(3 to "
                     "%1 characters).")
                      .arg(AccountLimits::maxUsernameLength);
    if (password.size() < AccountLimits::minPasswordLength)
        errors
            << tr("The password must be at least %1 characters long.").arg(AccountLimits::minPasswordLength);
    else if (password != confirmation)
        errors << tr("The password and its confirmation do not match.");
    if (role == Role::Unknown)
        errors << tr("Please choose a role.");
    if (personId.isEmpty())
        errors << tr("Please choose the employee or teacher who will use the account.");
    return errors;
}
