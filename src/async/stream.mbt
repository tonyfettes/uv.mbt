///|
struct ReadableStream {
  buffer : @buffer.T
  stream : @uv.Stream
}

///|
fn ReadableStream::new[ToStream : @uv.ToStream](
  stream : ToStream,
  buffer~ : @buffer.T = @buffer.new()
) -> ReadableStream {
  ReadableStream::{ buffer, stream: stream.to_stream() }
}

///|
fn ReadableStream::read(self : ReadableStream) -> Unit!Async + Error {
  suspend_with_error!(fn(resolve, reject) {
    try {
      self.stream.read_start!(
        fn(_, _) { Bytes::make(256, 0)[:] },
        fn(_, count, bytes) { self.buffer.write_bytesview(bytes[:count]) },
        fn(_, e) {
          self.stream.read_stop?() |> ignore()
          self.stream.close(fn(_) {
            if e is Errno(EOF) {
              resolve(())
            } else {
              reject(e)
            }
          })
        },
      )
    } catch {
      e => self.stream.close(fn(_) { reject(e) })
    }
  })
}

///|
pub fn ReadableStream::bytes(self : ReadableStream) -> Bytes {
  self.buffer.contents()
}

///|
pub fn ReadableStream::text(
  self : ReadableStream,
  encoding~ : @encoding.Encoding = UTF8
) -> String! {
  @encoding.decode!(self.buffer.contents(), encoding~)
}

///|
priv struct WritableStream {
  bytes : @bytes.View
  stream : @uv.Stream
}

///|
fn WritableStream::new[ToStream : @uv.ToStream](
  stream : ToStream,
  bytes : @bytes.View
) -> WritableStream {
  WritableStream::{ bytes, stream: stream.to_stream() }
}

///|
fn WritableStream::write(self : WritableStream) -> Unit!Async + Error {
  suspend_with_error!(fn(resolve, reject) {
    try {
      self.stream.write!([self.bytes], fn(_) { resolve(()) }, fn(_, e) {
        reject(e)
      })
    } catch {
      e => reject(e)
    }
  })
}
