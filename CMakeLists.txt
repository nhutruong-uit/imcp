cmake_minimum_required(VERSION 3.21)

project(QLTTTA
    VERSION 0.1.0
    DESCRIPTION "He thong quan ly trung tam tieng Anh - Do an IE103"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(QLTTTA_BUILD_TESTS "Build unit tests" ON)
option(QLTTTA_BUILD_TOOLS "Build developer tools (screenshot generator)" OFF)

set(QLTTTA_QT_COMPONENTS Core Gui Widgets Sql Svg)
if(QLTTTA_BUILD_TESTS)
    list(APPEND QLTTTA_QT_COMPONENTS Test)
endif()
find_package(Qt6 6.5 REQUIRED COMPONENTS ${QLTTTA_QT_COMPONENTS})
qt_standard_project_setup()   # bật AUTOMOC, AUTOUIC
set(CMAKE_AUTORCC ON)

# Cảnh báo trình biên dịch; MSVC cần /utf-8 để đọc đúng chuỗi tiếng Việt trong mã nguồn
if(MSVC)
    add_compile_options(/utf-8 /W4 /permissive-)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

add_subdirectory(src)

if(QLTTTA_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(QLTTTA_BUILD_TOOLS)
    add_subdirectory(tools)
endif()
