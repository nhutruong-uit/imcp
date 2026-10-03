# Unit tests (Qt Test). The domain/application layers are tested WITHOUT a database by using fake
# repositories - a direct benefit of the Clean Architecture.

# On Windows, a process without a console (e.g. a GitHub Actions runner) makes Qt Test send its log to
# OutputDebugString instead of stdout => ctest sees nothing. This variable forces Qt to print to stdout/stderr.
set(QLTTTA_TEST_ENV "QT_FORCE_STDERR_LOGGING=1")

# qlttta_add_test(<name> <libraries...>): one test executable from <name>.cpp, linked with Qt Test and the given
# layer libraries, registered with ctest under the same name (ctest -R <name> runs it alone)
function(qlttta_add_test name)
    qt_add_executable(${name} ${name}.cpp)
    target_link_libraries(${name} PRIVATE Qt6::Test ${ARGN})
    set_target_properties(${name} PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
    add_test(NAME ${name} COMMAND ${name})
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "${QLTTTA_TEST_ENV}")
endfunction()

# Entities and validation rules (domain layer only)
qlttta_add_test(tst_domain qlttta_domain)
# Use cases with fake repositories (application layer; it cannot reach SQL because it does not link infrastructure)
qlttta_add_test(tst_application qlttta_application)
# ODBC error messages and connection string (infrastructure layer, no connection is opened)
qlttta_add_test(tst_sqlerrormapper qlttta_infrastructure)
# FreeTDS Unicode workaround of SqlHelpers (infrastructure layer, no connection is opened)
qlttta_add_test(tst_sqlhelpers qlttta_infrastructure)

# CSV and PDF export of a table (presentation layer, no database); offscreen = no display needed for QPdfWriter
qlttta_add_test(tst_exporter qlttta_presentation)
set_tests_properties(tst_exporter PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;${QLTTTA_TEST_ENV}")

# Repository conventions read from the files (no database): SQL syntax/headers, layers, scripts, numbers in the docs
qlttta_add_test(tst_conventions)
target_compile_definitions(tst_conventions PRIVATE QLTTTA_SOURCE_DIR="${PROJECT_SOURCE_DIR}")

# Translations: English source strings, Vietnamese .ts/.qm, labels of database values and messages
qlttta_add_test(tst_i18n qlttta_presentation qlttta_infrastructure)
target_compile_definitions(tst_i18n PRIVATE
    QLTTTA_TS_FILE="${PROJECT_SOURCE_DIR}/resources/translations/qlttta_vi.ts"
    QLTTTA_DATABASE_DIR="${PROJECT_SOURCE_DIR}/database")

# End-to-end test through the GUI (needs a real database; SKIPPED when QLTTTA_E2E_PASSWORD is not set).
# It compiles AppContainer.cpp and the resources itself, like the application, to get the real wiring;
# QT_QPA_PLATFORM=offscreen lets the windows run without a display (CI).
qt_add_executable(tst_e2e_gui
    tst_e2e_gui.cpp
    ${PROJECT_SOURCE_DIR}/src/app/AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_link_libraries(tst_e2e_gui PRIVATE Qt6::Test qlttta_presentation qlttta_infrastructure)
set_target_properties(tst_e2e_gui PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
add_test(NAME tst_e2e_gui COMMAND tst_e2e_gui)
# QSKIP (no QLTTTA_E2E_PASSWORD, e.g. on CI) => ctest reports "Skipped" instead of "Passed"
set_tests_properties(tst_e2e_gui PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;${QLTTTA_TEST_ENV}"
                                            SKIP_REGULAR_EXPRESSION "SKIP   : ")
