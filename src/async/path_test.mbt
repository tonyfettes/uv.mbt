///|
test "relative_to" {
  @async.start(fn() {
    let async_pipe_mbt = @async.Path::new("src/async/pipe.mbt")
    let fs_mbt = @async.Path::new("src/fs.mbt")
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
      fs_mbt.join(relative_path).resolve().relative_to(@async.cwd()),
      content="src/async/pipe.mbt",
    )
  })
}

///|
test "windows/String" {
  let string : String = "C:\\Windows\\System32\\file.txt"
  let path = @async.Path::windows(string)
  @json.inspect(path, content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows", "System32", "file.txt"],
  })
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
  let path = @async.Path::windows(string)
  @json.inspect(path, content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows", "System32", "file.txt"],
  })
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
  let path = @async.Path::windows("\\\\server\\share\\file.txt")
  @json.inspect(path.parts(), content=["\\\\server\\share\\", "file.txt"])
  @json.inspect(path.drive(), content="\\\\server\\share")
  @json.inspect(path.root(), content="\\")
  inspect(path, content="\\\\server\\share\\file.txt")
}

///|
test "windows/relative" {
  let path = @async.Path::windows("directory/file.txt")
  @json.inspect(path.parts(), content=["directory", "file.txt"])
  @json.inspect(path.drive(), content="")
  @json.inspect(path.root(), content="")
  inspect(path, content="directory\\file.txt")
}

///|
test "windows/parent" {
  let path = @async.Path::windows("C:\\Windows\\System32\\file.txt")
  let parent = path.parent()
  @json.inspect(parent, content=[
    {
      "flavor": "windows",
      "drive": "C:",
      "root": "\\",
      "anchor": "C:\\",
      "parts": ["C:\\", "Windows", "System32"],
    },
  ])
  let grandparent = parent.bind(fn(parent) { parent.parent() })
  @json.inspect(grandparent, content=[
    {
      "flavor": "windows",
      "drive": "C:",
      "root": "\\",
      "anchor": "C:\\",
      "parts": ["C:\\", "Windows"],
    },
  ])
  let great_grandparent = grandparent.bind(fn(grandparent) {
    grandparent.parent()
  })
  @json.inspect(great_grandparent, content=[
    {
      "flavor": "windows",
      "drive": "C:",
      "root": "\\",
      "anchor": "C:\\",
      "parts": ["C:\\"],
    },
  ])
  let great_great_grandparent = great_grandparent.bind(fn(great_grandparent) {
    great_grandparent.parent()
  })
  @json.inspect(great_great_grandparent is None, content=true)
}

///|
test "windows/to_posix_path" {
  let path = @async.Path::windows("C:\\Windows\\System32\\file.txt")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="C:/Windows/System32/file.txt")
  let path = @async.Path::windows("\\\\server\\share\\file.txt")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="//server/share/file.txt")
  let path = @async.Path::windows("directory/file.txt")
  let posix_path = path.to_posix_path()
  inspect(posix_path, content="directory/file.txt")
}

///|
test "windows/relative_to" {
  let path = @async.Path::windows("C:\\Windows\\System32\\file.txt")
  let base = @async.Path::windows("C:\\Windows\\System32")
  let relative_path = path.relative_to(base)
  @json.inspect(relative_path, content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["file.txt"],
  })
}

///|
test "posix/String" {
  let string : String = "/usr/bin/file.txt"
  let path = @async.Path::posix(string)
  inspect(path, content="/usr/bin/file.txt")
}

///|
test "posix/@string.View" {
  let string : @string.View = "/usr/bin/file.txt"
  let path = @async.Path::posix(string)
  inspect(path, content="/usr/bin/file.txt")
}

///|
test "posix/parts" {
  let path = @async.posix_path("/usr/bin/file.txt")
  @json.inspect(path.parts(), content=["/", "usr", "bin", "file.txt"])
  @json.inspect(path.root(), content="/")
  @json.inspect(path.anchor(), content="/")
  inspect(path, content="/usr/bin/file.txt")
}

///|
test "posix/impl" {
  let path = @async.Path::posix("//usr//bin//file.txt")
  @json.inspect(path.parts(), content=["//", "usr", "bin", "file.txt"])
  @json.inspect(path.root(), content="//")
  inspect(path, content="//usr/bin/file.txt")
}

///|
test "posix/parent" {
  let path = @async.Path::posix("/usr/bin/file.txt")
  let parent = path.parent()
  @json.inspect(parent, content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "/",
      "anchor": "/",
      "parts": ["/", "usr", "bin"],
    },
  ])
  let grandparent = parent.bind(fn(parent) { parent.parent() })
  @json.inspect(grandparent, content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "/",
      "anchor": "/",
      "parts": ["/", "usr"],
    },
  ])
  let great_grandparent = grandparent.bind(fn(grandparent) {
    grandparent.parent()
  })
  @json.inspect(great_grandparent, content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "/",
      "anchor": "/",
      "parts": ["/"],
    },
  ])
  let great_great_grandparent = great_grandparent.bind(fn(great_grandparent) {
    great_grandparent.parent()
  })
  @json.inspect(great_great_grandparent is None, content=true)
}

