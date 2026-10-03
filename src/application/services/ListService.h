#pragma once

#include "application/ports/IListRepository.h"
#include "application/services/AuthService.h"
#include "application/services/Permissions.h"

#include <QCoreApplication>

// Lookup-list use case: checks that the current role may open the feature before reading its list.
// Used by ListPage (the generic page of every read-only list). The permission check is a second line of
// defense: the menu already hides the feature, and SQL Server would refuse the query anyway (GRANT/DENY).
class ListService {
    Q_DECLARE_TR_FUNCTIONS(ListService)
public:
    ListService(IListRepository& repository, const AuthService& auth);
    Result<TableData> fetch(Feature feature);
    static bool hasList(Feature feature); // false for features with their own page (dashboard, students)

private:
    IListRepository& m_repository;
    const AuthService& m_auth;
};
