# INFRASTRUCTURE layer: implements the ports of the application layer with Qt SQL (ODBC -> SQL Server)
# and QSettings. All SQL statements of the application live here.
add_library(qlttta_infrastructure STATIC
    db/DatabaseManager.h
    db/DatabaseManager.cpp
    db/DbMessages.h
    db/DbMessages.cpp
    db/SqlErrorMapper.h
    db/SqlErrorMapper.cpp
    db/SqlHelpers.h
    config/QSettingsStore.h
    config/QSettingsStore.cpp
    repositories/SqlAuthGateway.h
    repositories/SqlAuthGateway.cpp
    repositories/SqlStudentRepository.h
    repositories/SqlStudentRepository.cpp
    repositories/SqlCatalogRepository.h
    repositories/SqlCatalogRepository.cpp
    repositories/SqlStatisticsRepository.h
    repositories/SqlStatisticsRepository.cpp
    repositories/SqlListRepository.h
    repositories/SqlListRepository.cpp
)
target_link_libraries(qlttta_infrastructure PUBLIC qlttta_application Qt6::Sql)
