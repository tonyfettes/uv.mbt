///|
struct File {
  loop_ : Loop
  file : @uv.File
}

///|
pub fn Loop::stdout(self : Loop) -> File {
  File::{ loop_: self, file: @uv.STDOUT.to_int64() }
}

///|
pub(all) enum OpenFlag {
  ReadOnly
  WriteOnly
  ReadWrite
}

///|
pub impl ToOpenFlags for OpenFlag with to_open_flags(self : OpenFlag) -> OpenFlags {
  match self {
    ReadOnly => OpenFlags(@uv.FS_O_RDONLY)
    WriteOnly => OpenFlags(@uv.FS_O_WRONLY)
    ReadWrite => OpenFlags(@uv.FS_O_RDWR)
  }
}

///|
type OpenFlags Int

///|
trait ToOpenFlags {
  to_open_flags(Self) -> OpenFlags
}

///|
pub async fn Loop::open[T : ToOpenFlags](
  self : Loop,
  path : Bytes,
  flags : T,
  mode : Int
) -> File!Errno {
  let flags = flags.to_open_flags()
  async_suspend!!(fn(
    resolve : (File) -> Unit,
    reject : (Errno) -> Unit
  ) -> Unit {
    let req = @uv.fs_alloc()
    let result = @uv.fs_open(self._, req, path, flags._, mode, fn(req) {
      let result = @uv.fs_get_result(req)
      if result < 0 {
        reject(Errno(result.to_int()))
      } else {
        resolve({ loop_: self, file: result })
      }
    })
    if result < 0 {
      reject(Errno(result))
    }
  })
}

///|
fn identity[T, U](x : T) -> U = "%identity"

///|
priv struct MutableBytesView {
  bytes : Bytes
  start : Int
  end : Int
}

///|
fn MutableBytesView::of_array_view(view : ArrayView[Byte]) -> MutableBytesView = "%identity"

///|
fn MutableBytesView::of_bytes_view(view : @bytes.View) -> MutableBytesView {
  let view_ptr : VoidPtr = identity(view)
  identity(view_ptr)
}

///|
fn MutableBytesView::to_bytes_view(self : MutableBytesView) -> @bytes.View {
  let view_ptr : VoidPtr = identity(self)
  identity(view_ptr)
}

///|
fn MutableBytesView::op_as_view(
  self : MutableBytesView,
  start~ : Int = 0,
  end~ : Int = self.end - self.start
) -> MutableBytesView {
  MutableBytesView::{
    bytes: self.bytes,
    start: self.start + start,
    end: self.start + end,
  }
}

///|
pub async fn File::read(
  self : File,
  length~ : Int = 1024,
  offset~ : Int64 = -1
) -> @bytes.View!Errno {
  async_suspend!!(fn(
    resolve : (@bytes.View) -> Unit,
    reject : (Errno) -> Unit
  ) -> Unit {
    let { loop_, file } = self
    let req = @uv.fs_alloc()
    let buf = @uv.buf_alloc()
    let bytes = Bytes::make(length, (0 : Byte))
    @uv.buf_init(buf, bytes, 0, bytes.length())
    let bufs : FixedArray[@uv.Buf] = [buf]
    let result = @uv.fs_read(loop_._, req, file, bufs, offset, fn(req) {
      let result = @uv.fs_get_result(req).to_int()
      if result < 0 {
        reject(Errno(result))
      } else {
        resolve(bytes[:result])
      }
    })
    if result < 0 {
      reject(Errno(result))
    }
  })
}

///|
priv extern type VoidPtr

///|
pub async fn File::write(
  self : File,
  bytes : @bytes.View,
  offset~ : Int64 = -1
) -> @bytes.View!Errno {
  async_suspend!!(fn(
    resolve : (@bytes.View) -> Unit,
    reject : (Errno) -> Unit
  ) -> Unit {
    let { loop_, file } = self
    let req = @uv.fs_alloc()
    let buf = @uv.buf_alloc()
    let bytes = MutableBytesView::of_bytes_view(bytes)
    @uv.buf_init(buf, bytes.bytes, bytes.start, bytes.end - bytes.start)
    let bufs : FixedArray[@uv.Buf] = [buf]
    let result = @uv.fs_write(loop_._, req, file, bufs, offset, fn(req) {
      let result = @uv.fs_get_result(req).to_int()
      if result < 0 {
        reject(Errno(result))
      } else {
        let bytes = bytes.to_bytes_view()
        resolve(bytes[:result])
      }
    })
    if result < 0 {
      reject(Errno(result))
    }
  })
}

///|
pub async fn File::close(self : File) -> Unit!Errno {
  async_suspend!!(fn(
    resolve : (Unit) -> Unit,
    reject : (Errno) -> Unit
  ) -> Unit {
    let { loop_, file } = self
    let req = @uv.fs_alloc()
    let result = @uv.fs_close(loop_._, req, file, fn(req) {
      let result = @uv.fs_get_result(req)
      if result < 0 {
        reject(Errno(result.to_int()))
      } else {
        resolve(())
      }
    })
    if result < 0 {
      reject(Errno(result))
    }
  })
}
