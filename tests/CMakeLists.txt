# Unit test (Qt Test). Tầng domain/application được kiểm thử KHÔNG cần CSDL nhờ dùng
# repository giả (fake) - lợi ích trực tiếp của Clean Architecture.

# Trên Windows, tiến trình không gắn console (vd runner GitHub Actions) thì Qt Test gửi log vào
# OutputDebugString thay vì stdout => ctest không thấy kết quả. Biến này buộc Qt in ra stdout/stderr.
set(QLTTTA_TEST_ENV "QT_FORCE_STDERR_LOGGING=1")

function(qlttta_add_test name)
    qt_add_executable(${name} ${name}.cpp)
    target_link_libraries(${name} PRIVATE Qt6::Test ${ARGN})
    set_target_properties(${name} PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
    add_test(NAME ${name} COMMAND ${name})
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "${QLTTTA_TEST_ENV}")
endfunction()

qlttta_add_test(tst_domain qlttta_domain)
qlttta_add_test(tst_application qlttta_application)
qlttta_add_test(tst_sqlerrormapper qlttta_infrastructure)

# Kiểm thử end-to-end qua giao diện (cần CSDL thật, tự SKIP nếu thiếu QLTTTA_E2E_PASSWORD)
qt_add_executable(tst_e2e_gui
    tst_e2e_gui.cpp
    ${PROJECT_SOURCE_DIR}/src/app/AppContainer.cpp
    ${PROJECT_SOURCE_DIR}/resources/resources.qrc
)
target_link_libraries(tst_e2e_gui PRIVATE Qt6::Test qlttta_presentation qlttta_infrastructure)
set_target_properties(tst_e2e_gui PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
add_test(NAME tst_e2e_gui COMMAND tst_e2e_gui)
# QSKIP (thiếu QLTTTA_E2E_PASSWORD, vd trên CI) => ctest ghi "Skipped" thay vì "Passed"
set_tests_properties(tst_e2e_gui PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;${QLTTTA_TEST_ENV}"
                                            SKIP_REGULAR_EXPRESSION "SKIP   : ")
