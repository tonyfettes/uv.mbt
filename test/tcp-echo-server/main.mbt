///|
fn run_async[T](f :  async() -> T) = "%async.run"

///|
async fn suspend[T](f : ((T) -> Unit) -> Unit) -> T = "%async.suspend"

///|
async fn fs_open(
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
async fn fs_read(
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
async fn fs_write(
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
async fn ip4_addr(ip : Bytes, port : Int) -> @auv.SockaddrIn {
  let addr = @auv.sockaddr_in_alloc()
  suspend!!(fn(k) {
    @auv.ip4_addr(ip, port, addr) |> ignore
    k(addr)
  })
}

///|
fn tcp_init(loop_ : @auv.Loop) -> @auv.Tcp {
  let tcp = @auv.tcp_alloc()
  @auv.tcp_init(loop_, tcp) |> ignore
  tcp
}

///|
async fn listen(stream : @auv.Stream, backlog : Int) -> Int {
  suspend!!(fn(k) {
    @auv.listen(stream, backlog, fn(_stream, status) { k(status) }) |> ignore
  })
}

///|
async fn read_start(stream : @auv.Stream) -> (Int64, @auv.Buf) {
  suspend!!(fn(k) {
    let alloc_cb = fn(_handle, n : UInt64, buf) {
      @auv.buf_init(buf, FixedArray::make(n.to_int(), (0 : Byte))) |> ignore
    }
    let read_cb = fn(_stream, n : Int64, buf) { k((n, buf)) }
    @auv.read_start(stream, alloc_cb, read_cb) |> ignore
  })
}

///|
async fn write(stream : @auv.Stream, bufs : FixedArray[@auv.Buf]) -> Int {
  suspend!!(fn(k) {
    let write = @auv.write_alloc()
    @auv.write(write, stream, bufs, fn(_write, status) { k(status) }) |> ignore
  })
}

///|
fn identity[T, U](x : T) -> U = "%identity"

///|
fn main {
  let loop_ = @auv.loop_alloc()
  @auv.loop_init(loop_) |> ignore
  run_async(fn() {
    let server = tcp_init(loop_)
    let addr = ip4_addr!!(b"0.0.0.0", 12345)
    let r = @auv.tcp_bind(server, addr, 0)
    if r != 0 {
      println("bind error: \{r}")
      return
    }
    println("bind succeed: \{r}")
    println("listening")
    let status = listen!!(@auv.tcp_to_stream(server), 128)
    println("listen status: \{status}")
    if status < 0 {
      println("listen error: \{status}")
    }
    while true {
      let client = tcp_init(loop_)
      if @auv.accept(@auv.tcp_to_stream(server), @auv.tcp_to_stream(client)) !=
        0 {
        @auv.close(@auv.stream_to_handle(@auv.tcp_to_stream(client)), fn(_) {  })
        |> ignore
        break
      }
      println("accept succeed")
      loop read_start!!(@auv.tcp_to_stream(client)) {
        (nread, buf) => {
          println("nread: \{nread}")
          @auv.buf_set_len(buf, nread.reinterpret_as_uint64())
          let bufs : FixedArray[@auv.Buf] = FixedArray::make(1, 0L) |> identity
          bufs[0] = buf
          write!!(@auv.tcp_to_stream(client), bufs) |> ignore
          continue read_start!!(@auv.tcp_to_stream(client))
        }
      }
    }
  })
  |> ignore
  @auv.loop_run(loop_, 0) |> ignore
  @auv.loop_close(loop_) |> ignore
  @auv.loop_free(loop_) |> ignore
}
