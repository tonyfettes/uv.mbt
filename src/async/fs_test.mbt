///|
test "open" {
  @async.start!(fn() {
    let moon_mod_json = @async.path("moon.mod.json").read().text!()
      |> @json.parse!()
    assert_true!(moon_mod_json is Object({ "name": "tonyfettes/uv", .. }))
  })
}

///|
test "write" {
  @async.start!(fn() {
    let path = @async.path(["test", "fixtures", "example_write.txt"])
    assert_false(path.exists())
    let content = "Hello, world!"
    path.write_text(content, encoding=UTF8)
    assert_true(path.exists())
    assert_eq(path.read_text(encoding=UTF8), content)
    path.unlink()
    assert_false(path.exists())
  })
}

///|
test "write/stdio" {
  @async.start(fn() {
    @async.stdout.write_text("Hello, world!\n", encoding=UTF8)
  })
}

///|
test "write/truncate" {
  @async.start(fn() {
    let readme = @async.path("README.md")
    let backup = readme.read_text(encoding=UTF8)
    readme.write_bytes("")
    @json.inspect!(readme.read_text(encoding=UTF8), content="")
    readme.write_text(backup, encoding=UTF8)
  })
}

///|
test "scandir" {
  @async.start!(fn() {
    @json.inspect!(@async.path(["test", "fixtures"]).iter!().collect(), content=[
      "test/fixtures/example.txt",
    ])
  })
}

///|
test "copy_to/file" {
  @async.start!(fn() {
    let src = @async.path(["test", "fixtures", "example.txt"])
    assert_true(src.exists())
    let dst = @async.path(["test", "fixtures", "example_copy.txt"])
    assert_false(dst.exists())
    try {
      src.copy_to(dst)
      assert_true(dst.is_file())
      dst.unlink()
    } catch {
      error => {
        dst.unlink()
        raise error
      }
    }
  })
}

///|
test "copy_to/directory" {
  @async.start(fn() {
    let src = @async.path("src")
    let dst = @async.path("src_copy")
    src.copy_to(dst, recursive=true)
    assert_true(dst.is_dir())
    assert_true(dst.iter().collect().length() > 0)
    dst.remove(recursive=true)
  })
}

///|
test "exists" {
  @async.start(fn() {
    let path = @async.path(["test", "fixtures", "example.txt"])
    @json.inspect(path.exists(), content=true)
  })
}

///|
test "move_to" {
  @async.start(fn() {
    let src = @async.path(["test", "fixtures", "example.txt"])
    let dst = @async.path(["test", "fixtures", "example_move.txt"])
    @json.inspect(src.exists(), content=true)
    @json.inspect(dst.exists(), content=false)
    src.move_to(dst)
    @json.inspect(src.exists(), content=false)
    @json.inspect(dst.exists(), content=true)
    dst.move_to(src)
    @json.inspect(src.exists(), content=true)
    @json.inspect(dst.exists(), content=false)
  })
}
