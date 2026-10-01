# Công cụ cho lập trình viên: tự đăng nhập bằng tài khoản demo và chụp ảnh các màn hình
# (dùng để kiểm tra giao diện với CSDL thật và lấy hình minh họa cho báo cáo).
qt_add_executable(qlttta_screenshots
    screenshot_tool.cpp
    ${PROJECT_SOURCE_DIR}/src/app/AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_link_libraries(qlttta_screenshots PRIVATE qlttta_presentation qlttta_infrastructure)
target_compile_definitions(qlttta_screenshots PRIVATE QLTTTA_VERSION="${PROJECT_VERSION}")
set_target_properties(qlttta_screenshots PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
