///|
test "open" {
  @async.start!(fn() {
    let moon_mod_json = @async.path!("moon.mod.json").read!().text!()
      |> @json.parse!()
    assert_true!(moon_mod_json is Object({ "name": "tonyfettes/uv", .. }))
  })
}

///|
test "scandir" {
  @async.start!(fn() {
    @json.inspect!(@async.path!(["test", "fixtures"]).iter!().collect(), content=[
      "test/fixtures/example.txt",
    ])
  })
}

///|
test "copy_to" {
  @async.start!(fn() {
    let src = @async.path!(["test", "fixtures", "example.txt"])
    assert_true!(src.stat!().is_file())
    let dst = @async.path!(["test", "fixtures", "example_copy.txt"])
    assert_true!(dst.stat?().is_err())
    try {
      src.copy_to!(dst)
      assert_true!(dst.stat!().is_file())
      dst.unlink!()
    } catch {
      error => {
        dst.unlink?() |> ignore()
        raise error
      }
    }
  })
}

///|
test "move_to" {
  @async.start!(fn() {
    let src = @async.path!(["test", "fixtures", "example.txt"])
    assert_true!(src.stat!().is_file())
    let dst = @async.path!(["test", "fixtures", "example_move.txt"])
    assert_true!(dst.stat?().is_err())
    src.move_to!(dst)
    assert_true!(src.stat?().is_err())
    assert_true!(dst.stat!().is_file())
    dst.move_to!(src)
    assert_true!(src.stat!().is_file())
    assert_true!(dst.stat?().is_err())
  })
}
