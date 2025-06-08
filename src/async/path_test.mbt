///|
test "relative_to" {
  @async.start(fn() {
    let async_pipe_mbt = @async.Path::new("src/async/pipe.mbt")
    let fs_mbt = @async.path("src/fs.mbt")
    let relative_path = async_pipe_mbt.relative_to(fs_mbt)
    inspect(relative_path, content="../async/pipe.mbt")
    inspect(
      fs_mbt.join(relative_path).resolve(),
      content="/Users/haoxiang/Workspace/moonbit/feihaoxiang/uv.mbt/src/async/pipe.mbt",
    )
    inspect(
      @async.cwd(),
      content="/Users/haoxiang/Workspace/moonbit/feihaoxiang/uv.mbt",
    )
    inspect(
      (fs_mbt / relative_path).resolve().relative_to(@async.cwd()),
      content="src/async/pipe.mbt",
    )
  })
}

///|
test "windows/String" {
  let string : String = "C:\\Windows\\System32\\file.txt"
  let path = @async.WindowsPath::new(string)
  @json.inspect(path, content="C:\\Windows\\System32\\file.txt")
  @json.inspect(path.parts(), content=[
    "C:\\", "Windows", "System32", "file.txt",
  ])
  @json.inspect(path.drive(), content="C:")
  @json.inspect(path.root(), content="\\")
  @json.inspect(path.anchor(), content="C:\\")
}

///|
test "windows/@string.View" {
  let string : @string.View = "C:/Windows/System32/file.txt"
  let path = @async.WindowsPath::new(string)
  @json.inspect(path, content="C:\\Windows\\System32\\file.txt")
  @json.inspect(path.parts(), content=[
    "C:\\", "Windows", "System32", "file.txt",
  ])
  @json.inspect(path.drive(), content="C:")
  @json.inspect(path.root(), content="\\")
  @json.inspect(path.anchor(), content="C:\\")
}

///|
test "windows/drive" {
  let path = @async.windows_path("C:\\Windows\\System32")
  @json.inspect(path.parts(), content=["C:\\", "Windows", "System32"])
  @json.inspect(path.drive(), content="C:")
  @json.inspect(path.root(), content="\\")
  @json.inspect(path.anchor(), content="C:\\")
  inspect(path, content="C:\\Windows\\System32")
}

///|
test "windows/unc" {
  let path = @async.WindowsPath::new("\\\\server\\share\\file.txt")
  @json.inspect(path.parts(), content=["\\\\server\\share\\", "file.txt"])
  @json.inspect(path.drive(), content="\\\\server\\share")
  @json.inspect(path.root(), content="\\")
  inspect(path, content="\\\\server\\share\\file.txt")
}

///|
test "windows/relative" {
  let path = @async.WindowsPath::new("directory/file.txt")
  @json.inspect(path.parts(), content=["directory", "file.txt"])
  @json.inspect(path.drive(), content="")
  @json.inspect(path.root(), content="")
  inspect(path, content="directory\\file.txt")
}

///|
test "windows/parent" {
  let path = @async.WindowsPath::new("C:\\Windows\\System32\\file.txt")
  let parent = path.parent()
  @json.inspect(parent, content=["C:\\Windows\\System32"])
  let grandparent = parent.bind(fn(parent) { parent.parent() })
  @json.inspect(grandparent, content=["C:\\Windows"])
  let great_grandparent = grandparent.bind(fn(grandparent) {
    grandparent.parent()
  })
  @json.inspect(great_grandparent, content=["C:\\"])
  let great_great_grandparent = great_grandparent.bind(fn(great_grandparent) {
    great_grandparent.parent()
  })
  @json.inspect(great_great_grandparent is None, content=true)
}

///|
test "windows/to_posix_path" {
  let path = @async.WindowsPath::new("C:\\Windows\\System32\\file.txt")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="C:/Windows/System32/file.txt")
  let path = @async.WindowsPath::new("\\\\server\\share\\file.txt")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="//server/share/file.txt")
  let path = @async.WindowsPath::new("directory/file.txt")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="directory/file.txt")
}

