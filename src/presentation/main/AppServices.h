#pragma once

#include "application/services/AuthService.h"
#include "application/services/LanguageService.h"
#include "application/services/ListService.h"
#include "application/services/StatisticsService.h"
#include "application/services/StudentService.h"

// The use cases the UI may call (created in the composition root - src/app)
struct AppServices {
    AuthService& auth;
    StudentService& students;
    StatisticsService& statistics;
    ListService& lists;
    LanguageService& language;
};
