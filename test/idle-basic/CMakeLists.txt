add_custom_command(
  OUTPUT
    ${CMAKE_CURRENT_SOURCE_DIR}/target/native/release/build/idle-basic.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/main.mbt
  COMMAND moon build --directory ${CMAKE_CURRENT_SOURCE_DIR} --target=native)

add_executable(idle-basic target/native/release/build/idle-basic.c)
install(TARGETS idle-basic RUNTIME DESTINATION "${CMAKE_SOURCE_DIR}/bin")
target_link_libraries(idle-basic PRIVATE uv.mbt uv_a moonbit)
