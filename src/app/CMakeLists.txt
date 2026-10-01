# Composition root: nơi DUY NHẤT biết tất cả các tầng, khởi tạo và "nối dây" các đối tượng.
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
    set(QLTTTA_RC ${PROJECT_SOURCE_DIR}/packaging/windows/app.rc)
    target_sources(QLTTTA PRIVATE ${QLTTTA_RC})
    # windres/rc tìm app.ico theo thư mục include
    set_property(SOURCE ${QLTTTA_RC} APPEND PROPERTY INCLUDE_DIRECTORIES ${PROJECT_SOURCE_DIR}/packaging/windows)
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
