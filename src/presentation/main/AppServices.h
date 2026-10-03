#pragma once

#include "application/services/AuthService.h"
#include "application/services/LanguageService.h"
#include "application/services/ListService.h"
#include "application/services/StatisticsService.h"
#include "application/services/StudentService.h"

// The use cases the UI may call (created in the composition root - src/app)
// A bundle of references: pages receive it by value (copying references copies no data) and call e.g.
// m_services.students.search(filter). This is the only door from the UI to the inner layers.
struct AppServices {
    AuthService& auth;
    StudentService& students;
    StatisticsService& statistics;
    ListService& lists;
    LanguageService& language;
};
