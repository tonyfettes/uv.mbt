///|
priv enum Flavor {
  Windows
  Posix
} derive(Show, Eq, Compare)

///|
impl ToJson for Flavor with to_json(self : Flavor) -> Json {
  return match self {
    Windows => "windows"
    Posix => "posix"
  }
}

///|
struct BasicPath {
  flavor : Flavor
  drive : @string.View
  root : @string.View
  anchor : @string.View
  parts : ArrayView[@string.View]
} derive(ToJson, Eq)

///|
impl Compare for BasicPath with compare(self : BasicPath, other : BasicPath) -> Int {
  if self.flavor != other.flavor {
    return self.flavor.compare(other.flavor)
  }
  return self.parts.compare(other.parts)
}

///|
fn BasicPath::parse_posix_path(path : @string.View) -> BasicPath {
  let root = StringBuilder::new()
  fn make_path(path : Array[@string.View]) -> BasicPath {
    let root = root.to_string()
    return BasicPath::{
      flavor: Posix,
      drive: "",
      root,
      anchor: root,
      parts: path,
    }
  }

  let parts : Array[@string.View] = []
  let part = StringBuilder::new()
  let path = match path {
    [.. "///", .. path] => {
      root.write_char('/')
      parts.push("/")
      skip~: loop path {
        ['/', .. path] => continue skip~ path
        [char, .. path] => {
          part.write_char(char)
          path
        }
        [] => return make_path(parts)
      }
    }
    [.. "//", .. path] => {
      root.write_string("//")
      parts.push("//")
      path
    }
    ['/', .. path] => {
      root.write_char('/')
      parts.push("/")
      path
    }
    [.. path] => path
  }
  fn push_part(part : String) {
    if part is ("" | ".") {
      return
    }
    parts.push(part)
  }

  path~: loop path {
    ['/', .. path] => {
      push_part(part.to_string())
      skip~: loop path {
        ['/', .. path] => continue skip~ path
        [char, .. path] => {
          part.reset()
          part.write_char(char)
          continue path~ path
        }
        [] => break path~ make_path(parts)
      }
    }
    [char, .. path] => {
      part.write_char(char)
      continue path~ path
    }
    [] => {
      push_part(part.to_string())
      return make_path(parts)
    }
  }
}

///|
test "posix_path/root" {
  @json.inspect(BasicPath::parse_posix_path("/"), content={
    "flavor": "posix",
    "drive": "",
    "root": "/",
    "anchor": "/",
    "parts": ["/"],
  })
  @json.inspect(BasicPath::parse_posix_path("//"), content={
    "flavor": "posix",
    "drive": "",
    "root": "//",
    "anchor": "//",
    "parts": ["//"],
  })
  @json.inspect(BasicPath::parse_posix_path("///"), content={
    "flavor": "posix",
    "drive": "",
    "root": "/",
    "anchor": "/",
    "parts": ["/"],
  })
  @json.inspect!(BasicPath::parse_posix_path("//usr//bin//"), content={
    "flavor": "posix",
    "drive": "",
    "root": "//",
    "anchor": "//",
    "parts": ["//", "usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("////usr"), content={
    "flavor": "posix",
    "drive": "",
    "root": "/",
    "anchor": "/",
    "parts": ["/", "usr"],
  })
  @json.inspect!(BasicPath::parse_posix_path("/usr/bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "/",
    "anchor": "/",
    "parts": ["/", "usr", "bin"],
  })
}

///|
test "posix_path" {
  @json.inspect!(BasicPath::parse_posix_path("usr/bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr/bin/"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr//bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("C:\\Windows"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["C:\\Windows"],
  })
}

///|
test "posix_path/empty" {
  @json.inspect!(BasicPath::parse_posix_path(""), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": [],
  })
}

