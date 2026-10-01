# Unit test (Qt Test). Tầng domain/application được kiểm thử KHÔNG cần CSDL nhờ dùng
# repository giả (fake) - lợi ích trực tiếp của Clean Architecture.
function(qlttta_add_test name)
    qt_add_executable(${name} ${name}.cpp)
    target_link_libraries(${name} PRIVATE Qt6::Test ${ARGN})
    set_target_properties(${name} PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
    add_test(NAME ${name} COMMAND ${name})
endfunction()

qlttta_add_test(tst_domain qlttta_domain)
qlttta_add_test(tst_application qlttta_application)
qlttta_add_test(tst_sqlerrormapper qlttta_infrastructure)
