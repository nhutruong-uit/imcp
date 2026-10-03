#include "infrastructure/repositories/SqlCatalogRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlCatalogRepository::SqlCatalogRepository(DatabaseManager& db) : m_db(db) {}

// A plain SELECT is enough: every role is granted SELECT on BRANCH (06_security.sql) and nothing is written
Result<QList<Branch>> SqlCatalogRepository::branches() {
    QSqlQuery q = makeQuery(m_db.db());
    if (!q.exec(QStringLiteral(
            "SELECT BranchId, BranchName FROM dbo.BRANCH WHERE Status = N'Active' ORDER BY BranchId")))
        return Result<QList<Branch>>::failure(errorOf(q));
    QList<Branch> branches;
    while (q.next())
        branches.append({q.value(0).toString(), q.value(1).toString()});
    return Result<QList<Branch>>::success(branches);
}
