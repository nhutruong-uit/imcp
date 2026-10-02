cmake_minimum_required(VERSION 3.21)

project(QLTTTA
    VERSION 0.1.0
    DESCRIPTION "English center management system - IE103 course project"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(QLTTTA_BUILD_TESTS "Build unit tests" ON)
option(QLTTTA_BUILD_TOOLS "Build developer tools (screenshot generator)" OFF)

set(QLTTTA_QT_COMPONENTS Core Gui Widgets Sql Svg LinguistTools)
if(QLTTTA_BUILD_TESTS)
    list(APPEND QLTTTA_QT_COMPONENTS Test)
endif()
# Qt 6.7+: qt_add_translations(... SOURCE_TARGETS ...) used in src/presentation/CMakeLists.txt
find_package(Qt6 6.7 REQUIRED COMPONENTS ${QLTTTA_QT_COMPONENTS})
qt_standard_project_setup()   # enables AUTOMOC, AUTOUIC
set(CMAKE_AUTORCC ON)

# Compiler warnings; MSVC needs /utf-8 to read the Vietnamese text (database values) in the sources
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
