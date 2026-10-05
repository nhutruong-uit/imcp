# Developer tool: logs in with the demo accounts and takes screenshots of every screen
# (visual check against the real database and figures for the report).
# Built only when QLTTTA_BUILD_TOOLS=ON (top-level CMakeLists.txt). Like the end-to-end test it compiles
# AppContainer.cpp and the resources itself, to get the same wiring as the application.
qt_add_executable(qlttta_screenshots
    screenshot_tool.cpp
    ${PROJECT_SOURCE_DIR}/src/app/AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_link_libraries(qlttta_screenshots PRIVATE qlttta_presentation qlttta_infrastructure)
# Project version for QApplication::setApplicationVersion (the login screen shows it)
target_compile_definitions(qlttta_screenshots PRIVATE QLTTTA_VERSION="${PROJECT_VERSION}")
# A plain command-line program (no macOS .app bundle, console on Windows) so it prints its progress
set_target_properties(qlttta_screenshots PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
