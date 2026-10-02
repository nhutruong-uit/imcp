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
    common/TableExporter.h
    common/TableExporter.cpp
    common/UiHelpers.h
    common/UiHelpers.cpp
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
    lists/ListPage.h
    lists/ListPage.cpp
)
target_link_libraries(qlttta_presentation PUBLIC qlttta_application Qt6::Widgets Qt6::Svg)

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
