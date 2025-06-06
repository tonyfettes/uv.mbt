///|
priv struct WindowsPath {
  parts : ArrayView[@string.View]
}

///|
fn WindowsPath::new(parts : ArrayView[@string.View]) -> WindowsPath {
  WindowsPath::{ parts, }
}

///|
priv trait ToWindowsPath {
  to_windows_path(Self) -> WindowsPath
}

///|
impl ToWindowsPath for @string.View with to_windows_path(self : @string.View) -> WindowsPath {
  enum UncState {
    Zero
    One
  }
  fn make_part(char : Char) -> StringBuilder {
    let part = StringBuilder::new()
    part.write_char(char)
    return part
  }

  let parts : Array[@string.View] = []
  path~: loop None, self {
    None, [drive, ':', '/' | '\\', .. path] => {
      parts.push("\{drive}:\\")
      skip~: loop path {
        ['/' | '\\', .. path] => continue skip~ path
        [char, .. path] => continue path~ Some(make_part(char)), path
        [] => break path~ WindowsPath::new(parts)
      }
    }
    None, [drive, ':', char, .. path] => {
      parts.push("\{drive}:")
      continue path~ Some(make_part(char)), path
    }
    None, [drive, ':'] => {
      parts.push("\{drive}:")
      break path~ WindowsPath::new(parts)
    }
    None, [.. "//", .. path] | [.. "\\\\", .. path] => {
      let unc = StringBuilder::new()
      unc.write_string("\\\\")
      unc~: loop Zero, path {
        Zero, ['/' | '\\', .. path] => {
          unc.write_char('\\')
          continue unc~ One, path
        }
        One, ['/' | '\\', char, .. path] => {
          unc.write_char('\\')
          parts.push(unc.to_string())
          continue path~ Some(make_part(char)), path
        }
        One, ['/' | '\\'] => {
          unc.write_char('\\')
          parts.push(unc.to_string())
          break path~ WindowsPath::new(parts)
        }
        Zero, [char, .. path] => {
          unc.write_char(char)
          continue unc~ Zero, path
        }
        One, [char, .. path] => {
          unc.write_char(char)
          continue unc~ One, path
        }
        Zero, [] => {
          parts.push(unc.to_string())
          break path~ WindowsPath::new(parts)
        }
        One, [] => {
          unc.write_char('\\')
          parts.push(unc.to_string())
          break path~ WindowsPath::new(parts)
        }
      }
    }
    None, ['/' | '\\', char, .. path] => {
      parts.push("\\")
      continue path~ Some(make_part(char)), path
    }
    None, [char, .. path] => {
      let part = make_part(char)
      continue path~ Some(part), path
    }
    None, [] => break path~ WindowsPath::new(parts)
    Some(part), ['/' | '\\', .. path] => {
      parts.push(part.to_string())
      skip~: loop path {
        ['/' | '\\', .. path] => continue skip~ path
        [char, .. path] => continue path~ Some(make_part(char)), path
        [] => break path~ WindowsPath::new(parts)
      }
    }
    Some(part), [char, .. path] => {
      part.write_char(char)
      continue path~ Some(part), path
    }
    Some(part), [] => {
      parts.push(part.to_string())
      break path~ WindowsPath::new(parts)
    }
  }
}

///|
impl ToWindowsPath for String with to_windows_path(self : String) -> WindowsPath {
  ToWindowsPath::to_windows_path(self.view())
}

///|
impl[T : ToWindowsPath] ToWindowsPath for Array[T] with to_windows_path(
  self : Array[T]
) -> WindowsPath {
  let mut path : WindowsPath = WindowsPath::new([])
  for part in self {
    path = path / part.to_windows_path()
  }
  path
}