///|
test "posix/to_windows_path" {
  let path = @async.Path::posix("/usr/bin/file.txt")
  let windows_path = path.to_windows_path()
  inspect(windows_path, content="\\usr\\bin\\file.txt")
  let path = @async.Path::posix("//usr//bin//file.txt")
  let windows_path = path.to_windows_path()
  inspect(windows_path, content="\\\\usr\\bin\\file.txt")
  @json.inspect(windows_path.parts(), content=["\\\\usr\\bin\\", "file.txt"])
}

///|
test "posix/relative_to" {
  let path = @async.Path::posix("/usr/bin/file.txt")
  let base = @async.Path::posix("/usr/bin")
  let relative_path = path.relative_to(base)
  @json.inspect(relative_path, content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["file.txt"],
  })
}

///|
test "Path::new(String)" {
  let path = @async.Path::new("a/b/c")
  @json.inspect(path, content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c"],
  })
  @json.inspect(path.parts(), content=["a", "b", "c"])
  @json.inspect(path.drive(), content="")
  @json.inspect(path.root(), content="")
  @json.inspect(path.anchor(), content="")
}

///|
test "Path::parent" {
  let path = @async.Path::new("a/b/c/d/e")
  let parent = path.parent()
  @json.inspect(parent, content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "",
      "anchor": "",
      "parts": ["a", "b", "c", "d"],
    },
  ])
  let grandparent = parent.bind(fn(parent) { parent.parent() })
  @json.inspect(grandparent, content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "",
      "anchor": "",
      "parts": ["a", "b", "c"],
    },
  ])
  let great_grandparent = grandparent.bind(fn(grandparent) {
    grandparent.parent()
  })
  @json.inspect(great_grandparent, content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "",
      "anchor": "",
      "parts": ["a", "b"],
    },
  ])
  let great_great_grandparent = great_grandparent.bind(fn(great_grandparent) {
    great_grandparent.parent()
  })
  @json.inspect(great_great_grandparent, content=[
    { "flavor": "posix", "drive": "", "root": "", "anchor": "", "parts": ["a"] },
  ])
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
  let win_path = @async.Path::windows("C:\\a\\b")
  let unc_path = @async.Path::windows("\\\\server\\share\\a\\b")
  let win_rel_path = @async.Path::windows("a\\b")
  let nix_abs_path = @async.Path::posix("/c/d")
  let nix_ds_path = @async.Path::posix("//c/d")
  let nix_rel_path = @async.Path::posix("c/d")
  inspect(win_path.join(win_path), content="C:\\a\\b")
  inspect(win_path.join(unc_path), content="\\\\server\\share\\a\\b")
  inspect(win_path.join(win_rel_path), content="C:\\a\\b\\a\\b")
  inspect(win_path.join(nix_abs_path), content="C:\\c\\d")
  inspect(win_path.join(nix_ds_path), content="\\\\c\\d\\")
  inspect(win_path.join(nix_ds_path).drive(), content="\\\\c\\d")
  inspect(win_path.join(nix_ds_path).root(), content="\\")
  inspect(win_path.join(nix_rel_path), content="C:\\a\\b\\c\\d")
  inspect(unc_path.join(win_path), content="C:\\a\\b")
  inspect(unc_path.join(win_rel_path), content="\\\\server\\share\\a\\b\\a\\b")
  inspect(unc_path.join(unc_path), content="\\\\server\\share\\a\\b")
  inspect(
    unc_path.join(nix_abs_path.to_windows_path()),
    content="\\\\server\\share\\c\\d",
  )
  inspect(unc_path.join(nix_ds_path), content="\\\\c\\d\\")
  inspect(unc_path.join(nix_ds_path).drive(), content="\\\\c\\d")
  inspect(unc_path.join(nix_ds_path).root(), content="\\")
  inspect(unc_path.join(nix_rel_path), content="\\\\server\\share\\a\\b\\c\\d")
  inspect(nix_abs_path.join(win_path.to_posix_path()), content="/c/d/C:/a/b")
  inspect(
    nix_abs_path.join(unc_path.to_posix_path()),
    content="//server/share/a/b",
  )
  inspect(nix_abs_path.join(win_rel_path.to_posix_path()), content="/c/d/a/b")
  inspect(nix_abs_path.join(nix_abs_path), content="/c/d")
  inspect(nix_abs_path.join(nix_ds_path), content="//c/d")
  inspect(nix_abs_path.join(nix_rel_path), content="/c/d/c/d")
  inspect(nix_ds_path.join(win_path.to_posix_path()), content="//c/d/C:/a/b")
  inspect(
    nix_ds_path.join(unc_path.to_posix_path()),
    content="//server/share/a/b",
  )
  inspect(nix_ds_path.join(win_rel_path.to_posix_path()), content="//c/d/a/b")
  inspect(nix_ds_path.join(nix_abs_path), content="/c/d")
  inspect(nix_ds_path.join(nix_ds_path), content="//c/d")
  inspect(nix_ds_path.join(nix_rel_path), content="//c/d/c/d")
}
