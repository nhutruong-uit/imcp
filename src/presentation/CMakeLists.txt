# PRESENTATION layer: Qt Widgets UI (Menu - Form - Report).
# Only calls the services of the application layer, never the database directly.
add_library(qlttta_presentation STATIC
    common/Theme.h
    common/Theme.cpp
    common/Icons.h
    common/Icons.cpp
    common/I18n.h
    common/I18n.cpp
    common/Labels.h
    common/Labels.cpp
    common/Columns.h
    common/Columns.cpp
    common/DbValues.h
    common/DbValues.cpp
    common/Format.h
    common/Format.cpp
    common/TableDataModel.h
    common/TableDataModel.cpp
    common/ReportDocument.h
    common/ReportDocument.cpp
    common/TableExporter.h
    common/TableExporter.cpp
    common/ReportPreviewDialog.h
    common/ReportPreviewDialog.cpp
    common/UiHelpers.h
    common/UiHelpers.cpp
    common/DataTable.h
    common/DataTable.cpp
    common/DataPage.h
    common/DataPage.cpp
    common/FormDialog.h
    common/FormDialog.cpp
    common/Fields.h
    common/Fields.cpp
    common/TableDialog.h
    common/TableDialog.cpp
    login/LoginDialog.h
    login/LoginDialog.cpp
    main/AppServices.h
    main/MainWindow.h
    main/MainWindow.cpp
    main/ChangePasswordDialog.h
    main/ChangePasswordDialog.cpp
    dashboard/DashboardPage.h
    dashboard/DashboardPage.cpp
    dashboard/RevenueChart.h
    dashboard/RevenueChart.cpp
    students/StudentPage.h
    students/StudentPage.cpp
    students/StudentTableModel.h
    students/StudentTableModel.cpp
    students/StudentFormDialog.h
    students/StudentFormDialog.cpp
    students/StudentFormDialog.ui
    students/StudentProfileDialog.h
    students/StudentProfileDialog.cpp
    lists/ListPage.h
    lists/ListPage.cpp
    classes/ClassPage.h
    classes/ClassPage.cpp
    classes/ClassFormDialog.h
    classes/ClassFormDialog.cpp
    classes/ScheduleDialog.h
    classes/ScheduleDialog.cpp
    enrollments/EnrollmentPage.h
    enrollments/EnrollmentPage.cpp
    enrollments/EnrollDialog.h
    enrollments/EnrollDialog.cpp
    placement/PlacementPage.h
    placement/PlacementPage.cpp
    placement/PlacementTestDialog.h
    placement/PlacementTestDialog.cpp
    sessions/TimetablePage.h
    sessions/TimetablePage.cpp
    sessions/AttendanceDialog.h
    sessions/AttendanceDialog.cpp
    grades/GradeBookModel.h
    grades/GradeBookModel.cpp
    grades/GradeBookPage.h
    grades/GradeBookPage.cpp
    tuition/TuitionPage.h
    tuition/TuitionPage.cpp
    tuition/CollectPaymentDialog.h
    tuition/CollectPaymentDialog.cpp
    tuition/ReceiptPrinter.h
    tuition/ReceiptPrinter.cpp
    payroll/PayrollPage.h
    payroll/PayrollPage.cpp
    reports/RevenuePage.h
    reports/RevenuePage.cpp
    accounts/AccountPage.h
    accounts/AccountPage.cpp
    backup/BackupPage.h
    backup/BackupPage.cpp
    catalog/BranchPage.h
    catalog/BranchPage.cpp
    catalog/CoursePage.h
    catalog/CoursePage.cpp
    catalog/TeacherPage.h
    catalog/TeacherPage.cpp
    catalog/EmployeePage.h
    catalog/EmployeePage.cpp
    catalog/PromotionPage.h
    catalog/PromotionPage.cpp
    teaching/MyClassesPage.h
    teaching/MyClassesPage.cpp
)
# PrintSupport: print preview and printing of the reports (ReportPreviewDialog)
target_link_libraries(qlttta_presentation PUBLIC qlttta_application Qt6::Widgets Qt6::PrintSupport Qt6::Svg)

# ---- Translations (i18n) ----
# UI strings in the code are English (source language). resources/translations/qlttta_vi.ts holds the
# Vietnamese translation; at build time lrelease compiles it to qlttta_vi.qm and embeds it as :/i18n/qlttta_vi.qm.
# After adding/changing a tr("...") string:  cmake --build --preset <preset> --target update_translations
# (lupdate scans the domain/application/infrastructure/presentation sources), then translate in Qt Linguist.
qt_add_translations(qlttta_presentation
    SOURCE_TARGETS qlttta_domain qlttta_application qlttta_infrastructure qlttta_presentation
    TS_FILES ${PROJECT_SOURCE_DIR}/resources/translations/qlttta_vi.ts
    RESOURCE_PREFIX /i18n
    LUPDATE_OPTIONS -no-obsolete -locations none)