///|
test "to_windows_path" {
  @json.inspect!(ToWindowsPath::to_windows_path("C:\\Windows").parts, content=[
    "C:\\", "Windows",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("C:/Windows").parts, content=[
    "C:\\", "Windows",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("C:/Windows/").parts, content=[
    "C:\\", "Windows",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("C:\\Windows\\").parts, content=[
    "C:\\", "Windows",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("C:Windows").parts, content=[
    "C:", "Windows",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("C:Windows/").parts, content=[
    "C:", "Windows",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("//unc/share/a/b").parts, content=[
    "\\\\unc\\share\\", "a", "b",
  ])
  @json.inspect!(ToWindowsPath::to_windows_path("\\\\unc\\share\\a\\b").parts, content=[
    "\\\\unc\\share\\", "a", "b",
  ])
}

///|
priv struct PosixPath {
  parts : ArrayView[@string.View]
}

///|
priv trait ToPosixPath {
  to_posix_path(Self) -> PosixPath
}

///|
impl ToPosixPath for @string.View with to_posix_path(self : @string.View) -> PosixPath {
  fn make_part(char : Char) -> StringBuilder {
    let part = StringBuilder::new()
    part.write_char(char)
    return part
  }

  let parts : Array[@string.View] = []
  path~: loop None, self {
    None, [.. "///", .. path] => {
      parts.push("/")
      skip~: loop path {
        ['/', .. path] => continue skip~ path
        [char, .. path] => continue path~ Some(make_part(char)), path
        [] => break path~ { parts, }
      }
    }
    None, [.. "//", char, .. path] => {
      parts.push("//")
      continue path~ Some(make_part(char)), path
    }
    None, [.. "/", char, .. path] => {
      parts.push("/")
      continue path~ Some(make_part(char)), path
    }
    None, [char, .. path] => {
      let part = make_part(char)
      continue path~ Some(part), path
    }
    None, [] => break path~ { parts, }
    Some(part), ['/', .. path] => {
      parts.push(part.to_string())
      skip~: loop path {
        ['/', .. path] => continue skip~ path
        [char, .. path] => continue path~ Some(make_part(char)), path
        [] => break path~ { parts, }
      }
    }
    Some(part), [char, .. path] => {
      part.write_char(char)
      continue path~ Some(part), path
    }
    Some(part), [] => {
      parts.push(part.to_string())
      break path~ { parts, }
    }
  }
}

///|
impl ToPosixPath for String with to_posix_path(self : String) -> PosixPath {
  ToPosixPath::to_posix_path(self.view())
}

///|
impl[T : ToPosixPath] ToPosixPath for Array[T] with to_posix_path(
  self : Array[T]
) -> PosixPath {
  let mut path : PosixPath = PosixPath::{ parts: [] }
  for part in self {
    path = path / part.to_posix_path()
  }
  path
}

///|
test "to_posix_path" {
  @json.inspect!(ToPosixPath::to_posix_path("//usr//bin//").parts, content=[
    "//", "usr", "bin",
  ])
  @json.inspect!(ToPosixPath::to_posix_path("/usr/bin").parts, content=[
    "/", "usr", "bin",
  ])
  @json.inspect!(ToPosixPath::to_posix_path("/usr/bin/").parts, content=[
    "/", "usr", "bin",
  ])
  @json.inspect!(ToPosixPath::to_posix_path("usr/bin").parts, content=[
    "usr", "bin",
  ])
  @json.inspect!(ToPosixPath::to_posix_path("usr/bin/").parts, content=[
    "usr", "bin",
  ])
  @json.inspect!(ToPosixPath::to_posix_path("usr//bin").parts, content=[
    "usr", "bin",
  ])
  @json.inspect!(ToPosixPath::to_posix_path("C:\\Windows").parts, content=[
    "C:\\Windows",
  ])
}

///|
enum Path {
  WindowsPath(WindowsPath)
  PosixPath(PosixPath)
}

///|
impl Div for PosixPath with op_div(self : PosixPath, other : PosixPath) -> PosixPath {
  return PosixPath::{ parts: [..self.parts, ..other.parts] }
}

///|
impl @uv.ToNtbs for PosixPath with to_ntbs(self : PosixPath) -> Bytes {
  let buffer = @buffer.new()
  for i, part in self.parts {
    if i > 0 {
      buffer.write_byte('/')
    }
    @encoding.encode_to(part, buffer, encoding=UTF8)
  }
  buffer.write_byte(0)
  buffer.contents()
}

///|
fn PosixPath::parent(self : PosixPath) -> PosixPath {
  match self.parts {
    [.. parts, _] => PosixPath::{ parts, }
    [] => PosixPath::{ parts: [] }
  }
}

///|
impl Div for WindowsPath with op_div(self : WindowsPath, other : WindowsPath) -> WindowsPath {
  return WindowsPath::new([..self.parts, ..other.parts])
}

///|
impl @uv.ToNtbs for WindowsPath with to_ntbs(self : WindowsPath) -> Bytes {
  let buffer = @buffer.new()
  for part in self.parts {
    buffer.write_stringview(part)
    buffer.write_char('\\')
  }
  buffer.contents()
}

///|
fn WindowsPath::parent(self : WindowsPath) -> WindowsPath {
  match self.parts {
    [[_, ':', ..], .., _] as parts =>
      WindowsPath::new(parts[:parts.length() - 1])
    [['\\', ..], .., _] as parts => WindowsPath::new(parts[:parts.length() - 1])
    [.. parts, _] => WindowsPath::new(parts)
    [] => WindowsPath::new([])
  }
}

///|
pub fn &ToPath::parent(self : &ToPath) -> &ToPath {
  match self.to_path() {
    WindowsPath(w) => WindowsPath(w.parent())
    PosixPath(p) => PosixPath(p.parent())
  }
}

///|
pub impl Div for &ToPath with op_div(self : &ToPath, other : &ToPath) -> &ToPath {
  match (self.to_path(), other.to_path()) {
    (WindowsPath(self), WindowsPath(other)) => WindowsPath(self / other)
    (PosixPath(self), PosixPath(other)) => PosixPath(self / other)
    _ => abort("Cannot combine Windows and Posix paths")
  }
}

///|
pub impl @uv.ToNtbs for Path with to_ntbs(self : Path) -> Bytes {
  match self {
    WindowsPath(w) => w.to_ntbs()
    PosixPath(p) => p.to_ntbs()
  }
}

///|
pub trait ToPath {
  to_path(Self) -> Path
}

///|
pub impl Hash for &ToPath with hash_combine(self : &ToPath, hasher : Hasher) -> Unit {
  match self.to_path() {
    WindowsPath(w) => w.parts.hash_combine(hasher)
    PosixPath(p) => p.parts.hash_combine(hasher)
  }
}

///|
pub impl ToPath for @string.View with to_path(self : @string.View) -> Path {
  let utsname = try @uv.os_uname!() catch {
    e => abort(e.to_string())
  }
  if utsname.sysname() == "Windows_NT" {
    return WindowsPath(ToWindowsPath::to_windows_path(self))
  } else {
    return PosixPath(ToPosixPath::to_posix_path(self))
  }
}

///|
pub impl ToPath for String with to_path(self : String) -> Path {
  ToPath::to_path(self.view())
}

///|
pub impl ToPath for Path with to_path(self : Path) -> Path {
  return self
}

///|
pub impl[T : ToPath] ToPath for Array[T] with to_path(self : Array[T]) -> Path {
  let utsname = try @uv.os_uname!() catch {
    e => abort(e.to_string())
  }
  let mut path : &ToPath = if utsname.sysname() == "Windows_NT" {
    WindowsPath(WindowsPath::new([]))
  } else {
    PosixPath(PosixPath::{ parts: [] })
  }
  for part in self {
    path = path as &ToPath / part
  }
  return path.to_path()
}

///|
pub fn[Input : ToPath] path(path : Input) -> &ToPath {
  path.to_path()
}

///|
impl Eq for WindowsPath with op_equal(self : WindowsPath, other : WindowsPath) -> Bool {
  self.parts == other.parts
}

///|
impl Eq for PosixPath with op_equal(self : PosixPath, other : PosixPath) -> Bool {
  self.parts == other.parts
}

///|
pub impl Eq for Path with op_equal(self : Path, other : Path) -> Bool {
  match (self, other) {
    (WindowsPath(self), WindowsPath(other)) => self == other
    (PosixPath(self), PosixPath(other)) => self == other
    _ => false
  }
}

///|
pub impl Eq for &ToPath with op_equal(self : &ToPath, other : &ToPath) -> Bool {
  match (self.to_path(), other.to_path()) {
    (WindowsPath(self), WindowsPath(other)) => self == other
    (PosixPath(self), PosixPath(other)) => self == other
    _ => false
  }
}

///|
impl Show for WindowsPath with output(self : WindowsPath, logger : &Logger) -> Unit {
  for i, part in self.parts {
    if i > 0 {
      logger.write_char('\\')
    }
    for char in part {
      logger.write_char(char)
    }
  }
}

///|
impl Show for PosixPath with output(self : PosixPath, logger : &Logger) -> Unit {
  let parts = match self.parts {
    ["/", .. parts] => {
      logger.write_char('/')
      parts
    }
    [.. parts] => parts
  }
  for i, part in parts {
    if i > 0 {
      logger.write_char('/')
    }
    for char in part {
      logger.write_char(char)
    }
  }
}

///|
pub impl Show for Path with output(self : Path, logger : &Logger) -> Unit {
  match self.to_path() {
    WindowsPath(w) => w.output(logger)
    PosixPath(p) => p.output(logger)
  }
}

///|
pub impl Show for &ToPath with output(self : &ToPath, logger : &Logger) -> Unit {
  self.to_path().output(logger)
}

///|
pub impl ToJson for &ToPath with to_json(self : &ToPath) -> Json {
  self.to_string().to_json()
}

///|
pub impl @json.FromJson for &ToPath with from_json(
  json : Json,
  json_path : @json.JsonPath
) -> &ToPath!@json.JsonDecodeError {
  let string : String = @json.from_json!(json, path=json_path)
  path(string)
}

///|
fn WindowsPath::relative_to(
  self : WindowsPath,
  other : WindowsPath
) -> WindowsPath {
  let self_length = self.parts.length()
  let other_length = other.parts.length()
  let length = @math.minimum(self_length, other_length)
  let common_length = for i in 0..<length {
    if self.parts[i] != other.parts[i] {
      break i
    }
  } else {
    length
  }
  let parts : Array[@string.View] = []
  for i in common_length..<other_length {
    parts.push("..")
  }
  for i in common_length..<self_length {
    parts.push(self.parts[i])
  }
  return WindowsPath::new(parts)
}

///|
fn PosixPath::relative_to(self : PosixPath, other : PosixPath) -> PosixPath {
  let self_length = self.parts.length()
  let other_length = other.parts.length()
  let length = @math.minimum(self_length, other_length)
  let common_length = for i in 0..<length {
    if self.parts[i] != other.parts[i] {
      break i
    }
  } else {
    length
  }
  let parts : Array[@string.View] = []
  for i in common_length..<other_length {
    parts.push("..")
  }
  for i in common_length..<self_length {
    parts.push(self.parts[i])
  }
  return PosixPath::{ parts, }
}

///|
pub fn[Other : ToPath] &ToPath::relative_to(
  self : &ToPath,
  other : Other
) -> &ToPath! {
  match (self.to_path(), other.to_path()) {
    (WindowsPath(self), WindowsPath(base)) =>
      return WindowsPath(WindowsPath::relative_to(self, base))
    (PosixPath(self), PosixPath(base)) =>
      return PosixPath(PosixPath::relative_to(self, base))
    _ => fail("Cannot compute relative path between Windows and Posix paths")
  }
}

///|
pub fn[Other : ToPath] Path::relative_to(self : Path, other : Other) -> Path! {
  match (self.to_path(), other.to_path()) {
    (WindowsPath(self), WindowsPath(base)) =>
      return WindowsPath(WindowsPath::relative_to(self, base))
    (PosixPath(self), PosixPath(base)) =>
      return PosixPath(PosixPath::relative_to(self, base))
    _ => fail("Cannot compute relative path between Windows and Posix paths")
  }
}

///|
pub fn Path::is_absolute(self : Path) -> Bool {
  match self {
    WindowsPath(w) =>
      w.parts.length() > 0 && w.parts[0].length() > 1 && w.parts[0][1] == ':'
    PosixPath(p) => p.parts.length() > 0 && p.parts[0].has_prefix("/")
  }
}

///|
fn Path::name(self : Path) -> String {
  match self {
    WindowsPath(w) => w.parts[w.parts.length() - 1].to_string()
    PosixPath(p) => p.parts[p.parts.length() - 1].to_string()
  }
}

///|
pub fn &ToPath::name(self : &ToPath) -> String {
  self.to_path().name()
}

///|
pub fn &ToPath::parts(self : &ToPath) -> ArrayView[@string.View] {
  match self.to_path() {
    WindowsPath(w) => w.parts
    PosixPath(p) => p.parts
  }
}
