///|
pub(all) enum OpenFlags {
  ReadOnly
  WriteOnly
  ReadWrite
}

///|
pub impl Readable for File with read(self : File) {
  fn read(
    uv : @uv.Loop,
    file : @uv.File,
    yield_ : async (@bytes.View) -> Unit!,
    resolve : (Unit) -> Unit,
    reject : (Error) -> Unit
  ) -> Unit {
    try {
      let bytes = Bytes::make(256, 0)
      uv.fs_read!(
        file,
        [bytes[:]],
        fn(_, count) {
          if count == 0 {
            resolve(())
          } else {
            async_run(fn() {
              try {
                yield_!(bytes[:count])
                read(uv, file, yield_, resolve, reject)
              } catch {
                e => reject(e)
              }
            })
          }
        },
        fn(_, e) { reject(e) },
      )
    } catch {
      e => reject(e)
    }
  }

  fn(yield_) {
    let uv = uv!()
    async_suspend_with_error!(fn(resolve, reject) {
      read(uv, self._, yield_, resolve, reject)
    })
  }
}

///|
pub impl Writable for File with write(self : File, bytes : Iter[@bytes.View]) {
  fn write(
    uv : @uv.Loop,
    file : @uv.File,
    bytes : @bytes.View,
    resolve : (Unit) -> Unit,
    reject : (Error) -> Unit
  ) {
    if bytes.length() == 0 {
      resolve(())
      return
    }
    try
      uv.fs_write!(
        file,
        [bytes[:]],
        fn(_, count) { write(uv, file, bytes[count:], resolve, reject) },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  }

  let uv = uv!()
  bytes.each!(fn(bytes) {
    async_suspend_with_error!(fn(resolve, reject) {
      write(uv, self._, bytes, resolve, reject)
    })
  })
}

///|
pub impl Readable for &ToPath with read(self : &ToPath) -> Iter[@bytes.View]! {
  let uv = uv!()
  fn(yield_) {
    async_suspend_with_error!(fn(
      resolve : (Unit) -> Unit,
      reject : (Error) -> Unit
    ) {
      try
        uv.fs_open!(
          self.to_path().to_string(),
          @uv.OpenFlags::read(),
          0o644,
          fn(_, file) {
            let file = File(file)
            async_run(fn() {
              try {
                file.read!().each!(fn(bytes) { yield_!(bytes) })
                uv.fs_close!(file._, fn(_) { resolve(()) })
              } catch {
                e => reject(e)
              }
            })
          },
          fn(_, e) { reject(e) },
        ) catch {
        e => reject(e)
      }
    })
  }
}

///|
pub impl Writable for &ToPath with write(
  self : &ToPath,
  bytes : Iter[@bytes.View]
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_open!(
        self.to_path().to_string(),
        @uv.OpenFlags::write(create=true, truncate=true),
        0o644,
        fn(_, file) {
          let file = File(file)
          async_run(fn() {
            try {
              file.write!(bytes)
              uv.fs_close!(file._, fn(_) { resolve(()) })
            } catch {
              e => reject(e)
            }
          })
        },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::iter(self : &ToPath) -> Iter[&ToPath]! {
  let uv = uv!()
  async_suspend_with_error!(fn(
    resolve : (Iter[&ToPath]) -> Unit,
    reject : (Error) -> Unit
  ) {
    try
      uv.fs_scandir!(
        self.to_path().to_string(),
        0,
        fn(req) {
          let iter : Iter[&ToPath] = fn(yield_) {
            try {
              while true {
                let dirent = @uv.fs_scandir_next!(req)
                let name = dirent.name()
                yield_(self / name)
              }
            } catch! {
              @uv.Errno(EOF) => ()
            }
          }
          resolve(iter)
        },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::walk(
  self : &ToPath,
  loc~ : SourceLoc = _
) -> Iter[&ToPath]! {
  let uv = uv!()
  fn(yield_) {
    backtrace(loc~, fn() {
      async_suspend_with_error!(fn(resolve, reject) {
        try
          uv.fs_scandir!(
            self.to_path().to_string(),
            0,
            fn(req) {
              async_run(fn() {
                try {
                  while true {
                    let dirent = @uv.fs_scandir_next!(req)
                    let type_ = dirent.type_()
                    let name = dirent.name()
                    yield_!(self / name)
                    if type_ is Dir {
                      ((self / name).walk!()._)!(fn(path) { yield_!(path) })
                    }
                  }
                } catch {
                  @uv.Errno(EOF) => resolve(())
                  e => reject(e)
                }
              })
            },
            fn(_, e) { reject(e) },
          ) catch {
          e => reject(e)
        }
      })
    })
  }
}

///|
type Stat @uv.Stat

///|
pub async fn &ToPath::stat(self : &ToPath) -> Stat! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject) {
    try
      uv.fs_stat!(
        self.to_path().to_string(),
        fn(_, stat) { resolve(Stat(stat)) },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub fn Stat::is_dir(self : Stat) -> Bool {
  self._.is_directory()
}

///|
pub fn Stat::is_file(self : Stat) -> Bool {
  self._.is_file()
}

///|
pub async fn &ToPath::is_dir(self : &ToPath) -> Bool! {
  let stat = self.stat!()
  stat.is_dir()
}

///|
pub async fn &ToPath::is_file(self : &ToPath) -> Bool! {
  let stat = self.stat!()
  stat.is_file()
}

///|
pub async fn &ToPath::resolve(self : &ToPath) -> &ToPath! {
  let uv = uv!()
  let self = self.to_path()
  if self.flavor != flavor.val {
    raise SystemError::not_supported(self)
  }
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_realpath!(self.to_path().to_string(), fn(_, p) { resolve(p) }, fn(
        _,
        e
      ) {
        reject(e)
      }) catch {
      e => reject(e)
    }
  })
}

///|
priv enum ErrorInfo {
  Exists(&ToPath)
  IsDirectory(&ToPath)
  NotEmpty(&ToPath)
  NotFound(&ToPath)
  NotSupported(&ToPath)
} derive(ToJson(repr(ext_tagged)))

///|
impl Show for ErrorInfo with output(self : ErrorInfo, logger : &Logger) -> Unit {
  match self {
    Exists(path) => logger.write_string("Exists: \{path.to_string()}")
    IsDirectory(path) => logger.write_string("IsDirectory: \{path.to_string()}")
    NotEmpty(path) => logger.write_string("NotEmpty: \{path.to_string()}")
    NotFound(path) => logger.write_string("NotFound: \{path.to_string()}")
    NotSupported(path) =>
      logger.write_string("NotSupported: \{path.to_string()} is not supported")
  }
}

///|
impl Show for SystemError with output(self : SystemError, logger : &Logger) -> Unit {
  let SystemError((value, trace)) = self
  logger.write_string("Trace:\n")
  let uv = try? uv()
  let cwd = try? @uv.cwd()
  guard uv is Ok(uv) && cwd is Ok(cwd) else {
    for i = trace.length() - 1; i >= 0; i = i - 1 {
      let loc = trace[i].to_string()
      logger.write_string("  \{loc}\n")
    }
    logger.write_string(value.to_string())
  }
  fn write_file_content!(file : Path, start_row : @string.View) {
    let start_row = @strconv.parse_int(start_row.to_string())
    let content = StringBuilder::new()
    let decoder = @encoding.decoder(UTF8)
    let buffer = Bytes::make(1024, 0)
    let file = uv.fs_open_sync(file.to_string(), @uv.OpenFlags::read(), 0o644)
    for nread = uv.fs_read_sync(file, [buffer[:]])
        nread > 0
        nread = uv.fs_read_sync(file, [buffer[:]]) {
      decoder.decode_to(buffer[:nread], content, stream=true)
    }
    let content = content.to_string()
    let lines = content.split("\n").collect()
    logger.write_string("  \{lines[start_row - 1]}\n")
  }

  for i = trace.length() - 1; i >= 0; i = i - 1 {
    let loc = trace[i].to_string()
    guard loc.to_string().split(":").collect()
      is [.. file_parts, start_row, start_column_end_row, end_column] else {
      logger.write_string("  \{loc}\n")
      continue
    }
    let file = Path::new(file_parts)
    let file = file.relative_to(cwd)
    logger.write_string(
      "  \{file.to_string()}:\{start_row}:\{start_column_end_row}:\{end_column}\n",
    )
    try write_file_content(file, start_row) catch {
      e => {
        logger.write_string("  (error processing source location: \{e})")
        continue
      }
    }
  }
  logger.write_string(value.to_string())
}

///|
impl ToJson for SystemError with to_json(self : SystemError) -> Json {
  let SystemError((error, trace)) = self
  { "error": error, "trace": trace.map(fn(loc) { loc.to_string() }) }
}

///|
priv type! SystemError (ErrorInfo, Array[SourceLoc])

///|
fn SystemError::new(
  value : ErrorInfo,
  trace~ : Array[SourceLoc] = [],
  loc~ : SourceLoc = _
) -> SystemError {
  SystemError((value, [loc, ..trace]))
}

///|
fn SystemError::exists(
  path : &ToPath,
  loc~ : SourceLoc = _,
  caller? : SourceLoc
) -> SystemError {
  let locs = [loc]
  if caller is Some(caller) {
    locs.push(caller)
  }
  SystemError((Exists(path), locs))
}

///|
fn SystemError::is_directory(
  path : &ToPath,
  loc~ : SourceLoc = _
) -> SystemError {
  SystemError((IsDirectory(path), [loc]))
}

///|
fn SystemError::not_empty(path : &ToPath, loc~ : SourceLoc = _) -> SystemError {
  SystemError((NotEmpty(path), [loc]))
}

///|
fn SystemError::not_found(path : &ToPath, loc~ : SourceLoc = _) -> SystemError {
  SystemError((NotFound(path), [loc]))
}

///|
fn SystemError::not_supported(
  self : &ToPath,
  loc~ : SourceLoc = _
) -> SystemError {
  SystemError((NotSupported(self), [loc]))
}

///|
async fn[T] backtrace(loc~ : SourceLoc, f : async () -> T!Error) -> T!Error {
  try f() catch! {
    SystemError((_, trace)) as system_error => {
      trace.push(loc)
      raise system_error
    }
  }
}

///|
pub async fn[Target : ToPath] &ToPath::copy_to(
  self : &ToPath,
  target : Target,
  recursive~ : Bool = false,
  overwrite~ : Bool = false,
  loc~ : SourceLoc = _
) -> Unit! {
  backtrace(loc~, fn() {
    let uv = uv!()
    let target : &ToPath = target.to_path()
    if self.is_dir() {
      if not(recursive) {
        raise SystemError::is_directory(self)
      }
      if not(overwrite) && target.exists() {
        raise SystemError::exists(target)
      }
      target.mkdir()
      self
      .iter()
      .each(fn(entry) {
        let target_entry = target / entry.relative_to(self)
        entry.copy_to!(target_entry, recursive~, overwrite~)
      })
    } else {
      async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
        try
          uv.fs_copyfile!(
            self.to_path().to_string(),
            target.to_path().to_string(),
            @uv.CopyFileFlags::new(allow_exists=overwrite),
            fn(_) { resolve(()) },
            fn(_, e) { reject(e) },
          ) catch {
          e => reject(e)
        }
      })
    }
  })
}

///|
pub async fn[Target : ToPath] &ToPath::move_to(
  self : &ToPath,
  target : Target
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_rename!(
        self.to_path().to_string(),
        target.to_path().to_string(),
        fn(_) { resolve(()) },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::unlink(self : &ToPath) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_unlink!(self.to_path().to_string(), fn(_) { resolve(()) }, fn(
        _,
        e
      ) {
        reject(e)
      }) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::rmdir(self : &ToPath, loc~ : SourceLoc = _) -> Unit! {
  let uv = uv!()
  try
    async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
      try
        uv.fs_rmdir!(self.to_path().to_string(), fn(_) { resolve(()) }, fn(
          _,
          e
        ) {
          reject(e)
        }) catch {
        e => reject(e)
      }
    }) catch! {
    @uv.Errno(ENOTEMPTY) => raise SystemError::not_empty(self, loc~)
    @uv.Errno(ENOENT) => raise SystemError::not_found(self, loc~)
  }
}

///|
pub async fn &ToPath::mkdir(
  self : &ToPath,
  mode~ : Int = 0o777,
  loc~ : SourceLoc = _
) -> Unit! {
  let uv = uv!()
  backtrace(loc~, fn() {
    async_suspend_with_error(fn(resolve, reject : (Error) -> Unit) {
      try
        uv.fs_mkdir(self.to_path().to_string(), mode, fn(_) { resolve(()) }, fn(
          _,
          e
        ) {
          if e is @uv.Errno(EEXIST) {
            reject(SystemError::exists(self))
          } else {
            reject(e)
          }
        }) catch {
        @uv.Errno(EEXIST) => reject(SystemError::exists(self))
        e => {
          reject(e)
        }
      }
    })
  })
}

///|
pub async fn &ToPath::access(
  self : &ToPath,
  read~ : Bool = false,
  write~ : Bool = false,
  execute~ : Bool = false
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_access!(
        self.to_path().to_string(),
        @uv.AccessFlags::new(read~, write~, execute~),
        fn(_) { resolve(()) },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::exists(self : &ToPath) -> Bool! {
  try {
    self.access!()
    true
  } catch! {
    @uv.Errno(ENOENT) => false
  }
}

///|
pub async fn &ToPath::remove(
  self : &ToPath,
  recursive~ : Bool = false,
  loc~ : SourceLoc = _
) -> Unit! {
  backtrace(loc~, fn() {
    if self.is_dir() {
      let entries = self.iter!().collect()
      if not(entries.is_empty()) {
        if not(recursive) {
          raise SystemError::not_empty(self)
        }
        Scope::new(fn(scope) {
          for entry in entries {
            scope.launch(fn() { entry.remove!(recursive~) })
          }
        })
      }
      self.rmdir()
    } else {
      self.unlink()
    }
  })
}
