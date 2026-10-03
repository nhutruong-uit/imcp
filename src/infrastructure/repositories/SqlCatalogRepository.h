#pragma once

#include "application/ports/ICatalogRepository.h"
#include "infrastructure/db/DatabaseManager.h"

// Implements the port ICatalogRepository: reference data for combo boxes
class SqlCatalogRepository : public ICatalogRepository {
public:
    explicit SqlCatalogRepository(DatabaseManager& db);
    Result<QList<Branch>> branches() override;

private:
    DatabaseManager& m_db;
};
