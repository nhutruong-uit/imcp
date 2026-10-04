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
    db/SqlHelpers.cpp
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
    repositories/SqlClassRepository.h
    repositories/SqlClassRepository.cpp
    repositories/SqlEnrollmentRepository.h
    repositories/SqlEnrollmentRepository.cpp
    repositories/SqlTuitionRepository.h
    repositories/SqlTuitionRepository.cpp
    repositories/SqlPlacementRepository.h
    repositories/SqlPlacementRepository.cpp
    repositories/SqlSessionRepository.h
    repositories/SqlSessionRepository.cpp
    repositories/SqlGradeRepository.h
    repositories/SqlGradeRepository.cpp
    repositories/SqlPayrollRepository.h
    repositories/SqlPayrollRepository.cpp
    repositories/SqlAccountRepository.h
    repositories/SqlAccountRepository.cpp
    repositories/SqlCourseRepository.h
    repositories/SqlCourseRepository.cpp
    repositories/SqlStaffRepository.h
    repositories/SqlStaffRepository.cpp
    repositories/SqlBackupRepository.h
    repositories/SqlBackupRepository.cpp
)
target_link_libraries(qlttta_infrastructure PUBLIC qlttta_application Qt6::Sql)
