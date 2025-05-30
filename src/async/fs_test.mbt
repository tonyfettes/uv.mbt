///|
test "open" {
  @async.start!(fn() {
    let moon_mod_json = @async.path!("moon.mod.json").read!().text!()
      |> @json.parse!()
    assert_true!(moon_mod_json is Object({ "name": "tonyfettes/uv", .. }))
  })
}

///|
test "write" {
  @async.start!(fn() {
    let path = @async.path!(["test", "fixtures", "example_write.txt"])
    @json.inspect!(path.stat?().is_err(), content=true)
    path.write_text!("Hello, world!")
    @json.inspect!(path.stat!().is_file(), content=true)
    @json.inspect!(path.read_text!(), content="Hello, world!")
    path.unlink!()
    @json.inspect!(path.stat?().is_err(), content=true)
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
test "exists" {
  @async.start!(fn() {
    let path = @async.path!(["test", "fixtures", "example.txt"])
    @json.inspect!(path.exists!(), content=true)
  })
}

///|
test "move_to" {
  @async.start!(fn() {
    let src = @async.path(["test", "fixtures", "example.txt"])
    let dst = @async.path(["test", "fixtures", "example_move.txt"])
    @json.inspect(src.exists(), content=true)
    @json.inspect(dst.exists(), content=false)
    src.move_to!(dst)
    @json.inspect(src.exists(), content=false)
    @json.inspect(dst.exists(), content=true)
    dst.move_to!(src)
    @json.inspect(src.exists(), content=true)
    @json.inspect(dst.exists(), content=false)
  })
}
