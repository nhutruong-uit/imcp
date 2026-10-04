# Composition root: the ONLY place that knows every layer; it creates and wires the objects.
qt_add_executable(QLTTTA
    main.cpp
    AppContainer.h
    AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_link_libraries(QLTTTA PRIVATE qlttta_presentation qlttta_infrastructure)
target_compile_definitions(QLTTTA PRIVATE QLTTTA_VERSION="${PROJECT_VERSION}")

set_target_properties(QLTTTA PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE ON
    MACOSX_BUNDLE_BUNDLE_NAME "QLTTTA"
    MACOSX_BUNDLE_GUI_IDENTIFIER "vn.edu.uit.ie103.qlttta"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_INFO_PLIST "${PROJECT_SOURCE_DIR}/packaging/macos/Info.plist.in"
)

if(WIN32)
    # Icon and version information of QLTTTA.exe. windres (MinGW) hands include directories to its preprocessor
    # through cmd.exe without quoting them, so a folder with a space ("D:\My Projects\imcp") breaks the build.
    # The resource script is therefore compiled in its own object library, which has no include directories;
    # windres finds app.ico next to app.rc by itself. The version numbers come from project(VERSION ...).
    add_library(qlttta_app_resources OBJECT ${PROJECT_SOURCE_DIR}/packaging/windows/app.rc)
    set_target_properties(qlttta_app_resources PROPERTIES AUTOMOC OFF AUTOUIC OFF AUTORCC OFF)
    target_compile_definitions(qlttta_app_resources PRIVATE
        QLTTTA_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
        QLTTTA_VERSION_MINOR=${PROJECT_VERSION_MINOR}
        QLTTTA_VERSION_PATCH=${PROJECT_VERSION_PATCH}
        QLTTTA_VERSION_TEXT=${PROJECT_VERSION})
    target_link_libraries(QLTTTA PRIVATE qlttta_app_resources)
endif()
if(APPLE)
    set(QLTTTA_ICNS ${PROJECT_SOURCE_DIR}/packaging/macos/AppIcon.icns)
    if(EXISTS ${QLTTTA_ICNS})
        target_sources(QLTTTA PRIVATE ${QLTTTA_ICNS})
        set_source_files_properties(${QLTTTA_ICNS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        set_target_properties(QLTTTA PROPERTIES MACOSX_BUNDLE_ICON_FILE AppIcon.icns)
    endif()
endif()

install(TARGETS QLTTTA BUNDLE DESTINATION . RUNTIME DESTINATION .)
