///|
pub(all) enum OpenFlags {
  ReadOnly
  WriteOnly
  ReadWrite
}

///|
pub fn open(
  self : Path,
  flags : OpenFlags,
  mode~ : Int = 0o644
) -> File!Async + Error {
  let uv = uv!()
  suspend_with_error!(fn(resolve : (File) -> Unit, reject : (Error) -> Unit) {
    try {
      uv.fs_open!(
        self,
        match flags {
          ReadOnly => @uv.OpenFlags::read()
          WriteOnly => @uv.OpenFlags::write()
          ReadWrite => @uv.OpenFlags::read_write()
        },
        mode,
        fn(_, file) { resolve(File(file)) },
        fn(_, e) { reject(e) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
fn file_do_read(
  uv : @uv.Loop,
  file : @uv.File,
  bytes : Bytes,
  builder : StringBuilder,
  encoding~ : @encoding.Encoding,
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
            @encoding.decode_to!(bytes[:count], builder, encoding=UTF8)
            file_do_read(uv, file, bytes, builder, encoding~, resolve, reject)
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

///|
pub fn File::text(
  self : File,
  encoding~ : @encoding.Encoding = UTF8
) -> String!Async + Error {
  let uv = uv!()
  let bytes = Bytes::make(256, 0)
  let builder = StringBuilder::new()
  suspend_with_error!(fn(resolve, reject) {
    file_do_read(uv, self._, bytes, builder, encoding~, resolve, reject)
  })
  builder.to_string()
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
              @uv.Errno(EOF) => {
                IterContinue
              }
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