///|
test "windows/relative_to" {
  let path = @async.WindowsPath::new("C:\\Windows\\System32\\file.txt")
  let base = @async.WindowsPath::new("C:\\Windows\\System32")
  let relative_path = path.relative_to(base)
  @json.inspect(relative_path, content="file.txt")
}

///|
test "posix/String" {
  let string : String = "/usr/bin/file.txt"
  let path = @async.PosixPath::new(string)
  inspect(path, content="/usr/bin/file.txt")
}

///|
test "posix/@string.View" {
  let string : @string.View = "/usr/bin/file.txt"
  let path = @async.PosixPath::new(string)
  inspect(path, content="/usr/bin/file.txt")
}

///|
test "posix/parts" {
  let path = @async.posix_path("/usr/bin/file.txt")
  @json.inspect(path.parts(), content=["/", "usr", "bin", "file.txt"])
  @json.inspect(path.drive(), content="")
  @json.inspect(path.root(), content="/")
  @json.inspect(path.anchor(), content="/")
  inspect(path, content="/usr/bin/file.txt")
}

///|
test "posix/impl" {
  let path = @async.PosixPath::new("//usr//bin//file.txt")
  @json.inspect(path.parts(), content=["//", "usr", "bin", "file.txt"])
  @json.inspect(path.drive(), content="")
  @json.inspect(path.root(), content="//")
  inspect(path, content="//usr/bin/file.txt")
}

///|
test "posix/parent" {
  let path = @async.PosixPath::new("/usr/bin/file.txt")
  let parent = path.parent()
  @json.inspect(parent, content=["/usr/bin"])
  let grandparent = parent.bind(fn(parent) { parent.parent() })
  @json.inspect(grandparent, content=["/usr"])
  let great_grandparent = grandparent.bind(fn(grandparent) {
    grandparent.parent()
  })
  @json.inspect(great_grandparent, content=["/"])
  let great_great_grandparent = great_grandparent.bind(fn(great_grandparent) {
    great_grandparent.parent()
  })
  @json.inspect(great_great_grandparent is None, content=true)
}

///|
test "posix/to_windows_path" {
  let path = @async.PosixPath::new("/usr/bin/file.txt")
  let windows_path = path.to_windows_path()
  inspect(windows_path, content="\\usr\\bin\\file.txt")
  let path = @async.PosixPath::new("//usr//bin//file.txt")
  let windows_path = path.to_windows_path()
  inspect(windows_path, content="\\\\usr\\bin\\file.txt")
  @json.inspect(windows_path.parts(), content=["\\\\usr\\bin\\", "file.txt"])
}

///|
test "posix/relative_to" {
  let path = @async.PosixPath::new("/usr/bin/file.txt")
  let base = @async.PosixPath::new("/usr/bin")
  let relative_path = path.relative_to(base)
  @json.inspect(relative_path, content="file.txt")
}

///|
test "Path::new(String)" {
  let path = @async.Path::new("a/b/c")
  @json.inspect(path, content="a/b/c")
  @json.inspect(path.parts(), content=["a", "b", "c"])
  @json.inspect(path.drive(), content="")
  @json.inspect(path.root(), content="")
  @json.inspect(path.anchor(), content="")
}

///|
test "Path::parent" {
  let path = @async.Path::new("a/b/c/d/e")
  let parent = path.parent()
  @json.inspect(parent, content=["a/b/c/d"])
  let grandparent = parent.bind(fn(parent) { parent.parent() })
  @json.inspect(grandparent, content=["a/b/c"])
  let great_grandparent = grandparent.bind(fn(grandparent) {
    grandparent.parent()
  })
  @json.inspect(great_grandparent, content=["a/b"])
  let great_great_grandparent = great_grandparent.bind(fn(great_grandparent) {
    great_grandparent.parent()
  })
  @json.inspect(great_great_grandparent, content=["a"])
}

///|
test "Path::to_posix_path" {
  let path = @async.Path::new("a/b/c")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="a/b/c")
  @json.inspect(posix_path.parts(), content=["a", "b", "c"])
  @json.inspect(posix_path.drive(), content="")
  @json.inspect(posix_path.root(), content="")
  @json.inspect(posix_path.anchor(), content="")
}

