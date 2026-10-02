# APPLICATION layer: the use cases (services) that coordinate the business logic.
# Declares the "ports" (interfaces) that the outer layers implement: repositories, login gateway, settings store.
add_library(qlttta_application STATIC
    ports/IAuthGateway.h
    ports/ISettingsStore.h
    ports/IStudentRepository.h
    ports/ICatalogRepository.h
    ports/IStatisticsRepository.h
    ports/IListRepository.h
    services/Permissions.h
    services/Permissions.cpp
    services/AuthService.h
    services/AuthService.cpp
    services/StudentService.h
    services/StudentService.cpp
    services/StatisticsService.h
    services/StatisticsService.cpp
    services/ListService.h
    services/ListService.cpp
    services/LanguageService.h
    services/LanguageService.cpp
)
target_link_libraries(qlttta_application PUBLIC qlttta_domain)
