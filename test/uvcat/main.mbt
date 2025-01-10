///|
fn run_async[T](f :  async() -> T) = "%async.run"

///|
async fn suspend[T](f : ((T) -> Unit) -> Unit) -> T = "%async.suspend"

///|
async fn open(
  loop_ : @auv.Loop,
  path : Bytes,
  flags : Int,
  mode : Int
) -> @auv.File {
  let req = @auv.fs_alloc()
  suspend!!(fn(k) {
    @auv.fs_open(loop_, req, path, flags, mode, fn(req) {
      k(@auv.fs_get_result(req))
    })
    |> ignore
  })
}

///|
async fn read(
  loop_ : @auv.Loop,
  file : @auv.File,
  bufs : FixedArray[@auv.Buf],
  offset : Int64
) -> Int64 {
  let req = @auv.fs_alloc()
  suspend!!(fn(k) {
    @auv.fs_read(loop_, req, file, bufs, offset, fn(req) {
      k(@auv.fs_get_result(req))
    })
    |> ignore
  })
}

///|
async fn write(
  loop_ : @auv.Loop,
  file : @auv.File,
  bufs : FixedArray[@auv.Buf],
  offset : Int64
) -> Int64 {
  let req = @auv.fs_alloc()
  suspend!!(fn(k) {
    @auv.fs_write(loop_, req, file, bufs, offset, fn(req) {
      k(@auv.fs_get_result(req))
    })
    |> ignore
  })
}

///|
async fn close(loop_ : @auv.Loop, file : @auv.File) -> Unit {
  let req = @auv.fs_alloc()
  suspend!!(fn(k) {
    @auv.fs_close(loop_, req, file, fn(_req) { k(()) }) |> ignore
  })
}

///|
fn main {
  let loop_ = @auv.loop_alloc()
  run_async(fn() {
    @auv.loop_init(loop_) |> ignore
    let file = open!!(loop_, b"main.mbt", @auv.O_RDONLY, 0)
    let buffer = FixedArray::make(1024, (0 : Byte))
    let iov = @auv.buf_alloc()
    @auv.buf_init(iov, buffer) |> ignore
    loop read!!(loop_, file, [iov], -1) {
      0 => {
        close!!(loop_, file)
        return
      }
      nread => {
        @auv.buf_set_len(iov, nread.reinterpret_as_uint64()) |> ignore
        let nwritten = write!!(loop_, 1, [iov], -1)
        if nwritten < nread {
          close!!(loop_, file)
        }
        continue read!!(loop_, file, [iov], -1)
      }
    }
  })
  @auv.loop_run(loop_, 0) |> ignore
  @auv.loop_close(loop_) |> ignore
  @auv.loop_free(loop_) |> ignore
}
