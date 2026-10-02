# DOMAIN layer: business entities and pure business rules.
# Depends on Qt Core only (QString, QDate, tr()); knows nothing about the database or the UI.
add_library(qlttta_domain STATIC
    common/Result.h
    common/TableData.h
    entities/Role.h
    entities/Role.cpp
    entities/Language.h
    entities/Language.cpp
    entities/Account.h
    entities/ServerConfig.h
    entities/Branch.h
    entities/Student.h
    entities/Student.cpp
    entities/DashboardStats.h
)
target_include_directories(qlttta_domain PUBLIC ${PROJECT_SOURCE_DIR}/src)
target_link_libraries(qlttta_domain PUBLIC Qt6::Core)
