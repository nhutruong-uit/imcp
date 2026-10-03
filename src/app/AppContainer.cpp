#include "app/AppContainer.h"

AppContainer::AppContainer()
    : m_authGateway(m_db), m_studentRepository(m_db), m_catalogRepository(m_db), m_statisticsRepository(m_db),
      m_listRepository(m_db), m_classRepository(m_db), m_enrollmentRepository(m_db),
      m_tuitionRepository(m_db), m_placementRepository(m_db), m_sessionRepository(m_db),
      m_gradeRepository(m_db), m_payrollRepository(m_db), m_accountRepository(m_db), m_courseRepository(m_db),
      m_staffRepository(m_db), m_backupRepository(m_db), m_auth(m_authGateway, m_settings),
      m_students(m_studentRepository, m_catalogRepository), m_statistics(m_statisticsRepository),
      m_lists(m_listRepository, m_auth), m_language(m_settings), m_classes(m_classRepository),
      m_enrollments(m_enrollmentRepository), m_tuition(m_tuitionRepository),
      m_placement(m_placementRepository), m_sessions(m_sessionRepository), m_grades(m_gradeRepository),
      m_payroll(m_payrollRepository), m_accounts(m_accountRepository), m_catalog(m_catalogRepository),
      m_courses(m_courseRepository), m_staff(m_staffRepository), m_backup(m_backupRepository) {}

AppServices AppContainer::services() {
    return AppServices{m_auth,        m_students, m_statistics, m_lists,    m_language, m_classes,
                       m_enrollments, m_tuition,  m_placement,  m_sessions, m_grades,   m_payroll,
                       m_accounts,    m_catalog,  m_courses,    m_staff,    m_backup};
}
