add_custom_command(
  OUTPUT
    ${CMAKE_CURRENT_SOURCE_DIR}/target/native/release/build/tcp-echo-server.c
  COMMAND moon build --directory ${CMAKE_CURRENT_SOURCE_DIR} --target=native)

add_executable(
  tcp-echo-server
  ${CMAKE_CURRENT_SOURCE_DIR}/target/native/release/build/tcp-echo-server.c)
install(TARGETS tcp-echo-server RUNTIME DESTINATION "${CMAKE_SOURCE_DIR}/bin")
target_link_libraries(tcp-echo-server PRIVATE uv.mbt uv_a moonbit)
