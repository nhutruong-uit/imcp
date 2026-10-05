#include "infrastructure/repositories/SqlAccountRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlAccountRepository::SqlAccountRepository(DatabaseManager& db) : m_db(db) {}

Result<TableData> SqlAccountRepository::list() {
    return queryTable(m_db, QStringLiteral("EXEC dbo.usp_Account_List"), {});
}

VoidResult SqlAccountRepository::create(const NewAccount& account) {
    // The password is a parameter like any value: usp_Account_Create builds CREATE USER itself with QUOTENAME
    // and doubled quotes, so nothing typed here can change the statement
    const bool teacher = account.role == Role::Teacher;
    return execCall(m_db,
                    QStringLiteral("EXEC dbo.usp_Account_Create @Username = ?, @Password = ?, @Role = ?, "
                                   "@EmployeeId = ?, @TeacherId = ?"),
                    {account.username, account.password, roleCode(account.role),
                     stringOrNull(teacher ? QString() : account.personId),
                     stringOrNull(teacher ? account.personId : QString())});
}

VoidResult SqlAccountRepository::setLocked(const QString& username, bool locked) {
    return execCall(m_db, QStringLiteral("EXEC dbo.usp_Account_Lock @Username = ?, @Lock = ?"),
                    {username, locked ? 1 : 0});
}

VoidResult SqlAccountRepository::resetPassword(const QString& username, const QString& newPassword) {
    return execCall(m_db,
                    QStringLiteral("EXEC dbo.usp_Account_ResetPassword @Username = ?, @NewPassword = ?"),
                    {username, newPassword});
}

Result<QList<LookupItem>> SqlAccountRepository::peopleWithoutAccount(Role role) {
    // A teacher account belongs to a TEACHER, the other roles to an EMPLOYEE (CK_ACCOUNT_Owner); people who
    // left cannot get one (50069), and a person has at most one account (UX_ACCOUNT_EmployeeId / _TeacherId)
    if (role == Role::Teacher)
        return queryLookup(
            m_db,
            QStringLiteral("SELECT te.TeacherId, te.TeacherId + N' - ' + te.FullName FROM dbo.TEACHER te "
                           "WHERE te.Status <> N'Left' AND NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT ac "
                           "WHERE ac.TeacherId = te.TeacherId) ORDER BY te.FullName"),
            {});
    return queryLookup(
        m_db,
        QStringLiteral("SELECT em.EmployeeId, em.EmployeeId + N' - ' + em.FullName, em.Position "
                       "FROM dbo.EMPLOYEE em WHERE em.Status <> N'Left' AND NOT EXISTS "
                       "(SELECT 1 FROM dbo.ACCOUNT ac WHERE ac.EmployeeId = em.EmployeeId) "
                       "ORDER BY em.FullName"),
        {});
}
