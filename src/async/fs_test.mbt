///|
test "open" {
  @async.start!(fn() {
    let moon_mod_json = @async.Path::new("moon.mod.json").read().text!()
      |> @json.parse!()
    assert_true!(moon_mod_json is Object({ "name": "tonyfettes/uv", .. }))
  })
}

///|
test "write" {
  @async.start!(fn() {
    let path = @async.Path::new(["test", "fixtures", "example_write.txt"])
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
    let readme = @async.Path::new("README.md")
    let backup = readme.read_text(encoding=UTF8)
    readme.write_bytes("")
    @json.inspect!(readme.read_text(encoding=UTF8), content="")
    readme.write_text(backup, encoding=UTF8)
  })
}

///|
test "scandir" {
  @async.start!(fn() {
    @json.inspect!(@async.Path::new(["test", "fixtures"]).iter!().collect(), content=[
      "test/fixtures/example.txt",
    ])
  })
}

///|
test "copy_to/file" {
  @async.start!(fn() {
    let src = @async.Path::new(["test", "fixtures", "example.txt"])
    assert_true(src.exists())
    let dst = @async.Path::new(["test", "fixtures", "example_copy.txt"])
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
    let src = @async.Path::new("src")
    let dst = @async.Path::new("src_copy")
    src.copy_to(dst, recursive=true)
    assert_true(dst.is_dir())
    assert_true(dst.iter().collect().length() > 0)
    dst.remove(recursive=true)
  })
}

///|
test "exists" {
  @async.start(fn() {
    let path = @async.Path::new(["test", "fixtures", "example.txt"])
    @json.inspect(path.exists(), content=true)
  })
}

///|
test "move_to" {
  @async.start(fn() {
    let src = @async.Path::new(["test", "fixtures", "example.txt"])
    let dst = @async.Path::new(["test", "fixtures", "example_move.txt"])
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

///|
test "walk" {
  @async.start(fn() {
    let fixtures = @async.Path::new(["test", "fixtures"])
    async fn cleanup() {
      try (fixtures / "example").remove(recursive=true) catch {
        _ => ()
      }
      try (fixtures / "example_0.txt").unlink() catch {
        _ => ()
      }
      try (fixtures / "example" / "1.txt").unlink() catch {
        _ => ()
      }
      try (fixtures / "example" / "2.txt").unlink() catch {
        _ => ()
      }
    }

    try {
      (fixtures / "example").mkdir()
      let src = fixtures / "example.txt"
      src.copy_to(fixtures / "example_0.txt")
      src.copy_to(fixtures / "example" / "1.txt")
      src.copy_to(fixtures / "example" / "2.txt")
      let files = @async.Path::new(["test", "fixtures"]).walk!().collect()
      files.sort()
      @json.inspect(files, content=[
        "test/fixtures/example", "test/fixtures/example.txt", "test/fixtures/example_0.txt",
        "test/fixtures/example/1.txt", "test/fixtures/example/2.txt",
      ])
      cleanup()
    } catch {
      error => {
        cleanup()
        raise error
      }
    }
  })
}

///|
test "trace" {
  @async.start(fn() {
    try {
      @async.Path::new(["test", "fixtures"]).mkdir()
      fail("Should not be able to create a directory that already exists")
    } catch {
      error =>
        inspect(
          error,
          content=
            #|Trace:
            #|  src/async/fs_test.mbt:152:7-152:53
            #|        @async.Path::new(["test", "fixtures"]).mkdir()
            #|  src/async/fs.mbt:534:20-534:45
            #|              reject(SystemError::exists(self))
            #|Exists: test/fixtures
          ,
        )
    }
  })
}