///|
test "Path::to_windows_path" {
  let path = @async.Path::new("a/b/c")
  let windows_path = path.to_windows_path()
  inspect(windows_path, content="a\\b\\c")
  @json.inspect(windows_path.parts(), content=["a", "b", "c"])
  @json.inspect(windows_path.drive(), content="")
  @json.inspect(windows_path.root(), content="")
  @json.inspect(windows_path.anchor(), content="")
}

///|
test "Path::op_equal" {
  let path1 = @async.Path::new("a/b/c")
  let path2 = @async.Path::new("a/b/c")
  let path3 = @async.Path::new("a/b/d")
  @json.inspect(path1 == path2, content=true)
  @json.inspect(path1 == path3, content=false)
  @json.inspect(path1 != path2, content=false)
  @json.inspect(path1 != path3, content=true)
}

///|
test "concat" {
  let win_path = @async.WindowsPath::new("C:\\a\\b")
  let unc_path = @async.WindowsPath::new("\\\\server\\share\\a\\b")
  let win_rel_path = @async.WindowsPath::new("a\\b")
  let nix_abs_path = @async.PosixPath::new("/c/d")
  let nix_ds_path = @async.PosixPath::new("//c/d")
  let nix_rel_path = @async.PosixPath::new("c/d")
  inspect(win_path / win_path, content="C:\\a\\b")
  inspect(win_path / unc_path, content="\\\\server\\share\\a\\b")
  inspect(win_path / win_rel_path, content="C:\\a\\b\\a\\b")
  inspect(win_path / nix_abs_path.to_windows_path(), content="C:\\c\\d")
  inspect(win_path / nix_ds_path.to_windows_path(), content="\\\\c\\d\\")
  inspect(
    (win_path / nix_ds_path.to_windows_path()).drive(),
    content="\\\\c\\d",
  )
  inspect((win_path / nix_ds_path.to_windows_path()).root(), content="\\")
  inspect(win_path / nix_rel_path.to_windows_path(), content="C:\\a\\b\\c\\d")
  inspect(unc_path / win_path, content="C:\\a\\b")
  inspect(unc_path / win_rel_path, content="\\\\server\\share\\a\\b\\a\\b")
  inspect(unc_path / unc_path, content="\\\\server\\share\\a\\b")
  inspect(
    unc_path / nix_abs_path.to_windows_path(),
    content="\\\\server\\share\\c\\d",
  )
  inspect(unc_path / nix_ds_path.to_windows_path(), content="\\\\c\\d\\")
  inspect(
    (unc_path / nix_ds_path.to_windows_path()).drive(),
    content="\\\\c\\d",
  )
  inspect((unc_path / nix_ds_path.to_windows_path()).root(), content="\\")
  inspect(
    unc_path / nix_rel_path.to_windows_path(),
    content="\\\\server\\share\\a\\b\\c\\d",
  )
  inspect(nix_abs_path / win_path.to_posix_path(), content="/c/d/C:/a/b")
  inspect(nix_abs_path / unc_path.to_posix_path(), content="//server/share/a/b")
  inspect(nix_abs_path / win_rel_path.to_posix_path(), content="/c/d/a/b")
  inspect(nix_abs_path / nix_abs_path, content="/c/d")
  inspect(nix_abs_path / nix_ds_path, content="//c/d")
  inspect(nix_abs_path / nix_rel_path, content="/c/d/c/d")
  inspect(nix_ds_path / win_path.to_posix_path(), content="//c/d/C:/a/b")
  inspect(nix_ds_path / unc_path.to_posix_path(), content="//server/share/a/b")
  inspect(nix_ds_path / win_rel_path.to_posix_path(), content="//c/d/a/b")
  inspect(nix_ds_path / nix_abs_path, content="/c/d")
  inspect(nix_ds_path / nix_ds_path, content="//c/d")
  inspect(nix_ds_path / nix_rel_path, content="//c/d/c/d")
}
