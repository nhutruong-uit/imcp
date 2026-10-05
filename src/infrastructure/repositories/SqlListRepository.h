#pragma once

#include "application/ports/IListRepository.h"
#include "infrastructure/db/DatabaseManager.h"

// Read-only lists: each kind is one SELECT on a view (granted to the matching roles).
// Implements the port IListRepository. The teacher lists (vw_Teacher_My*) need no parameter: the views
// filter by the logged-in user themselves, so a teacher can only ever receive their own rows.
class SqlListRepository : public IListRepository {
public:
    explicit SqlListRepository(DatabaseManager& db);
    Result<TableData> fetch(ListKind kind) override;

private:
    DatabaseManager& m_db;
};
