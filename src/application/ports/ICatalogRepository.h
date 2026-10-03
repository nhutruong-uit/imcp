#pragma once

#include "domain/common/Result.h"
#include "domain/entities/Branch.h"

#include <QList>

// Shared reference data for combo boxes.
// Port (interface, see IStudentRepository.h): implemented by SqlCatalogRepository, faked in
// tst_application.cpp, used by StudentService::branches.
class ICatalogRepository {
public:
    virtual ~ICatalogRepository() = default;
    virtual Result<QList<Branch>> branches() = 0; // active branches, ordered by ID
};
