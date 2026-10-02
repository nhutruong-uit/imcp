#include "app/AppContainer.h"

AppContainer::AppContainer()
    : m_authGateway(m_db), m_studentRepository(m_db), m_catalogRepository(m_db), m_statisticsRepository(m_db),
      m_listRepository(m_db), m_auth(m_authGateway, m_settings),
      m_students(m_studentRepository, m_catalogRepository), m_statistics(m_statisticsRepository),
      m_lists(m_listRepository, m_auth), m_language(m_settings) {}
