///|
fn run_async(f :  async() -> Unit) -> Unit = "%async.run"

///|
async fn suspend[T, E : Error](f : ((T) -> Unit, (E) -> Unit) -> Unit) -> T!E = "%async.suspend"

///|
async fn open(
  loop_ : @uv.Loop,
  path : Bytes,
  flags : Int,
  mode : Int
) -> @uv.File!ErrorCode {
  let req = @uv.fs_alloc()
  suspend!!(fn(resolve, reject : (ErrorCode) -> Unit) {
    @uv.fs_open(loop_, req, path, flags, mode, fn(req) {
      let file = @uv.fs_get_result(req)
      if file < 0 {
        reject(ErrorCode(file.to_int()))
      } else {
        resolve(@uv.fs_get_result(req))
      }
    })
    |> ignore
  })
}

///|
let gid : Ref[Int] = @ref.new(0)

///|
fn fresh_id() -> Int {
  let id = gid.val
  gid.val = id + 1
  id
}

///|
async fn fs_read(
  loop_ : @uv.Loop,
  file : @uv.File,
  bufs : FixedArray[@uv.Buf],
  offset : Int64
) -> Int64!ErrorCode {
  suspend!!(fn(resolve, reject) {
    let req = @uv.fs_alloc()
    let req_id = fresh_id()
    println("fs_read: \{req_id}")
    @uv.fs_read(loop_, req, file, bufs, offset, fn(req) {
      let n_read = @uv.fs_get_result(req)
      if n_read < 0 {
        reject(ErrorCode(n_read.to_int()))
      } else {
        resolve(@uv.fs_get_result(req))
      }
      println("fs_read 1: \{req_id}")
    })
    |> ignore
    println("fs_read 2: \{req_id}")
  })
}

///|
async fn fs_write(
  loop_ : @uv.Loop,
  file : @uv.File,
  bufs : FixedArray[@uv.Buf],
  offset : Int64
) -> Int64!ErrorCode {
  suspend!!(fn(resolve, reject) {
    let req = @uv.fs_alloc()
    println("fs_write")
    @uv.fs_write(loop_, req, file, bufs, offset, fn(req) {
      let n_write = @uv.fs_get_result(req)
      if n_write < 0 {
        reject(ErrorCode(n_write.to_int()))
      } else {
        resolve(@uv.fs_get_result(req))
      }
      println("fs_write 1")
    })
    |> ignore
    println("fs_write 2")
  })
}

///|
type! ErrorCode Int

///|
async fn fs_close(loop_ : @uv.Loop, file : @uv.File) -> Unit!ErrorCode {
  suspend!!(fn(resolve, reject) {
    let req = @uv.fs_alloc()
    println("fs_close")
    @uv.fs_close(loop_, req, file, fn(req) {
      let rc = @uv.fs_get_result(req)
      if rc < 0 {
        reject(ErrorCode(rc.to_int()))
      } else {
        resolve(())
      }
      println("fs_close 1")
    })
    |> ignore()
    println("fs_close 2")
  })
}

///|
fn identity[T, U](x : T) -> U = "%identity"

///|
fn main {
  let loop_ = @uv.loop_alloc()
  run_async(fn!() {
    try {
      @uv.loop_init(loop_) |> ignore
      let file = open!!(loop_, b"main.mbt", @uv.O_RDONLY, 0)
      let buffer = FixedArray::make(1024, (0 : Byte))
      let iov = @uv.buf_alloc()
      let iovs : FixedArray[@uv.Buf] = FixedArray::make(1, 0L) |> identity
      iovs[0] = iov
      @uv.buf_init(iov, buffer) |> ignore
      loop fs_read!!(loop_, file, iovs, -1) {
        0 => {
          fs_close!!(loop_, file)
          return
        }
        n_read => {
          @uv.buf_set_len(iov, n_read.reinterpret_as_uint64()) |> ignore
          let nwritten = fs_write!!(loop_, 0, iovs, -1)
          if nwritten < nread {
            fs_close!!(loop_, file)
            return
          }
          continue fs_read!!(loop_, file, iovs, -1)
        }
      }
      @uv.buf_free(iov)
    } catch {
      _ => println("error")
    }
  })
  @uv.run(loop_, 0) |> ignore
  @uv.loop_close(loop_) |> ignore
  @uv.loop_free(loop_) |> ignore
}
