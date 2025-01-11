cmake_minimum_required(VERSION 3.18)
project(uv.mbt)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_VERBOSE_MAKEFILE on)

find_package(PkgConfig REQUIRED)
pkg_check_modules(uv REQUIRED IMPORTED_TARGET libuv)

add_library(moonbit OBJECT IMPORTED)
set_target_properties(
  moonbit
  PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/include"
             IMPORTED_OBJECTS "${CMAKE_SOURCE_DIR}/lib/libmoonbitrun.o")

add_library(uv.mbt STATIC src/uv.c)
target_include_directories(uv.mbt SYSTEM PRIVATE "${uv_INCLUDE_DIRS}"
                                                 "${CMAKE_SOURCE_DIR}/include")

install(TARGETS uv.mbt DESTINATION ${CMAKE_SOURCE_DIR}/lib)

add_subdirectory(test)
