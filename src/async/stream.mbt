///|
type Stream @uv.Stream

///|
trait ToStream {
  to_stream(Self) -> Stream
}

///|
pub async fn Stream::listen(self : Stream, backlog : Int) -> Unit!Errno {
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
pub async fn Stream::read_start(self : Stream) -> BytesView!Errno {
  async_suspend!!(fn(resolve, reject) {
    let alloc_cb = fn(_, n : UInt64, buf) {
      @uv.buf_init(buf, Bytes::make(n.to_int(), (0 : Byte)), 0)
    }
    let read_cb = fn(_, n : Int64, buf) {
      resolve(@uv.buf_get(buf, 0, n.to_int()))
    }
    let status = @uv.read_start(self._, alloc_cb, read_cb)
    if status < 0 {
      reject(Errno(status))
    }
  })
}
