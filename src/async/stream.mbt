///|
type Stream @uv.Stream

///|
priv trait ToStream {
  to_stream(Self) -> Stream
}

///|
pub async fn ToStream::listen(self : Stream, backlog : Int) -> Unit!Errno {
  async_suspend!!(fn(resolve, reject) {
    let r = @uv.listen(self._, backlog, fn(_stream, status) {
      if status < 0 {
        reject(Errno(status))
      } else {
        resolve(())
      }
    })
    if r < 0 {
      reject(Errno(r))
    }
  })
}

///|
pub async fn Stream::read(self : Stream) -> @bytes.View!Errno {
  async_suspend!!(fn(resolve, reject) {
    let alloc_cb = fn(_, n : UInt64, buf) {
      let bytes = Bytes::make(n.to_int(), (0 : Byte))
      @uv.buf_init(buf, bytes, 0, bytes.length())
    }
    let read_cb = fn(_, n : Int64, buf) {
      @uv.read_stop(self._) |> ignore()
      resolve(@uv.buf_get(buf)[:n.to_int()])
    }
    let status = @uv.read_start(self._, alloc_cb, read_cb)
    if status < 0 {
      reject(Errno(status))
    }
  })
}

///|
pub async fn Stream::write(self : Stream, bytes : @bytes.View) -> @bytes.View!Errno {
  async_suspend!!(fn(resolve, reject) {
    let buf = @uv.buf_alloc()
    let bytes = MutableBytesView::of_bytes_view(bytes)
    @uv.buf_init(buf, bytes.bytes, bytes.start, bytes.len - bytes.start)
    let bufs : FixedArray[@uv.Buf] = [buf]
    let write_cb = fn(_, status) {
      if status < 0 {
        reject(Errno(status))
      } else {
        resolve(bytes.to_bytes_view()[:status])
      }
    }
    let write = @uv.write_alloc()
    let status = @uv.write(write, self._, bufs, write_cb)
    if status < 0 {
      reject(Errno(status))
    }
  })
}
