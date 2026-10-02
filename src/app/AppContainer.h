#pragma once

#include "application/services/AuthService.h"
#include "application/services/LanguageService.h"
#include "application/services/ListService.h"
#include "application/services/StatisticsService.h"
#include "application/services/StudentService.h"
#include "infrastructure/config/QSettingsStore.h"
#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/repositories/SqlAuthGateway.h"
#include "infrastructure/repositories/SqlCatalogRepository.h"
#include "infrastructure/repositories/SqlListRepository.h"
#include "infrastructure/repositories/SqlStatisticsRepository.h"
#include "infrastructure/repositories/SqlStudentRepository.h"
#include "presentation/main/AppServices.h"

// Creates every object in dependency order (manual dependency injection).
// To switch DBMS (e.g. PostgreSQL) or run with fake data, only the Sql...Repository classes change here;
// the application and presentation layers stay the same.
class AppContainer {
public:
    AppContainer();
    AuthService& auth() { return m_auth; }
    LanguageService& language() { return m_language; }
    AppServices services() { return AppServices{m_auth, m_students, m_statistics, m_lists, m_language}; }

private:
    // Infrastructure
    DatabaseManager m_db;
    QSettingsStore m_settings;
    SqlAuthGateway m_authGateway;
    SqlStudentRepository m_studentRepository;
    SqlCatalogRepository m_catalogRepository;
    SqlStatisticsRepository m_statisticsRepository;
    SqlListRepository m_listRepository;
    // Application
    AuthService m_auth;
    StudentService m_students;
    StatisticsService m_statistics;
    ListService m_lists;
    LanguageService m_language;
};
