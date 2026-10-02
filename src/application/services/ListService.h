#pragma once

#include "application/ports/IListRepository.h"
#include "application/services/AuthService.h"
#include "application/services/Permissions.h"

#include <QCoreApplication>

// Lookup-list use case: checks that the current role may open the feature before reading its list
class ListService {
    Q_DECLARE_TR_FUNCTIONS(ListService)
public:
    ListService(IListRepository& repository, const AuthService& auth);
    Result<TableData> fetch(Feature feature);
    static bool hasList(Feature feature);

private:
    IListRepository& m_repository;
    const AuthService& m_auth;
};