///|
test "posix_path/collapse_slashes" {
  @json.inspect!(BasicPath::parse_posix_path("usr/////bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr//bin//"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr///bin//"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
}

///|
test "posix_path/collapse_dots" {
  @json.inspect!(BasicPath::parse_posix_path("usr/./bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr/../bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "..", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr/.././bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "..", "bin"],
  })
  @json.inspect!(BasicPath::parse_posix_path("usr/./../bin"), content={
    "flavor": "posix",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["usr", "..", "bin"],
  })
}

///|
fn BasicPath::parse_windows_path(path : @string.View) -> BasicPath {
  enum UncState {
    Zero
    One
  }
  let drive = StringBuilder::new()
  let root = StringBuilder::new()
  fn make_path(parts : Array[@string.View]) -> BasicPath {
    let drive_string = drive.to_string()
    let root = root.to_string()
    drive.write_string(root)
    let anchor = drive.to_string()
    return BasicPath::{
      flavor: Windows,
      drive: drive_string,
      root,
      anchor,
      parts,
    }
  }

  let parts : Array[@string.View] = []
  let part = StringBuilder::new()
  let path = match path {
    [drive_letter, ':', '/' | '\\', .. path] => {
      drive.write_char(drive_letter)
      drive.write_char(':')
      root.write_char('\\')
      parts.push("\{drive_letter}:\\")
      skip~: loop path {
        ['/' | '\\', .. path] => continue skip~ path
        [char, .. path] => {
          part.write_char(char)
          path
        }
        [] => return make_path(parts)
      }
    }
    [drive_letter, ':', char, .. path] => {
      drive.write_char(drive_letter)
      drive.write_char(':')
      parts.push("\{drive_letter}:")
      part.write_char(char)
      path
    }
    [drive_letter, ':'] => {
      drive.write_char(drive_letter)
      drive.write_char(':')
      parts.push("\{drive_letter}:")
      return make_path(parts)
    }
    ['/' | '\\', '/' | '\\', .. path] => {
      drive.write_string("\\\\")
      unc~: loop Zero, path {
        Zero, ['/' | '\\', .. path] => {
          drive.write_char('\\')
          continue unc~ One, path
        }
        Zero, [char, .. path] => {
          drive.write_char(char)
          continue unc~ Zero, path
        }
        Zero, [] => {
          parts.push(drive.to_string())
          return make_path(parts)
        }
        One, ['/' | '\\', .. path] => {
          root.write_char('\\')
          parts.push("\{drive.to_string()}\\")
          path
        }
        One, [char, .. path] => {
          drive.write_char(char)
          continue unc~ One, path
        }
        One, [] => {
          let drive = drive.to_string()
          if drive is [.., '\\'] {
            parts.push(drive)
            return make_path(parts)
          } else {
            root.write_char('\\')
            parts.push("\{drive.to_string()}\\")
            return make_path(parts)
          }
        }
      }
    }
    ['/' | '\\', char, .. path] => {
      root.write_char('\\')
      parts.push("\\")
      part.write_char(char)
      path
    }
    ['/' | '\\'] => {
      root.write_char('\\')
      parts.push("\\")
      return make_path(parts)
    }
    [char, .. path] => {
      part.write_char(char)
      path
    }
    [] => return make_path(parts)
  }
  fn push_part(part : String) {
    if part is ("" | ".") {
      return
    }
    parts.push(part)
  }

  path~: loop path {
    ['/' | '\\', .. path] => {
      push_part(part.to_string())
      skip~: loop path {
        ['/' | '\\', .. path] => continue skip~ path
        [char, .. path] => {
          part.reset()
          part.write_char(char)
          continue path~ path
        }
        [] => break path~ make_path(parts)
      }
    }
    [char, .. path] => {
      part.write_char(char)
      continue path~ path
    }
    [] => {
      push_part(part.to_string())
      break path~ make_path(parts)
    }
  }
}

///|
test "parse_windows_path/empty" {
  @json.inspect(BasicPath::parse_windows_path(""), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": [],
  })
}

///|
test "parse_windows_path/drive" {
  @json.inspect!(BasicPath::parse_windows_path("C:"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "",
    "anchor": "C:",
    "parts": ["C:"],
  })
  @json.inspect!(BasicPath::parse_windows_path("ABC:"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["ABC:"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:\\"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:\\\\"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:\\Windows"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:\\\\Windows"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:/Windows"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:/Windows/"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:\\Windows\\"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "\\",
    "anchor": "C:\\",
    "parts": ["C:\\", "Windows"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:Windows"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "",
    "anchor": "C:",
    "parts": ["C:", "Windows"],
  })
  @json.inspect!(BasicPath::parse_windows_path("C:Windows/"), content={
    "flavor": "windows",
    "drive": "C:",
    "root": "",
    "anchor": "C:",
    "parts": ["C:", "Windows"],
  })
}

///|
test "parse_windows_path/root" {
  @json.inspect(BasicPath::parse_windows_path("/"), content={
    "flavor": "windows",
    "drive": "",
    "root": "\\",
    "anchor": "\\",
    "parts": ["\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("\\"), content={
    "flavor": "windows",
    "drive": "",
    "root": "\\",
    "anchor": "\\",
    "parts": ["\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("Windows"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["Windows"],
  })
  @json.inspect(BasicPath::parse_windows_path("/Windows"), content={
    "flavor": "windows",
    "drive": "",
    "root": "\\",
    "anchor": "\\",
    "parts": ["\\", "Windows"],
  })
  @json.inspect(BasicPath::parse_windows_path("\\Windows"), content={
    "flavor": "windows",
    "drive": "",
    "root": "\\",
    "anchor": "\\",
    "parts": ["\\", "Windows"],
  })
}

///|
test "parse_windows_path/unc" {
  @json.inspect(BasicPath::parse_windows_path("//"), content={
    "flavor": "windows",
    "drive": "\\\\",
    "root": "",
    "anchor": "\\\\",
    "parts": ["\\\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("\\\\"), content={
    "flavor": "windows",
    "drive": "\\\\",
    "root": "",
    "anchor": "\\\\",
    "parts": ["\\\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("/\\"), content={
    "flavor": "windows",
    "drive": "\\\\",
    "root": "",
    "anchor": "\\\\",
    "parts": ["\\\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("///"), content={
    "flavor": "windows",
    "drive": "\\\\\\",
    "root": "",
    "anchor": "\\\\\\",
    "parts": ["\\\\\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("////"), content={
    "flavor": "windows",
    "drive": "\\\\\\",
    "root": "\\",
    "anchor": "\\\\\\\\",
    "parts": ["\\\\\\\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("/////"), content={
    "flavor": "windows",
    "drive": "\\\\\\",
    "root": "\\",
    "anchor": "\\\\\\\\",
    "parts": ["\\\\\\\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("//unc"), content={
    "flavor": "windows",
    "drive": "\\\\unc",
    "root": "",
    "anchor": "\\\\unc",
    "parts": ["\\\\unc"],
  })
  @json.inspect(BasicPath::parse_windows_path("//unc/"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\",
    "root": "",
    "anchor": "\\\\unc\\",
    "parts": ["\\\\unc\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("//unc/share"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\share",
    "root": "\\",
    "anchor": "\\\\unc\\share\\",
    "parts": ["\\\\unc\\share\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("//unc/share/"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\share",
    "root": "\\",
    "anchor": "\\\\unc\\share\\",
    "parts": ["\\\\unc\\share\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("\\\\unc\\share"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\share",
    "root": "\\",
    "anchor": "\\\\unc\\share\\",
    "parts": ["\\\\unc\\share\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("\\\\unc\\share\\"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\share",
    "root": "\\",
    "anchor": "\\\\unc\\share\\",
    "parts": ["\\\\unc\\share\\"],
  })
  @json.inspect!(BasicPath::parse_windows_path("//unc/share/a/b"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\share",
    "root": "\\",
    "anchor": "\\\\unc\\share\\",
    "parts": ["\\\\unc\\share\\", "a", "b"],
  })
  @json.inspect!(BasicPath::parse_windows_path("\\\\unc\\share\\a\\b"), content={
    "flavor": "windows",
    "drive": "\\\\unc\\share",
    "root": "\\",
    "anchor": "\\\\unc\\share\\",
    "parts": ["\\\\unc\\share\\", "a", "b"],
  })
}

///|
test "parse_windows_path/collapse_slashes" {
  @json.inspect(BasicPath::parse_windows_path("a//b///c////d"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c", "d"],
  })
  @json.inspect(BasicPath::parse_windows_path("a\\\\b\\\\\\c\\\\\\\\d"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c", "d"],
  })
  @json.inspect(BasicPath::parse_windows_path("a/b/c/d"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c", "d"],
  })
}

///|
test "parse_windows_path/collapse_dots" {
  @json.inspect(BasicPath::parse_windows_path("./a/b/c"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c"],
  })
  @json.inspect(BasicPath::parse_windows_path("a/b/c/."), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c"],
  })
  @json.inspect(BasicPath::parse_windows_path("a/b/c/./d"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c", "d"],
  })
  @json.inspect(BasicPath::parse_windows_path("a/b/c/././d"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c", "d"],
  })
  @json.inspect(BasicPath::parse_windows_path("a/b/c/./././d"), content={
    "flavor": "windows",
    "drive": "",
    "root": "",
    "anchor": "",
    "parts": ["a", "b", "c", "d"],
  })
  @json.inspect(BasicPath::parse_windows_path("//./"), content={
    "flavor": "windows",
    "drive": "\\\\.\\",
    "root": "",
    "anchor": "\\\\.\\",
    "parts": ["\\\\.\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("//./."), content={
    "flavor": "windows",
    "drive": "\\\\.\\.",
    "root": "\\",
    "anchor": "\\\\.\\.\\",
    "parts": ["\\\\.\\.\\"],
  })
  @json.inspect(BasicPath::parse_windows_path("//./././a/b/c"), content={
    "flavor": "windows",
    "drive": "\\\\.\\.",
    "root": "\\",
    "anchor": "\\\\.\\.\\",
    "parts": ["\\\\.\\.\\", "a", "b", "c"],
  })
}

///|
impl Show for BasicPath with output(self : BasicPath, logger : &Logger) -> Unit {
  let separator = if self.flavor is Windows { '\\' } else { '/' }
  fn write_stringview(s : @string.View) {
    for c in s {
      logger.write_char(c)
    }
  }

  if self.drive != "" || self.root != "" {
    write_stringview(self.drive)
    write_stringview(self.root)
    let parts = self.parts[1:]
    for i, part in parts {
      write_stringview(part)
      if i < parts.length() - 1 {
        logger.write_char(separator)
      }
    }
  } else {
    for i, part in self.parts {
      write_stringview(part)
      if i < self.parts.length() - 1 {
        logger.write_char(separator)
      }
    }
  }
}

///|
fn BasicPath::parent(self : BasicPath) -> BasicPath? {
  if self.parts.length() == 0 {
    return None
  }
  if (self.drive != "" || self.root != "") && self.parts.length() == 1 {
    return None
  }
  Some(BasicPath::{ ..self, parts: self.parts[:self.parts.length() - 1] })
}

///|
test "BasicPath::parent" {
  let path = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "",
    anchor: "",
    parts: ["usr", "bin"],
  }
  @json.inspect(path.parent(), content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "",
      "anchor": "",
      "parts": ["usr"],
    },
  ])
  let path = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "/",
    anchor: "/",
    parts: ["/", "usr", "bin"],
  }
  @json.inspect(path.parent(), content=[
    {
      "flavor": "posix",
      "drive": "",
      "root": "/",
      "anchor": "/",
      "parts": ["/", "usr"],
    },
  ])
  let path = BasicPath::{
    flavor: Windows,
    drive: "C:",
    root: "\\",
    anchor: "C:\\",
    parts: ["C:\\", "Windows", "System32"],
  }
  @json.inspect(path.parent(), content=[
    {
      "flavor": "windows",
      "drive": "C:",
      "root": "\\",
      "anchor": "C:\\",
      "parts": ["C:\\", "Windows"],
    },
  ])
  let path = BasicPath::{
    flavor: Windows,
    drive: "C:",
    root: "\\",
    anchor: "C:\\",
    parts: ["C:\\"],
  }
  @json.inspect(path.parent() is None, content=true)
  let path = BasicPath::{
    flavor: Windows,
    drive: "",
    root: "",
    anchor: "",
    parts: [],
  }
  @json.inspect(path.parent() is None, content=true)
}

///|
fn BasicPath::to_posix_path(self : BasicPath) -> BasicPath {
  fn convert_to_slash(source : @string.View, target : StringBuilder) -> Unit {
    loop source {
      ['\\', .. chars] => {
        target.write_char('/')
        continue chars
      }
      [char, .. chars] => {
        target.write_char(char)
        continue chars
      }
      [] => ()
    }
  }

  if self.flavor is Posix {
    self
  } else if self.drive != "" || self.root != "" {
    let anchor = StringBuilder::new()
    convert_to_slash(self.drive, anchor)
    convert_to_slash(self.root, anchor)
    let anchor = BasicPath::parse_posix_path(anchor.to_string())
    BasicPath::{ ..anchor, parts: [..anchor.parts, ..self.parts[1:]] }
  } else {
    BasicPath::{ ..self, flavor: Posix }
  }
}

///|
fn BasicPath::to_windows_path(self : BasicPath) -> BasicPath {
  if self.flavor is Windows {
    self
  } else {
    BasicPath::parse_windows_path(self.to_string())
  }
}

///|
fn BasicPath::relative_to(self : BasicPath, other : BasicPath) -> BasicPath {
  let self_parts_length = self.parts.length()
  let other_parts_length = other.parts.length()
  let minimum_parts_length = @math.minimum(
    self_parts_length, other_parts_length,
  )
  let start_index = if self.anchor != "" { 1 } else { 0 }
  let common_parts_length = for i in start_index..<minimum_parts_length {
    if self.parts[i] != other.parts[i] {
      break i
    }
  } else {
    minimum_parts_length
  }
  let parts : Array[@string.View] = []
  for i in common_parts_length..<other_parts_length {
    parts.push("..")
  }
  for i in common_parts_length..<self_parts_length {
    parts.push(self.parts[i])
  }
  BasicPath::{ ..self, drive: "", root: "", anchor: "", parts }
}

///|
impl Div for BasicPath with op_div(self : BasicPath, other : BasicPath) -> BasicPath {
  match self.flavor {
    Windows => {
      let other = other.to_windows_path()
      if other.drive != "" {
        return other
      }
      if other.root != "" {
        return BasicPath::{
          flavor: Windows,
          drive: self.drive,
          root: other.root,
          anchor: [..self.drive, ..other.root],
          parts: other.parts,
        }
      }
      BasicPath::{ ..self, parts: [..self.parts, ..other.parts] }
    }
    Posix => {
      let other = other.to_posix_path()
      if other.root != "" {
        return other
      }
      BasicPath::{ ..self, parts: [..self.parts, ..other.parts] }
    }
  }
}

///|
test "BasicPath::op_div" {
  let a = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "",
    anchor: "",
    parts: ["usr", "bin"],
  }
  let b = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "",
    anchor: "",
    parts: ["local", "bin"],
  }
  let c = a / b
  inspect(c, content="usr/bin/local/bin")
  let a = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "/",
    anchor: "/",
    parts: ["/", "usr", "bin"],
  }
  let b = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "",
    anchor: "",
    parts: ["local", "bin"],
  }
  let c = a / b
  inspect(c, content="/usr/bin/local/bin")
  let a = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "",
    anchor: "",
    parts: ["usr", "bin"],
  }
  let b = BasicPath::{
    flavor: Posix,
    drive: "",
    root: "/",
    anchor: "/",
    parts: ["/", "local", "bin"],
  }
  let c = a / b
  inspect(c, content="/local/bin")
  let a = BasicPath::{
    flavor: Windows,
    drive: "C:",
    root: "\\",
    anchor: "C:\\",
    parts: ["C:\\", "Windows"],
  }
  let b = BasicPath::{
    flavor: Windows,
    drive: "",
    root: "",
    anchor: "",
    parts: ["System32"],
  }
  let c = a / b
  inspect(c, content="C:\\Windows\\System32")
  let a = BasicPath::{
    flavor: Windows,
    drive: "C:",
    root: "\\",
    anchor: "C:\\",
    parts: ["C:\\", "Windows"],
  }
  let b = BasicPath::{
    flavor: Windows,
    drive: "D:",
    root: "\\",
    anchor: "D:\\",
    parts: ["D:\\", "System32"],
  }
  let c = a / b
  inspect(c, content="D:\\System32")
  let a = BasicPath::{
    flavor: Windows,
    drive: "C:",
    root: "\\",
    anchor: "C:\\",
    parts: ["C:\\", "Windows"],
  }
  let b = BasicPath::{
    flavor: Windows,
    drive: "",
    root: "\\",
    anchor: "\\",
    parts: ["\\", "System32"],
  }
  let c = a / b
  inspect(c, content="C:\\System32")
}

///|
let flavor : Ref[Flavor] = Ref::new(Posix)

///|
fn init {
  try {
    if @uv.os_uname().sysname() == "Windows_NT" {
      flavor.val = Windows
    }
  } catch {
    e => println("Warning: Failed to determine OS, defaulting to Posix: \{e}")
  }
}

///|
trait ToPath {
  to_path(Self) -> BasicPath
}

///|
pub typealias Path = &ToPath

///|
pub impl ToPath for @string.View with to_path(self : @string.View) -> BasicPath {
  match flavor.val {
    Windows => ToWindowsPath::to_windows_path(self)
    Posix => ToPosixPath::to_posix_path(self)
  }
}

///|
pub impl ToPath for String with to_path(self : String) -> BasicPath {
  ToPath::to_path(self.view())
}

///|
impl ToPath for BasicPath with to_path(self : BasicPath) -> BasicPath {
  self
}

///|
pub impl ToPath for &ToWindowsPath with to_path(self : &ToWindowsPath) -> BasicPath {
  self.to_windows_path()
}

///|
pub impl ToPath for &ToPosixPath with to_path(self : &ToPosixPath) -> BasicPath {
  self.to_posix_path()
}

///|
pub impl[T : ToPath] ToPath for Array[T] with to_path(self : Array[T]) -> BasicPath {
  ToPath::to_path(self[:])
}

///|
pub impl[T : ToPath] ToPath for ArrayView[T] with to_path(self : ArrayView[T]) -> BasicPath {
  let mut path = BasicPath::{
    flavor: flavor.val,
    drive: "",
    root: "",
    anchor: "",
    parts: [],
  }
  for item in self {
    path = path / item.to_path()
  }
  path
}

///|
pub fn[ToPath : ToPath] &ToPath::new(path : ToPath) -> &ToPath {
  path.to_path()
}

///|
pub fn[ToPath : ToPath] path(path : ToPath) -> &ToPath {
  path.to_path()
}

///|
pub fn &ToPath::parts(self : &ToPath) -> ArrayView[@string.View] {
  self.to_path().parts
}

///|
pub fn &ToPath::drive(self : &ToPath) -> @string.View {
  self.to_path().drive
}

///|
pub fn &ToPath::root(self : &ToPath) -> @string.View {
  return self.to_path().root
}

///|
pub fn &ToPath::anchor(self : &ToPath) -> @string.View {
  self.to_path().anchor
}

///|
pub fn &ToPath::parent(self : &ToPath) -> &ToPath? {
  match self.to_path().parent() {
    None => None
    Some(parent) => Some(parent)
  }
}

///|
pub fn &ToPath::to_windows_path(self : &ToPath) -> &ToWindowsPath {
  match self.to_path().flavor {
    Windows => {
      self as &ToWindowsPath
    }
    Posix => {
      &ToPosixPath::to_posix_path(self) as &ToWindowsPath
    }
  }
}

///|
pub fn &ToPath::to_posix_path(self : &ToPath) -> &ToPosixPath {
  match self.to_path().flavor {
    Posix => {
      self as &ToPosixPath
    }
    Windows => {
      &ToWindowsPath::to_windows_path(self) as &ToPosixPath
    }
  }
}

///|
pub impl Show for &ToPath with output(self : &ToPath, logger : &Logger) -> Unit {
  self.to_path().output(logger)
}

///|
pub impl Div for &ToPath with op_div(self : &ToPath, other : &ToPath) -> &ToPath {
  let self = self.to_path()
  match self.flavor {
    Windows => {
      &ToWindowsPath::op_div(self, other) as &ToPath
    }
    Posix => {
      &ToPosixPath::op_div(self, other) as &ToPath
    }
  }
}

///|
pub impl ToJson for &ToPath with to_json(self : &ToPath) -> Json {
  return self.to_string().to_json()
}

///|
pub impl Eq for &ToPath with op_equal(self : &ToPath, other : &ToPath) -> Bool {
  self.to_path() == other.to_path()
}

///|
pub impl Compare for &ToPath with compare(self : &ToPath, other : &ToPath) -> Int {
  self.to_path().compare(other.to_path())
}

///|
pub fn &ToPath::relative_to(self : &ToPath, other : &ToPath) -> &ToPath {
  self.to_path().relative_to(other.to_path())
}

///|
trait ToPosixPath {
  to_posix_path(Self) -> BasicPath
}

///|
pub typealias PosixPath = &ToPosixPath

///|
pub impl ToPosixPath for @string.View with to_posix_path(self : @string.View) -> BasicPath {
  BasicPath::parse_posix_path(self)
}

///|
pub impl ToPosixPath for String with to_posix_path(self : String) -> BasicPath {
  BasicPath::parse_posix_path(self.view())
}

///|
impl ToPosixPath for BasicPath with to_posix_path(self : BasicPath) -> BasicPath {
  self.to_posix_path()
}

///|
pub impl ToPosixPath for &ToPath with to_posix_path(self : &ToPath) -> BasicPath {
  self.to_path().to_posix_path()
}

///|
pub fn[ToPosixPath : ToPosixPath] &ToPosixPath::new(
  path : ToPosixPath
) -> &ToPosixPath {
  path.to_posix_path()
}

///|
pub fn[ToPosixPath : ToPosixPath] posix_path(
  path : ToPosixPath
) -> &ToPosixPath {
  path.to_posix_path()
}

///|
pub impl Show for &ToPosixPath with output(
  self : &ToPosixPath,
  logger : &Logger
) -> Unit {
  self.to_posix_path().output(logger)
}

///|
pub impl ToJson for &ToPosixPath with to_json(self : &ToPosixPath) -> Json {
  self.to_string().to_json()
}

///|
pub fn &ToPosixPath::parts(self : &ToPosixPath) -> ArrayView[@string.View] {
  self.to_posix_path().parts
}

///|
pub fn &ToPosixPath::drive(self : &ToPosixPath) -> @string.View {
  self.to_posix_path().drive
}

///|
pub fn &ToPosixPath::root(self : &ToPosixPath) -> @string.View {
  self.to_posix_path().root
}

///|
pub fn &ToPosixPath::anchor(self : &ToPosixPath) -> @string.View {
  self.to_posix_path().anchor
}

///|
pub fn &ToPosixPath::parent(self : &ToPosixPath) -> &ToPosixPath? {
  match self.to_posix_path().parent() {
    None => None
    Some(parent) => Some(parent.to_posix_path())
  }
}

///|
pub fn &ToPosixPath::to_windows_path(self : &ToPosixPath) -> &ToWindowsPath {
  self.to_posix_path().to_windows_path()
}

///|
pub fn &ToPosixPath::relative_to(
  self : &ToPosixPath,
  other : &ToPosixPath
) -> &ToPosixPath {
  self.to_posix_path().relative_to(other.to_posix_path())
}

///|
pub impl Div for &ToPosixPath with op_div(
  self : &ToPosixPath,
  other : &ToPosixPath
) -> &ToPosixPath {
  let self = self.to_posix_path()
  let other = other.to_posix_path()
  if other.root != "" {
    return other
  }
  BasicPath::{ ..self, parts: [..self.parts, ..other.parts] }
}

///|
trait ToWindowsPath {
  to_windows_path(Self) -> BasicPath
}

///|
pub typealias WindowsPath = &ToWindowsPath

///|
pub impl ToWindowsPath for @string.View with to_windows_path(
  self : @string.View
) -> BasicPath {
  BasicPath::parse_windows_path(self)
}

///|
pub impl ToWindowsPath for String with to_windows_path(self : String) -> BasicPath {
  BasicPath::parse_windows_path(self.view())
}

///|
impl ToWindowsPath for BasicPath with to_windows_path(self : BasicPath) -> BasicPath {
  self.to_windows_path()
}

///|
pub impl ToWindowsPath for &ToPath with to_windows_path(self : &ToPath) -> BasicPath {
  self.to_path().to_windows_path()
}

///|
pub fn[ToWindowsPath : ToWindowsPath] &ToWindowsPath::new(
  path : ToWindowsPath
) -> &ToWindowsPath {
  path.to_windows_path()
}

///|
pub fn[ToWindowsPath : ToWindowsPath] windows_path(
  path : ToWindowsPath
) -> &ToWindowsPath {
  path.to_windows_path()
}

///|
pub impl Show for &ToWindowsPath with output(
  self : &ToWindowsPath,
  logger : &Logger
) -> Unit {
  self.to_windows_path().output(logger)
}

///|
pub impl ToJson for &ToWindowsPath with to_json(self : &ToWindowsPath) -> Json {
  self.to_string().to_json()
}

///|
pub fn &ToWindowsPath::parts(self : &ToWindowsPath) -> ArrayView[@string.View] {
  self.to_windows_path().parts
}

///|
pub fn &ToWindowsPath::drive(self : &ToWindowsPath) -> @string.View {
  self.to_windows_path().drive
}

///|
pub fn &ToWindowsPath::root(self : &ToWindowsPath) -> @string.View {
  return self.to_windows_path().root
}

///|
pub fn &ToWindowsPath::anchor(self : &ToWindowsPath) -> @string.View {
  self.to_windows_path().anchor
}

///|
pub fn &ToWindowsPath::parent(self : &ToWindowsPath) -> &ToWindowsPath? {
  match self.to_windows_path().parent() {
    None => None
    Some(parent) => Some(parent)
  }
}

///|
pub fn &ToWindowsPath::to_posix_path(self : &ToWindowsPath) -> &ToPosixPath {
  self.to_windows_path().to_posix_path()
}

///|
pub impl Div for &ToWindowsPath with op_div(
  self : &ToWindowsPath,
  other : &ToWindowsPath
) -> &ToWindowsPath {
  let self = self.to_windows_path()
  let other = other.to_windows_path()
  if other.drive != "" {
    return other
  }
  if other.root != "" {
    return BasicPath::{
      flavor: Windows,
      drive: self.drive,
      root: other.root,
      anchor: [..self.drive, ..other.root],
      parts: other.parts,
    }
  }
  BasicPath::{ ..self, parts: [..self.parts, ..other.parts] }
}

///|
pub fn &ToWindowsPath::relative_to(
  self : &ToWindowsPath,
  other : &ToWindowsPath
) -> &ToWindowsPath {
  self.to_windows_path().relative_to(other.to_windows_path())
}
