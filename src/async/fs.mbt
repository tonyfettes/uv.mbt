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
          self.to_path(),
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
        self.to_path(),
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
        self.to_path(),
        0,
        fn(req) {
          fn(yield_) {
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
          |> resolve()
        },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::walk(self : &ToPath) -> Iter[&ToPath]! {
  let uv = uv!()
  fn(yield_) {
    async_suspend_with_error!(fn(resolve, reject) {
      try
        uv.fs_scandir!(
          self.to_path(),
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
  }
}

///|
type Stat @uv.Stat

///|
pub async fn &ToPath::stat(self : &ToPath) -> Stat! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject) {
    try
      uv.fs_stat!(self.to_path(), fn(_, stat) { resolve(Stat(stat)) }, fn(
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
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_realpath!(self.to_path(), fn(_, p) { resolve(p) }, fn(_, e) {
        reject(e)
      }) catch {
      e => reject(e)
    }
  })
}

///|
pub type! SystemError {
  Exists(&ToPath, loc~ : Array[SourceLoc])
  IsDirectory(&ToPath, loc~ : Array[SourceLoc])
  NotEmpty(&ToPath, loc~ : Array[SourceLoc])
  NotFound(&ToPath, loc~ : Array[SourceLoc])
} derive(Show)

///|
fn SystemError::exists(path : &ToPath, loc~ : SourceLoc = _) -> SystemError {
  Exists(path, loc=[loc])
}

///|
fn SystemError::is_directory(
  path : &ToPath,
  loc~ : SourceLoc = _
) -> SystemError {
  IsDirectory(path, loc=[loc])
}

///|
fn SystemError::not_empty(path : &ToPath, loc~ : SourceLoc = _) -> SystemError {
  NotEmpty(path, loc=[loc])
}

///|
fn SystemError::not_found(path : &ToPath, loc~ : SourceLoc = _) -> SystemError {
  NotFound(path, loc=[loc])
}

///|
pub async fn[Target : ToPath] &ToPath::copy_to(
  self : &ToPath,
  target : Target,
  recursive~ : Bool = false,
  overwrite~ : Bool = false,
  loc~ : SourceLoc = _
) -> Unit! {
  let uv = uv!()
  let target : &ToPath = target.to_path()
  if self.is_dir() {
    if not(recursive) {
      raise SystemError::is_directory(self, loc~)
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
          self.to_path(),
          target.to_path(),
          @uv.CopyFileFlags::new(allow_exists=overwrite),
          fn(_) { resolve(()) },
          fn(_, e) { reject(e) },
        ) catch {
        e => reject(e)
      }
    })
  }
}

///|
pub async fn[Target : ToPath] &ToPath::move_to(
  self : &ToPath,
  target : Target
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_rename!(self.to_path(), target.to_path(), fn(_) { resolve(()) }, fn(
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
pub async fn &ToPath::unlink(self : &ToPath) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_unlink!(self.to_path(), fn(_) { resolve(()) }, fn(_, e) {
        reject(e)
      }) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn &ToPath::rmdir(self : &ToPath) -> Unit! {
  let uv = uv!()
  try
    async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
      try
        uv.fs_rmdir!(self.to_path(), fn(_) { resolve(()) }, fn(_, e) {
          reject(e)
        }) catch {
        e => reject(e)
      }
    }) catch! {
    @uv.Errno(ENOTEMPTY) => raise SystemError::not_empty(self)
    @uv.Errno(ENOENT) => raise SystemError::not_found(self)
  }
}

///|
pub async fn &ToPath::mkdir(self : &ToPath, mode~ : Int = 0o777) -> Unit! {
  let uv = uv!()
  try
    async_suspend_with_error(fn(resolve, reject : (Error) -> Unit) {
      try
        uv.fs_mkdir(self.to_path(), mode, fn(_) { resolve(()) }, fn(_, e) {
          reject(e)
        }) catch {
        e => reject(e)
      }
    }) catch! {
    @uv.Errno(EEXIST) => raise SystemError::exists(self)
  }
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
        self.to_path(),
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
  if self.is_dir() {
    let entries = self.iter!().collect()
    if not(entries.is_empty()) {
      if not(recursive) {
        raise NotEmpty(self, loc=[loc])
      }
      for entry in entries {
        entry.remove!(recursive~)
      }
    }
    self.rmdir()
  } else {
    self.unlink()
  }
}
