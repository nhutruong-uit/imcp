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

# Developer tool: plays the demo accounts through the real screens and records the demo video (docs/demo),
# see tools/demo_video_tool.cpp. Same wiring as the screenshot tool; needs ffmpeg when it runs, not to build.
qt_add_executable(qlttta_demo_video
    demo_video_tool.cpp
    demo/Director.cpp
    demo/Director.h
    demo/Recorder.cpp
    demo/Recorder.h
    demo/Scenario.cpp
    demo/Scenario.h
    ${PROJECT_SOURCE_DIR}/src/app/AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_include_directories(qlttta_demo_video PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(qlttta_demo_video PRIVATE qlttta_presentation qlttta_infrastructure)
target_compile_definitions(qlttta_demo_video PRIVATE QLTTTA_VERSION="${PROJECT_VERSION}")
set_target_properties(qlttta_demo_video PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
