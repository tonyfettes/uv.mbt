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
        fn(_, count) {
          async_run(fn() { write(uv, file, bytes[count:], resolve, reject) })
        },
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
pub async fn read(self : Path) -> Iter[@bytes.View]! {
  let uv = uv!()
  fn(yield_) {
    async_suspend_with_error!(fn(
      resolve : (Unit) -> Unit,
      reject : (Error) -> Unit
    ) {
      try
        uv.fs_open!(
          self,
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
pub async fn read_bytes(self : Path) -> Bytes! {
  self.read!().bytes!()
}

///|
pub async fn read_text(
  self : Path,
  encoding~ : @encoding.Encoding = UTF8
) -> String! {
  self.read!().text!(encoding~)
}

///|
pub async fn Path::write(self : Path, bytes : Iter[@bytes.View]) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_open!(
        self,
        @uv.OpenFlags::write(create=true),
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
pub async fn Path::write_bytes(self : Path, bytes : @bytes.View) -> Unit! {
  self.write!(fn(yield_) { yield_!(bytes[:]) })
}

///|
pub async fn Path::write_text(
  self : Path,
  text : @string.View,
  encoding~ : @encoding.Encoding = UTF8
) -> Unit! {
  let bytes = @encoding.encode(text, encoding~)
  self.write!(fn(yield_) { yield_!(bytes[:]) })
}

///|
pub async fn Path::iter(self : Path) -> @builtin.Iter[Path]! {
  let uv = uv!()
  async_suspend_with_error!(fn(
    resolve : (@builtin.Iter[Path]) -> Unit,
    reject : (Error) -> Unit
  ) {
    try
      uv.fs_scandir!(
        self,
        0,
        fn(req) {
          fn(yield_) {
            try {
              while true {
                let dirent = @uv.fs_scandir_next!(req)
                let name = dirent.name()
                match yield_(self / path!(name)) {
                  IterEnd => break IterEnd
                  IterContinue => continue
                }
              } else {
                IterContinue
              }
            } catch {
              @uv.Errno(EOF) => IterContinue
              e => {
                reject(e)
                IterEnd
              }
            }
          }
          |> @builtin.Iter::new()
          |> resolve()
        },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn Path::walk(self : Path) -> Iter[Path]! {
  let uv = uv!()
  fn(yield_) {
    async_suspend_with_error!(fn(resolve, reject) {
      try
        uv.fs_scandir!(
          self,
          0,
          fn(req) {
            async_run(fn() {
              try {
                while true {
                  let dirent = @uv.fs_scandir_next!(req)
                  let type_ = dirent.type_()
                  if type_ is Dir {
                    let name = dirent.name()
                    ((self / path!(name)).walk!()._)!(fn(path) { yield_!(path) })
                  } else {
                    let name = dirent.name()
                    yield_!(self / path!(name))
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
pub async fn Path::stat(self : Path) -> Stat! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject) {
    try
      uv.fs_stat!(self, fn(_, stat) { resolve(Stat(stat)) }, fn(_, e) {
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
pub async fn Path::is_dir(self : Path) -> Bool! {
  let stat = self.stat!()
  stat.is_dir()
}

///|
pub async fn Path::is_file(self : Path) -> Bool! {
  let stat = self.stat!()
  stat.is_file()
}

///|
pub async fn Path::resolve(self : Path) -> Path! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_realpath!(
        self,
        fn(_, p) {
          try resolve(path!(p)) catch {
            e => reject(e)
          }
        },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn[Target : ToPath] Path::copy_to(
  self : Path,
  target : Target
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_copyfile!(
        self,
        target.to_path(),
        @uv.CopyFileFlags::new(),
        fn(_) { resolve(()) },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn[Target : ToPath] Path::move_to(
  self : Path,
  target : Target
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_rename!(self, target.to_path(), fn(_) { resolve(()) }, fn(_, e) {
        reject(e)
      }) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn Path::unlink(self : Path) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try uv.fs_unlink!(self, fn(_) { resolve(()) }, fn(_, e) { reject(e) }) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn Path::access(
  self : Path,
  read~ : Bool = false,
  write~ : Bool = false,
  execute~ : Bool = false
) -> Unit! {
  let uv = uv!()
  async_suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try
      uv.fs_access!(
        self,
        @uv.AccessFlags::new(read~, write~, execute~),
        fn(_) { resolve(()) },
        fn(_, e) { reject(e) },
      ) catch {
      e => reject(e)
    }
  })
}

///|
pub async fn Path::exists(self : Path) -> Bool! {
  try {
    self.access!()
    true
  } catch {
    @uv.Errno(ENOENT) => false
    e => raise e
  }
}
