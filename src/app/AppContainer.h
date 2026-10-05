#pragma once

#include "infrastructure/config/QSettingsStore.h"
#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/repositories/SqlAccountRepository.h"
#include "infrastructure/repositories/SqlAuthGateway.h"
#include "infrastructure/repositories/SqlBackupRepository.h"
#include "infrastructure/repositories/SqlCatalogRepository.h"
#include "infrastructure/repositories/SqlClassRepository.h"
#include "infrastructure/repositories/SqlCourseRepository.h"
#include "infrastructure/repositories/SqlEnrollmentRepository.h"
#include "infrastructure/repositories/SqlGradeRepository.h"
#include "infrastructure/repositories/SqlListRepository.h"
#include "infrastructure/repositories/SqlPayrollRepository.h"
#include "infrastructure/repositories/SqlPlacementRepository.h"
#include "infrastructure/repositories/SqlSessionRepository.h"
#include "infrastructure/repositories/SqlStaffRepository.h"
#include "infrastructure/repositories/SqlStatisticsRepository.h"
#include "infrastructure/repositories/SqlStudentRepository.h"
#include "infrastructure/repositories/SqlTuitionRepository.h"
#include "presentation/main/AppServices.h"

// Creates every object in dependency order (manual dependency injection).
// To switch DBMS (e.g. PostgreSQL) or run with fake data, only the Sql...Repository classes change here;
// the application and presentation layers stay the same.
// "Composition root": the only place that includes all layers. Each object receives references to the
// objects it needs (SqlStudentRepository gets the DatabaseManager, StudentService gets the repository...).
// The order of the members below matters: C++ builds members in the order they are declared, so the
// infrastructure objects exist before the services that keep references to them. Also used by the
// end-to-end test and the screenshot tool (they compile AppContainer.cpp too).
class AppContainer {
public:
    AppContainer();
    AuthService& auth() { return m_auth; }
    LanguageService& language() { return m_language; }
    // The use cases handed to the UI (the UI never sees the repositories or the database)
    AppServices services();

private:
    // Infrastructure
    DatabaseManager m_db;
    QSettingsStore m_settings;
    SqlAuthGateway m_authGateway;
    SqlStudentRepository m_studentRepository;
    SqlCatalogRepository m_catalogRepository;
    SqlStatisticsRepository m_statisticsRepository;
    SqlListRepository m_listRepository;
    SqlClassRepository m_classRepository;
    SqlEnrollmentRepository m_enrollmentRepository;
    SqlTuitionRepository m_tuitionRepository;
    SqlPlacementRepository m_placementRepository;
    SqlSessionRepository m_sessionRepository;
    SqlGradeRepository m_gradeRepository;
    SqlPayrollRepository m_payrollRepository;
    SqlAccountRepository m_accountRepository;
    SqlCourseRepository m_courseRepository;
    SqlStaffRepository m_staffRepository;
    SqlBackupRepository m_backupRepository;
    // Application
    AuthService m_auth;
    StudentService m_students;
    StatisticsService m_statistics;
    ListService m_lists;
    LanguageService m_language;
    ClassService m_classes;
    EnrollmentService m_enrollments;
    TuitionService m_tuition;
    PlacementService m_placement;
    SessionService m_sessions;
    GradeService m_grades;
    PayrollService m_payroll;
    AccountService m_accounts;
    CatalogService m_catalog;
    CourseService m_courses;
    StaffService m_staff;
    BackupService m_backup;
};
