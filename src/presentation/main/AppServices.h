#pragma once

#include "application/services/AccountService.h"
#include "application/services/AuthService.h"
#include "application/services/BackupService.h"
#include "application/services/CatalogService.h"
#include "application/services/ClassService.h"
#include "application/services/CourseService.h"
#include "application/services/EnrollmentService.h"
#include "application/services/GradeService.h"
#include "application/services/LanguageService.h"
#include "application/services/ListService.h"
#include "application/services/PayrollService.h"
#include "application/services/PlacementService.h"
#include "application/services/SessionService.h"
#include "application/services/StaffService.h"
#include "application/services/StatisticsService.h"
#include "application/services/StudentService.h"
#include "application/services/TuitionService.h"

// The use cases the UI may call (created in the composition root - src/app)
// A bundle of references: pages receive it by value (copying references copies no data) and call e.g.
// m_services.students.search(filter). This is the only door from the UI to the inner layers.
struct AppServices {
    AuthService& auth;
    StudentService& students;
    StatisticsService& statistics;
    ListService& lists;
    LanguageService& language;
    ClassService& classes;
    EnrollmentService& enrollments;
    TuitionService& tuition;
    PlacementService& placement;
    SessionService& sessions;
    GradeService& grades;
    PayrollService& payroll;
    AccountService& accounts;
    CatalogService& catalog;
    CourseService& courses;
    StaffService& staff;
    BackupService& backup;
};
