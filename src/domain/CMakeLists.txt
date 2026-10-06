# DOMAIN layer: business entities and pure business rules.
# Depends on Qt Core only (QString, QDate, tr()); knows nothing about the database or the UI.
add_library(qlttta_domain STATIC
    common/Result.h
    common/TableData.h
    common/Lookup.h
    common/Validation.h
    common/Validation.cpp
    entities/Role.h
    entities/Role.cpp
    entities/Language.h
    entities/Language.cpp
    entities/Account.h
    entities/ServerConfig.h
    entities/ServerConfig.cpp
    entities/Student.h
    entities/Student.cpp
    entities/DashboardStats.h
    entities/Catalog.h
    entities/Catalog.cpp
    entities/Staff.h
    entities/Staff.cpp
    entities/ClassInfo.h
    entities/ClassInfo.cpp
    entities/Enrollment.h
    entities/Enrollment.cpp
    entities/Receipt.h
    entities/Receipt.cpp
    entities/PlacementTest.h
    entities/PlacementTest.cpp
    entities/Session.h
    entities/Session.cpp
    entities/GradeBook.h
    entities/GradeBook.cpp
    entities/Payroll.h
    entities/NewAccount.h
    entities/NewAccount.cpp
)
target_include_directories(qlttta_domain PUBLIC ${PROJECT_SOURCE_DIR}/src)
target_link_libraries(qlttta_domain PUBLIC Qt6::Core)
