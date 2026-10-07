cmake_minimum_required(VERSION 3.21)

# macOS: build for the major version of this Mac (e.g. 27.0), the version the Homebrew Qt bottles are built for.
# Left empty, the compiler targets the version of the Xcode SDK, which can be older than macOS and the bottles
# (ld: "building for macOS-26.5, but linking with dylib ... QtSvg ... built for newer version 27.0").
# scripts/package-macos.sh uses the same rule; -DCMAKE_OSX_DEPLOYMENT_TARGET=<version> still overrides it.
# Must be set before project().
if(CMAKE_HOST_APPLE AND NOT CMAKE_OSX_DEPLOYMENT_TARGET AND NOT DEFINED ENV{MACOSX_DEPLOYMENT_TARGET})
    execute_process(COMMAND sw_vers -productVersion
        OUTPUT_VARIABLE _qlttta_macos_version OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REGEX MATCH "^[0-9]+" _qlttta_macos_major "${_qlttta_macos_version}")
    if(_qlttta_macos_major)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "${_qlttta_macos_major}.0" CACHE STRING
            "Minimum macOS version of the build (default: the major version of this Mac)" FORCE)
    endif()
endif()

project(QLTTTA
    VERSION 1.1.0
    DESCRIPTION "English center management system - IE103 course project"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# clangd only searches ancestor directories of the source file for compile_commands.json,
# while each preset writes it under build/<preset>/. A symlink at the repo root (gitignored)
# lets every machine and preset resolve Qt and project headers without a local clangd path.
# Created before generation: the link target is written when configuration finishes.
if(CMAKE_EXPORT_COMPILE_COMMANDS AND NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    set(_qlttta_compile_commands "${CMAKE_SOURCE_DIR}/compile_commands.json")
    if(IS_SYMLINK "${_qlttta_compile_commands}" OR EXISTS "${_qlttta_compile_commands}")
        file(REMOVE "${_qlttta_compile_commands}")
    endif()
    file(RELATIVE_PATH _qlttta_compile_commands_rel
        "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/compile_commands.json")
    file(CREATE_LINK "${_qlttta_compile_commands_rel}" "${_qlttta_compile_commands}"
        SYMBOLIC RESULT _qlttta_link_result)
    if(_qlttta_link_result)
        message(STATUS
            "clangd: could not symlink compile_commands.json into the source root "
            "(${_qlttta_link_result}). On Windows, enable Developer Mode for symlinks.")
    endif()
endif()

option(QLTTTA_BUILD_TESTS "Build unit tests" ON)
option(QLTTTA_BUILD_TOOLS "Build developer tools (screenshot generator)" OFF)

set(QLTTTA_QT_COMPONENTS Core Gui Widgets PrintSupport Sql Svg LinguistTools)
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
