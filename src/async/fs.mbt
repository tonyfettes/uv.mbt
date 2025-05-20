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
    bytes : Bytes,
    yield_ : (@bytes.View) -> Unit!Error + Async,
    resolve : (Unit) -> Unit,
    reject : (Error) -> Unit
  ) -> Unit {
    try {
      uv.fs_read!(
        file,
        [bytes[:]],
        fn(_, count) {
          try {
            if count == 0 {
              uv.fs_close!(file, fn(_) { resolve(()) })
            } else {
              run(fn() {
                try {
                  yield_!(bytes[:count])
                } catch {
                  e => reject(e)
                }
              })
              read(uv, file, bytes, yield_, resolve, reject)
            }
          } catch {
            e => reject(e)
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
    suspend_with_error!(fn(resolve, reject) {
      let bytes = Bytes::make(256, 0)
      read(uv, self._, bytes, yield_, resolve, reject)
    })
  }
}

///|
pub fn read(self : Path) -> AsyncIter[@bytes.View]!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(
    resolve : (AsyncIter[@bytes.View]) -> Unit,
    reject : (Error) -> Unit
  ) {
    try {
      uv.fs_open!(
        self,
        @uv.OpenFlags::read(),
        0o644,
        fn(_, file) {
          let file = File(file)
          run(fn() {
            try {
              resolve(file.read!())
            } catch {
              e => reject(e)
            }
          })
        },
        fn(_, e) { reject(e) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
pub fn read_bytes(self : Path) -> Bytes!Async + Error {
  self.read!().bytes!()
}

///|
pub fn read_text(
  self : Path,
  encoding~ : @encoding.Encoding = UTF8
) -> String!Async + Error {
  self.read!().text!(encoding~)
}

///|
pub fn Path::iter(self : Path) -> Iter[Path]!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(
    resolve : (Iter[Path]) -> Unit,
    reject : (Error) -> Unit
  ) {
    try {
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
          |> Iter::new()
          |> resolve()
        },
        fn(_, e) { reject(e) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
pub fn Path::walk(self : Path) -> AsyncIter[Path]!Async + Error {
  let uv = uv!()
  fn(yield_) {
    suspend_with_error!(fn(resolve, reject) {
      try {
        uv.fs_scandir!(
          self,
          0,
          fn(req) {
            run(fn() {
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
        )
      } catch {
        e => reject(e)
      }
    })
  }
}

///|
type Stat @uv.Stat

///|
pub fn Path::stat(self : Path) -> Stat!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(resolve, reject) {
    try {
      uv.fs_stat!(self, fn(_, stat) { resolve(Stat(stat)) }, fn(_, e) {
        reject(e)
      })
    } catch {
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
pub fn Path::is_dir(self : Path) -> Bool!Async + Error {
  let stat = self.stat!()
  stat.is_dir()
}

///|
pub fn Path::is_file(self : Path) -> Bool!Async + Error {
  let stat = self.stat!()
  stat.is_file()
}

///|
pub fn Path::resolve(self : Path) -> Path!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try {
      uv.fs_realpath!(
        self,
        fn(_, p) {
          try {
            resolve(path!(p))
          } catch {
            e => reject(e)
          }
        },
        fn(_, e) { reject(e) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
pub fn Path::copy_to(self : Path, target : Path) -> Unit!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try {
      uv.fs_copyfile!(
        self,
        target,
        @uv.CopyFileFlags::new(),
        fn(_) { resolve(()) },
        fn(_, e) { reject(e) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
pub fn Path::move_to(self : Path, target : Path) -> Unit!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(resolve, reject : (Error) -> Unit) {
    try {
      uv.fs_rename!(self, target, fn(_) { resolve(()) }, fn(_, e) { reject(e) })
    } catch {
      e => reject(e)
    }
  })
}
