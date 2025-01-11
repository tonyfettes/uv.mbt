add_custom_command(
  OUTPUT
    ${CMAKE_CURRENT_SOURCE_DIR}/target/native/release/build/uvcat.c
  COMMAND moon build --directory ${CMAKE_CURRENT_SOURCE_DIR} --target=native)

add_executable(
  uvcat
  ${CMAKE_CURRENT_SOURCE_DIR}/target/native/release/build/uvcat.c)
install(TARGETS uvcat RUNTIME DESTINATION "${CMAKE_SOURCE_DIR}/bin")
target_link_libraries(uvcat PRIVATE uv.mbt PkgConfig::uv moonbit)
