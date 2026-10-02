#include "infrastructure/repositories/SqlAuthGateway.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

namespace {
const QString kActiveStatus = QStringLiteral("Active"); // ACCOUNT.Status of an active account
} // namespace

SqlAuthGateway::SqlAuthGateway(DatabaseManager& db) : m_db(db) {}

Result<Account> SqlAuthGateway::login(const ServerConfig& config, const QString& username,
                                      const QString& password) {
    const VoidResult connected = m_db.open(config, username, password);
    if (!connected.ok())
        return Result<Account>::failure(connected.error());

    QSqlQuery q = makeQuery(m_db.db());
    if (!q.exec(QStringLiteral("EXEC dbo.usp_Account_RecordLogin"))) {
        const QString error = errorOf(q);
        m_db.close();
        return Result<Account>::failure(error);
    }

    // Columns: Username, Role, EmployeeId, TeacherId, Status, FullName, BranchId
    Account account;
    if (q.next()) {
        account.username = q.value(0).toString();
        account.role = roleFromCode(q.value(1).toString());
        account.employeeId = q.value(2).toString();
        account.teacherId = q.value(3).toString();
        account.fullName = q.value(5).toString();
        account.branchId = q.value(6).toString();
        account.active = q.value(4).toString() == kActiveStatus;
        return Result<Account>::success(account);
    }

    // Not in ACCOUNT: let the database owner (sa / db_owner) in with the Manager role
    QSqlQuery owner = makeQuery(m_db.db());
    if (owner.exec(QStringLiteral("SELECT IS_MEMBER('db_owner'), ORIGINAL_LOGIN()")) && owner.next() &&
        owner.value(0).toInt() == 1) {
        account.username = owner.value(1).toString();
        account.fullName = account.username + tr(" (database administrator)");
        account.role = Role::Manager;
        return Result<Account>::success(account);
    }
    account.username = username;
    return Result<Account>::success(account); // Role::Unknown => rejected by AuthService
}

void SqlAuthGateway::logout() {
    m_db.close();
}

VoidResult SqlAuthGateway::changePassword(const QString& oldPassword, const QString& newPassword) {
    QSqlQuery q = makeQuery(m_db.db());
    q.prepare(QStringLiteral("EXEC dbo.usp_Account_ChangePassword @OldPassword = ?, @NewPassword = ?"));
    q.addBindValue(oldPassword);
    q.addBindValue(newPassword);
    if (!q.exec())
        return VoidResult::failure(errorOf(q));
    return VoidResult::success();
}
