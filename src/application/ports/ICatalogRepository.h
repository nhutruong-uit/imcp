#pragma once

#include "domain/common/Result.h"
#include "domain/entities/Branch.h"

#include <QList>

// Shared reference data for combo boxes
class ICatalogRepository {
public:
    virtual ~ICatalogRepository() = default;
    virtual Result<QList<Branch>> branches() = 0;
};
