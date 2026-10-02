# Developer tool: logs in with the demo accounts and takes screenshots of every screen
# (visual check against the real database and figures for the report).
qt_add_executable(qlttta_screenshots
    screenshot_tool.cpp
    ${PROJECT_SOURCE_DIR}/src/app/AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_link_libraries(qlttta_screenshots PRIVATE qlttta_presentation qlttta_infrastructure)
target_compile_definitions(qlttta_screenshots PRIVATE QLTTTA_VERSION="${PROJECT_VERSION}")
set_target_properties(qlttta_screenshots PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
