#pragma once

#include "application/ports/IListRepository.h"
#include "infrastructure/db/DatabaseManager.h"

// Read-only lists: each kind is one SELECT on a view (granted to the matching roles)
class SqlListRepository : public IListRepository {
public:
    explicit SqlListRepository(DatabaseManager& db);
    Result<TableData> fetch(ListKind kind) override;

private:
    DatabaseManager& m_db;
};
