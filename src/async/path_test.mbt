///|
test "relative_to" {
  @async.start(fn() {
    let async_pipe_mbt = @async.path("src/async/pipe.mbt")
    let sync_path_mbt = @async.path("src/sync/path.mbt")
    let relative_path = async_pipe_mbt.relative_to(sync_path_mbt)
    inspect(relative_path, content="../../async/pipe.mbt")
    inspect(
      (sync_path_mbt / relative_path).resolve().relative_to(@async.cwd()),
      content="src/async/pipe.mbt",
    )
  })
}
